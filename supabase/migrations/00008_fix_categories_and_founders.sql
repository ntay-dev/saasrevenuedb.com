-- Migration 00008: Fix categories mapping + founder extraction from xHandle
--
-- Problems fixed:
-- 1. TrustMRR categories don't match lookup table (different names)
-- 2. Founders not extracted because API returns xHandle, not cofounders
-- 3. category_slug is NULL in Gold because category_id is never set

-- ============================================================
-- 1. Add missing categories from TrustMRR data
-- ============================================================

INSERT INTO categories (id, name, slug) VALUES
  (gen_random_uuid(), 'Artificial Intelligence', 'artificial-intelligence'),
  (gen_random_uuid(), 'Community', 'community'),
  (gen_random_uuid(), 'Content Creation', 'content-creation'),
  (gen_random_uuid(), 'Crypto & Web3', 'crypto-web3'),
  (gen_random_uuid(), 'Education', 'education'),
  (gen_random_uuid(), 'Entertainment', 'entertainment'),
  (gen_random_uuid(), 'Games', 'games'),
  (gen_random_uuid(), 'Green Tech', 'green-tech'),
  (gen_random_uuid(), 'Health & Fitness', 'health-fitness'),
  (gen_random_uuid(), 'Legal', 'legal'),
  (gen_random_uuid(), 'Marketing', 'marketing'),
  (gen_random_uuid(), 'Marketplace', 'marketplace'),
  (gen_random_uuid(), 'Mobile Apps', 'mobile-apps'),
  (gen_random_uuid(), 'News & Magazines', 'news-magazines'),
  (gen_random_uuid(), 'No-Code', 'no-code'),
  (gen_random_uuid(), 'Real Estate', 'real-estate'),
  (gen_random_uuid(), 'Sales', 'sales'),
  (gen_random_uuid(), 'SaaS', 'saas'),
  (gen_random_uuid(), 'Social Media', 'social-media'),
  (gen_random_uuid(), 'Utilities', 'utilities')
ON CONFLICT DO NOTHING;

-- Fix near-matches: TrustMRR uses slightly different names
-- "E-commerce" vs "E-Commerce", "Fintech" vs "FinTech", etc.
-- Update data points to use the canonical lookup name

UPDATE product_data_points SET field_value = 'E-Commerce'
WHERE field_name = 'category_name' AND field_value = 'E-commerce' AND is_current = true;

UPDATE product_data_points SET field_value = 'FinTech'
WHERE field_name = 'category_name' AND field_value = 'Fintech' AND is_current = true;

UPDATE product_data_points SET field_value = 'IoT'
WHERE field_name = 'category_name' AND field_value = 'IoT & Hardware' AND is_current = true;

UPDATE product_data_points SET field_value = 'Design'
WHERE field_name = 'category_name' AND field_value = 'Design Tools' AND is_current = true;

UPDATE product_data_points SET field_value = 'HR'
WHERE field_name = 'category_name' AND field_value = 'Recruiting & HR' AND is_current = true;

UPDATE product_data_points SET field_value = 'Productivity'
WHERE field_name = 'category_name' AND field_value ilike 'Produktivit%' AND is_current = true;

-- ============================================================
-- 2. Backfill founders from xHandle in bronze_raw_records
-- ============================================================

INSERT INTO product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
SELECT
  sp.id as product_id,
  'founders' as field_name,
  jsonb_build_array(
    jsonb_build_object(
      'xHandle', br.raw_data->>'xHandle',
      'name', br.raw_data->>'name',
      'avatarUrl', 'https://unavatar.io/x/' || (br.raw_data->>'xHandle')
    )
  )::text as field_value,
  s.id as source_id,
  now() as sourced_at,
  now() as data_as_of,
  true as is_current
FROM bronze_raw_records br
JOIN saas_products sp ON sp.slug = br.raw_data->>'slug'
CROSS JOIN (SELECT id FROM sources WHERE name = 'TrustMRR' LIMIT 1) s
WHERE br.source_name = 'trustmrr'
  AND br.raw_data->>'xHandle' IS NOT NULL
  AND br.raw_data->>'xHandle' != ''
  AND NOT EXISTS (
    SELECT 1 FROM product_data_points pdp
    WHERE pdp.product_id = sp.id
      AND pdp.field_name = 'founders'
      AND pdp.is_current = true
  );

