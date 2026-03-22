-- ============================================================
-- saas-products.com — Migration: Grant anon access
-- Fixes 401 "Permission denied" errors for the anon role.
--
-- Problem: RLS policies (public read) exist on all tables,
-- but the anon role lacks explicit GRANT SELECT on views
-- and lookup tables. Supabase requires both RLS policies
-- AND role-level grants.
--
-- IMPORTANT: Run this manually in the Supabase Dashboard
-- SQL Editor (direct connection not available from WSL2).
-- ============================================================

-- Grant read access on the flattened products view
GRANT SELECT ON public.products_view TO anon;
GRANT SELECT ON public.products_view TO authenticated;

-- Grant read access on lookup tables
GRANT SELECT ON public.countries TO anon;
GRANT SELECT ON public.countries TO authenticated;

GRANT SELECT ON public.categories TO anon;
GRANT SELECT ON public.categories TO authenticated;

-- Grant read access on core tables (belt-and-suspenders — RLS still applies)
GRANT SELECT ON public.sources TO anon;
GRANT SELECT ON public.sources TO authenticated;

GRANT SELECT ON public.saas_products TO anon;
GRANT SELECT ON public.saas_products TO authenticated;

GRANT SELECT ON public.product_data_points TO anon;
GRANT SELECT ON public.product_data_points TO authenticated;
