-- products_gold materialized view was missing SELECT grant for anon/authenticated.
-- This caused the build-time static data generator to fail on Cloudflare Pages.
GRANT SELECT ON products_gold TO anon, authenticated;
