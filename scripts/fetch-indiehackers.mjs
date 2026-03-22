#!/usr/bin/env node
/**
 * Fetch IndieHackers product data from their Firebase database.
 * Loads raw data into Bronze layer, transforms to Silver, refreshes Gold.
 *
 * Usage: SUPABASE_ACCESS_TOKEN=... node scripts/fetch-indiehackers.mjs
 */

import { writeFileSync } from "fs";
import {
  startRun,
  loadBronzeRecords,
  transformRun,
  autoCategorize,
  refreshGold,
  completeRun,
  failRun,
} from "./lib/pipeline.mjs";

const FIREBASE_BASE = "https://indie-hackers.firebaseio.com";

async function fetchJSON(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.json();
}

async function fetchAllProductKeys() {
  console.log("Fetching product keys (shallow)...");
  const data = await fetchJSON(`${FIREBASE_BASE}/products.json?shallow=true`);
  const keys = Object.keys(data);
  console.log(`Found ${keys.length} total product keys`);
  return keys;
}

async function fetchProductBatch(keys) {
  const results = [];
  const batchSize = 20;

  for (let i = 0; i < keys.length; i += batchSize) {
    const batch = keys.slice(i, i + batchSize);
    const promises = batch.map(async (key) => {
      try {
        const data = await fetchJSON(`${FIREBASE_BASE}/products/${key}.json`);
        return { key, ...data };
      } catch (err) {
        console.error(`  Error fetching ${key}: ${err.message}`);
        return null;
      }
    });

    const batchResults = await Promise.all(promises);
    results.push(...batchResults.filter(Boolean));

    if (i % 200 === 0 && i > 0) {
      console.log(`  Fetched ${i}/${keys.length} products...`);
    }

    await new Promise((r) => setTimeout(r, 200));
  }

  return results;
}

async function fetchUserName(userId) {
  try {
    const data = await fetchJSON(
      `${FIREBASE_BASE}/users/${userId}.json?shallow=false`,
    );
    if (data) {
      return {
        name: data.name || data.displayName || null,
        twitterHandle: data.twitterHandle || null,
      };
    }
  } catch {
    // ignore
  }
  return null;
}

async function main() {
  const run = await startRun("indiehackers");

  try {
    const allKeys = await fetchAllProductKeys();

    console.log("Fetching all product data...");
    const allProducts = await fetchProductBatch(allKeys);
    console.log(`Fetched ${allProducts.length} products total`);

    // Filter to products with revenue > 0
    const withRevenue = allProducts.filter(
      (p) => p.selfReportedMonthlyRevenue && p.selfReportedMonthlyRevenue > 0,
    );
    console.log(`${withRevenue.length} products have revenue > $0`);

    // Sort by revenue descending
    withRevenue.sort(
      (a, b) =>
        (b.selfReportedMonthlyRevenue || 0) -
        (a.selfReportedMonthlyRevenue || 0),
    );

    // Get founder info for top products
    console.log("Fetching founder data for products with revenue...");
    const founderCache = {};

    for (const product of withRevenue.slice(0, 200)) {
      if (product.userRoles) {
        const userIds = Object.keys(product.userRoles);
        for (const uid of userIds) {
          if (!founderCache[uid]) {
            founderCache[uid] = await fetchUserName(uid);
            await new Promise((r) => setTimeout(r, 100));
          }
        }
      }
    }

    // Build bronze records with raw data + resolved founder info
    const records = withRevenue.map((p) => {
      const founders = [];
      if (p.userRoles) {
        for (const [uid, roleData] of Object.entries(p.userRoles)) {
          const userData = founderCache[uid];
          founders.push({
            role: roleData.role || "Founder",
            name: userData?.name || null,
            twitterHandle: userData?.twitterHandle || p.twitterHandle || null,
          });
        }
      }

      return {
        externalId: p.key,
        rawData: {
          name: p.name || p.key,
          monthlyRevenue: p.selfReportedMonthlyRevenue || 0,
          revenueTimestamp: p.selfReportedRevenueTimestamp || null,
          description: p.description || null,
          tagline: p.tagline || null,
          websiteUrl: p.websiteUrl || null,
          twitterHandle: p.twitterHandle || null,
          startDate: p.startDateStr || null,
          country: p.country || null,
          city: p.city || null,
          founders,
          tags: p.tagIds ? Object.keys(p.tagIds) : [],
          indiehackersUrl: `https://www.indiehackers.com/product/${p.key}`,
        },
      };
    });

    // Save JSON backup
    const scriptDir = new URL(".", import.meta.url).pathname;
    const repoRoot = scriptDir.replace(/\/scripts\/$/, "");
    try {
      writeFileSync(
        `${repoRoot}/data/indiehackers_products.json`,
        JSON.stringify(
          {
            meta: {
              fetchedAt: new Date().toISOString(),
              count: records.length,
            },
            products: records.map((r) => r.rawData),
          },
          null,
          2,
        ),
      );
      console.log(`Saved JSON backup: data/indiehackers_products.json`);
    } catch {
      console.log("Skipped JSON backup");
    }

    // Load into Bronze
    const bronzeResult = await loadBronzeRecords(
      run.runId,
      "indiehackers",
      records,
    );

    // Transform Bronze -> Silver
    const transformResult = await transformRun(run.runId);

    // Auto-categorize + Refresh Gold
    await autoCategorize();
    await refreshGold();

    // Complete run
    await completeRun(run.runId, {
      fetched: withRevenue.length,
      loaded: bronzeResult.loaded,
      errors: bronzeResult.errors + transformResult.errors,
      metadata: {
        totalProducts: allProducts.length,
        productsWithRevenue: withRevenue.length,
        transformInserts: transformResult.inserts,
        transformUpdates: transformResult.updates,
        transformSkips: transformResult.skips,
      },
    });

    console.log("\n=== COMPLETE ===");
    console.log(
      `Total fetched: ${allProducts.length}, with revenue: ${withRevenue.length}`,
    );
    console.log(
      `Bronze: ${bronzeResult.loaded} loaded, ${bronzeResult.errors} errors`,
    );
    console.log(
      `Silver: ${transformResult.inserts} inserts, ${transformResult.updates} updates, ${transformResult.skips} skips`,
    );

    // Print top 10
    console.log("\nTop 10 by revenue:");
    records.slice(0, 10).forEach((r, i) => {
      console.log(
        `  ${i + 1}. ${r.rawData.name} - $${r.rawData.monthlyRevenue}/mo`,
      );
    });
  } catch (err) {
    await failRun(run.runId, err.message);
    throw err;
  }
}

main().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
