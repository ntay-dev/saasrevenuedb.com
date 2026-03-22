<template>
  <div>
    <!-- Header -->
    <section class="border-b border-(--color-border) bg-(--color-surface)">
      <div class="mx-auto max-w-380 px-4 py-10 sm:px-6 lg:px-8">
        <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">
          <span class="gradient-text">Analytics</span>
          <span class="text-(--color-text-primary)"> Dashboard</span>
        </h1>
        <p v-if="ready" class="mt-2 text-base text-(--color-text-secondary)">
          {{ stats.withMrr.toLocaleString() }} products with MRR data across
          {{ stats.sourceCount }} sources.
          <span class="text-(--color-text-muted)">· DuckDB-WASM</span>
        </p>
        <p v-else class="mt-2 text-base text-(--color-text-secondary)">
          <span v-if="loadingPhase === 'duckdb'">Initializing DuckDB...</span>
          <span v-else-if="loadingPhase === 'fetch'"> Loading data... </span>
          <span v-else-if="loadingPhase === 'ingest'"
            >Ingesting into DuckDB...</span
          >
          <span v-else-if="loadingPhase === 'query'"
            >Running analytics queries...</span
          >
          <span v-else>Loading...</span>
        </p>
      </div>
    </section>

    <div class="mx-auto max-w-380 px-4 py-8 sm:px-6 lg:px-8">
      <template v-if="ready">
        <!-- Stats badges -->
        <div class="mb-6 flex flex-wrap gap-2">
          <span
            class="inline-flex items-center gap-1.5 rounded-full border border-(--color-border) bg-(--color-surface) px-3 py-1 text-xs text-(--color-text-secondary)"
          >
            {{ stats.total.toLocaleString() }} total products
          </span>
          <span
            class="inline-flex items-center gap-1.5 rounded-full border border-(--color-border) bg-(--color-surface) px-3 py-1 text-xs text-(--color-text-secondary)"
          >
            {{ stats.withMrr.toLocaleString() }} with MRR
          </span>
          <span
            class="inline-flex items-center gap-1.5 rounded-full border border-(--color-border) bg-(--color-surface) px-3 py-1 text-xs text-(--color-text-secondary)"
          >
            {{ formatCurrency(stats.avgMrr) }} avg MRR
          </span>
          <span
            v-if="stats.uncategorized > 0"
            class="inline-flex items-center gap-1.5 rounded-full border border-yellow-500/20 bg-yellow-500/5 px-3 py-1 text-xs text-yellow-400/80"
          >
            {{ stats.uncategorized.toLocaleString() }} uncategorized
          </span>
          <span
            v-if="stats.unknownCountry > 0"
            class="inline-flex items-center gap-1.5 rounded-full border border-yellow-500/20 bg-yellow-500/5 px-3 py-1 text-xs text-yellow-400/80"
          >
            {{ stats.unknownCountry.toLocaleString() }} unknown country
          </span>
        </div>

        <!-- Charts -->
        <div class="space-y-6">
          <!-- 1. MRR Distribution by Source — full width -->
          <div
            class="rounded-xl border border-(--color-border) bg-(--color-surface) p-5"
          >
            <h2 class="mb-1 text-lg font-semibold text-(--color-text-primary)">
              MRR Distribution by Source
            </h2>
            <p class="mb-4 text-xs text-(--color-text-muted)">
              How many products fall into each MRR range, broken down by data
              source.
            </p>
            <AgCharts
              :options="mrrDistributionBySourceOptions as any"
              style="height: 400px"
            />
            <p
              v-if="excluded.mrrDist > 0"
              class="mt-2 text-xs text-(--color-text-muted)"
            >
              {{ excluded.mrrDist.toLocaleString() }} products without MRR data
              not shown.
            </p>
          </div>

          <!-- 2a. Founded Year — Product Count -->
          <div
            class="rounded-xl border border-(--color-border) bg-(--color-surface) p-5"
          >
            <h2 class="mb-1 text-lg font-semibold text-(--color-text-primary)">
              Products by Founded Year
            </h2>
            <p class="mb-4 text-xs text-(--color-text-muted)">
              Products founded per year, stacked by source.
            </p>
            <AgCharts
              :options="foundedYearCountOptions as any"
              style="height: 350px"
            />
            <p
              v-if="excluded.foundedYear > 0"
              class="mt-2 text-xs text-(--color-text-muted)"
            >
              {{ excluded.foundedYear.toLocaleString() }} products without
              founded year not shown — most sources lack this field.
            </p>
          </div>

          <!-- 2b. Founded Year — Avg MRR -->
          <div
            class="rounded-xl border border-(--color-border) bg-(--color-surface) p-5"
          >
            <h2 class="mb-1 text-lg font-semibold text-(--color-text-primary)">
              Avg MRR by Founded Year
            </h2>
            <p class="mb-4 text-xs text-(--color-text-muted)">
              Average MRR trend per source over founded year.
            </p>
            <AgCharts
              :options="foundedYearMrrOptions as any"
              style="height: 350px"
            />
          </div>

          <!-- 3. Products by Country -->
          <div
            class="rounded-xl border border-(--color-border) bg-(--color-surface) p-5"
          >
            <h2 class="mb-1 text-lg font-semibold text-(--color-text-primary)">
              Products by Country
            </h2>
            <p class="mb-4 text-xs text-(--color-text-muted)">
              Top 15 countries, stacked by source.
            </p>
            <AgCharts
              :options="productsByCountryOptions as any"
              style="height: 500px"
            />
            <p
              v-if="
                excluded.countryUnknown > 0 || excluded.countryOutsideTop15 > 0
              "
              class="mt-2 text-xs text-(--color-text-muted)"
            >
              {{ excluded.countryUnknown.toLocaleString() }} with unknown
              country<template v-if="excluded.countryOutsideTop15 > 0"
                >, {{ excluded.countryOutsideTop15.toLocaleString() }} in other
                countries</template
              >
              not shown.
            </p>
          </div>
        </div>
      </template>

      <!-- Loading state -->
      <div
        v-else
        class="flex items-center justify-center py-24 text-(--color-text-muted)"
      >
        <div
          class="size-8 animate-spin rounded-full border-2 border-(--color-border) border-t-blue-500"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { AgCharts } from "ag-charts-vue3";
