-- Fix: Gold view used German country names (name_de). Switch to English (name_en).

-- Drop and recreate the refresh function first (it depends on the view)
CREATE OR REPLACE FUNCTION public.refresh_gold_view()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DROP MATERIALIZED VIEW IF EXISTS products_gold;

  CREATE MATERIALIZED VIEW products_gold AS
  SELECT
    p.id, p.slug, p.name, p.logo_url, p.website_url,
    p.company_id, p.created_at, p.updated_at,

    (SELECT dp.field_value FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'company' AND dp.is_current = true LIMIT 1) AS company,

    (SELECT dp.field_value FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'country_code' AND dp.is_current = true LIMIT 1) AS country_code,

    (SELECT c.name_en FROM countries c
     WHERE c.code = (SELECT dp.field_value FROM product_data_points dp
                     WHERE dp.product_id = p.id AND dp.field_name = 'country_code' AND dp.is_current = true LIMIT 1)
    ) AS country_name,

    (SELECT dp.field_value::integer FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'employees' AND dp.is_current = true LIMIT 1) AS employees,

    COALESCE(
      (SELECT cat.name FROM categories cat WHERE cat.id::text = (SELECT dp.field_value FROM product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)),
      (SELECT cat.name FROM categories cat WHERE cat.name = (SELECT dp.field_value FROM product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_name' AND dp.is_current = true LIMIT 1)),
      (SELECT dp.field_value FROM product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_name' AND dp.is_current = true LIMIT 1)
    ) AS category,

    COALESCE(
      (SELECT cat.slug FROM categories cat WHERE cat.id::text = (SELECT dp.field_value FROM product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)),
      (SELECT cat.slug FROM categories cat WHERE cat.name = (SELECT dp.field_value FROM product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_name' AND dp.is_current = true LIMIT 1))
    ) AS category_slug,

    (SELECT dp.field_value FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'description' AND dp.is_current = true LIMIT 1) AS description,

    (SELECT dp.field_value::integer FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'founded_year' AND dp.is_current = true LIMIT 1) AS founded_year,

    (SELECT dp.field_value::bigint FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'mrr' AND dp.is_current = true LIMIT 1) AS mrr,

    (SELECT dp.field_value::bigint FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'revenue_last_30d' AND dp.is_current = true LIMIT 1) AS revenue_last_30d,

    (SELECT dp.field_value::numeric FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'growth_30d' AND dp.is_current = true LIMIT 1) AS growth_30d,

    (SELECT dp.field_value::bigint FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'customers' AND dp.is_current = true LIMIT 1) AS customers,

    (SELECT dp.field_value FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'founders' AND dp.is_current = true LIMIT 1) AS founders,

    (SELECT dp.field_value FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_url' AND dp.is_current = true LIMIT 1) AS trustmrr_url,

    (SELECT dp.field_value::integer FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_rank' AND dp.is_current = true LIMIT 1) AS trustmrr_rank,

    (SELECT s.name FROM sources s WHERE s.id = (
      SELECT dp.source_id FROM product_data_points dp
      WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL
      ORDER BY dp.sourced_at DESC LIMIT 1
    )) AS primary_source,

    (SELECT s.url FROM sources s WHERE s.id = (
      SELECT dp.source_id FROM product_data_points dp
      WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL
      ORDER BY dp.sourced_at DESC LIMIT 1
    )) AS primary_source_url,

    (SELECT max(dp.sourced_at) FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.is_current = true) AS latest_sourced_at

  FROM saas_products p;

  -- Recreate index for fast lookups
  CREATE UNIQUE INDEX IF NOT EXISTS idx_products_gold_id ON products_gold(id);
  CREATE INDEX IF NOT EXISTS idx_products_gold_slug ON products_gold(slug);
  CREATE INDEX IF NOT EXISTS idx_products_gold_mrr ON products_gold(mrr DESC NULLS LAST);
END;
$$;

-- Refresh now to apply the fix
SELECT refresh_gold_view();
