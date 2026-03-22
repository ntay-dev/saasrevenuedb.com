<template>
  <div>
    <!-- Hero Section -->
    <section class="border-b border-(--color-border) bg-(--color-surface)">
      <div class="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
        <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">
          <span class="gradient-text">All</span>
          <span class="text-(--color-text-primary)"> Products</span>
        </h1>
        <p class="mt-2 text-base leading-relaxed text-(--color-text-secondary)">
          {{ store.totalProducts.toLocaleString() }} products from
          {{ sourcesWithProducts.length }} sources:
          <template v-for="(src, idx) in sourcesWithProducts" :key="src.id">
            <a
              v-if="src.url"
              :href="src.url"
              target="_blank"
              rel="noopener noreferrer"
              class="underline decoration-dotted underline-offset-2 transition-colors hover:text-blue-400"
              >{{ src.name }}</a
            >
            <span v-else>{{ src.name }}</span>
            <span v-if="idx < sourcesWithProducts.length - 1">
              ·
            </span> </template
          >. Every data point linked to its original source.
        </p>
      </div>
    </section>

    <!-- Filters + Content -->
    <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <!-- Filters -->
      <div class="flex flex-col gap-3">
        <!-- Row 1: Search + Dropdowns -->
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
          <div class="relative flex-1">
            <Search
              class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-(--color-text-muted)"
            />
            <input
              v-model="search"
              type="text"
              placeholder="Search products..."
              class="w-full rounded-lg border border-(--color-border) bg-(--color-surface) py-2 pl-9 pr-3 text-sm text-(--color-text-primary) placeholder:text-(--color-text-muted) focus:border-blue-500 focus:outline-none"
              @input="applyFilters"
            />
          </div>
          <select
            v-model="selectedCategory"
            class="rounded-lg border border-(--color-border) bg-(--color-surface) px-3 py-2 text-sm text-(--color-text-primary) focus:border-blue-500 focus:outline-none"
            @change="applyFilters"
          >
            <option value="">All categories</option>
            <option
              v-for="cat in categoriesWithProducts"
              :key="cat.slug"
              :value="cat.slug"
            >
              {{ cat.name }} ({{ cat.count }})
            </option>
          </select>
          <select
            v-model="selectedSource"
            class="rounded-lg border border-(--color-border) bg-(--color-surface) px-3 py-2 text-sm text-(--color-text-primary) focus:border-blue-500 focus:outline-none"
            @change="applyFilters"
          >
            <option value="">All sources</option>
            <option
              v-for="src in sourcesWithProducts"
              :key="src.id"
              :value="src.name"
            >
              {{ src.name }} ({{ src.count }})
            </option>
          </select>
          <select
            v-model="selectedSort"
            class="rounded-lg border border-(--color-border) bg-(--color-surface) px-3 py-2 text-sm text-(--color-text-primary) focus:border-blue-500 focus:outline-none"
            @change="applyFilters"
          >
            <option value="mrr-desc">MRR ↓</option>
            <option value="mrr-asc">MRR ↑</option>
            <option value="name-asc">Name A–Z</option>
            <option value="name-desc">Name Z–A</option>
          </select>
        </div>
        <!-- Row 2: Checkbox -->
        <div>
          <label
            class="flex items-center gap-2 text-sm text-(--color-text-secondary)"
          >
            <input
              v-model="hideAnonymous"
              type="checkbox"
              class="rounded"
              @change="applyFilters"
            />
            Hide anonymous
          </label>
        </div>
      </div>

      <!-- Loading -->
      <div v-if="store.loading" class="mt-6">
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          <div
            v-for="i in 6"
            :key="i"
            class="animate-pulse rounded-xl border border-(--color-border) bg-(--color-surface) p-5"
          >
            <div class="flex items-start gap-3">
              <div class="h-10 w-10 rounded-lg bg-(--color-surface-elevated)" />
              <div class="flex-1 space-y-2">
                <div class="h-4 w-3/4 rounded bg-(--color-surface-elevated)" />
                <div class="h-3 w-1/2 rounded bg-(--color-surface-elevated)" />
              </div>
            </div>
            <div
              class="mt-4 h-3 w-full rounded bg-(--color-surface-elevated)"
            />
          </div>
        </div>
      </div>

      <!-- Error -->
      <div v-else-if="store.error" class="mt-6">
        <div
          class="rounded-xl border border-red-500/20 bg-(--color-surface) p-6 text-center"
        >
          <AlertTriangle class="mx-auto mb-2 size-8 text-red-400" />
          <p class="text-sm text-red-400">{{ store.error }}</p>
          <button
            class="mt-3 rounded-lg border border-(--color-border) px-4 py-2 text-sm text-(--color-text-secondary) transition-colors hover:text-(--color-text-primary)"
            @click="store.initialize()"
          >
            Retry
          </button>
        </div>
      </div>

      <!-- Product Grid -->
      <div v-else class="mt-6">
        <div
          v-if="store.products.length === 0"
          class="rounded-xl border border-(--color-border) bg-(--color-surface) py-16 text-center"
        >
          <Search class="mx-auto mb-3 size-10 opacity-30" />
          <p class="text-base font-medium text-(--color-text-secondary)">
            No products found
          </p>
          <p class="mt-1 text-sm text-(--color-text-muted)">
            Try a different search term or category.
          </p>
        </div>

        <template v-else>
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
            <ProductCard
              v-for="product in store.products"
              :key="product.id"
              :product="product"
            />
          </div>

          <div class="mt-8 flex flex-col items-center gap-4">
            <p class="text-sm text-(--color-text-muted)">
              Showing {{ store.products.length }} of
              {{ store.totalCount }} products
            </p>
            <button
              v-if="store.hasMore"
              class="inline-flex items-center gap-2 rounded-lg border border-(--color-border) bg-(--color-surface-elevated) px-5 py-2.5 text-sm font-medium text-(--color-text-secondary) transition-colors hover:border-(--color-border-hover) hover:text-(--color-text-primary)"
              @click="store.loadMore()"
            >
              <ArrowDown class="size-4" />
              Load more
            </button>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { AlertTriangle, Search, ArrowDown } from "lucide-vue-next";
