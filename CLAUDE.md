# CLAUDE.md — IndieRadar (saas-products.com)

## Vision

Comprehensive, source-based database of all SaaS products worldwide. Every piece of information is tagged with source, timestamp, and trust level. Free forever.

## Tech Stack

Nuxt 4 (SPA), Vue 3, TypeScript, Tailwind CSS 4, shadcn-vue + Reka UI, Supabase, Pinia, i18n (DE/EN)

## Repo

- **GitHub:** `ntay-dev/saas-products.com`

## Supabase Connection

- **URL & Keys:** Stored in `.env` (see `.env.template` for variable names)
- **CLI Access:** `SUPABASE_ACCESS_TOKEN=<from .env> npx supabase db query --linked "SQL"`
- **Migrations:** `supabase/migrations/` — run via CLI `--linked` or Dashboard
- **Prefer Supabase CLI** for migrations, data seeding, and SQL execution. MCP only as fallback for small queries/checks. The CLI handles large SQL files and is more reliable than MCP for batch operations. For large SQL files: split into batches and run sequentially via CLI.

## Project Rules

### Pricing & Access

- **Always free.** No paid tier, no freemium.
- Some information (e.g., detailed financial data) may require login, but never payment.
- Login is for personalization only, not monetization.

### Data Quality & Sources

- **Every piece of information needs a source.** No data without `source_id` and `sourced_at`.
- **Every source is always linked.** In the frontend, every data point must link to the original source (clickable URL). No data point without a visible source link.
- **TrustMRR is the primary source** for revenue data, founder info, and startup metrics (Stripe-verified, high trust).
- Sources have a `trust_level` (0–100):
  - 90+ — Official company website, SEC Filings
  - 85–89 — TrustMRR (Stripe-verified), Crunchbase, PitchBook, Bloomberg
  - 70–79 — LinkedIn, Wikipedia, G2
  - 50–69 — News articles, press releases
  - 20–49 — Community data, estimates
  - 0–19 — Unverified, user-submitted
- When sources conflict: higher trust level wins.
- **Two timestamps per data point:**
  - `sourced_at` — When the information was fetched/crawled (query time).
  - `data_as_of` — When the data refers to (data freshness, e.g., "MRR as of January 2026"). Can be NULL if unknown.
- `is_current` marks the current value. Old values are retained (historization).

### Founder Display

- **Founders are always shown with avatar** (icon/profile pic + name + X handle).
- Founder data comes primarily from TrustMRR (`cofounders` array with `xHandle`, `xName`).
- Avatar URL: `https://unavatar.io/x/{xHandle}` (auto-generated from X handle).
- On the product detail page, founders are displayed prominently (like on TrustMRR).
- `field_name = 'founder'` contains JSON: `{"name": "...", "xHandle": "...", "avatarUrl": "..."}`.

### TrustMRR Integration

- **API:** `GET /api/v1/startups` (list) and `GET /api/v1/startups/{slug}` (detail).
- **Auth:** Bearer Token (`TRUSTMRR_API_KEY` in `.env`).
- **Trust Level:** 85 (Stripe-verified financial data).
- **Fields from TrustMRR:** `mrr`, `revenue_last_30d`, `growth_30d`, `customers`, `founder(s)`, `category`, `country`, `founded_date`, `description`.
- **URL format for source linking:** `https://trustmrr.com/{slug}`.
- **Fetch script:** `scripts/fetch-trustmrr.mjs` — fetches data via API and loads into Bronze layer.
- **Rate limiting:** Max 50 results per request, pagination required.

### Data Model (Medallion Architecture)

- **Bronze/Silver/Gold Architecture:**
  - **Bronze:** `bronze_raw_records` — Raw data as JSONB, unchanged from source.
  - **Silver:** `saas_products` + `product_data_points` (EAV) — cleaned, deduplicated, normalized.
  - **Gold:** `products_gold` — Materialized View, flattened, frontend-ready.
- **Pipeline tracking:** `pipeline_runs` (per run), `pipeline_transformations` (per record).
- **Transform:** SQL function `transform_bronze_to_silver(run_id)` + `refresh_gold_view()`.
- Adding new fields = new `field_name` in `product_data_points`, extend Gold View.
- Categories and countries are lookup tables, not free-text fields.

### Crawling & Data Enrichment

- Allowed sources: TrustMRR (primary), company websites, Wikipedia, Crunchbase, LinkedIn (public), G2, Glassdoor (public), SEC/EDGAR, PitchBook (if access available).
- **No scraping of login-protected pages** without explicit permission.
- **Respect rate limiting:** Max 1 request/second per domain.
- Crawler results always persisted as SQL seed or via Supabase REST API.
- For automated crawling: `source.type = 'crawler'` and set `trust_level` conservatively (max 60).

### Code Conventions

- Same stack and patterns as `studycards.io` (reference project).
- **runtimeConfig public:** All public variables must explicitly reference `process.env.NUXT_PUBLIC_*` (e.g., `supabaseUrl: process.env.NUXT_PUBLIC_SUPABASE_URL || ''`). No empty string defaults without `process.env` reference — Nuxt auto-mapping is not reliable enough.
- Supabase integration via plugin (`supabase.client.ts`) + composable (`useSupabase.ts`).
- TypeScript strict, no `any` types.
- PrimeVue components imported, not globally registered.
- i18n: German as default locale, English as fallback.
- CSS: Tailwind v4 with `@theme` for custom properties.

### Deployment

- Cloudflare Pages (SPA, no SSR).
- `.env` never committed — only `.env.template`.

## Files & Directories

```
app/
  assets/css/main.css     — Tailwind + Theme
  components/             — Vue components (TrustBadge, etc.)
  composables/            — useProducts, useSupabase
  pages/                  — index.vue (list), products/[slug].vue (detail)
  plugins/                — supabase.client.ts
  types/                  — database.types.ts, supabase.d.ts
i18n/locales/             — de-DE.json, en-US.json
scripts/
  lib/pipeline.mjs        — Shared pipeline library (Bronze/Silver/Gold)
  fetch-trustmrr.mjs      — TrustMRR API → Bronze → Silver → Gold
  fetch-indiehackers.mjs  — IndieHackers Firebase → Bronze → Silver → Gold
  fetch-starterstory.mjs  — StarterStory YouTube Transcripts → Bronze → Silver → Gold
  transform-and-refresh.mjs — Manual re-transform + Gold refresh
  execute-sql.mjs         — SQL executor for migrations
supabase/
  migrations/             — SQL migrations (00007 = Medallion Architecture)
  seed.sql                — Initial seed data
```
