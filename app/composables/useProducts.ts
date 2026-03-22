import type {
  ProductView,
  Source,
  ProductDataPoint,
} from "~/types/database.types";

/**
 * Composable for single-product detail fetches via DuckDB.
 * The product list/filtering is handled by the Pinia store.
 */
export function useProducts() {
  const duck = useDuckDB();
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchProduct(slug: string) {
    loading.value = true;
    error.value = null;

    try {
      await duck.ensureData();

      const safeSlug = slug.replace(/'/g, "''");
      const rows = await duck.query<ProductView>(
        `SELECT * FROM gold WHERE slug = '${safeSlug}' LIMIT 1`,
      );

      return rows[0] ?? null;
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : "Product not found";
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function fetchProductDataPoints(productId: string) {
    try {
      await duck.ensureDatapoints();

      const safeId = productId.replace(/'/g, "''");

      // Query data points with source info joined
      const rows = await duck.query<Record<string, unknown>>(
        `SELECT
          dp.id, dp.product_id, dp.field_name, dp.field_value,
          dp.source_id, dp.sourced_at, dp.data_as_of,
          s.id as s_id, s.name as s_name, s.url as s_url,
          s.type as s_type, s.trust_level as s_trust_level,
          s.notes as s_notes
        FROM data_points dp
        LEFT JOIN sources s ON dp.source_id = s.id
        WHERE dp.product_id = '${safeId}'
        ORDER BY dp.field_name`,
      );

      // Reshape into expected format
      return rows.map((r) => ({
        id: r.id as string,
        product_id: r.product_id as string,
        field_name: r.field_name as string,
        field_value: r.field_value as string,
        source_id: r.source_id as string | null,
        sourced_at: r.sourced_at as string,
        data_as_of: r.data_as_of as string | null,
        is_current: true,
        created_at: "",
        source: r.s_id
          ? {
              id: r.s_id as string,
              name: r.s_name as string,
              url: r.s_url as string | null,
              type: r.s_type as string,
              trust_level: r.s_trust_level as number,
              notes: r.s_notes as string | null,
              created_at: "",
              updated_at: "",
            }
          : null,
      })) as (ProductDataPoint & { source: Source | null })[];
    } catch (e) {
      console.error("Error fetching data points:", e);
      return [];
    }
  }

  return {
    loading,
    error,
    fetchProduct,
    fetchProductDataPoints,
  };
}
