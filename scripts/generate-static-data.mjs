/**
 * Build-time static data generator.
 * Fetches all data from Supabase and writes compressed JSON files to public/data/.
 * These files are loaded into DuckDB-WASM on the client — every visitor has all data locally.
 *
 * Output files:
 *   /public/data/products.json  — gold products (compact keys, null-stripped)
 *   /public/data/meta.json      — categories, countries, sources
 *   /public/data/bronze.json    — raw bronze records (compact)
 *   /public/data/datapoints.json — product_data_points with source info
 *
 * Usage: node scripts/generate-static-data.mjs
 * Requires: NUXT_PUBLIC_SUPABASE_URL + NUXT_PUBLIC_SUPABASE_ANON_KEY in env
 */

import { createClient } from "@supabase/supabase-js";
import { writeFileSync, mkdirSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { config } from "dotenv";

// Load .env
const __dirname = dirname(fileURLToPath(import.meta.url));
config({ path: resolve(__dirname, "../.env") });

const SUPABASE_URL = process.env.NUXT_PUBLIC_SUPABASE_URL;
const SUPABASE_KEY = process.env.NUXT_PUBLIC_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error(
    "Missing NUXT_PUBLIC_SUPABASE_URL or NUXT_PUBLIC_SUPABASE_ANON_KEY",
  );
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
const outDir = resolve(__dirname, "../public/data");

async function fetchAll(table, options = {}) {
  const { order, ascending, select } = options;

  // Paginate to handle >1000 rows
  const BATCH = 1000;
  const all = [];
  let from = 0;

  while (true) {
    let q = supabase.from(table).select(select || "*");
    if (order) {
      q = q.order(order, { ascending: ascending ?? true, nullsFirst: false });
    }
    q = q.range(from, from + BATCH - 1);
    const { data, error } = await q;
    if (error) throw new Error(`Failed to fetch ${table}: ${error.message}`);
    if (!data || data.length === 0) break;
    all.push(...data);
    if (data.length < BATCH) break;
    from += BATCH;
  }

  return all;
}

// --- Compact key mappings ---

const PRODUCT_KEYS = {
  id: "i",
  slug: "s",
  name: "n",
  logo_url: "lo",
  website_url: "wu",
  company: "co",
  country_code: "cc",
  country_name: "cn",
  employees: "em",
  category: "ca",
  category_slug: "cs",
  description: "d",
  founded_year: "fy",
  mrr: "m",
  revenue_last_30d: "r30",
  growth_30d: "g30",
  customers: "cu",
  founders: "fo",
  trustmrr_url: "tu",
  trustmrr_rank: "tr",
  primary_source: "ps",
  primary_source_url: "pu",
  latest_sourced_at: "ls",
};

const BRONZE_KEYS = {
  id: "i",
  source_name: "sn",
  external_id: "ei",
  raw_data: "rd",
  fetched_at: "fa",
};

const DATAPOINT_KEYS = {
  id: "i",
  product_id: "pi",
  field_name: "fn",
  field_value: "fv",
  source_id: "si",
  sourced_at: "sa",
  data_as_of: "da",
  is_current: "ic",
};

function compactRow(row, keyMap) {
  const out = {};
  for (const [long, short] of Object.entries(keyMap)) {
    const val = row[long];
    if (val != null && val !== "") {
      out[short] = val;
    }
  }
  return out;
}

async function main() {
  const start = Date.now();
  console.log("[static-data] Fetching data from Supabase...");

  // Fetch all tables in parallel
  const [products, categories, countries, sources, bronzeRecords, dataPoints] =
    await Promise.all([
      fetchAll("products_gold", { order: "mrr", ascending: false }),
      fetchAll("categories", { order: "name" }),
      fetchAll("countries", { order: "name_de" }),
      fetchAll("sources", { order: "name" }),
      fetchAll("bronze_raw_records", { order: "fetched_at", ascending: false }),
      fetchAll("product_data_points", { order: "field_name" }),
    ]);

  console.log(
    `[static-data] Fetched: ${products.length} products, ${bronzeRecords.length} bronze, ${dataPoints.length} data points`,
  );

  // Compact products
  const compactProducts = products.map((p) => compactRow(p, PRODUCT_KEYS));

  // Compact bronze records
  const compactBronze = bronzeRecords.map((r) => compactRow(r, BRONZE_KEYS));

  // Compact data points (only current ones for detail pages)
  const currentDataPoints = dataPoints.filter((dp) => dp.is_current);
  const compactDataPoints = currentDataPoints.map((dp) =>
    compactRow(dp, DATAPOINT_KEYS),
  );

  // Build version hash (short timestamp-based, used for cache busting)
  const buildVersion = Date.now().toString(36);

  // Meta (small tables — no compression needed)
  const meta = {
    categories,
    countries,
    sources,
    generatedAt: new Date().toISOString(),
    buildVersion,
  };

  // Write files
  mkdirSync(outDir, { recursive: true });

  const files = [
    { name: "products.json", data: compactProducts },
    { name: "meta.json", data: meta },
    { name: "bronze.json", data: compactBronze },
  ];

  let totalSize = 0;
  for (const f of files) {
    const json = JSON.stringify(f.data);
    const path = resolve(outDir, f.name);
    writeFileSync(path, json);
    const sizeKB = (Buffer.byteLength(json) / 1024).toFixed(0);
    totalSize += Buffer.byteLength(json);
    console.log(`[static-data] Written ${f.name} (${sizeKB} KB)`);
  }

  // Split datapoints into chunks < 20 MB (Cloudflare Pages limit: 25 MB per file)
  const MAX_CHUNK_BYTES = 20 * 1024 * 1024;
  const dpChunks = [];
  let currentChunk = [];
  let currentSize = 2; // account for "[]"

  for (const dp of compactDataPoints) {
    const itemJson = JSON.stringify(dp);
    const itemSize = Buffer.byteLength(itemJson) + 1; // +1 for comma
    if (currentSize + itemSize > MAX_CHUNK_BYTES && currentChunk.length > 0) {
      dpChunks.push(currentChunk);
      currentChunk = [];
      currentSize = 2;
    }
    currentChunk.push(dp);
    currentSize += itemSize;
  }
  if (currentChunk.length > 0) dpChunks.push(currentChunk);

  for (let i = 0; i < dpChunks.length; i++) {
    const name =
      dpChunks.length === 1 ? "datapoints.json" : `datapoints-${i}.json`;
    const json = JSON.stringify(dpChunks[i]);
    writeFileSync(resolve(outDir, name), json);
    const sizeKB = (Buffer.byteLength(json) / 1024).toFixed(0);
    totalSize += Buffer.byteLength(json);
    console.log(`[static-data] Written ${name} (${sizeKB} KB)`);
  }

  // Write manifest so the client knows how many chunks exist
  const dpManifest = {
    chunks: dpChunks.length,
    total: compactDataPoints.length,
  };
  writeFileSync(
    resolve(outDir, "datapoints-manifest.json"),
    JSON.stringify(dpManifest),
  );
  console.log(
    `[static-data] Datapoints: ${compactDataPoints.length} rows in ${dpChunks.length} chunk(s)`,
  );

  // Remove old all.json if it exists
  try {
    const { unlinkSync } = await import("fs");
    unlinkSync(resolve(outDir, "all.json"));
    console.log("[static-data] Removed old all.json");
  } catch {
    // ignore if not exists
  }

  const elapsed = ((Date.now() - start) / 1000).toFixed(1);
  console.log(
    `[static-data] Total: ${(totalSize / 1024).toFixed(0)} KB, Time: ${elapsed}s`,
  );
}

main().catch((err) => {
  console.error("[static-data] Fatal:", err.message);
  process.exit(1);
});