import { AllCommunityModule, ModuleRegistry } from "ag-charts-community";
import { formatCompact, formatCurrency } from "~/utils/format";

ModuleRegistry.registerModules([AllCommunityModule]);

useHead({
  title: "Analytics — IndieRadar",
  meta: [{ name: "robots", content: "noindex, nofollow" }],
});

const duck = useDuckDB();

const ready = ref(false);
const loadingPhase = ref<"duckdb" | "fetch" | "ingest" | "query" | "">("");

// --- Pre-computed data from DuckDB queries ---
const stats = ref({
  total: 0,
  withMrr: 0,
  avgMrr: 0,
  sourceCount: 0,
  uncategorized: 0,
  unknownCountry: 0,
});
const sourceNames = ref<string[]>([]);
const mrrDistData = ref<Record<string, unknown>[]>([]);
const foundedYearData = ref<Record<string, unknown>[]>([]);
const countryData = ref<Record<string, unknown>[]>([]);

/** Per-chart excluded product counts */
const excluded = ref({
  mrrDist: 0,
  foundedYear: 0,
  countryUnknown: 0,
  countryOutsideTop15: 0,
});

// --- Source colors ---
const SOURCE_COLORS: Record<string, string> = {
  TrustMRR: "#3b82f6",
  IndieHackers: "#f97316",
  "Acquire.com": "#a855f7",
  "StarterStory YouTube": "#ef4444",
  "Auto-Categorizer": "#10b981",
  Unknown: "#6b7280",
};

function sourceColor(name: string): string {
  return SOURCE_COLORS[name] || "#6b7280";
}

// --- Dark theme ---
const darkTheme = {
  baseTheme: "ag-default-dark" as const,
  overrides: {
    common: {
      background: { fill: "transparent" },
      legend: {
        item: {
          label: { color: "#a3a3a3" },
        },
      },
    },
  },
};

// --- MRR Bucket labels (ordered) ---
const MRR_BUCKET_LABELS = [
  "$0–500",
  "$500–1K",
  "$1K–2K",
  "$2K–5K",
  "$5K–10K",
  "$10K–25K",
  "$25K–50K",
  "$50K–100K",
  "$100K+",
];

