-- ============================================================
-- saas-products.com — Initial Schema
-- ============================================================

-- Sources: Where information comes from
CREATE TABLE public.sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  url TEXT,
  type TEXT NOT NULL DEFAULT 'website', -- 'website', 'api', 'report', 'manual', 'crunchbase', 'linkedin', 'wikipedia'
  trust_level INTEGER NOT NULL DEFAULT 50 CHECK (trust_level >= 0 AND trust_level <= 100),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Product categories
CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Countries
CREATE TABLE public.countries (
  code TEXT PRIMARY KEY, -- ISO 3166-1 alpha-2
  name_en TEXT NOT NULL,
  name_de TEXT NOT NULL
);

-- Main SaaS products table
CREATE TABLE public.saas_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  logo_url TEXT,
  website_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Per-field data points with source tracking
-- Each attribute of a product is stored as a data point with its own source
CREATE TABLE public.product_data_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.saas_products(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL, -- 'company', 'country_code', 'employees', 'category_id', 'description', 'founded_year', etc.
  field_value TEXT NOT NULL,
  source_id UUID REFERENCES public.sources(id) ON DELETE SET NULL,
  sourced_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- when was this info retrieved from the source
  is_current BOOLEAN NOT NULL DEFAULT true, -- marks the latest value for this field
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure only one current value per product per field per source
CREATE UNIQUE INDEX unique_current_field ON public.product_data_points (product_id, field_name, source_id) WHERE (is_current = true);

-- Index for fast lookups
CREATE INDEX idx_data_points_product ON public.product_data_points(product_id);
CREATE INDEX idx_data_points_field ON public.product_data_points(product_id, field_name) WHERE is_current = true;
CREATE INDEX idx_data_points_source ON public.product_data_points(source_id);

-- View: Flattened product view with latest data for easy querying
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
  -- Category
  (SELECT cat.name FROM public.categories cat WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)) AS category,
  (SELECT cat.slug FROM public.categories cat WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)) AS category_slug,
  -- Description
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'description' AND dp.is_current = true LIMIT 1) AS description,
  -- Founded year
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'founded_year' AND dp.is_current = true LIMIT 1) AS founded_year
FROM public.saas_products p;

-- RLS policies (public read, no write from client)
ALTER TABLE public.sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saas_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_data_points ENABLE ROW LEVEL SECURITY;

-- Public read access
CREATE POLICY "Public read sources" ON public.sources FOR SELECT USING (true);
CREATE POLICY "Public read categories" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Public read countries" ON public.countries FOR SELECT USING (true);
CREATE POLICY "Public read products" ON public.saas_products FOR SELECT USING (true);
CREATE POLICY "Public read data points" ON public.product_data_points FOR SELECT USING (true);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sources_updated_at BEFORE UPDATE ON public.sources FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER products_updated_at BEFORE UPDATE ON public.saas_products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