import { useProductsStore } from "~/stores/products";

const store = useProductsStore();
const route = useRoute();
const router = useRouter();

const search = ref("");
const selectedCategory = ref("");
const selectedSource = ref("");
const selectedSort = ref("mrr-desc");
const hideAnonymous = ref(true);

/** Categories that have at least one product, with counts */
const categoriesWithProducts = computed(() => {
  const counts = new Map<string, number>();
  for (const p of store.allProducts) {
    if (p.category_slug) {
      counts.set(p.category_slug, (counts.get(p.category_slug) ?? 0) + 1);
    }
  }
  return store.categories
    .filter((cat) => (counts.get(cat.slug) ?? 0) > 0)
    .map((cat) => ({ ...cat, count: counts.get(cat.slug)! }));
});

/** Sources that have at least one product, with counts */
const sourcesWithProducts = computed(() => {
  const counts = new Map<string, number>();
  for (const p of store.allProducts) {
    if (p.primary_source) {
      counts.set(p.primary_source, (counts.get(p.primary_source) ?? 0) + 1);
    }
  }
  return store.sources
    .filter((src) => (counts.get(src.name) ?? 0) > 0)
    .map((src) => ({ ...src, count: counts.get(src.name)! }));
});

useHead({
  title: "Products — IndieRadar",
  meta: [
    {
      name: "description",
      content:
        "Browse all SaaS products with verified MRR data, founders, and sources. Filter by category, search, and explore.",
    },
  ],
});

useCanonical("/products");
useBreadcrumbSchema([
  { name: "Home", url: "/" },
  { name: "Products", url: "/products" },
]);

function readFiltersFromUrl() {
  const q = route.query;
  search.value = typeof q.search === "string" ? q.search : "";
  selectedCategory.value = typeof q.category === "string" ? q.category : "";
  selectedSource.value = typeof q.source === "string" ? q.source : "";
  selectedSort.value = typeof q.sort === "string" ? q.sort : "mrr-desc";
  if (typeof q.hideAnonymous === "string") {
    hideAnonymous.value = q.hideAnonymous !== "false";
  }
}

function syncFiltersToUrl() {
  const query: Record<string, string | undefined> = {};
  if (search.value) query.search = search.value;
  if (selectedCategory.value) query.category = selectedCategory.value;
  if (selectedSource.value) query.source = selectedSource.value;
  if (selectedSort.value !== "mrr-desc") query.sort = selectedSort.value;
  if (!hideAnonymous.value) query.hideAnonymous = "false";
  router.replace({ query });
}

function applyFilters() {
  syncFiltersToUrl();
  const [sortBy, sortOrder] = selectedSort.value.split("-") as [
    string,
    "asc" | "desc",
  ];
  store.setFilters({
    categories: selectedCategory.value ? [selectedCategory.value] : undefined,
    primarySource: selectedSource.value || undefined,
    search: search.value || undefined,
    hideAnonymous: hideAnonymous.value,
    sortBy,
    sortOrder,
  });
}

onMounted(async () => {
  await store.initialize();
  readFiltersFromUrl();
  applyFilters();
});
</script>