// --- Data loading ---

async function runAnalyticsQueries() {
  // 1. Basic stats
  const statsRows = await duck.query<{
    total: number;
    with_mrr: number;
    avg_mrr: number;
    source_count: number;
    uncategorized: number;
    unknown_country: number;
  }>(`
    SELECT
      count(*) as total,
      count(*) FILTER (WHERE mrr IS NOT NULL AND mrr > 0) as with_mrr,
      coalesce(avg(mrr) FILTER (WHERE mrr IS NOT NULL AND mrr > 0), 0)::int as avg_mrr,
      count(DISTINCT coalesce(primary_source, 'Unknown')) as source_count,
      count(*) FILTER (WHERE category IS NULL) as uncategorized,
      count(*) FILTER (WHERE country_name IS NULL AND country_code IS NULL) as unknown_country
    FROM gold
  `);
  const statsRow = statsRows[0];
  if (statsRow) {
    stats.value = {
      total: statsRow.total,
      withMrr: statsRow.with_mrr,
      avgMrr: statsRow.avg_mrr,
      sourceCount: statsRow.source_count,
      uncategorized: statsRow.uncategorized,
      unknownCountry: statsRow.unknown_country,
    };
  }

  // 1b. Per-chart exclusion counts
  const exRows = await duck.query<{
    no_mrr: number;
    no_founded: number;
    no_country: number;
    outside_top15: number;
  }>(`
    WITH country_counts AS (
      SELECT
        CASE coalesce(country_name, country_code)
          WHEN 'United States of America' THEN 'United States'
          WHEN 'USA' THEN 'United States'
          WHEN 'US' THEN 'United States'
          WHEN 'Estados Unidos de América' THEN 'United States'
          WHEN 'Estados Unidos' THEN 'United States'
          WHEN 'UK' THEN 'United Kingdom'
          WHEN 'Great Britain' THEN 'United Kingdom'
          ELSE coalesce(country_name, country_code)
        END as country
      FROM gold
      WHERE country_name IS NOT NULL OR country_code IS NOT NULL
    ),
    top15 AS (
      SELECT country FROM country_counts GROUP BY country ORDER BY count(*) DESC LIMIT 15
    )
    SELECT
      (SELECT count(*) FROM gold WHERE mrr IS NULL OR mrr <= 0) as no_mrr,
      (SELECT count(*) FROM gold WHERE founded_year IS NULL OR founded_year < 2000) as no_founded,
      (SELECT count(*) FROM gold WHERE country_name IS NULL AND country_code IS NULL) as no_country,
      (SELECT count(*) FROM country_counts c WHERE c.country NOT IN (SELECT country FROM top15)) as outside_top15
  `);
  if (exRows[0]) {
    excluded.value = {
      mrrDist: exRows[0].no_mrr,
      foundedYear: exRows[0].no_founded,
      countryUnknown: exRows[0].no_country,
      countryOutsideTop15: exRows[0].outside_top15,
    };
  }

  // 2. Source names
  const srcRows = await duck.query<{ src: string }>(`
    SELECT DISTINCT coalesce(primary_source, 'Unknown') as src FROM gold ORDER BY src
  `);
  sourceNames.value = srcRows.map((r) => r.src);

  // 3. MRR distribution by source (pivoted)
  const mrrRows = await duck.query<{
    range_label: string;
    src: string;
    cnt: number;
  }>(`
    SELECT
      CASE
        WHEN mrr < 500 THEN '$0–500'
        WHEN mrr < 1000 THEN '$500–1K'
        WHEN mrr < 2000 THEN '$1K–2K'
        WHEN mrr < 5000 THEN '$2K–5K'
        WHEN mrr < 10000 THEN '$5K–10K'
        WHEN mrr < 25000 THEN '$10K–25K'
        WHEN mrr < 50000 THEN '$25K–50K'
        WHEN mrr < 100000 THEN '$50K–100K'
        ELSE '$100K+'
      END as range_label,
      coalesce(primary_source, 'Unknown') as src,
      count(*)::int as cnt
    FROM gold
    WHERE mrr IS NOT NULL AND mrr > 0
    GROUP BY range_label, src
  `);

  // Pivot into chart format
  const bucketMap = new Map<string, Record<string, unknown>>();
  for (const label of MRR_BUCKET_LABELS) {
    const row: Record<string, unknown> = { range: label };
    for (const s of sourceNames.value) row[s] = 0;
    bucketMap.set(label, row);
  }
  for (const r of mrrRows) {
    const row = bucketMap.get(r.range_label);
    if (row) row[r.src] = r.cnt;
  }
  mrrDistData.value = MRR_BUCKET_LABELS.map((l) => bucketMap.get(l)!);

  // 4. Founded year timeline
  const yearRows = await duck.query<{
    year: string;
    src: string;
    cnt: number;
    avg_mrr: number;
  }>(`
    SELECT
      founded_year::varchar as year,
      coalesce(primary_source, 'Unknown') as src,
      count(*)::int as cnt,
      coalesce(avg(mrr) FILTER (WHERE mrr IS NOT NULL AND mrr > 0), 0)::int as avg_mrr
    FROM gold
    WHERE founded_year IS NOT NULL AND founded_year >= 2000
    GROUP BY founded_year, src
    ORDER BY founded_year, src
  `);

  const yearMap = new Map<string, Record<string, unknown>>();
  for (const r of yearRows) {
    if (!yearMap.has(r.year)) {
      const row: Record<string, unknown> = { year: r.year };
      for (const s of sourceNames.value) {
        row[s] = 0;
        row[`avgMrr_${s}`] = 0;
      }
      yearMap.set(r.year, row);
    }
    const row = yearMap.get(r.year)!;
    row[r.src] = r.cnt;
    row[`avgMrr_${r.src}`] = r.avg_mrr;
  }

  const years = Array.from(yearMap.keys()).sort();
  foundedYearData.value = years.map((y) => yearMap.get(y)!);

  // 5. Products by country (top 15)
  const countryRows = await duck.query<{
    country: string;
    src: string;
    cnt: number;
  }>(`
    WITH normalized AS (
      SELECT
        CASE coalesce(country_name, country_code)
          WHEN 'United States of America' THEN 'United States'
          WHEN 'USA' THEN 'United States'
          WHEN 'US' THEN 'United States'
          WHEN 'Estados Unidos de América' THEN 'United States'
          WHEN 'Estados Unidos' THEN 'United States'
          WHEN 'UK' THEN 'United Kingdom'
          WHEN 'Great Britain' THEN 'United Kingdom'
          ELSE coalesce(country_name, country_code)
        END as country,
        coalesce(primary_source, 'Unknown') as src
      FROM gold
      WHERE country_name IS NOT NULL OR country_code IS NOT NULL
    ),
    top15 AS (
      SELECT country FROM normalized GROUP BY country ORDER BY count(*) DESC LIMIT 15
    )
    SELECT n.country, n.src, count(*)::int as cnt
    FROM normalized n
    JOIN top15 t ON n.country = t.country
    GROUP BY n.country, n.src
    ORDER BY n.country, n.src
  `);

  // Pivot + order by total descending then reverse for horizontal bar
  const cMap = new Map<string, Record<string, unknown>>();
  const cTotals = new Map<string, number>();
  for (const r of countryRows) {
    if (!cMap.has(r.country)) {
      const row: Record<string, unknown> = { country: r.country };
      for (const s of sourceNames.value) row[s] = 0;
      cMap.set(r.country, row);
      cTotals.set(r.country, 0);
    }
    cMap.get(r.country)![r.src] = r.cnt;
    cTotals.set(r.country, (cTotals.get(r.country) || 0) + r.cnt);
  }
  const sortedCountries = Array.from(cTotals.entries())
    .sort((a, b) => b[1] - a[1])
    .reverse()
    .map(([c]) => c);
  countryData.value = sortedCountries.map((c) => cMap.get(c)!);
}

