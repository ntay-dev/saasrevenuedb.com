import { describe, it, expect, vi, beforeEach } from "vitest";

import { useProducts } from "~/composables/useProducts";

describe("useProducts", () => {
  let composable: ReturnType<typeof useProducts>;
  let mockDuck: any;

  beforeEach(() => {
    mockDuck = (globalThis as any).__mockDuckDB;
    mockDuck.query.mockResolvedValue([]);
    mockDuck.ensureData.mockResolvedValue(undefined);
    mockDuck.ensureDatapoints.mockResolvedValue(undefined);
    vi.clearAllMocks();
    composable = useProducts();
  });

  describe("initial state", () => {
    it("starts with loading false", () => {
      expect(composable.loading.value).toBe(false);
    });

    it("starts with no error", () => {
      expect(composable.error.value).toBeNull();
    });
  });

  describe("fetchProduct", () => {
    it("ensures DuckDB data is loaded", async () => {
      await composable.fetchProduct("notion");
      expect(mockDuck.ensureData).toHaveBeenCalled();
    });

    it("returns product data on success", async () => {
      const product = { slug: "notion", name: "Notion" };
      mockDuck.query.mockResolvedValueOnce([product]);
      const result = await composable.fetchProduct("notion");
      expect(result).toEqual(product);
    });

    it("queries by slug via DuckDB SQL", async () => {
      await composable.fetchProduct("notion");
      const sql = mockDuck.query.mock.calls[0][0] as string;
      expect(sql).toContain("notion");
      expect(sql).toContain("slug");
      expect(sql).toContain("gold");
    });

    it("returns null when product not found", async () => {
      mockDuck.query.mockResolvedValueOnce([]);
      const result = await composable.fetchProduct("nonexistent");
      expect(result).toBeNull();
    });

    it("returns null and sets error on failure", async () => {
      mockDuck.ensureData.mockRejectedValueOnce(new Error("DB error"));
      const result = await composable.fetchProduct("test");
      expect(result).toBeNull();
      expect(composable.error.value).toBe("DB error");
    });

    it("sets loading false after fetch", async () => {
      await composable.fetchProduct("test");
      expect(composable.loading.value).toBe(false);
    });

    it("escapes single quotes in slug", async () => {
      await composable.fetchProduct("test's-product");
      const sql = mockDuck.query.mock.calls[0][0] as string;
      expect(sql).toContain("test''s-product");
    });
  });

  describe("fetchProductDataPoints", () => {
    it("loads datapoints from DuckDB with source join", async () => {
      mockDuck.query.mockResolvedValueOnce([]);
      await composable.fetchProductDataPoints("abc-123");
      expect(mockDuck.ensureDatapoints).toHaveBeenCalled();
      const sql = mockDuck.query.mock.calls[0][0] as string;
      expect(sql).toContain("data_points");
      expect(sql).toContain("sources");
      expect(sql).toContain("abc-123");
    });

    it("returns empty array on error", async () => {
      mockDuck.ensureDatapoints.mockRejectedValueOnce(new Error("fail"));
      const result = await composable.fetchProductDataPoints("abc-123");
      expect(result).toEqual([]);
    });
  });
});
