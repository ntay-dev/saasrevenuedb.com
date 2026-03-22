-- ============================================================
-- 00007_medallion_architecture.sql
-- Introduces Bronze/Silver/Gold medallion data architecture
-- WARNING: Drops all existing product data (confirmed OK)
-- ============================================================

-- ======================== BRONZE LAYER ========================

-- Pipeline run tracking
CREATE TABLE public.pipeline_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'running'
    CHECK (status IN ('running', 'completed', 'failed', 'partial')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  records_fetched INTEGER DEFAULT 0,
  records_loaded INTEGER DEFAULT 0,
  records_errors INTEGER DEFAULT 0,
  error_message TEXT,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_pipeline_runs_source ON public.pipeline_runs(source_name);
CREATE INDEX idx_pipeline_runs_status ON public.pipeline_runs(status);
CREATE INDEX idx_pipeline_runs_started ON public.pipeline_runs(started_at DESC);

-- Bronze: raw ingested records
CREATE TABLE public.bronze_raw_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_run_id UUID NOT NULL REFERENCES public.pipeline_runs(id) ON DELETE CASCADE,
  source_name TEXT NOT NULL,
  external_id TEXT NOT NULL,
  raw_data JSONB NOT NULL,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  checksum TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_bronze_unique_record
  ON public.bronze_raw_records(pipeline_run_id, source_name, external_id);
CREATE INDEX idx_bronze_source ON public.bronze_raw_records(source_name);
CREATE INDEX idx_bronze_external_id ON public.bronze_raw_records(source_name, external_id);
CREATE INDEX idx_bronze_fetched ON public.bronze_raw_records(fetched_at DESC);

-- Pipeline transformation log
CREATE TABLE public.pipeline_transformations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_run_id UUID REFERENCES public.pipeline_runs(id) ON DELETE CASCADE,
  bronze_record_id UUID REFERENCES public.bronze_raw_records(id) ON DELETE CASCADE,
  product_slug TEXT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('insert', 'update', 'skip', 'error')),
  changes JSONB,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_transformations_run ON public.pipeline_transformations(pipeline_run_id);
CREATE INDEX idx_transformations_slug ON public.pipeline_transformations(product_slug);

-- ======================== SILVER LAYER ========================
-- Keep existing tables (sources, categories, countries, companies, saas_products, product_data_points)
-- but truncate all product data to start fresh from Bronze

DROP VIEW IF EXISTS public.products_view;

TRUNCATE public.product_data_points CASCADE;
TRUNCATE public.saas_products CASCADE;
TRUNCATE public.companies CASCADE;

-- ======================== GOLD LAYER ========================

CREATE MATERIALIZED VIEW public.products_gold AS
SELECT
  p.id,
  p.slug,
  p.name,
  p.logo_url,
  p.website_url,
  p.company_id,
  p.created_at,
  p.updated_at,
  (SELECT dp.field_value FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'company'
   AND dp.is_current = true LIMIT 1) AS company,
  (SELECT dp.field_value FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'country_code'
   AND dp.is_current = true LIMIT 1) AS country_code,
  (SELECT c.name_de FROM public.countries c
   WHERE c.code = (SELECT dp.field_value FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'country_code'
   AND dp.is_current = true LIMIT 1)) AS country_name,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'employees'
   AND dp.is_current = true LIMIT 1) AS employees,
  COALESCE(
    (SELECT cat.name FROM public.categories cat
     WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'category_id'
     AND dp.is_current = true LIMIT 1)),
    (SELECT dp.field_value FROM public.product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'category_name'
     AND dp.is_current = true LIMIT 1)
  ) AS category,
  (SELECT cat.slug FROM public.categories cat
   WHERE cat.id::TEXT = (SELECT dp.field_value FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'category_id'
   AND dp.is_current = true LIMIT 1)) AS category_slug,
  (SELECT dp.field_value FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'description'
   AND dp.is_current = true LIMIT 1) AS description,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'founded_year'
   AND dp.is_current = true LIMIT 1) AS founded_year,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'mrr'
   AND dp.is_current = true LIMIT 1) AS mrr,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'revenue_last_30d'
   AND dp.is_current = true LIMIT 1) AS revenue_last_30d,
  (SELECT dp.field_value::NUMERIC FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'growth_30d'
   AND dp.is_current = true LIMIT 1) AS growth_30d,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'customers'
   AND dp.is_current = true LIMIT 1) AS customers,
  (SELECT dp.field_value FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'founders'
   AND dp.is_current = true LIMIT 1) AS founders,
  (SELECT dp.field_value FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_url'
   AND dp.is_current = true LIMIT 1) AS trustmrr_url,
  (SELECT dp.field_value::INTEGER FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_rank'
   AND dp.is_current = true LIMIT 1) AS trustmrr_rank,
  (SELECT s.name FROM public.sources s
   WHERE s.id = (SELECT dp.source_id FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL
   ORDER BY dp.sourced_at DESC LIMIT 1)) AS primary_source,
  (SELECT s.url FROM public.sources s
   WHERE s.id = (SELECT dp.source_id FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL
   ORDER BY dp.sourced_at DESC LIMIT 1)) AS primary_source_url,
  (SELECT MAX(dp.sourced_at) FROM public.product_data_points dp
   WHERE dp.product_id = p.id AND dp.is_current = true) AS latest_sourced_at
