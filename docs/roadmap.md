# IndieRadar — Roadmap

> **Current focus: S1 (Ship It)** — Complete search, filters, and trust system, deploy and validate as first user

## Vision

Comprehensive, source-based SaaS database. Every piece of information verified with source, timestamp, and trust level. Always free.

## Tech Stack

Nuxt 4 (SPA), Vue 3, TypeScript, Tailwind CSS 4, shadcn-vue, Supabase, Pinia, i18n (DE/EN), Cloudflare Pages

---

## Stages — Overarching Milestones

> These three stages apply to all projects and define the path to a sustainable product.

### S1: Ship It — MLP done, use it yourself, be satisfied

> Everything works: search, filters, product details, trust display. Use the database as the first user, find weaknesses, fix until it feels right.

**What belongs to S1:**

- [x] M0 (Setup) + M1 (Database) complete — 1,268 products
- [ ] M2 (Search & Filters) finish — full-text search, filters, category/country pages, pagination
- [ ] M3 (Data Quality & Trust System) — trust level visual, sources page, data age
- [x] **shadcn-vue / reka-ui migration complete** — radix-vue fully removed, all components use reka-ui exclusively
- [ ] **Finalize design system tokens** — project-specific theme (Data/Professional: neutral, trustworthy) (shadcn-vue already set up)
- [ ] M7 (Deployment) — Cloudflare Pages, custom domain, analytics
- [ ] **"Be Your First User" QA:** Full walkthrough — Search → Filter → Read product detail → Check sources → Understand trust levels. The database must be more useful than a Google search.
- [ ] Bug fixes and UX improvements until satisfied

### S2: Scale It — Acquire free users (without monetization)

> SEO, content, marketing — bring users to the platform before money flows. For saas-products.com the product itself is already free.

**What belongs to S2:**

- [ ] M6 (SEO & Content): Programmatic SEO (`/saas/[slug]`, `/category/[slug]`, `/country/[code]`, `/compare/[a]-vs-[b]`)
- [ ] Blog: "Top 10 CRM Tools 2026", "SaaS Market Germany"
- [ ] Structured Data (JSON-LD), Sitemap, robots.txt, OG tags
- [ ] M4 (Crawling) — automated data updates for fresh content
- [ ] M5 (User Features) — Login, favorites, lists, export, comparison
- [ ] Reddit marketing (r/SaaS, r/startups, r/Entrepreneur)
- [ ] Twitter/X presence: Post weekly SaaS insights
- [ ] Product Hunt preparation

### S3: Sell It — Monetization (newsletter ads + ad spaces)

> No Stripe needed — monetization via direct ad sales.

**What belongs to S3:**

- [ ] M8 (Newsletter & Monetization): Newsletter signup, weekly report
- [ ] Sponsored sections in newsletter
- [ ] Ad spaces on website (product list, category pages, comparison pages)
- [ ] Media kit page for ad partners
- [ ] Ad tracking (impressions + clicks, privacy-compliant)
- [ ] Acquire first ad partners

---

## Detailed Milestones (historical)

### Completed

- [x] M0: Project setup (Nuxt 4, Supabase schema, GitHub repo)
- [x] DB schema: sources, categories, countries, saas_products, product_data_points
- [x] EAV architecture for source-based data per field
- [x] products_view (flattened view)
- [x] Product list with DataTable (search, filter, sorting)
- [x] Product detail with source sidebar + TrustBadge
- [x] i18n (DE/EN), RLS public-read policies
- [x] Legal pages: Impressum, Privacy, Terms
- [x] SEO meta + useHead()
- [x] Custom error page + catch-all route
- [x] Build time in footer

### Recently implemented (2026-03-18)

- [x] **Database fully populated** — 1,268 products, 11,484 data points, 33 categories, 16 countries, 9 sources
- [x] Migration 00002 (TrustMRR fields + products_view update) applied
- [x] Migration 00003 (GRANT anon access) applied — **fixed 401 error**
- [x] Seed: Base (20 products) + Extended (248 from Web/G2/Wikipedia) + TrustMRR (~1000 startups)
- [x] Search field SQL injection fix (special characters escaped)
- [x] Google OAuth credentials configured (GCP + Supabase Dashboard)

### M1: ~~Database & Initial Population~~ Done

- [x] Supabase migrations executed
- [x] TrustMRR integrated as primary source (fetch-trustmrr.mjs, trust level 85)
- [x] Seed data loaded (via CLI)
- [x] UUID fix in seeds (s/p prefixes → valid hex UUIDs)

### M2: Search & Filter Extension ← CURRENT

- [ ] Full-text search (Supabase `to_tsvector`)
- [ ] Filter: employee size (ranges: 1–50, 51–200, 201–1000, 1000+)
- [ ] Filter: founded year
- [ ] Category pages (`/category/[slug]`) with SEO text
- [ ] Country pages (`/country/[code]`) with overview
- [ ] Pagination + URL-based filters (query params)
- [ ] **Remove newsletter section from landing page** (if present)

### M3: Data Quality & Trust System

