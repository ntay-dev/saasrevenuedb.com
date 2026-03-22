import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("pinia", () => ({
  defineStore: (id: string, setup: () => unknown) => () => setup(),
}));

import { useProductsStore } from "~/stores/products";

describe("products store DuckDB initialization", () => {
  let mockDuck: any;

  beforeEach(() => {
    mockDuck = (globalThis as any).__mockDuckDB;
    mockDuck.query.mockResolvedValue([]);
    mockDuck.ensureData.mockResolvedValue(undefined);
    mockDuck.ensureDatapoints.mockResolvedValue(undefined);
    vi.clearAllMocks();
  });

  it("initializes from DuckDB and sets initialized flag", async () => {
    const store = useProductsStore();
    await store.initialize();
    expect(store.initialized.value).toBe(true);
    expect(mockDuck.ensureData).toHaveBeenCalledOnce();
  });

  it("loads products, categories, countries, sources from DuckDB", async () => {
    const mockProducts = [{ id: "1", name: "Test", slug: "test", mrr: 5000 }];
    mockDuck.query
      .mockResolvedValueOnce(mockProducts) // products
      .mockResolvedValueOnce([]) // categories
      .mockResolvedValueOnce([]) // countries
      .mockResolvedValueOnce([]); // sources

    const store = useProductsStore();
    await store.initialize();

    expect(store.allProducts.value).toEqual(mockProducts);
    expect(store.loadProgress.value).toBe(100);
  });

  it("does not re-initialize if already initialized", async () => {
    const store = useProductsStore();
    await store.initialize();
    const callCount = mockDuck.ensureData.mock.calls.length;
    await store.initialize();
    expect(mockDuck.ensureData.mock.calls.length).toBe(callCount);
  });

  it("sets error on DuckDB failure", async () => {
    mockDuck.ensureData.mockRejectedValueOnce(new Error("DuckDB init failed"));

    const store = useProductsStore();
    await store.initialize();

    expect(store.error.value).toBe("DuckDB init failed");
    expect(store.loading.value).toBe(false);
  });
});