FROM public.saas_products p
WITH NO DATA;

CREATE UNIQUE INDEX idx_products_gold_id ON public.products_gold(id);
CREATE INDEX idx_products_gold_slug ON public.products_gold(slug);
CREATE INDEX idx_products_gold_mrr ON public.products_gold(mrr DESC NULLS LAST);
CREATE INDEX idx_products_gold_name ON public.products_gold(name);

-- ======================== RLS ========================

ALTER TABLE public.pipeline_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bronze_raw_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pipeline_transformations ENABLE ROW LEVEL SECURITY;

-- Pipeline tables: service role only (no public read)
-- Gold view: public read
GRANT SELECT ON public.products_gold TO anon;
GRANT SELECT ON public.products_gold TO authenticated;

-- ======================== TRANSFORM FUNCTION ========================

CREATE OR REPLACE FUNCTION public.transform_bronze_to_silver(p_run_id UUID)
RETURNS TABLE(inserts INTEGER, updates INTEGER, skips INTEGER, errors INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserts INTEGER := 0;
  v_updates INTEGER := 0;
  v_skips INTEGER := 0;
  v_errors INTEGER := 0;
  v_record RECORD;
  v_source_id UUID;
  v_product_id UUID;
  v_slug TEXT;
  v_existing_checksum TEXT;
  v_raw JSONB;
  v_now TIMESTAMPTZ := now();
  v_action TEXT;
  v_name TEXT;
BEGIN
  FOR v_record IN
    SELECT * FROM public.bronze_raw_records
    WHERE pipeline_run_id = p_run_id
  LOOP
    BEGIN
      v_raw := v_record.raw_data;

      -- ========== SLUG ==========
      IF v_record.source_name = 'trustmrr' THEN
        v_slug := v_raw->>'slug';
      ELSIF v_record.source_name = 'indiehackers' THEN
        v_slug := v_record.external_id;
      ELSIF v_record.source_name = 'acquire' THEN
        v_slug := v_record.external_id;
      ELSE
        v_slug := v_record.external_id;
      END IF;

      IF v_slug IS NULL OR v_slug = '' THEN
        v_slug := lower(regexp_replace(
          regexp_replace(COALESCE(v_raw->>'name', v_record.external_id), '[^a-zA-Z0-9]+', '-', 'g'),
          '(^-+|-+$)', '', 'g'
        ));
      END IF;

      -- ========== CHANGE DETECTION ==========
      SELECT br.checksum INTO v_existing_checksum
      FROM public.bronze_raw_records br
      WHERE br.source_name = v_record.source_name
        AND br.external_id = v_record.external_id
        AND br.pipeline_run_id != p_run_id
      ORDER BY br.fetched_at DESC
      LIMIT 1;

      IF v_existing_checksum IS NOT NULL AND v_existing_checksum = v_record.checksum THEN
        v_skips := v_skips + 1;
        INSERT INTO public.pipeline_transformations
          (pipeline_run_id, bronze_record_id, product_slug, action)
        VALUES (p_run_id, v_record.id, v_slug, 'skip');
        CONTINUE;
      END IF;

      -- ========== GET/CREATE SOURCE ==========
      IF v_record.source_name = 'trustmrr' THEN
        SELECT id INTO v_source_id FROM public.sources WHERE name = 'TrustMRR' LIMIT 1;
        IF v_source_id IS NULL THEN
          INSERT INTO public.sources (name, url, type, trust_level, notes)
          VALUES ('TrustMRR', 'https://trustmrr.com', 'api', 85, 'Stripe-verifizierte Revenue-Daten')
          RETURNING id INTO v_source_id;
        END IF;
      ELSIF v_record.source_name = 'indiehackers' THEN
        SELECT id INTO v_source_id FROM public.sources WHERE name = 'IndieHackers' LIMIT 1;
        IF v_source_id IS NULL THEN
          INSERT INTO public.sources (name, url, type, trust_level, notes)
          VALUES ('IndieHackers', 'https://www.indiehackers.com', 'api', 40, 'Self-reported revenue data')
          RETURNING id INTO v_source_id;
        END IF;
      ELSIF v_record.source_name = 'acquire' THEN
        SELECT id INTO v_source_id FROM public.sources WHERE name = 'Acquire.com' LIMIT 1;
        IF v_source_id IS NULL THEN
          INSERT INTO public.sources (name, url, type, trust_level, notes)
          VALUES ('Acquire.com', 'https://acquire.com', 'api', 70, 'SaaS marketplace listings')
          RETURNING id INTO v_source_id;
        END IF;
      END IF;

      -- ========== PRODUCT NAME ==========
      IF v_record.source_name = 'trustmrr' THEN
        v_name := v_raw->>'name';
      ELSIF v_record.source_name = 'indiehackers' THEN
        v_name := COALESCE(v_raw->>'name', v_record.external_id);
      ELSIF v_record.source_name = 'acquire' THEN
        v_name := COALESCE(v_raw->>'n', v_record.external_id);
      ELSE
        v_name := COALESCE(v_raw->>'name', v_record.external_id);
      END IF;

      -- ========== UPSERT PRODUCT ==========
      INSERT INTO public.saas_products (slug, name, logo_url, website_url)
      VALUES (
        v_slug,
        v_name,
        CASE v_record.source_name
          WHEN 'trustmrr' THEN v_raw->>'icon'
          ELSE v_raw->>'logo_url'
        END,
        CASE v_record.source_name
          WHEN 'trustmrr' THEN v_raw->>'website'
          WHEN 'indiehackers' THEN v_raw->>'websiteUrl'
          WHEN 'acquire' THEN v_raw->>'u'
          ELSE v_raw->>'website_url'
        END
      )
      ON CONFLICT (slug) DO UPDATE SET
        name = COALESCE(EXCLUDED.name, saas_products.name),
        logo_url = COALESCE(EXCLUDED.logo_url, saas_products.logo_url),
        website_url = COALESCE(EXCLUDED.website_url, saas_products.website_url),
        updated_at = now()
      RETURNING id INTO v_product_id;

      -- Determine action
      IF v_existing_checksum IS NULL THEN
        v_action := 'insert';
        v_inserts := v_inserts + 1;
      ELSE
        v_action := 'update';
        v_updates := v_updates + 1;
      END IF;

      -- Mark old data points from this source as not current
      UPDATE public.product_data_points
      SET is_current = false
      WHERE product_id = v_product_id
        AND source_id = v_source_id
        AND is_current = true;

      -- ========== EXTRACT FIELDS PER SOURCE ==========

      IF v_record.source_name = 'trustmrr' THEN
        -- Company name
        IF v_raw->>'name' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'company', v_raw->>'name', v_source_id, v_now, v_now, true);
        END IF;

        -- MRR
        IF v_raw->'revenue'->>'mrr' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'mrr', round((v_raw->'revenue'->>'mrr')::NUMERIC)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        -- Revenue last 30d
        IF v_raw->'revenue'->>'last30Days' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'revenue_last_30d', round((v_raw->'revenue'->>'last30Days')::NUMERIC)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        -- Growth 30d
        IF v_raw->>'growth30d' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'growth_30d', round((v_raw->>'growth30d')::NUMERIC * 100, 1)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        -- Customers
        IF v_raw->>'customers' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'customers', v_raw->>'customers', v_source_id, v_now, v_now, true);
        END IF;

        -- Country
        IF v_raw->>'country' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'country_code', v_raw->>'country', v_source_id, v_now, v_now, true);
        END IF;

        -- Category
        IF v_raw->>'category' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'category_name', v_raw->>'category', v_source_id, v_now, v_now, true);
        END IF;

        -- Description
        IF v_raw->>'description' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'description', v_raw->>'description', v_source_id, v_now, v_now, true);
        END IF;

        -- Founded year
        IF v_raw->>'foundedDate' IS NOT NULL THEN
          BEGIN
            INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
            VALUES (v_product_id, 'founded_year', extract(year from (v_raw->>'foundedDate')::date)::TEXT, v_source_id, v_now, v_now, true);
          EXCEPTION WHEN OTHERS THEN NULL; -- skip invalid dates
          END;
        END IF;

        -- Founders
        IF v_raw->'cofounders' IS NOT NULL AND jsonb_array_length(COALESCE(v_raw->'cofounders', '[]'::jsonb)) > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'founders', v_raw->'cofounders'::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        -- TrustMRR URL
        INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
        VALUES (v_product_id, 'trustmrr_url', 'https://trustmrr.com/' || (v_raw->>'slug'), v_source_id, v_now, v_now, true);

        -- Rank
        IF v_raw->>'rank' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'trustmrr_rank', v_raw->>'rank', v_source_id, v_now, v_now, true);
        END IF;

      ELSIF v_record.source_name = 'indiehackers' THEN
        -- Company name
        IF v_raw->>'name' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'company', v_raw->>'name', v_source_id, v_now, v_now, true);
        END IF;

        -- MRR (self-reported)
        IF (v_raw->>'monthlyRevenue')::NUMERIC > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'mrr', round((v_raw->>'monthlyRevenue')::NUMERIC)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        -- Description
        IF v_raw->>'description' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'description', v_raw->>'description', v_source_id, v_now, v_now, true);
        END IF;

        -- Country
        IF v_raw->>'country' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'country_code', v_raw->>'country', v_source_id, v_now, v_now, true);
        END IF;

        -- Founded year from startDate
        IF v_raw->>'startDate' IS NOT NULL THEN
          BEGIN
            INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
            VALUES (v_product_id, 'founded_year', extract(year from (v_raw->>'startDate')::date)::TEXT, v_source_id, v_now, v_now, true);
          EXCEPTION WHEN OTHERS THEN NULL;
          END;
        END IF;

        -- Founders
        IF v_raw->'founders' IS NOT NULL AND jsonb_array_length(COALESCE(v_raw->'founders', '[]'::jsonb)) > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'founders', v_raw->'founders'::TEXT, v_source_id, v_now, v_now, true);
        END IF;

      ELSIF v_record.source_name = 'acquire' THEN
        -- Company name
        IF v_raw->>'n' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'company', v_raw->>'n', v_source_id, v_now, v_now, true);
        END IF;

        -- MRR
        IF (v_raw->>'m')::NUMERIC > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'mrr', round((v_raw->>'m')::NUMERIC)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        -- Category
        IF v_raw->>'c' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'category_name', v_raw->>'c', v_source_id, v_now, v_now, true);
        END IF;

        -- Description
        IF v_raw->>'d' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'description', v_raw->>'d', v_source_id, v_now, v_now, true);
        END IF;
      END IF;

      -- Log transformation
      INSERT INTO public.pipeline_transformations
        (pipeline_run_id, bronze_record_id, product_slug, action)
      VALUES (p_run_id, v_record.id, v_slug, v_action);

    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      INSERT INTO public.pipeline_transformations
        (pipeline_run_id, bronze_record_id, product_slug, action, error_message)
      VALUES (p_run_id, v_record.id, COALESCE(v_slug, 'unknown'), 'error', SQLERRM);
    END;
  END LOOP;

  RETURN QUERY SELECT v_inserts, v_updates, v_skips, v_errors;
END;
$$;

-- Refresh gold view function
CREATE OR REPLACE FUNCTION public.refresh_gold_view()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF (SELECT relispopulated FROM pg_class WHERE relname = 'products_gold' AND relkind = 'm') THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.products_gold;
  ELSE
    REFRESH MATERIALIZED VIEW public.products_gold;
  END IF;
END;
$$;
