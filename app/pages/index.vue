<template>
  <div>
    <!-- Hero -->
    <section class="border-b border-(--color-border) bg-(--color-surface)">
      <div class="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <h1 class="text-3xl font-bold tracking-tight sm:text-4xl lg:text-5xl">
          <span class="text-(--color-text-primary)">Real revenue data.</span>
          <br >
          <span class="gradient-text">Find your next market.</span>
        </h1>
        <p
          class="mt-3 max-w-2xl text-base leading-relaxed text-(--color-text-secondary) sm:text-lg"
        >
          Open-source intelligence on
          <span
            v-if="ready"
            class="font-semibold text-(--color-text-primary)"
            >{{ store.allProducts.length.toLocaleString() }}</span
          >
          <span v-else>...</span>
          SaaS products with verified MRR. Every data point linked to its
          source. Free forever.
        </p>
        <div class="mt-6 flex flex-wrap gap-3">
          <NuxtLink
            to="/products"
            class="inline-flex items-center gap-2 rounded-lg bg-emerald-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-emerald-700"
          >
            <Search class="size-4" />
            Browse Products
          </NuxtLink>
          <a
            href="https://github.com/ntay-dev/saasrevenuedb.com"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-2 rounded-lg border border-(--color-border) bg-(--color-surface-elevated) px-5 py-2.5 text-sm font-medium text-(--color-text-secondary) transition-colors hover:border-(--color-border-hover) hover:text-(--color-text-primary)"
          >
            <Github class="size-4" />
            View on GitHub
          </a>
        </div>
      </div>
    </section>

    <!-- Loading -->
    <div v-if="!ready" class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
      <div
        class="flex items-center justify-center py-24 text-(--color-text-muted)"
      >
        <div
          class="size-8 animate-spin rounded-full border-2 border-(--color-border) border-t-emerald-500"
        />
      </div>
    </div>

    <!-- Insights -->
    <div v-else class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <!-- Stat Cards -->
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div
          v-for="stat in stats"
          :key="stat.label"
          class="rounded-xl border border-(--color-border) bg-(--color-surface) p-4"
        >
          <p
            class="text-xs font-medium uppercase tracking-wider text-(--color-text-muted)"
          >
            {{ stat.label }}
          </p>
          <p
            class="mt-1 text-2xl font-bold tabular-nums text-(--color-text-primary)"
          >
            {{ stat.value }}
          </p>
          <p
            v-if="stat.sub && !stat.sources"
            class="mt-0.5 text-xs text-(--color-text-muted)"
          >
            {{ stat.sub }}
          </p>
          <div
            v-else-if="stat.sources"
            class="mt-0.5 flex flex-wrap gap-x-1.5 gap-y-0.5"
          >
            <template v-for="(src, idx) in activeSources" :key="src.id">
              <a
                v-if="src.url"
                :href="src.url"
                target="_blank"
                rel="noopener noreferrer"
                class="text-xs text-(--color-text-muted) underline decoration-dotted underline-offset-2 transition-colors hover:text-blue-400"
                @click.stop
                >{{ src.name }}</a
              >
              <span v-else class="text-xs text-(--color-text-muted)">{{
                src.name
              }}</span>
              <span
                v-if="idx < activeSources.length - 1"
                class="text-xs text-(--color-text-muted)"
                >&middot;</span
              >
            </template>
          </div>
        </div>
      </div>

      <!-- Main Grid -->
      <div class="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <!-- MRR Distribution (spans 2 cols) -->
        <div
          class="rounded-xl border border-(--color-border) bg-(--color-surface) p-5 lg:col-span-2"
        >
          <h2 class="text-lg font-semibold text-(--color-text-primary)">
            MRR Distribution
          </h2>
          <p class="mb-4 text-xs text-(--color-text-muted)">
            How many products fall into each MRR range — see what's realistic.
          </p>
          <div class="space-y-2">
            <div
              v-for="bucket in mrrBuckets"
              :key="bucket.label"
              class="flex items-center gap-3"
            >
              <span
                class="w-20 shrink-0 text-right text-xs tabular-nums text-(--color-text-muted)"
              >
                {{ bucket.label }}
              </span>
              <div
                class="relative h-7 flex-1 overflow-hidden rounded-md bg-(--color-surface-elevated)"
              >
                <div
                  class="absolute inset-y-0 left-0 rounded-md bg-emerald-500/80 transition-all duration-500"
                  :style="{ width: bucket.pct + '%' }"
                />
                <span
                  class="relative z-10 flex h-full items-center pl-2 text-xs font-medium tabular-nums text-white"
                >
                  {{ bucket.count }}
                </span>
              </div>
              <span
                class="w-10 shrink-0 text-right text-xs tabular-nums text-(--color-text-muted)"
              >
                {{ bucket.pct }}%
              </span>
            </div>
          </div>
        </div>

        <!-- Top Products by MRR -->
        <div
          class="rounded-xl border border-(--color-border) bg-(--color-surface) p-5"
        >
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-(--color-text-primary)">
              Top by MRR
            </h2>
            <NuxtLink
              to="/products"
              class="text-xs text-(--color-text-muted) transition-colors hover:text-(--color-text-secondary)"
            >
              View all →
            </NuxtLink>
          </div>
          <div class="mt-3 space-y-2.5">
            <NuxtLink
              v-for="(product, i) in topProducts"
              :key="product.id"
              :to="`/products/${product.slug}`"
              class="flex items-center gap-3 rounded-lg px-2 py-1.5 transition-colors hover:bg-(--color-surface-elevated)"
            >
              <span
                class="flex h-6 w-6 shrink-0 items-center justify-center rounded-md bg-(--color-surface-elevated) text-xs font-medium text-(--color-text-muted)"
              >
                {{ i + 1 }}
              </span>
              <div
                v-if="product.logo_url"
                class="flex h-7 w-7 shrink-0 items-center justify-center overflow-hidden rounded-md bg-(--color-surface-elevated) ring-1 ring-(--color-border)"
              >
                <img
                  :src="product.logo_url"
                  :alt="product.name"
                  class="h-full w-full object-contain"
                  loading="lazy"
                >
              </div>
              <div
                v-else
                class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-emerald-500/10 text-xs font-bold text-emerald-400 ring-1 ring-white/5"
              >
                {{ product.name?.charAt(0) }}
              </div>
              <div class="min-w-0 flex-1">
                <p
                  class="truncate text-sm font-medium text-(--color-text-primary)"
                >
                  {{ product.name }}
                </p>
                <p class="text-xs text-(--color-text-muted)">
                  {{ product.category || "Uncategorized" }}
                </p>
              </div>
              <span
                class="shrink-0 text-sm font-semibold tabular-nums text-emerald-400"
              >
                {{ formatCurrency(product.mrr) }}
              </span>
              <a
                v-if="product.website_url"
                :href="product.website_url"
                target="_blank"
                rel="noopener noreferrer"
                class="shrink-0 text-(--color-text-muted) transition-colors hover:text-blue-400"
                title="Open app"
                @click.stop
              >
                <ExternalLink class="size-3.5" />
              </a>
              <a
                v-if="product.primary_source_url"
                :href="product.primary_source_url"
                target="_blank"
                rel="noopener noreferrer"
                class="shrink-0 text-(--color-text-muted) transition-colors hover:text-blue-400"
                :title="product.primary_source || 'Source'"
                @click.stop
              >
                <LinkIcon class="size-3.5" />
              </a>
            </NuxtLink>
          </div>
        </div>
      </div>

      <!-- Second Row -->
      <div class="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
        <!-- Categories by Median MRR -->
        <div
          class="rounded-xl border border-(--color-border) bg-(--color-surface) p-5"
        >
          <h2 class="text-lg font-semibold text-(--color-text-primary)">
            Categories by Median MRR
          </h2>
          <p class="mb-4 text-xs text-(--color-text-muted)">
            Which categories generate the most revenue? Find underserved
            markets.
          </p>
          <div class="space-y-2">
            <NuxtLink
              v-for="cat in categoryInsights"
              :key="cat.name"
              :to="`/products?category=${cat.slug}`"
              class="flex items-center gap-3 rounded-lg px-2 py-1.5 transition-colors hover:bg-(--color-surface-elevated)"
            >
              <div class="min-w-0 flex-1">
                <p
                  class="truncate text-sm font-medium text-(--color-text-primary)"
                >
                  {{ cat.name }}
                </p>
                <p class="text-xs text-(--color-text-muted)">
                  {{ cat.count }} products
                </p>
              </div>
              <span
                class="shrink-0 text-sm font-semibold tabular-nums text-emerald-400"
              >
                {{ formatCurrency(cat.medianMrr) }}
              </span>
            </NuxtLink>
          </div>
        </div>

        <!-- Countries -->
        <div
          class="rounded-xl border border-(--color-border) bg-(--color-surface) p-5"
        >
          <h2 class="text-lg font-semibold text-(--color-text-primary)">
            Top Countries
          </h2>
          <p class="mb-4 text-xs text-(--color-text-muted)">
            Where are SaaS founders building?
          </p>
          <div class="space-y-2">
            <div
              v-for="country in countryInsights"
              :key="country.name"
              class="flex items-center gap-3 rounded-lg px-2 py-1.5"
            >
              <span class="text-lg">{{ country.flag }}</span>
              <div class="min-w-0 flex-1">
                <p
                  class="truncate text-sm font-medium text-(--color-text-primary)"
                >
                  {{ country.name }}
                </p>
              </div>
              <span class="text-sm tabular-nums text-(--color-text-secondary)">
                {{ country.count }}
              </span>
              <div
                class="relative h-2 w-24 overflow-hidden rounded-full bg-(--color-surface-elevated)"
              >
                <div
                  class="absolute inset-y-0 left-0 rounded-full bg-emerald-500/60"
                  :style="{ width: country.pct + '%' }"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Recently Added -->
      <div class="mt-6">
        <div
          class="rounded-xl border border-(--color-border) bg-(--color-surface) p-5"
        >
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-(--color-text-primary)">
              Recently Added
            </h2>
            <NuxtLink
              to="/products"
              class="text-xs text-(--color-text-muted) transition-colors hover:text-(--color-text-secondary)"
            >
              View all →
            </NuxtLink>
          </div>
          <div
            class="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4"
          >
            <NuxtLink
              v-for="product in recentProducts"
              :key="product.id"
              :to="`/products/${product.slug}`"
              class="flex items-center gap-3 rounded-lg border border-(--color-border) p-3 transition-colors hover:border-(--color-border-hover)"
            >
              <div
                v-if="product.logo_url"
                class="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-(--color-surface-elevated) ring-1 ring-(--color-border)"
              >
                <img
                  :src="product.logo_url"
                  :alt="product.name"
                  class="h-full w-full object-contain"
                  loading="lazy"
                >
              </div>
              <div
                v-else
                class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-emerald-500/10 text-xs font-bold text-emerald-400 ring-1 ring-white/5"
              >
                {{ product.name?.charAt(0) }}
              </div>
              <div class="min-w-0 flex-1">
                <p
                  class="truncate text-sm font-medium text-(--color-text-primary)"
                >
                  {{ product.name }}
                </p>
                <div class="flex items-center gap-2">
                  <span
                    v-if="product.mrr"
                    class="text-xs font-semibold tabular-nums text-emerald-400"
                  >
                    {{ formatCurrency(product.mrr) }}
                  </span>
                  <span
                    v-if="product.category"
                    class="truncate text-xs text-(--color-text-muted)"
                  >
                    {{ product.category }}
                  </span>
                  <a
                    v-if="product.website_url"
                    :href="product.website_url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="ml-auto shrink-0 text-(--color-text-muted) transition-colors hover:text-blue-400"
                    title="Open app"
                    @click.stop
                  >
                    <ExternalLink class="size-3" />
                  </a>
                  <a
                    v-if="product.primary_source_url"
                    :href="product.primary_source_url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="shrink-0 text-(--color-text-muted) transition-colors hover:text-blue-400"
                    :title="product.primary_source || 'Source'"
                    @click.stop
                  >
                    <LinkIcon class="size-3" />
                  </a>
                </div>
              </div>
            </NuxtLink>
          </div>
        </div>
      </div>

      <!-- Open Source CTA -->
      <div
        class="mt-8 rounded-xl border border-emerald-500/20 bg-emerald-500/5 p-6 text-center"
      >
        <p class="text-lg font-semibold text-(--color-text-primary)">
          Open Source. Free Forever.
        </p>
        <p class="mx-auto mt-1 max-w-lg text-sm text-(--color-text-secondary)">
          All data is source-verified and publicly accessible. Contribute data,
          report issues, or build on top of our API.
        </p>
        <div class="mt-4 flex flex-wrap items-center justify-center gap-3">
          <a
            href="https://github.com/ntay-dev/saasrevenuedb.com"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-2 rounded-lg border border-(--color-border) bg-(--color-surface) px-4 py-2 text-sm font-medium text-(--color-text-secondary) transition-colors hover:text-(--color-text-primary)"
          >
            <Github class="size-4" />
            Star on GitHub
          </a>
          <a
            href="https://x.com/ntay_dev"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-2 rounded-lg border border-(--color-border) bg-(--color-surface) px-4 py-2 text-sm font-medium text-(--color-text-secondary) transition-colors hover:text-(--color-text-primary)"
          >
            Follow @ntay_dev
          </a>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  Search,
  Github,
  Link as LinkIcon,
  ExternalLink,
} from "lucide-vue-next";
import { useProductsStore } from "~/stores/products";
import { formatCurrency } from "~/utils/format";

