const BASE_URL = "https://indie-radar.com";

/** Inject a JSON-LD script block via useHead */
export function useJsonLd(
  data: Record<string, unknown> | (() => Record<string, unknown> | null),
) {
  useHead({
    script: [
      {
        type: "application/ld+json",
        innerHTML:
          typeof data === "function"
            ? computed(() => {
                const result = data();
                return result ? JSON.stringify(result) : "";
              })
            : JSON.stringify(data),
      },
    ],
  });
}

/** Organization schema — use on homepage */
export function useOrganizationSchema() {
  useJsonLd({
    "@context": "https://schema.org",
    "@type": "Organization",
    name: "IndieRadar",
    url: BASE_URL,
    logo: `${BASE_URL}/favicon.svg`,
    description:
      "Open-source SaaS revenue database with verified MRR data and founder insights. Free forever.",
    sameAs: [
      "https://github.com/ntay-dev/indie-radar.com",
      "https://x.com/ntay_dev",
    ],
  });
}

/** WebSite schema with search action — use on homepage */
export function useWebSiteSchema() {
  useJsonLd({
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: "IndieRadar",
    url: BASE_URL,
    description:
      "Discover SaaS markets, verified MRR data, and founder insights. Free forever.",
    potentialAction: {
      "@type": "SearchAction",
      target: {
        "@type": "EntryPoint",
        urlTemplate: `${BASE_URL}/products?search={search_term_string}`,
      },
      "query-input": "required name=search_term_string",
    },
  });
}

/** Breadcrumb schema */
export function useBreadcrumbSchema(items: { name: string; url: string }[]) {
  useJsonLd({
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((item, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: item.name,
      item: item.url.startsWith("http") ? item.url : `${BASE_URL}${item.url}`,
    })),
  });
}

/** Product schema for detail pages */
export function useProductSchema(
  getData: () => {
    name: string;
    slug: string;
    description?: string | null;
    company?: string | null;
    category?: string | null;
    url?: string | null;
    mrr?: number | bigint | null;
    country?: string | null;
    foundedYear?: number | null;
  } | null,
) {
  useJsonLd(() => {
    const p = getData();
    if (!p) return null;
    return {
      "@context": "https://schema.org",
      "@type": "SoftwareApplication",
      name: p.name,
      url: p.url || `${BASE_URL}/products/${p.slug}`,
      applicationCategory: p.category || "SaaS",
      description:
        p.description ||
        `${p.name}${p.company ? ` by ${p.company}` : ""} — SaaS product with verified revenue data.`,
      ...(p.company && {
        author: { "@type": "Organization", name: p.company },
      }),
      ...(p.country && { countryOfOrigin: p.country }),
      ...(p.foundedYear && { datePublished: `${p.foundedYear}` }),
      operatingSystem: "Web",
      offers: {
        "@type": "Offer",
        price: "0",
        priceCurrency: "USD",
        availability: "https://schema.org/OnlineOnly",
      },
    };
  });
}

/** Set canonical URL for a page */
export function useCanonical(path: string | (() => string)) {
  useHead({
    link: [
      {
        rel: "canonical",
        href:
          typeof path === "function"
            ? computed(() => {
                const p = path();
                return p.startsWith("http") ? p : `${BASE_URL}${p}`;
              })
            : path.startsWith("http")
              ? path
              : `${BASE_URL}${path}`,
      },
    ],
  });
}
