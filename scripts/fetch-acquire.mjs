#!/usr/bin/env node
/**
 * Fetch SaaS listings from Acquire.com marketplace.
 * Uses Firebase Auth + their internal v1-search Cloud Function.
 * Loads raw data into Bronze layer, transforms to Silver, refreshes Gold.
 *
 * Usage: ACQUIRE_EMAIL=... ACQUIRE_PASSWORD=... SUPABASE_ACCESS_TOKEN=... node scripts/fetch-acquire.mjs
 *
 * Env vars can also be loaded from .env file.
 */

import { writeFileSync, readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import {
  startRun,
  loadBronzeRecords,
  transformRun,
  autoCategorize,
  refreshGold,
  completeRun,
  failRun,
} from "./lib/pipeline.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..");

// Load .env if present
try {
  const envFile = readFileSync(resolve(repoRoot, ".env"), "utf-8");
  for (const line of envFile.split("\n")) {
    const match = line.match(/^\s*([\w]+)\s*=\s*(.+?)\s*$/);
    if (match && !process.env[match[1]]) {
      process.env[match[1]] = match[2];
    }
  }
} catch {
  // .env not found, continue with existing env
}

const ACQUIRE_EMAIL = process.env.ACQUIRE_EMAIL;
const ACQUIRE_PASSWORD = process.env.ACQUIRE_PASSWORD;
const FIREBASE_API_KEY = "AIzaSyDUxAmTGc7LhbduowuDOJF0YZl5xXrmJaI"; // public key from acquire.com app

if (!ACQUIRE_EMAIL || !ACQUIRE_PASSWORD) {
  console.error(
    "Error: ACQUIRE_EMAIL and ACQUIRE_PASSWORD environment variables required",
  );
  console.error(
    "Usage: ACQUIRE_EMAIL=... ACQUIRE_PASSWORD=... SUPABASE_ACCESS_TOKEN=... node scripts/fetch-acquire.mjs",
  );
  process.exit(1);
}

const SEARCH_URL =
  "https://us-central1-microacquire.cloudfunctions.net/v1-search";
const PAGE_SIZE = 50;

// ============================================================
// Firebase Auth — get ID token via email/password sign-in
// ============================================================

async function getFirebaseToken() {
  console.log("Authenticating with Firebase...");
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Referer: "https://app.acquire.com/",
        Origin: "https://app.acquire.com",
      },
      body: JSON.stringify({
        email: ACQUIRE_EMAIL,
        password: ACQUIRE_PASSWORD,
        returnSecureToken: true,
      }),
    },
  );

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firebase auth failed (${res.status}): ${err}`);
  }

  const data = await res.json();
  console.log(`Authenticated as ${data.email}`);
  return data.idToken;
}

// ============================================================
// Search API — paginated fetch of all SaaS listings
// ============================================================

async function searchListings(token, skip = 0, take = PAGE_SIZE) {
  const body = {
    data: {
      marketplace: {
        query: {
          ids: { exclude: [], only: null },
          dateFounded: [{ range: { gte: null, lte: Date.now() }, type: "and" }],
          type: [
            {
              match: "SaaS",
              type: ["and", { operator: "or", index: 2 }],
            },
          ],
          // No askingPrice filter — get all SaaS listings
          revenueMultiple: [{ range: { gte: 0, lte: null }, type: "and" }],
          profitMultiple: [{ range: { gte: 0, lte: null }, type: "and" }],
          totalRevenueAnnual: [{ range: { gte: 0, lte: null }, type: "and" }],
          annualProfit: [{ range: { gte: 0, lte: null }, type: "and" }],
        },
        skip,
        take,
        order: [{ by: "date", order: "desc", salt: null }],
      },
      __meta: {
        referrer: "https://app.acquire.com/all-listing",
        cookie: "",
      },
    },
  };

  const res = await fetch(SEARCH_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      Origin: "https://app.acquire.com",
      Referer: "https://app.acquire.com/",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(
      `Search API failed (${res.status}): ${err.substring(0, 500)}`,
    );
  }

  const data = await res.json();
  const marketplace = data.result?.marketplace;
  return {
    results: marketplace?.results || [],
    total: marketplace?.total || 0,
  };
}

async function fetchAllListings(token) {
  console.log("Fetching SaaS listings from Acquire.com...");

  const first = await searchListings(token, 0, PAGE_SIZE);
  const total = first.total;
  console.log(`Total SaaS listings available: ${total}`);

  const allResults = [...first.results];

  for (let skip = PAGE_SIZE; skip < total; skip += PAGE_SIZE) {
    console.log(
      `  Fetching ${skip}–${Math.min(skip + PAGE_SIZE, total)} of ${total}...`,
    );
    await new Promise((r) => setTimeout(r, 1000)); // rate limit
    const page = await searchListings(token, skip, PAGE_SIZE);
    allResults.push(...page.results);
  }

  console.log(`Fetched ${allResults.length} listings total`);
  return allResults;
}

// ============================================================
// Map to Bronze records
// ============================================================

function mapToBronzeRecord(listing) {
  const mrr = listing.totalRevenueAnnual
    ? Math.round(listing.totalRevenueAnnual / 12)
    : 0;

  return {
    externalId: listing.startupId,
    rawData: {
      // Fields expected by current transform_bronze_to_silver
      n: listing.listingHeadline || listing.slug || listing.startupId,
      m: mrr,
      c: listing.type || "SaaS",
      d: listing.about || null,
      u: null, // no public website URL in search results

      // Rich data for future transform enhancements
      startupId: listing.startupId,
      uid: listing.uid,
      slug: listing.slug,
      listingHeadline: listing.listingHeadline,
      askingPrice: listing.askingPrice || 0,
      totalRevenueAnnual: listing.totalRevenueAnnual || 0,
      totalProfitAnnual: listing.totalProfitAnnual || 0,
      totalGrowthAnnual: listing.totalGrowthAnnual || 0,
      location: listing.location || null,
      dateFounded: listing.dateFounded || null,
      team: listing.team || null,
      customers: listing.customers || null,
      keywords: listing.keywords || [],
      businessVerified: listing.businessVerified || false,
      techStack: listing.techStack || null,
      techStackKeywords: listing.techStackKeywords || [],
      businessModel: listing.businessModel || null,
      businessModelKeywords: listing.businessModelKeywords || [],
      competitors: listing.competitors || [],
      revenueMultiple: listing.revenueMultiple || null,
      profitMultiple: listing.profitMultiple || null,
      listingType: listing.listingType || null,
      acquireUrl: `https://app.acquire.com/startup/${listing.uid}/${listing.startupId}`,
    },
  };
}

