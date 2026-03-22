import { describe, it, expect, vi, beforeEach } from "vitest";

import { useProductsStore } from "~/stores/products";

vi.mock("pinia", () => ({
  defineStore: (id: string, setup: () => any) => () => setup(),
}));

describe("filter logic (client-side)", () => {
  let store: ReturnType<typeof useProductsStore>;

  const sampleProducts = [
    {
      id: "1",
      slug: "notion",
      name: "Notion",
      company: "Notion Labs",
      description: "All-in-one workspace",
      category_slug: "productivity",
      country_code: "US",
      employees: 100,
      founded_year: 2018,
      mrr: 5000,
    },
    {
      id: "2",
      slug: "slack",
      name: "Slack",
      company: "Salesforce",
      description: "Team messaging",
      category_slug: "communication",
      country_code: "US",
      employees: 3000,
      founded_year: 2013,
      mrr: 20000,
    },
    {
      id: "3",
      slug: "pipedrive",
      name: "Pipedrive",
      company: "Pipedrive",
      description: "CRM for sales",
      category_slug: "crm",
      country_code: "EE",
      employees: 800,
      founded_year: 2010,
      mrr: 8000,
    },
    {
      id: "4",
      slug: "anonymous-app",
      name: "Anonymous App",
      company: null,
      description: null,
      category_slug: "other",
      country_code: null,
      employees: null,
      founded_year: null,
      mrr: null,
    },
  ] as any;

  beforeEach(() => {
    vi.clearAllMocks();
    store = useProductsStore();
    store.allProducts.value = sampleProducts;
  });

  describe("employee filter", () => {
    it("stores employeeMin and employeeMax in filters", () => {
      store.setFilters({ employeeMin: 51, employeeMax: 200 });
      expect(store.filters.value.employeeMin).toBe(51);
      expect(store.filters.value.employeeMax).toBe(200);
    });

    it("filters by employeeMin", () => {
      store.setFilters({ employeeMin: 100, hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "slack",
        "pipedrive",
        "notion",
      ]);
    });

    it("filters by employeeMax", () => {
      store.setFilters({ employeeMax: 500, hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "notion",
      ]);
    });

    it("applies both min and max together", () => {
      store.setFilters({
        employeeMin: 201,
        employeeMax: 1000,
        hideAnonymous: false,
      });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "pipedrive",
      ]);
    });
  });

  describe("founded year filter", () => {
    it("stores foundedFrom and foundedTo in filters", () => {
      store.setFilters({ foundedFrom: 2020, foundedTo: 2025 });
      expect(store.filters.value.foundedFrom).toBe(2020);
      expect(store.filters.value.foundedTo).toBe(2025);
    });

    it("filters by foundedFrom", () => {
      store.setFilters({ foundedFrom: 2015, hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "notion",
      ]);
    });

    it("filters by foundedTo", () => {
      store.setFilters({ foundedTo: 2012, hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "pipedrive",
      ]);
    });
  });

  describe("search filter", () => {
    it("matches by name", () => {
      store.setFilters({ search: "notion", hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "notion",
      ]);
    });

    it("matches by company", () => {
      store.setFilters({ search: "salesforce", hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "slack",
      ]);
    });

    it("matches by description", () => {
      store.setFilters({ search: "CRM", hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "pipedrive",
      ]);
    });

    it("is case-insensitive", () => {
      store.setFilters({ search: "NOTION", hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "notion",
      ]);
    });

    it("trims whitespace", () => {
      store.setFilters({ search: "  notion  ", hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "notion",
      ]);
    });
  });

  describe("category filter", () => {
    it("filters by single category", () => {
      store.setFilters({ categories: ["crm"], hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "pipedrive",
      ]);
    });

    it("filters by multiple categories", () => {
      store.setFilters({
        categories: ["crm", "productivity"],
        hideAnonymous: false,
      });
      const slugs = store.filteredProducts.value.map((p) => p.slug);
      expect(slugs).toContain("pipedrive");
      expect(slugs).toContain("notion");
      expect(slugs).not.toContain("slack");
    });
  });

  describe("country filter", () => {
    it("filters by single country", () => {
      store.setFilters({ countries: ["EE"], hideAnonymous: false });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "pipedrive",
      ]);
    });

    it("filters by multiple countries", () => {
      store.setFilters({ countries: ["US", "EE"], hideAnonymous: false });
      const slugs = store.filteredProducts.value.map((p) => p.slug);
      expect(slugs).toHaveLength(3);
    });
  });

  describe("hide anonymous filter", () => {
    it("hides products with 'anonymous' in name by default", () => {
      store.setFilters({ hideAnonymous: true });
      const slugs = store.filteredProducts.value.map((p) => p.slug);
      expect(slugs).not.toContain("anonymous-app");
    });

    it("shows anonymous products when disabled", () => {
      store.setFilters({ hideAnonymous: false });
      const slugs = store.filteredProducts.value.map((p) => p.slug);
      expect(slugs).toContain("anonymous-app");
    });
  });

  describe("combined filters", () => {
    it("applies all filters together", () => {
      store.setFilters({
        search: "pipe",
        categories: ["crm"],
        countries: ["EE"],
        employeeMin: 50,
        employeeMax: 1000,
        foundedFrom: 2005,
        foundedTo: 2015,
        hideAnonymous: true,
      });
      expect(store.filteredProducts.value.map((p) => p.slug)).toEqual([
        "pipedrive",
      ]);
    });

    it("returns empty when filters exclude everything", () => {
      store.setFilters({
        categories: ["nonexistent"],
        hideAnonymous: false,
      });
      expect(store.filteredProducts.value).toEqual([]);
    });
  });

  describe("sorting", () => {
    it("sorts by MRR descending by default", () => {
      store.setFilters({ hideAnonymous: false });
      const mrrs = store.filteredProducts.value.map((p) => p.mrr);
      expect(mrrs).toEqual([20000, 8000, 5000, null]);
    });

    it("sorts by name ascending", () => {
      store.setFilters({
        sortBy: "name",
        sortOrder: "asc",
        hideAnonymous: false,
      });
      const names = store.filteredProducts.value.map((p) => p.name);
      expect(names).toEqual(["Anonymous App", "Notion", "Pipedrive", "Slack"]);
    });
  });

  describe("pagination", () => {
    it("starts at page 1", () => {
      expect(store.page.value).toBe(1);
    });

    it("resets page to 1 on setFilters", () => {
      store.page.value = 3;
      store.setFilters({ search: "new" });
      expect(store.page.value).toBe(1);
    });

    it("hasMore is false when all visible", () => {
      store.setFilters({ hideAnonymous: false });
      store.pageSize.value = 100;
      expect(store.hasMore.value).toBe(false);
    });

    it("hasMore is true when more exist", () => {
      store.setFilters({ hideAnonymous: false });
      store.pageSize.value = 2;
      expect(store.hasMore.value).toBe(true);
    });

    it("loadMore increments page", () => {
      store.setFilters({ hideAnonymous: false });
      store.pageSize.value = 2;
      expect(store.products.value).toHaveLength(2);
      store.loadMore();
      expect(store.products.value).toHaveLength(4);
    });
  });
});