-- ============================================================
-- 3. Fix Gold view: resolve category by name (not just ID)
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS products_gold;

CREATE MATERIALIZED VIEW products_gold AS
SELECT
  p.id,
  p.slug,
  p.name,
  p.logo_url,
  p.website_url,
  p.company_id,
  p.created_at,
  p.updated_at,

  (SELECT dp.field_value FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'company' AND dp.is_current = true LIMIT 1) AS company,

  (SELECT dp.field_value FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'country_code' AND dp.is_current = true LIMIT 1) AS country_code,

  (SELECT c.name_de FROM countries c
   WHERE c.code = (SELECT dp.field_value FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'country_code' AND dp.is_current = true LIMIT 1)
  ) AS country_name,

  (SELECT dp.field_value::integer FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'employees' AND dp.is_current = true LIMIT 1) AS employees,

  -- Category: resolve by category_id first, then by category_name matching lookup
  COALESCE(
    (SELECT cat.name FROM categories cat
     WHERE cat.id::text = (SELECT dp.field_value FROM product_data_points dp
       WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)),
    (SELECT cat.name FROM categories cat
     WHERE cat.name = (SELECT dp.field_value FROM product_data_points dp
       WHERE dp.product_id = p.id AND dp.field_name = 'category_name' AND dp.is_current = true LIMIT 1)),
    (SELECT dp.field_value FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.field_name = 'category_name' AND dp.is_current = true LIMIT 1)
  ) AS category,

  -- Category slug: now resolves via name match too
  COALESCE(
    (SELECT cat.slug FROM categories cat
     WHERE cat.id::text = (SELECT dp.field_value FROM product_data_points dp
       WHERE dp.product_id = p.id AND dp.field_name = 'category_id' AND dp.is_current = true LIMIT 1)),
    (SELECT cat.slug FROM categories cat
     WHERE cat.name = (SELECT dp.field_value FROM product_data_points dp
       WHERE dp.product_id = p.id AND dp.field_name = 'category_name' AND dp.is_current = true LIMIT 1))
  ) AS category_slug,

  (SELECT dp.field_value FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'description' AND dp.is_current = true LIMIT 1) AS description,

  (SELECT dp.field_value::integer FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'founded_year' AND dp.is_current = true LIMIT 1) AS founded_year,

  (SELECT dp.field_value::integer FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'mrr' AND dp.is_current = true LIMIT 1) AS mrr,

  (SELECT dp.field_value::integer FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'revenue_last_30d' AND dp.is_current = true LIMIT 1) AS revenue_last_30d,

  (SELECT dp.field_value::numeric FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'growth_30d' AND dp.is_current = true LIMIT 1) AS growth_30d,

  (SELECT dp.field_value::integer FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'customers' AND dp.is_current = true LIMIT 1) AS customers,

  (SELECT dp.field_value FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'founders' AND dp.is_current = true LIMIT 1) AS founders,

  (SELECT dp.field_value FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_url' AND dp.is_current = true LIMIT 1) AS trustmrr_url,

  (SELECT dp.field_value::integer FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.field_name = 'trustmrr_rank' AND dp.is_current = true LIMIT 1) AS trustmrr_rank,

  (SELECT s.name FROM sources s
   WHERE s.id = (SELECT dp.source_id FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL
     ORDER BY dp.sourced_at DESC LIMIT 1)
  ) AS primary_source,

  (SELECT s.url FROM sources s
   WHERE s.id = (SELECT dp.source_id FROM product_data_points dp
     WHERE dp.product_id = p.id AND dp.is_current = true AND dp.source_id IS NOT NULL
     ORDER BY dp.sourced_at DESC LIMIT 1)
  ) AS primary_source_url,

  (SELECT max(dp.sourced_at) FROM product_data_points dp
   WHERE dp.product_id = p.id AND dp.is_current = true) AS latest_sourced_at

FROM saas_products p;

-- Create index on Gold view
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_gold_id ON products_gold (id);
CREATE INDEX IF NOT EXISTS idx_products_gold_slug ON products_gold (slug);
CREATE INDEX IF NOT EXISTS idx_products_gold_mrr ON products_gold (mrr DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_products_gold_category ON products_gold (category);
CREATE INDEX IF NOT EXISTS idx_products_gold_category_slug ON products_gold (category_slug);

-- Grant access
GRANT SELECT ON products_gold TO anon, authenticated;

-- ============================================================
-- 4. Update transform function to extract xHandle as founder
-- ============================================================

CREATE OR REPLACE FUNCTION transform_bronze_to_silver(p_run_id UUID)
RETURNS TABLE(inserts INTEGER, updates INTEGER, skips INTEGER, errors INTEGER)
LANGUAGE plpgsql AS $$
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
        IF v_raw->>'name' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'company', v_raw->>'name', v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->'revenue'->>'mrr' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'mrr', round((v_raw->'revenue'->>'mrr')::NUMERIC)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->'revenue'->>'last30Days' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'revenue_last_30d', round((v_raw->'revenue'->>'last30Days')::NUMERIC)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'growth30d' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'growth_30d', round((v_raw->>'growth30d')::NUMERIC * 100, 1)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'customers' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'customers', v_raw->>'customers', v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'country' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'country_code', v_raw->>'country', v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'category' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'category_name', v_raw->>'category', v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'description' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'description', v_raw->>'description', v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'foundedDate' IS NOT NULL THEN
          BEGIN
            INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
            VALUES (v_product_id, 'founded_year', extract(year from (v_raw->>'foundedDate')::date)::TEXT, v_source_id, v_now, v_now, true);
          EXCEPTION WHEN OTHERS THEN NULL;
          END;
        END IF;

        -- Founders: extract from xHandle (TrustMRR returns xHandle, not cofounders)
        IF v_raw->>'xHandle' IS NOT NULL AND v_raw->>'xHandle' != '' THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'founders',
            jsonb_build_array(jsonb_build_object(
              'xHandle', v_raw->>'xHandle',
              'name', v_raw->>'name',
              'avatarUrl', 'https://unavatar.io/x/' || (v_raw->>'xHandle')
            ))::TEXT,
            v_source_id, v_now, v_now, true);
        -- Fallback: if cofounders array exists (future API versions)
        ELSIF v_raw->'cofounders' IS NOT NULL AND jsonb_array_length(COALESCE(v_raw->'cofounders', '[]'::jsonb)) > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'founders', v_raw->'cofounders'::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
        VALUES (v_product_id, 'trustmrr_url', 'https://trustmrr.com/' || (v_raw->>'slug'), v_source_id, v_now, v_now, true);

        IF v_raw->>'rank' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'trustmrr_rank', v_raw->>'rank', v_source_id, v_now, v_now, true);
        END IF;

      ELSIF v_record.source_name = 'indiehackers' THEN
        IF v_raw->>'name' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'company', v_raw->>'name', v_source_id, v_now, v_now, true);
        END IF;

        IF (v_raw->>'monthlyRevenue')::NUMERIC > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'mrr', round((v_raw->>'monthlyRevenue')::NUMERIC)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'description' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'description', v_raw->>'description', v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'country' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'country_code', v_raw->>'country', v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'startDate' IS NOT NULL THEN
          BEGIN
            INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
            VALUES (v_product_id, 'founded_year', extract(year from (v_raw->>'startDate')::date)::TEXT, v_source_id, v_now, v_now, true);
          EXCEPTION WHEN OTHERS THEN NULL;
          END;
        END IF;

        IF v_raw->'founders' IS NOT NULL AND jsonb_array_length(COALESCE(v_raw->'founders', '[]'::jsonb)) > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'founders', v_raw->'founders'::TEXT, v_source_id, v_now, v_now, true);
        END IF;

      ELSIF v_record.source_name = 'acquire' THEN
        IF v_raw->>'n' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'company', v_raw->>'n', v_source_id, v_now, v_now, true);
        END IF;

        IF (v_raw->>'m')::NUMERIC > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'mrr', round((v_raw->>'m')::NUMERIC)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'c' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'category_name', v_raw->>'c', v_source_id, v_now, v_now, true);
        END IF;

        IF v_raw->>'d' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'description', v_raw->>'d', v_source_id, v_now, v_now, true);
        END IF;
      END IF;

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

-- ============================================================
-- 5. Update refresh_gold_view function
-- ============================================================

CREATE OR REPLACE FUNCTION refresh_gold_view()
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY products_gold;
EXCEPTION WHEN OTHERS THEN
  REFRESH MATERIALIZED VIEW products_gold;
END;
$$;
