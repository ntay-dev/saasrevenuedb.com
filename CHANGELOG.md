# Changelog

All notable changes to saasrevenuedb.com are documented here.

## [1.2.2] - 2026-03-22

- Applied Prettier formatting across codebase
- Removed unused `radix-vue` dependency (fully migrated to reka-ui)

## [1.2.0] - 2026-03-22 — SEO Overhaul

- JSON-LD structured data (Organization, WebSite, BreadcrumbList, SoftwareApplication)
- SEO composable (`useSeo.ts`) with reusable schema helpers
- Canonical tags, hreflang, dynamic OG tags on product pages
- Sitemap `<lastmod>` dates and caching
- Fixed HTML `lang` attribute, added `noindex` on auxiliary pages

## [1.1.1] - 2026-03-22

- Fixed Bronze raw data extraction for Acquire.com and StarterStory records
- Switched Gold view country names from German to English
- Improved analytics charts (per-chart exclusion counts, grouped bar chart)

## [1.1.0] - 2026-03-22

- Open App buttons on product cards and detail pages
- AG Grid context menu with "Open App" and "Show Raw Data" actions
- Raw data overlay dialog replacing inline JSON panel
- Cache-busting for static data files
- Fixed source filter to only show sources with data

## [1.0.1] - 2026-03-22

- Split `datapoints.json` into chunks for Cloudflare's 25 MB file limit
- StarterStory fetch: replaced regex parsing with GPT-4o-mini extraction

## [1.0.0] - 2026-03-22 — DuckDB-Only Architecture

- All data loaded client-side via DuckDB-WASM from static JSON (no Supabase API calls in browser)
- Build-time static data generation: `products.json`, `meta.json`, `bronze.json`, `datapoints.json`
- Removed localStorage cache, 3-tier strategy, and all client-side Supabase fetch logic

## [0.9.2] - 2026-03-22

- StarterStory YouTube fetch script (yt-dlp transcripts)
- Loading overlay with radar animation and progress bar
- DuckDB-WASM analytics

## [0.9.1] - 2026-03-22

- Auto-categorization pipeline (38 categories, 97% coverage)
- Normalized German category names and Russian country names to English

## [0.9.0] - 2026-03-22 — Rebrand to IndieRadar

- Full rebrand from saas-products.com to IndieRadar (indie-radar.com)
- Note: Later rebranded to SaaSRevenueDB (saasrevenuedb.com) in v1.3.0
- New radar-inspired logo, emerald/cyan color scheme
- New landing page with insight dashboard
- Product list moved from `/` to `/products`
- MIT license added

## [0.8.0] - 2026-03-22

- Analytics dashboard with AG Charts (MRR distribution, country breakdown, founded timeline)
- AG Grid for Bronze Data Explorer with DuckDB-WASM backend
- Simplified app to indie hacker focus, removed 8 pages and 16 unused components

## [0.6.0] - 2026-03-22

- Build-time static data generation with 3-tier cache (localStorage → CDN → Supabase)
- Scheduled GitHub Actions deploy every 6 hours

## [0.5.0] - 2026-03-22

- Design system polish (dark theme tokens, new favicon, mobile menu animation)
- Migrated tooltips to Reka UI primitives

## [0.4.0] - 2026-03-22 — Medallion Architecture

- Bronze/Silver/Gold data pipeline with `bronze_raw_records`, `transform_bronze_to_silver()`, `products_gold` materialized view
- Pipeline tracking (`pipeline_runs`, `pipeline_transformations`)
- Shared pipeline library (`scripts/lib/pipeline.mjs`)

## [0.3.0] - 2026-03-19 — shadcn-vue Migration

- Replaced PrimeVue with shadcn-vue + Lucide icons
- Client-side filtering (all products loaded once, instant filter/sort/paginate)
- Stale-while-revalidate caching via localStorage

## [0.2.0] - 2026-03-19

- Fulltext search, employee size filter, founded year filter
- Category and country pages with SEO
- Sources overview page with trust level legend
- DataAge and enhanced TrustBadge components

## [0.1.1] - 2026-03-18

- Initial Cloudflare Pages deployment setup
