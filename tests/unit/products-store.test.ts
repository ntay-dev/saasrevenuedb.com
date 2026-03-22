import { describe, it, expect, vi, beforeEach } from "vitest";

import { useProductsStore } from "~/stores/products";

vi.mock("pinia", () => ({
  defineStore: (id: string, setup: () => any) => () => setup(),
}));

describe("products store", () => {
  let store: ReturnType<typeof useProductsStore>;

  beforeEach(() => {
    vi.clearAllMocks();
    // Clear localStorage cache
    try {
      localStorage.removeItem("saas-products-cache");
    } catch {
      // ignore
    }
    store = useProductsStore();
  });

  describe("initial state", () => {
    it("starts with empty products", () => {
      expect(store.products.value).toEqual([]);
    });

    it("starts with empty allProducts", () => {
      expect(store.allProducts.value).toEqual([]);
    });

    it("starts with empty categories", () => {
      expect(store.categories.value).toEqual([]);
    });

    it("starts with empty countries", () => {
      expect(store.countries.value).toEqual([]);
    });

    it("starts with empty sources", () => {
      expect(store.sources.value).toEqual([]);
    });

    it("starts with loading false", () => {
      expect(store.loading.value).toBe(false);
    });

    it("starts with no error", () => {
      expect(store.error.value).toBeNull();
    });

    it("starts not initialized", () => {
      expect(store.initialized.value).toBe(false);
    });

    it("starts with hideAnonymous true", () => {
      expect(store.filters.value).toEqual({ hideAnonymous: true });
    });
  });

  describe("computed: totalProducts", () => {
    it("returns count of filtered products", () => {
      store.allProducts.value = [
        { id: "1", name: "A", mrr: 100 },
        { id: "2", name: "B", mrr: 200 },
        { id: "3", name: "C", mrr: 300 },
      ] as any;
      store.setFilters({ hideAnonymous: false });
      expect(store.totalProducts.value).toBe(3);
    });

    it("returns 0 by default", () => {
      expect(store.totalProducts.value).toBe(0);
    });
  });

  describe("computed: totalCategories", () => {
    it("returns count of categories", () => {
      store.categories.value = [{ name: "CRM" }, { name: "Analytics" }] as any;
      expect(store.totalCategories.value).toBe(2);
    });

    it("returns 0 for empty array", () => {
      store.categories.value = [];
      expect(store.totalCategories.value).toBe(0);
    });
  });

  describe("computed: uniqueCountries", () => {
    it("counts unique non-null country codes from filtered products", () => {
      store.allProducts.value = [
        { id: "1", name: "A", country_code: "US", mrr: 100 },
        { id: "2", name: "B", country_code: "DE", mrr: 200 },
        { id: "3", name: "C", country_code: "US", mrr: 300 },
        { id: "4", name: "D", country_code: null, mrr: 50 },
      ] as any;
      store.setFilters({ hideAnonymous: false });
      expect(store.uniqueCountries.value).toBe(2);
    });

    it("returns 0 for empty products", () => {
      store.allProducts.value = [];
      expect(store.uniqueCountries.value).toBe(0);
    });
  });

  describe("computed: uniqueCompanies", () => {
    it("counts unique non-null companies", () => {
      store.allProducts.value = [
        { id: "1", name: "A", company: "Acme", mrr: 100 },
        { id: "2", name: "B", company: "Beta", mrr: 200 },
        { id: "3", name: "C", company: "Acme", mrr: 300 },
        { id: "4", name: "D", company: null, mrr: 50 },
      ] as any;
      store.setFilters({ hideAnonymous: false });
      expect(store.uniqueCompanies.value).toBe(2);
    });

    it("returns 0 for empty products", () => {
      store.allProducts.value = [];
      expect(store.uniqueCompanies.value).toBe(0);
    });
  });

  describe("computed: totalMRR", () => {
    it("sums MRR values from filtered products", () => {
      store.allProducts.value = [
        { id: "1", name: "A", mrr: 1000 },
        { id: "2", name: "B", mrr: 2000 },
        { id: "3", name: "C", mrr: 500 },
      ] as any;
      store.setFilters({ hideAnonymous: false });
      expect(store.totalMRR.value).toBe(3500);
    });

    it("treats null MRR as 0", () => {
      store.allProducts.value = [
        { id: "1", name: "A", mrr: 1000 },
        { id: "2", name: "B", mrr: null },
      ] as any;
      store.setFilters({ hideAnonymous: false });
      expect(store.totalMRR.value).toBe(1000);
    });

    it("returns 0 for empty products", () => {
      store.allProducts.value = [];
      expect(store.totalMRR.value).toBe(0);
    });
  });

  describe("computed: reactivity", () => {
    it("updates totalMRR when allProducts change", () => {
      store.setFilters({ hideAnonymous: false });
      store.allProducts.value = [{ id: "1", name: "A", mrr: 100 }] as any;
      expect(store.totalMRR.value).toBe(100);
      store.allProducts.value = [
        { id: "1", name: "A", mrr: 100 },
        { id: "2", name: "B", mrr: 200 },
      ] as any;
      expect(store.totalMRR.value).toBe(300);
    });

    it("updates uniqueCountries when allProducts change", () => {
      store.setFilters({ hideAnonymous: false });
      store.allProducts.value = [
        { id: "1", name: "A", country_code: "US", mrr: 100 },
      ] as any;
      expect(store.uniqueCountries.value).toBe(1);
      store.allProducts.value = [
        { id: "1", name: "A", country_code: "US", mrr: 100 },
        { id: "2", name: "B", country_code: "DE", mrr: 200 },
      ] as any;
      expect(store.uniqueCountries.value).toBe(2);
    });
  });

  describe("setFilters", () => {
    it("merges filters", () => {
      store.setFilters({ search: "test" });
      expect(store.filters.value.search).toBe("test");
      expect(store.filters.value.hideAnonymous).toBe(true);
    });

    it("resets page to 1", () => {
      store.page.value = 5;
      store.setFilters({ search: "new" });
      expect(store.page.value).toBe(1);
    });
  });

  describe("initialize", () => {
    it("sets initialized to true after first call", async () => {
      expect(store.initialized.value).toBe(false);
      await store.initialize();
      expect(store.initialized.value).toBe(true);
    });

    it("does not re-initialize if already initialized", async () => {
      const mockClient = (globalThis as any).__mockSupabaseClient;
      await store.initialize();
      const callCount = mockClient.from.mock.calls.length;
      await store.initialize();
      expect(mockClient.from.mock.calls.length).toBe(callCount);
    });
  });

  describe("loadMore", () => {
    it("increments page when hasMore is true", () => {
      store.allProducts.value = Array.from({ length: 50 }, (_, i) => ({
        id: String(i),
        name: `Product ${i}`,
        mrr: i * 100,
      })) as any;
      store.setFilters({ hideAnonymous: false });
      store.pageSize.value = 10;

      expect(store.page.value).toBe(1);
      expect(store.products.value).toHaveLength(10);

      store.loadMore();
      expect(store.page.value).toBe(2);
      expect(store.products.value).toHaveLength(20);
    });

    it("does not increment when all loaded", () => {
      store.allProducts.value = [{ id: "1", name: "A", mrr: 100 }] as any;
      store.setFilters({ hideAnonymous: false });
      store.pageSize.value = 10;

      store.loadMore();
      expect(store.page.value).toBe(1);
    });
  });
});
