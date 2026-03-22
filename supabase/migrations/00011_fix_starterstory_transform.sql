-- Fix: Skip StarterStory records without a product name instead of
-- inserting them with YouTube video IDs as names.
-- Also clean up existing junk records.

-- 1. Delete Silver products that have video-ID slugs (no real product name)
DELETE FROM public.saas_products
WHERE slug ~ '^ss-[A-Za-z0-9_-]{8,15}$';

-- 2. Replace transform function with StarterStory skip logic
CREATE OR REPLACE FUNCTION public.transform_bronze_to_silver(p_run_id UUID)
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

      -- ========== SKIP RECORDS WITHOUT PRODUCT NAME (StarterStory) ==========
      IF v_record.source_name = 'starterstory' AND (v_raw->>'productName') IS NULL THEN
        v_skips := v_skips + 1;
        INSERT INTO public.pipeline_transformations
          (pipeline_run_id, bronze_record_id, product_slug, action)
        VALUES (p_run_id, v_record.id, 'ss-' || v_record.external_id, 'skip');
        CONTINUE;
      END IF;

      -- ========== SLUG ==========
      IF v_record.source_name = 'trustmrr' THEN
        v_slug := v_raw->>'slug';
      ELSIF v_record.source_name = 'starterstory' THEN
        v_slug := lower(regexp_replace(
          regexp_replace(v_raw->>'productName', '[^a-zA-Z0-9]+', '-', 'g'),
          '(^-+|-+$)', '', 'g'
        ));
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
      ELSIF v_record.source_name = 'starterstory' THEN
        SELECT id INTO v_source_id FROM public.sources WHERE name = 'StarterStory YouTube' LIMIT 1;
        IF v_source_id IS NULL THEN
          INSERT INTO public.sources (name, url, type, trust_level, notes)
          VALUES ('StarterStory YouTube', 'https://www.youtube.com/@starterstory', 'crawler', 50, 'Founder interviews — revenue self-reported in video transcripts')
          RETURNING id INTO v_source_id;
        END IF;
      END IF;

      -- ========== PRODUCT NAME ==========
      IF v_record.source_name = 'trustmrr' THEN
        v_name := v_raw->>'name';
      ELSIF v_record.source_name = 'acquire' THEN
        v_name := COALESCE(v_raw->>'n', v_record.external_id);
      ELSIF v_record.source_name = 'starterstory' THEN
        v_name := v_raw->>'productName';
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
          WHEN 'starterstory' THEN v_raw->>'websiteUrl'
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

        IF v_raw->>'xHandle' IS NOT NULL AND v_raw->>'xHandle' != '' THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'founders',
            jsonb_build_array(jsonb_build_object(
              'xHandle', v_raw->>'xHandle',
              'name', v_raw->>'name',
              'avatarUrl', 'https://unavatar.io/x/' || (v_raw->>'xHandle')
            ))::TEXT,
            v_source_id, v_now, v_now, true);
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

      ELSIF v_record.source_name = 'starterstory' THEN
        -- Company/product name
        IF v_raw->>'productName' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'company', v_raw->>'productName', v_source_id, v_now, v_now, true);
        END IF;

        -- MRR (parsed from transcript/title)
        IF (v_raw->>'mrr') IS NOT NULL AND (v_raw->>'mrr')::NUMERIC > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'mrr', round((v_raw->>'mrr')::NUMERIC)::TEXT, v_source_id, v_now, v_now, true);
        END IF;

        -- Description
        IF v_raw->>'description' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'description', v_raw->>'description', v_source_id, v_now, v_now, true);
        END IF;

        -- Customers
        IF (v_raw->>'customers') IS NOT NULL AND (v_raw->>'customers')::NUMERIC > 0 THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'customers', v_raw->>'customers', v_source_id, v_now, v_now, true);
        END IF;

        -- Founder
        IF v_raw->>'founderName' IS NOT NULL THEN
          INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
          VALUES (v_product_id, 'founders',
            jsonb_build_array(jsonb_build_object(
              'name', v_raw->>'founderName'
            ))::TEXT,
            v_source_id, v_now, v_now, true);
        END IF;

        -- Source URL (YouTube video)
        INSERT INTO public.product_data_points (product_id, field_name, field_value, source_id, sourced_at, data_as_of, is_current)
        VALUES (v_product_id, 'starterstory_url', COALESCE(v_raw->>'videoUrl', 'https://www.youtube.com/watch?v=' || v_record.external_id), v_source_id, v_now, v_now, true);

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
