-- ============================================================
-- saas-products.com — Migration: TrustMRR fields + data_as_of
-- Adds data_as_of timestamp, updates products_view with
-- MRR, revenue, growth, customers, founders, TrustMRR fields
-- ============================================================

-- Add data_as_of column (when the data itself is from, e.g. "MRR as of Jan 2026")
ALTER TABLE public.product_data_points
  ADD COLUMN IF NOT EXISTS data_as_of TIMESTAMPTZ;

-- Add category_name field support (TrustMRR uses category names, not IDs)
-- No schema change needed — just use field_name = 'category_name'

-- Update products_view with new TrustMRR fields
CREATE OR REPLACE VIEW public.products_view AS
SELECT
  p.id,
  p.slug,
  p.name,
  p.logo_url,
  p.website_url,
  p.created_at,
  p.updated_at,
  -- Company
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'company' AND dp.is_current = true LIMIT 1) AS company,
  -- Country
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'country_code' AND dp.is_current = true LIMIT 1) AS country_code,
  (SELECT c.name_de FROM public.countries c WHERE c.code = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'country_code' AND dp.is_current = true LIMIT 1)) AS country_name,
  -- Employees
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'employees' AND dp.is_current = true LIMIT 1) AS employees,
  -- Category (support both category_id and category_name)
  COALESCE(
    (SELECT cat.name FROM public.categories cat WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)),
    (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_name' AND dp.is_current = true LIMIT 1)
  ) AS category,
  (SELECT cat.slug FROM public.categories cat WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)) AS category_slug,
  -- Description
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'description' AND dp.is_current = true LIMIT 1) AS description,
  -- Founded year
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'founded_year' AND dp.is_current = true LIMIT 1) AS founded_year,
  -- MRR (USD)
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'mrr' AND dp.is_current = true LIMIT 1) AS mrr,
  -- Revenue last 30 days (USD)
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'revenue_last_30d' AND dp.is_current = true LIMIT 1) AS revenue_last_30d,
  -- Growth 30d (%)
  (SELECT dp.field_value::NUMERIC FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'growth_30d' AND dp.is_current = true LIMIT 1) AS growth_30d,
  -- Customers
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'customers' AND dp.is_current = true LIMIT 1) AS customers,
  -- Founders (JSON array)
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'founders' AND dp.is_current = true LIMIT 1) AS founders,
  -- TrustMRR URL
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_url' AND dp.is_current = true LIMIT 1) AS trustmrr_url,
  -- TrustMRR Rank
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_rank' AND dp.is_current = true LIMIT 1) AS trustmrr_rank
FROM public.saas_products p;