const store = useProductsStore();
const ready = ref(false);

useHead({
  title: "SaaSRevenueDB — The Open SaaS Revenue Database",
  meta: [
    {
      name: "description",
      content:
        "Discover SaaS markets, verified MRR data, and founder insights. Open-source intelligence for indie hackers. Free forever.",
    },
  ],
});

useCanonical("/");
useOrganizationSchema();
useWebSiteSchema();

onMounted(async () => {
  await store.initialize();
  ready.value = true;
});

// --- Active sources (only those with products) ---
const activeSources = computed(() => {
  const used = new Set(
    store.allProducts.map((p) => p.primary_source).filter(Boolean),
  );
  return store.sources.filter((s) => used.has(s.name));
});

// --- Stats ---
const productsWithMrr = computed(() =>
  store.allProducts.filter((p) => p.mrr != null && p.mrr > 0),
);

const medianMrr = computed(() => {
  const sorted = productsWithMrr.value
    .map((p) => Number(p.mrr!))
    .sort((a, b) => a - b);
  if (sorted.length === 0) return 0;
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 !== 0) return sorted[mid]!;
  return Math.round(((sorted[mid - 1] ?? 0) + (sorted[mid] ?? 0)) / 2);
});

const stats = computed(
  (): { label: string; value: string; sub?: string; sources?: boolean }[] => [
    {
      label: "Total Products",
      value: store.allProducts.length.toLocaleString(),
    },
    {
      label: "With MRR Data",
      value: productsWithMrr.value.length.toLocaleString(),
      sub: `${Math.round((productsWithMrr.value.length / Math.max(store.allProducts.length, 1)) * 100)}% of all`,
    },
    {
      label: "Median MRR",
      value: formatCurrency(medianMrr.value),
      sub: "across all products",
    },
    {
      label: "Categories",
      value: store.categories.length.toString(),
      sub: `${activeSources.value.length} data sources`,
      sources: true,
    },
  ],
);