- [ ] Display trust level prominently (color, icon, tooltip)
- [ ] Sources overview page (`/sources`) — all sources with trust level
- [ ] Show data age ("Last updated X days ago")
- [ ] Automatic warning for stale data (> 6 months)
- [ ] Show multiple sources per field (consensus vs. conflict)
- [ ] Make trust rules configurable (admin UI or config)

### M4: Automated Crawling & Scraping Schedule

**Daily scraping schedule (cron-based):**

| Time (UTC) | Source              | Frequency    | Script                         | Trust |
| ---------- | ------------------- | ------------ | ------------------------------ | ----- |
| 02:00      | TrustMRR API        | Daily        | `scripts/fetch-trustmrr.mjs`   | 85    |
| 03:00      | Company websites    | Weekly (Mon) | `scripts/crawl-websites.mjs`   | 90    |
| 04:00      | Wikipedia           | Weekly (Wed) | `scripts/crawl-wikipedia.mjs`  | 75    |
| 05:00      | Crunchbase (public) | Weekly (Fri) | `scripts/crawl-crunchbase.mjs` | 85    |
| 06:00      | G2 Reviews          | Weekly (Sat) | `scripts/crawl-g2.mjs`         | 70    |

**Implementation:**

- [ ] Supabase Edge Function for crawling pipeline (HTTP-triggered)
- [ ] Cron job via Cloudflare Workers / Supabase pg_cron
- [ ] Diff detection: only create new data point on change
- [ ] Set old `is_current` to `false` when new value arrives
- [ ] Changelog per product (what changed when?)

### M5: User Features & Login

- [ ] Supabase Auth (Google OAuth + Magic Link)
- [ ] Favorites / Watchlist
- [ ] Create custom lists ("My CRM Shortlist")
- [ ] Export: CSV, JSON, PDF
- [ ] Comparison feature (2–3 products side by side)

### M6: SEO & Content

- [ ] Landing page with hero + statistics
- [ ] Programmatic SEO:
  - `/saas/[slug]` — Product pages (indexable)
  - `/category/[slug]` — "CRM Software Comparison", "Best HR Software"
  - `/country/[code]` — "SaaS Companies from Germany"
  - `/compare/[product1]-vs-[product2]` — Comparison pages
- [ ] Blog: "Top 10 CRM Tools 2026", "SaaS Market Germany"
- [ ] Structured Data (JSON-LD: Organization, Product)
- [ ] Sitemap, robots.txt, OG tags

### M7: Deployment & Launch

- [ ] Cloudflare Pages deployment
- [ ] Custom domain
- [ ] Analytics (Cloudflare Web Analytics)
- [ ] BetterStack logging
- [ ] Performance optimization (lazy loading, image CDN)
- [ ] Launch: Product Hunt, HackerNews, Reddit

---

### M8: Newsletter & Monetization

- [ ] Newsletter signup (landing page + footer widget + popup after 30s)
- [ ] Weekly SaaS market report (automated from new data)
- [ ] Sponsored section in newsletter (template + booking logic)
- [ ] Ad spaces on website: banners on product list, category, and comparison pages
- [ ] Direct sales: contact form / media kit page for ad partners
- [ ] Ad tracking: measure impressions + clicks (privacy-compliant)

### S2 Future: MCP Integration (Model Context Protocol)

> saas-products.com as MCP server: AI assistants can search the SaaS database and retrieve product data.

- [ ] Implement MCP server (`@saas-products/mcp-server`)
- [ ] Tools: `search-products`, `get-product`, `list-categories`, `compare-products`, `get-market-stats`
- [ ] Resources: Product data, category overviews, and market statistics as AI context
- [ ] Auth: Public (read-only) + API key for extended queries
- [ ] Use cases:
  - Claude can research and compare SaaS products
  - AI agents can create market analyses (e.g., "Top CRM Tools by MRR")
  - Automated competitive analyses for startup founders
  - Integration with investment tools and due diligence workflows

### Post-MLP: Features

- API for third parties (`/api/v1/products`)
- Embeddable widgets (badges: "Listed on IndieRadar")
- Community contributions (users can suggest corrections)
- Trend analysis (employee growth over time)
- SaaS stack analysis (which tools do companies use together?)

### Competitors

- **G2** ($) — Review platform, expensive for vendors, no open data
- **Capterra** ($) — Lead-gen model, vendor-paid
- **Crunchbase** ($/Free) — Startup-focused, funding data
- **SaaSWorthy** — Review-based
- **Product Hunt** — Launch platform, not a database

### Monetization

Two revenue streams — the product itself remains completely free:

1. **Newsletter ads** — Sponsored sections in the weekly SaaS market report (e.g., "Presented by [Sponsor]", Featured Tool of the Week)
2. **Ad spaces on the website** — Display ad placements on strategic pages (product list, category pages, comparison pages). Directly sold to SaaS vendors, no programmatic ads.

**No** vendor pay-to-play, **no** lead-gen model, **no** paywall.

### Differentiation

- **100% free for users** (no paywall, no lead-gen)
- **Source-based** — Every data point is traceable
- **Trust system** — Transparency about data quality
- **Open data** — No paywall for base data
- **German + English** — Only DE-focused SaaS database
- **Monetization via advertising** — not via vendor rankings or lead selling
