import * as duckdb from "@duckdb/duckdb-wasm";

// --- Module-level singletons ---
let dbInstance: duckdb.AsyncDuckDB | null = null;
let connInstance: duckdb.AsyncDuckDBConnection | null = null;
let initPromise: Promise<void> | null = null;
let dataLoadPromise: Promise<void> | null = null;
let bronzeLoadPromise: Promise<void> | null = null;
let datapointsLoadPromise: Promise<void> | null = null;
let dataLoaded = false;
let bronzeLoaded = false;
let datapointsLoaded = false;
let buildVersion = "";

// --- Key mappings (short → long) for decompression ---

const PRODUCT_KEY_MAP: Record<string, string> = {
  i: "id",
  s: "slug",
  n: "name",
  lo: "logo_url",
  wu: "website_url",
  co: "company",
  cc: "country_code",
  cn: "country_name",
  em: "employees",
  ca: "category",
  cs: "category_slug",
  d: "description",
  fy: "founded_year",
  m: "mrr",
  r30: "revenue_last_30d",
  g30: "growth_30d",
  cu: "customers",
  fo: "founders",
  tu: "trustmrr_url",
  tr: "trustmrr_rank",
  ps: "primary_source",
  pu: "primary_source_url",
  ls: "latest_sourced_at",
};

const BRONZE_KEY_MAP: Record<string, string> = {
  i: "id",
  sn: "source_name",
  ei: "external_id",
  rd: "raw_data",
  fa: "fetched_at",
};

const DATAPOINT_KEY_MAP: Record<string, string> = {
  i: "id",
  pi: "product_id",
  fn: "field_name",
  fv: "field_value",
  si: "source_id",
  sa: "sourced_at",
  da: "data_as_of",
  ic: "is_current",
};

function expandRow(
  compact: Record<string, unknown>,
  keyMap: Record<string, string>,
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [short, value] of Object.entries(compact)) {
    const long = keyMap[short] || short;
    out[long] = value;
  }
  return out;
}

async function init() {
  if (dbInstance) return;

  const bundles = duckdb.getJsDelivrBundles();
  const bundle = await duckdb.selectBundle(bundles);

  const workerUrl = URL.createObjectURL(
    new Blob([`importScripts("${bundle.mainWorker!}");`], {
      type: "text/javascript",
    }),
  );

  const worker = new Worker(workerUrl);
  const logger = new duckdb.ConsoleLogger();
  const db = new duckdb.AsyncDuckDB(logger, worker);
  await db.instantiate(bundle.mainModule, bundle.pthreadWorker);
  URL.revokeObjectURL(workerUrl);

  dbInstance = db;
  connInstance = await db.connect();
}

/**
 * Singleton DuckDB-WASM instance — the central data layer.
 *
 * All pages load data from static JSON files (built at deploy time)
 * into DuckDB tables. Every visitor has all data locally.
 *
 * Usage:
 *   const duck = useDuckDB()
 *   await duck.ensureData()          // loads gold + meta (idempotent)
 *   await duck.ensureBronze()        // lazy-loads bronze data
 *   await duck.ensureDatapoints()    // lazy-loads product_data_points
 *   const rows = await duck.query<T>('SELECT * FROM gold')
 */