// ============================================================
// Main
// ============================================================

async function main() {
  const run = await startRun("acquire");

  try {
    const token = await getFirebaseToken();
    const listings = await fetchAllListings(token);

    // Filter to SaaS only (should already be, but be safe)
    const saasListings = listings.filter(
      (l) => l.type === "SaaS" || l.type === "saas",
    );
    console.log(`${saasListings.length} SaaS listings`);

    // Build bronze records
    const records = saasListings.map(mapToBronzeRecord);

    // Save JSON backup
    try {
      writeFileSync(
        resolve(repoRoot, "data", "acquire_listings.json"),
        JSON.stringify(
          {
            meta: {
              fetchedAt: new Date().toISOString(),
              count: records.length,
            },
            listings: records.map((r) => r.rawData),
          },
          null,
          2,
        ),
      );
      console.log(`Saved JSON backup: data/acquire_listings.json`);
    } catch {
      console.log("Skipped JSON backup (data/ dir may not exist)");
    }

    // Load into Bronze
    const bronzeResult = await loadBronzeRecords(run.runId, "acquire", records);

    // Transform Bronze -> Silver
    const transformResult = await transformRun(run.runId);

    // Auto-categorize + Refresh Gold
    await autoCategorize();
    await refreshGold();

    // Complete run
    await completeRun(run.runId, {
      fetched: saasListings.length,
      loaded: bronzeResult.loaded,
      errors: bronzeResult.errors + transformResult.errors,
      metadata: {
        totalListings: listings.length,
        saasListings: saasListings.length,
        transformInserts: transformResult.inserts,
        transformUpdates: transformResult.updates,
        transformSkips: transformResult.skips,
      },
    });

    console.log("\n=== COMPLETE ===");
    console.log(
      `Total fetched: ${listings.length}, SaaS: ${saasListings.length}`,
    );
    console.log(
      `Bronze: ${bronzeResult.loaded} loaded, ${bronzeResult.errors} errors`,
    );
    console.log(
      `Silver: ${transformResult.inserts} inserts, ${transformResult.updates} updates, ${transformResult.skips} skips`,
    );

    // Print top 10 by MRR
    const byMrr = [...records].sort(
      (a, b) => (b.rawData.m || 0) - (a.rawData.m || 0),
    );
    console.log("\nTop 10 by estimated MRR:");
    byMrr.slice(0, 10).forEach((r, i) => {
      console.log(
        `  ${i + 1}. ${r.rawData.n?.substring(0, 60)} - $${r.rawData.m?.toLocaleString()}/mo (asking: $${(r.rawData.askingPrice || 0).toLocaleString()})`,
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