// --- Chart options (reactive, based on pre-computed data) ---

const mrrDistributionBySourceOptions = computed(() => ({
  theme: darkTheme,
  background: { fill: "transparent" },
  data: mrrDistData.value,
  series: sourceNames.value.map((src) => ({
    type: "bar" as const,
    xKey: "range",
    yKey: src,
    yName: src,
    stacked: true,
    cornerRadius: 2,
    fill: sourceColor(src),
    stroke: sourceColor(src),
  })),
  axes: [
    {
      type: "category" as const,
      position: "bottom" as const,
      label: { color: "#a3a3a3", rotation: -30 },
      gridLine: { style: [{ stroke: "#222", lineDash: [4, 4] }] },
    },
    {
      type: "number" as const,
      position: "left" as const,
      label: {
        color: "#a3a3a3",
        formatter: (params: { value: number }) => formatCompact(params.value),
      },
      gridLine: { style: [{ stroke: "#222", lineDash: [4, 4] }] },
    },
  ],
}));

const foundedYearCountOptions = computed(() => ({
  theme: darkTheme,
  background: { fill: "transparent" },
  data: foundedYearData.value,
  series: sourceNames.value.map((src) => ({
    type: "bar" as const,
    xKey: "year",
    yKey: src,
    yName: src,
    stacked: true,
    cornerRadius: 2,
    fill: sourceColor(src),
    stroke: sourceColor(src),
  })),
  axes: [
    {
      type: "category" as const,
      position: "bottom" as const,
      label: { color: "#a3a3a3", rotation: -45 },
      gridLine: { style: [{ stroke: "#222", lineDash: [4, 4] }] },
    },
    {
      type: "number" as const,
      position: "left" as const,
      title: { text: "Products", color: "#a3a3a3" },
      label: {
        color: "#a3a3a3",
        formatter: (params: { value: number }) => formatCompact(params.value),
      },
      gridLine: { style: [{ stroke: "#222", lineDash: [4, 4] }] },
    },
  ],
}));

