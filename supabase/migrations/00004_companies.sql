-- ============================================================
-- saas-products.com — Companies Table
-- Sprint 2: Separate companies from products
-- ============================================================

CREATE TABLE public.companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  logo_url TEXT,
  website_url TEXT,
  country_code TEXT REFERENCES public.countries(code),
  founded_year INTEGER,
  employees INTEGER,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add company_id foreign key to saas_products
ALTER TABLE public.saas_products ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES public.companies(id);

-- Indexes
CREATE INDEX idx_companies_slug ON public.companies(slug);
CREATE INDEX idx_companies_country ON public.companies(country_code);
CREATE INDEX idx_products_company ON public.saas_products(company_id);

-- RLS
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read companies" ON public.companies FOR SELECT USING (true);

-- Updated_at trigger
CREATE TRIGGER companies_updated_at BEFORE UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Grant anon access
GRANT SELECT ON public.companies TO anon;

-- Update products_view to include company_id (preserves all existing fields from 00002)
CREATE OR REPLACE VIEW public.products_view AS
SELECT
  p.id,
  p.slug,
  p.name,
  p.logo_url,
  p.website_url,
  p.company_id,
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
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_rank' AND dp.is_current = true LIMIT 1) AS trustmrr_rank,
  -- Primary source info
  (SELECT s.name FROM public.sources s WHERE s.id = (SELECT dp.source_id FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL ORDER BY dp.sourced_at DESC LIMIT 1)) AS primary_source,
  (SELECT s.url FROM public.sources s WHERE s.id = (SELECT dp.source_id FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL ORDER BY dp.sourced_at DESC LIMIT 1)) AS primary_source_url
FROM public.saas_products p;