// --- MRR Distribution ---
const MRR_RANGES = [
  { label: "$0–500", min: 0, max: 500 },
  { label: "$500–1K", min: 500, max: 1000 },
  { label: "$1K–5K", min: 1000, max: 5000 },
  { label: "$5K–10K", min: 5000, max: 10000 },
  { label: "$10K–50K", min: 10000, max: 50000 },
  { label: "$50K+", min: 50000, max: Infinity },
];

const mrrBuckets = computed(() => {
  const total = productsWithMrr.value.length || 1;
  return MRR_RANGES.map((range) => {
    const count = productsWithMrr.value.filter(
      (p) => Number(p.mrr ?? 0) >= range.min && Number(p.mrr ?? 0) < range.max,
    ).length;
    return {
      label: range.label,
      count,
      pct: Math.round((count / total) * 100),
    };
  });
});

// --- Top Products ---
const topProducts = computed(() =>
  [...store.allProducts]
    .filter((p) => p.mrr != null && p.mrr > 0)
    .sort((a, b) => Number(b.mrr ?? 0) - Number(a.mrr ?? 0))
    .slice(0, 5),
);

// --- Category Insights ---
function median(arr: number[]): number {
  if (arr.length === 0) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 !== 0) return sorted[mid]!;
  return Math.round(((sorted[mid - 1] ?? 0) + (sorted[mid] ?? 0)) / 2);
}