const foundedYearMrrOptions = computed(() => ({
  theme: darkTheme,
  background: { fill: "transparent" },
  data: foundedYearData.value,
  series: sourceNames.value.map((src) => ({
    type: "line" as const,
    xKey: "year",
    yKey: `avgMrr_${src}`,
    yName: src,
    stroke: sourceColor(src),
    strokeWidth: 2,
    marker: { fill: sourceColor(src), stroke: sourceColor(src), size: 4 },
    tooltip: {
      renderer: (params: Record<string, unknown>) => ({
        content: `Avg MRR: ${formatCurrency((params.datum as Record<string, unknown>)[`avgMrr_${src}`] as number)}`,
      }),
    },
  })),
  axes: [
    {
      type: "category" as const,
      position: "bottom" as const,
      label: { color: "#a3a3a3", rotation: -45 },
      gridLine: { style: [{ stroke: "#222", lineDash: [4, 4] }] },
    },
    {
      type: "number" as const,
      position: "left" as const,
      title: { text: "Avg MRR", color: "#a3a3a3" },
      label: {
        color: "#a3a3a3",
        formatter: (params: { value: number }) => formatCurrency(params.value),
      },
      gridLine: { style: [{ stroke: "#222", lineDash: [4, 4] }] },
    },
  ],
}));

const productsByCountryOptions = computed(() => ({
  theme: darkTheme,
  background: { fill: "transparent" },
  data: countryData.value,
  series: sourceNames.value.map((src) => ({
    type: "bar" as const,
    direction: "horizontal" as const,
    xKey: "country",
    yKey: src,
    yName: src,
    stacked: true,
    cornerRadius: 2,
    fill: sourceColor(src),
    stroke: sourceColor(src),
  })),
  axes: [
    {
      type: "category" as const,
      position: "left" as const,
      label: { color: "#a3a3a3" },
    },
    {
      type: "number" as const,
      position: "bottom" as const,
      label: { color: "#a3a3a3" },
      gridLine: { style: [{ stroke: "#222", lineDash: [4, 4] }] },
    },
  ],
}));

// --- Init ---
onMounted(async () => {
  try {
    // 1. Load data into DuckDB from static JSON
    loadingPhase.value = "fetch";
    await duck.ensureData();

    // 2. Run all analytics queries
    loadingPhase.value = "query";
    await runAnalyticsQueries();

    ready.value = true;
  } catch (e) {
    console.error("Analytics load failed:", e);
  } finally {
    loadingPhase.value = "";
  }
});
</script>
