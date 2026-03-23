import { createClient } from "@supabase/supabase-js";

export default defineEventHandler(async (event) => {
  const baseUrl = "https://saasrevenuedb.com";
  const config = useRuntimeConfig();
  const today = new Date().toISOString().split("T")[0];

  const staticPages = [
    { path: "/", changefreq: "weekly", priority: "1.0" },
    { path: "/products", changefreq: "weekly", priority: "0.9" },
    { path: "/impressum", changefreq: "monthly", priority: "0.3" },
    { path: "/privacy", changefreq: "monthly", priority: "0.3" },
    { path: "/terms", changefreq: "monthly", priority: "0.3" },
  ];

  const staticUrls = staticPages
    .map(
      (page) => `  <url>
    <loc>${baseUrl}${page.path}</loc>
    <lastmod>${today}</lastmod>
    <changefreq>${page.changefreq}</changefreq>
    <priority>${page.priority}</priority>
  </url>`,
    )
    .join("\n");

  let productUrls = "";
  try {
    const supabase = createClient(
      config.public.supabaseUrl,
      config.public.supabaseKey,
    );
    const { data: products } = await supabase
      .from("saas_products")
      .select("slug, updated_at")
      .order("name");

    if (products) {
      productUrls = products
        .map((p) => {
          const lastmod = p.updated_at
            ? new Date(p.updated_at).toISOString().split("T")[0]
            : today;
          return `  <url>
    <loc>${baseUrl}/products/${p.slug}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.7</priority>
  </url>`;
        })
        .join("\n");
    }
  } catch {
    // Fallback: only static pages
  }

  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${staticUrls}
${productUrls}
</urlset>`;

  setResponseHeader(event, "content-type", "application/xml");
  setResponseHeader(event, "cache-control", "public, max-age=3600");
  return sitemap;
});
