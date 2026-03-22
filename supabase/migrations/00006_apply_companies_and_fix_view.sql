-- ============================================================
-- Apply companies table + fix products_view
-- Combines 00004 (companies) + 00005 (latest_sourced_at)
-- that were never applied to production
-- ============================================================

-- 1. Create companies table
CREATE TABLE IF NOT EXISTS public.companies (
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

-- 2. Add company_id to saas_products
ALTER TABLE public.saas_products ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES public.companies(id);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_companies_slug ON public.companies(slug);
CREATE INDEX IF NOT EXISTS idx_companies_country ON public.companies(country_code);
CREATE INDEX IF NOT EXISTS idx_products_company ON public.saas_products(company_id);

-- 4. RLS
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'companies' AND policyname = 'Public read companies') THEN
    CREATE POLICY "Public read companies" ON public.companies FOR SELECT USING (true);
  END IF;
END $$;

-- 5. Trigger
DROP TRIGGER IF EXISTS companies_updated_at ON public.companies;
CREATE TRIGGER companies_updated_at BEFORE UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- 6. Grant
GRANT SELECT ON public.companies TO anon;

-- 7. Drop and recreate products_view with company_id + latest_sourced_at
DROP VIEW IF EXISTS public.products_view;
CREATE VIEW public.products_view AS
SELECT
  p.id,
  p.slug,
  p.name,
  p.logo_url,
  p.website_url,
  p.company_id,
  p.created_at,
  p.updated_at,
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'company' AND dp.is_current = true LIMIT 1) AS company,
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'country_code' AND dp.is_current = true LIMIT 1) AS country_code,
  (SELECT c.name_de FROM public.countries c WHERE c.code = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'country_code' AND dp.is_current = true LIMIT 1)) AS country_name,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'employees' AND dp.is_current = true LIMIT 1) AS employees,
  COALESCE(
    (SELECT cat.name FROM public.categories cat WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)),
    (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_name' AND dp.is_current = true LIMIT 1)
  ) AS category,
  (SELECT cat.slug FROM public.categories cat WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)) AS category_slug,
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'description' AND dp.is_current = true LIMIT 1) AS description,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'founded_year' AND dp.is_current = true LIMIT 1) AS founded_year,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'mrr' AND dp.is_current = true LIMIT 1) AS mrr,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'revenue_last_30d' AND dp.is_current = true LIMIT 1) AS revenue_last_30d,
  (SELECT dp.field_value::NUMERIC FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'growth_30d' AND dp.is_current = true LIMIT 1) AS growth_30d,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'customers' AND dp.is_current = true LIMIT 1) AS customers,
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'founders' AND dp.is_current = true LIMIT 1) AS founders,
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_url' AND dp.is_current = true LIMIT 1) AS trustmrr_url,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_rank' AND dp.is_current = true LIMIT 1) AS trustmrr_rank,
  (SELECT s.name FROM public.sources s WHERE s.id = (SELECT dp.source_id FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL ORDER BY dp.sourced_at DESC LIMIT 1)) AS primary_source,
  (SELECT s.url FROM public.sources s WHERE s.id = (SELECT dp.source_id FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL ORDER BY dp.sourced_at DESC LIMIT 1)) AS primary_source_url,
  (SELECT MAX(dp.sourced_at) FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.is_current = true) AS latest_sourced_at
FROM public.saas_products p;

-- 8. Grant on view
GRANT SELECT ON public.products_view TO anon;