const categoryInsights = computed(() => {
  const catMap = new Map<
    string,
    { name: string; slug: string; mrrs: number[] }
  >();

  for (const p of productsWithMrr.value) {
    if (!p.category || !p.category_slug) continue;
    if (!catMap.has(p.category_slug)) {
      catMap.set(p.category_slug, {
        name: p.category,
        slug: p.category_slug,
        mrrs: [],
      });
    }
    catMap.get(p.category_slug)!.mrrs.push(Number(p.mrr ?? 0));
  }

  return Array.from(catMap.values())
    .map((c) => ({
      name: c.name,
      slug: c.slug,
      count: c.mrrs.length,
      medianMrr: median(c.mrrs),
    }))
    .filter((c) => c.count >= 2)
    .sort((a, b) => b.medianMrr - a.medianMrr)
    .slice(0, 8);
});

// --- Country Insights ---
function codeToFlag(code: string): string {
  return code
    .toUpperCase()
    .split("")
    .map((c) => String.fromCodePoint(0x1f1e6 + c.charCodeAt(0) - 65))
    .join("");
}

const countryInsights = computed(() => {
  const countryMap = new Map<
    string,
    { name: string; code: string; count: number }
  >();

  for (const p of store.allProducts) {
    const name = p.country_name;
    const code = p.country_code;
    if (!name || !code) continue;
    if (!countryMap.has(code)) {
      countryMap.set(code, { name, code, count: 0 });
    }
    countryMap.get(code)!.count++;
  }

  const sorted = Array.from(countryMap.values()).sort(
    (a, b) => b.count - a.count,
  );
  const maxCount = sorted[0]?.count || 1;

  return sorted.slice(0, 10).map((c) => ({
    name: c.name,
    flag: codeToFlag(c.code),
    count: c.count,
    pct: Math.round((c.count / maxCount) * 100),
  }));
});

// --- Recently Added ---
const recentProducts = computed(() => [...store.allProducts].slice(0, 8));
</script>
