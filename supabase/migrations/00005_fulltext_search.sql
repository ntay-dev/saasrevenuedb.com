-- ============================================================
-- saas-products.com — Fulltext Search + products_view enhancement
-- Adds tsvector column for fast fulltext search
-- Adds sourced_at to products_view for data age display
-- ============================================================

-- Add tsvector column to saas_products for fast search
ALTER TABLE public.saas_products ADD COLUMN IF NOT EXISTS search_vector tsvector;

-- Create GIN index for fast fulltext search
CREATE INDEX IF NOT EXISTS idx_products_search ON public.saas_products USING GIN (search_vector);

-- Function to build search vector from product data points
CREATE OR REPLACE FUNCTION public.update_product_search_vector(p_product_id UUID)
RETURNS void AS $$
DECLARE
  v_name TEXT;
  v_company TEXT;
  v_description TEXT;
  v_category TEXT;
BEGIN
  SELECT name INTO v_name FROM public.saas_products WHERE id = p_product_id;

  SELECT field_value INTO v_company
  FROM public.product_data_points
  WHERE product_id = p_product_id AND field_name = 'company' AND is_current = true
  LIMIT 1;

  SELECT field_value INTO v_description
  FROM public.product_data_points
  WHERE product_id = p_product_id AND field_name = 'description' AND is_current = true
  LIMIT 1;

  SELECT field_value INTO v_category
  FROM public.product_data_points
  WHERE product_id = p_product_id AND field_name IN ('category_name', 'category_id') AND is_current = true
  LIMIT 1;

  UPDATE public.saas_products
  SET search_vector =
    setweight(to_tsvector('english', COALESCE(v_name, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(v_company, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(v_category, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(v_description, '')), 'C')
  WHERE id = p_product_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Populate search vectors for all existing products
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.saas_products LOOP
    PERFORM public.update_product_search_vector(r.id);
  END LOOP;
END $$;

-- RPC function for fulltext search (callable from Supabase client)
CREATE OR REPLACE FUNCTION public.search_products(
  search_query TEXT,
  category_slugs TEXT[] DEFAULT NULL,
  country_codes TEXT[] DEFAULT NULL,
  employee_min INTEGER DEFAULT NULL,
  employee_max INTEGER DEFAULT NULL,
  founded_from INTEGER DEFAULT NULL,
  founded_to INTEGER DEFAULT NULL,
  hide_anonymous BOOLEAN DEFAULT true,
  sort_field TEXT DEFAULT 'mrr',
  sort_direction TEXT DEFAULT 'desc',
  page_offset INTEGER DEFAULT 0,
  page_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  slug TEXT,
  name TEXT,
  logo_url TEXT,
  website_url TEXT,
  company_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  company TEXT,
  country_code TEXT,
  country_name TEXT,
  employees INTEGER,
  category TEXT,
  category_slug TEXT,
  description TEXT,
  founded_year INTEGER,
  mrr INTEGER,
  revenue_last_30d INTEGER,
  growth_30d NUMERIC,
  customers INTEGER,
  founders TEXT,
  trustmrr_url TEXT,
  trustmrr_rank INTEGER,
  primary_source TEXT,
  primary_source_url TEXT,
  latest_sourced_at TIMESTAMPTZ,
  total_count BIGINT,
  search_rank REAL
) AS $$
DECLARE
  ts_query tsquery;
  base_query TEXT;
  where_clauses TEXT[] := ARRAY[]::TEXT[];
  order_clause TEXT;
  final_query TEXT;
BEGIN
  -- Build tsquery if search term provided
  IF search_query IS NOT NULL AND search_query <> '' THEN
    ts_query := plainto_tsquery('english', search_query);
  END IF;

  -- Build WHERE clauses
  IF search_query IS NOT NULL AND search_query <> '' THEN
    where_clauses := array_append(where_clauses,
      format('(p.search_vector @@ %L::tsquery OR pv.name ILIKE %L)',
        ts_query::TEXT, '%' || search_query || '%'));
  END IF;

  IF category_slugs IS NOT NULL AND array_length(category_slugs, 1) > 0 THEN
    where_clauses := array_append(where_clauses,
      format('pv.category_slug = ANY(%L)', category_slugs));
  END IF;

  IF country_codes IS NOT NULL AND array_length(country_codes, 1) > 0 THEN
    where_clauses := array_append(where_clauses,
      format('pv.country_code = ANY(%L)', country_codes));
  END IF;

  IF employee_min IS NOT NULL THEN
    where_clauses := array_append(where_clauses,
      format('pv.employees >= %s', employee_min));
  END IF;

  IF employee_max IS NOT NULL THEN
    where_clauses := array_append(where_clauses,
      format('pv.employees <= %s', employee_max));
  END IF;

  IF founded_from IS NOT NULL THEN
    where_clauses := array_append(where_clauses,
      format('pv.founded_year >= %s', founded_from));
  END IF;

  IF founded_to IS NOT NULL THEN
    where_clauses := array_append(where_clauses,
      format('pv.founded_year <= %s', founded_to));
  END IF;

  IF hide_anonymous THEN
    where_clauses := array_append(where_clauses,
      'pv.name NOT ILIKE ''%anonymous%''');
  END IF;

  -- Build ORDER BY
  IF search_query IS NOT NULL AND search_query <> '' AND sort_field = 'relevance' THEN
    order_clause := format('ts_rank(p.search_vector, %L::tsquery) DESC NULLS LAST', ts_query::TEXT);
  ELSIF sort_field = 'mrr' THEN
    order_clause := format('pv.mrr %s NULLS LAST', CASE WHEN sort_direction = 'asc' THEN 'ASC' ELSE 'DESC' END);
  ELSIF sort_field = 'name' THEN
    order_clause := format('pv.name %s NULLS LAST', CASE WHEN sort_direction = 'asc' THEN 'ASC' ELSE 'DESC' END);
  ELSIF sort_field = 'founded_year' THEN
    order_clause := format('pv.founded_year %s NULLS LAST', CASE WHEN sort_direction = 'asc' THEN 'ASC' ELSE 'DESC' END);
  ELSIF sort_field = 'employees' THEN
    order_clause := format('pv.employees %s NULLS LAST', CASE WHEN sort_direction = 'asc' THEN 'ASC' ELSE 'DESC' END);
  ELSE
    order_clause := format('pv.%I %s NULLS LAST', sort_field, CASE WHEN sort_direction = 'asc' THEN 'ASC' ELSE 'DESC' END);
  END IF;

  -- Build final query
  final_query := '
    SELECT
      pv.id, pv.slug, pv.name, pv.logo_url, pv.website_url, pv.company_id,
      pv.created_at, pv.updated_at,
      pv.company, pv.country_code, pv.country_name, pv.employees,
      pv.category, pv.category_slug, pv.description, pv.founded_year,
      pv.mrr, pv.revenue_last_30d, pv.growth_30d, pv.customers,
      pv.founders, pv.trustmrr_url, pv.trustmrr_rank,
      pv.primary_source, pv.primary_source_url,
      pv.latest_sourced_at,
      COUNT(*) OVER() AS total_count,
      ' || CASE WHEN search_query IS NOT NULL AND search_query <> ''
        THEN format('ts_rank(p.search_vector, %L::tsquery)', ts_query::TEXT)
        ELSE '0'
      END || '::REAL AS search_rank
    FROM public.products_view pv
    JOIN public.saas_products p ON p.id = pv.id';

  IF array_length(where_clauses, 1) > 0 THEN
    final_query := final_query || ' WHERE ' || array_to_string(where_clauses, ' AND ');
  END IF;

  final_query := final_query || ' ORDER BY ' || order_clause;
  final_query := final_query || format(' LIMIT %s OFFSET %s', page_limit, page_offset);

  RETURN QUERY EXECUTE final_query;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant access
GRANT EXECUTE ON FUNCTION public.search_products TO anon;
GRANT EXECUTE ON FUNCTION public.update_product_search_vector TO anon;

-- Update products_view to include latest_sourced_at for data age
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
  -- Category
  COALESCE(
    (SELECT cat.name FROM public.categories cat WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)),
    (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_name' AND dp.is_current = true LIMIT 1)
  ) AS category,
  (SELECT cat.slug FROM public.categories cat WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)) AS category_slug,
  -- Description
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'description' AND dp.is_current = true LIMIT 1) AS description,
  -- Founded year
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'founded_year' AND dp.is_current = true LIMIT 1) AS founded_year,
  -- MRR
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'mrr' AND dp.is_current = true LIMIT 1) AS mrr,
  -- Revenue last 30d
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'revenue_last_30d' AND dp.is_current = true LIMIT 1) AS revenue_last_30d,
  -- Growth 30d
  (SELECT dp.field_value::NUMERIC FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'growth_30d' AND dp.is_current = true LIMIT 1) AS growth_30d,
  -- Customers
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'customers' AND dp.is_current = true LIMIT 1) AS customers,
  -- Founders
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'founders' AND dp.is_current = true LIMIT 1) AS founders,
  -- TrustMRR URL
  (SELECT dp.field_value FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_url' AND dp.is_current = true LIMIT 1) AS trustmrr_url,
  -- TrustMRR Rank
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_rank' AND dp.is_current = true LIMIT 1) AS trustmrr_rank,
  -- Primary source
  (SELECT s.name FROM public.sources s WHERE s.id = (SELECT dp.source_id FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL ORDER BY dp.sourced_at DESC LIMIT 1)) AS primary_source,
  (SELECT s.url FROM public.sources s WHERE s.id = (SELECT dp.source_id FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL ORDER BY dp.sourced_at DESC LIMIT 1)) AS primary_source_url,
  -- Latest sourced_at for data age display
  (SELECT MAX(dp.sourced_at) FROM public.product_data_points dp WHERE dp.product_id = p.id AND dp.is_current = true) AS latest_sourced_at
FROM public.saas_products p;