export function useDuckDB() {
  async function initialize(): Promise<void> {
    if (!initPromise) {
      initPromise = init();
    }
    await initPromise;
  }

  /** Load gold products + meta tables (categories, countries, sources). Idempotent. */
  async function ensureData(): Promise<void> {
    if (dataLoaded) return;
    if (dataLoadPromise) return dataLoadPromise;

    dataLoadPromise = (async () => {
      await initialize();

      // Load meta first (small, contains buildVersion for cache busting)
      const metaRes = await fetch("/data/meta.json");
      if (!metaRes.ok)
        throw new Error(`Failed to load meta.json: ${metaRes.status}`);

      const meta = (await metaRes.json()) as {
        categories: Record<string, unknown>[];
        countries: Record<string, unknown>[];
        sources: Record<string, unknown>[];
        generatedAt: string;
        buildVersion?: string;
      };

      // Use buildVersion as cache-buster for all subsequent fetches
      buildVersion = meta.buildVersion ?? "";
      const v = buildVersion ? `?v=${buildVersion}` : "";

      const productsRes = await fetch(`/data/products.json${v}`);
      if (!productsRes.ok)
        throw new Error(`Failed to load products.json: ${productsRes.status}`);

      const compactProducts = (await productsRes.json()) as Record<
        string,
        unknown
      >[];

      // Expand short keys back to full names
      const products = compactProducts.map((p) =>
        expandRow(p, PRODUCT_KEY_MAP),
      );

      // Register as DuckDB tables
      await insertJSON("gold", products);
      await insertJSON("categories", meta.categories);
      await insertJSON("countries", meta.countries);
      await insertJSON("sources", meta.sources);

      dataLoaded = true;
    })();

    return dataLoadPromise;
  }

  /** Lazy-load bronze raw records. Only loaded when bronze page is visited. */
  async function ensureBronze(): Promise<void> {
    if (bronzeLoaded) return;
    if (bronzeLoadPromise) return bronzeLoadPromise;

    bronzeLoadPromise = (async () => {
      await initialize();

      const v = buildVersion ? `?v=${buildVersion}` : "";
      const res = await fetch(`/data/bronze.json${v}`);
      if (!res.ok) throw new Error(`Failed to load bronze.json: ${res.status}`);

      const compactBronze = (await res.json()) as Record<string, unknown>[];

      // Expand and transform for DuckDB (extract fields from raw_data)
      const bronze = compactBronze.map((r) => {
        const expanded = expandRow(r, BRONZE_KEY_MAP);
        const raw = expanded.raw_data as Record<string, unknown> | null;

        let name = expanded.external_id as string;
        let mrr: number | null = null;
        let category: string | null = null;
        let country: string | null = null;
        let url: string | null = null;

        if (raw) {
          // Name: full key or compact key (n) or StarterStory (productName)
          for (const key of ["name", "n", "productName"]) {
            if (typeof raw[key] === "string" && raw[key]) {
              name = raw[key] as string;
              break;
            }
          }

          // MRR: nested revenue.mrr, or top-level mrr/monthlyRevenue, or compact (m)
          if (raw.revenue && typeof raw.revenue === "object") {
            const rev = raw.revenue as Record<string, unknown>;
            if (typeof rev.mrr === "number" && rev.mrr > 0) mrr = rev.mrr;
          }
          if (mrr === null) {
            for (const key of ["mrr", "monthlyRevenue", "m"]) {
              if (typeof raw[key] === "number" && (raw[key] as number) > 0) {
                mrr = raw[key] as number;
                break;
              }
            }
          }

          // Category: full key or compact (c)
          for (const key of ["category", "c"]) {
            if (typeof raw[key] === "string" && raw[key]) {
              category = raw[key] as string;
              break;
            }
          }

          // Country: full key or compact (co)
          for (const key of ["country", "co"]) {
            if (typeof raw[key] === "string" && raw[key]) {
              country = raw[key] as string;
              break;
            }
          }

          // Extract URL from various possible field names
          for (const key of [
            "url",
            "website",
            "websiteUrl",
            "website_url",
            "link",
            "homepage",
            "u",
          ]) {
            if (typeof raw[key] === "string" && raw[key]) {
              url = raw[key] as string;
              break;
            }
          }
        }

        return {
          id: expanded.id,
          source_name: expanded.source_name,
          name,
          external_id: expanded.external_id,
          mrr,
          category,
          country,
          url,
          fetched_at: expanded.fetched_at,
          raw_json: raw ? JSON.stringify(raw, null, 2) : "{}",
        };
      });

      await insertJSON("bronze", bronze);
      bronzeLoaded = true;
    })();

    return bronzeLoadPromise;
  }

  /** Lazy-load product data points (for detail page sources sidebar). */
  async function ensureDatapoints(): Promise<void> {
    if (datapointsLoaded) return;
    if (datapointsLoadPromise) return datapointsLoadPromise;

    datapointsLoadPromise = (async () => {
      await ensureData(); // Need sources table for joins

      // Load manifest to check for chunked datapoints
      const v = buildVersion ? `?v=${buildVersion}` : "";
      const manifestRes = await fetch(`/data/datapoints-manifest.json${v}`);
      let chunkCount = 1;
      if (manifestRes.ok) {
        const manifest = (await manifestRes.json()) as { chunks: number };
        chunkCount = manifest.chunks;
      }

      // Load all chunks (single file or multiple)
      const allDps: Record<string, unknown>[] = [];
      for (let i = 0; i < chunkCount; i++) {
        const url =
          chunkCount === 1
            ? `/data/datapoints.json${v}`
            : `/data/datapoints-${i}.json${v}`;
        const res = await fetch(url);
        if (!res.ok) throw new Error(`Failed to load ${url}: ${res.status}`);
        const compactDps = (await res.json()) as Record<string, unknown>[];
        allDps.push(...compactDps);
      }

      const dps = allDps.map((dp) => expandRow(dp, DATAPOINT_KEY_MAP));
      await insertJSON("data_points", dps);
      datapointsLoaded = true;
    })();

    return datapointsLoadPromise;
  }

  async function query<T = Record<string, unknown>>(sql: string): Promise<T[]> {
    if (!connInstance) throw new Error("DuckDB not initialized");
    const result = await connInstance.query(sql);
    return result.toArray().map((row) => row.toJSON() as T);
  }

  async function run(sql: string): Promise<void> {
    if (!connInstance) throw new Error("DuckDB not initialized");
    await connInstance.query(sql);
  }

  async function insertJSON(
    tableName: string,
    data: Record<string, unknown>[],
  ): Promise<void> {
    if (!dbInstance || !connInstance) throw new Error("DuckDB not initialized");

    const json = JSON.stringify(data);
    await dbInstance.registerFileText(`${tableName}.json`, json);
    await connInstance.query(
      `CREATE OR REPLACE TABLE ${tableName} AS SELECT * FROM read_json_auto('${tableName}.json')`,
    );
  }

  function isReady(): boolean {
    return dbInstance !== null && connInstance !== null;
  }

  function isDataLoaded(): boolean {
    return dataLoaded;
  }

  return {
    initialize,
    ensureData,
    ensureBronze,
    ensureDatapoints,
    query,
    run,
    insertJSON,
    isReady,
    isDataLoaded,
  };
}
