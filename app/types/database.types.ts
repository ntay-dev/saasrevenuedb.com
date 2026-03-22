// Database types — will be replaced by auto-generated types via `npm run db:types`
// For now, manually defined to match the migration schema

export interface Database {
  public: {
    Tables: {
      sources: {
        Row: {
          id: string;
          name: string;
          url: string | null;
          type: string;
          trust_level: number;
          notes: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          url?: string | null;
          type?: string;
          trust_level?: number;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          url?: string | null;
          type?: string;
          trust_level?: number;
          notes?: string | null;
          updated_at?: string;
        };
      };
      categories: {
        Row: {
          id: string;
          name: string;
          slug: string;
          description: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          slug: string;
          description?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          slug?: string;
          description?: string | null;
        };
      };
      countries: {
        Row: {
          code: string;
          name_en: string;
          name_de: string;
        };
        Insert: {
          code: string;
          name_en: string;
          name_de: string;
        };
        Update: {
          code?: string;
          name_en?: string;
          name_de?: string;
        };
      };
      companies: {
        Row: {
          id: string;
          slug: string;
          name: string;
          logo_url: string | null;
          website_url: string | null;
          country_code: string | null;
          founded_year: number | null;
          employees: number | null;
          description: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          slug: string;
          name: string;
          logo_url?: string | null;
          website_url?: string | null;
          country_code?: string | null;
          founded_year?: number | null;
          employees?: number | null;
          description?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          slug?: string;
          name?: string;
          logo_url?: string | null;
          website_url?: string | null;
          country_code?: string | null;
          founded_year?: number | null;
          employees?: number | null;
          description?: string | null;
          updated_at?: string;
        };
      };
      saas_products: {
        Row: {
          id: string;
          slug: string;
          name: string;
          logo_url: string | null;
          website_url: string | null;
          company_id: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          slug: string;
          name: string;
          logo_url?: string | null;
          website_url?: string | null;
          company_id?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          slug?: string;
          name?: string;
          logo_url?: string | null;
          website_url?: string | null;
          company_id?: string | null;
          updated_at?: string;
        };
      };
      product_data_points: {
        Row: {
          id: string;
          product_id: string;
          field_name: string;
          field_value: string;
          source_id: string | null;
          sourced_at: string;
          data_as_of: string | null;
          is_current: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          product_id: string;
          field_name: string;
          field_value: string;
          source_id?: string | null;
          sourced_at?: string;
          data_as_of?: string | null;
          is_current?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          product_id?: string;
          field_name?: string;
          field_value?: string;
          source_id?: string | null;
          sourced_at?: string;
          data_as_of?: string | null;
          is_current?: boolean;
        };
      };
    };
    Views: {
      products_gold: {
        Row: {
          id: string;
          slug: string;
          name: string;
          logo_url: string | null;
          website_url: string | null;
          company_id: string | null;
          created_at: string;
          updated_at: string;
          company: string | null;
          country_code: string | null;
          country_name: string | null;
          employees: number | null;
          category: string | null;
          category_slug: string | null;
          description: string | null;
          founded_year: number | null;
          mrr: number | null;
          revenue_last_30d: number | null;
          growth_30d: number | null;
          customers: number | null;
          founders: string | null;
          trustmrr_url: string | null;
          trustmrr_rank: number | null;
          primary_source: string | null;
          primary_source_url: string | null;
          latest_sourced_at: string | null;
        };
      };
    };
    Functions: {
      search_products: {
        Args: {
          search_query?: string;
          category_slugs?: string[];
          country_codes?: string[];
          employee_min?: number;
          employee_max?: number;
          founded_from?: number;
          founded_to?: number;
          hide_anonymous?: boolean;
          sort_field?: string;
          sort_direction?: string;
          page_offset?: number;
          page_limit?: number;
        };
        Returns: (ProductView & {
          total_count: number;
          search_rank: number;
        })[];
      };
    };
    Enums: Record<string, never>;
  };
}

export interface TopSaasProduct {
  id: string;
  slug: string;
  name: string;
  company: string;
  website_url: string | null;
  category: string;
  country_code: string;
  users_millions: number | null;
  employees: number | null;
  estimated_arr_millions: number | null;
  source_name: string;
  source_url: string | null;
  created_at: string;
  updated_at: string;
}

// Convenience types
export type Source = Database["public"]["Tables"]["sources"]["Row"];
export type Category = Database["public"]["Tables"]["categories"]["Row"];
export type Country = Database["public"]["Tables"]["countries"]["Row"];
export type Company = Database["public"]["Tables"]["companies"]["Row"];
export type SaasProduct = Database["public"]["Tables"]["saas_products"]["Row"];
export type ProductDataPoint =
  Database["public"]["Tables"]["product_data_points"]["Row"];
export type ProductView = Database["public"]["Views"]["products_gold"]["Row"];

/** Company with product count, used on /companies page */
export interface CompanyWithCount extends Company {
  product_count: number;
  country?: Country | null;
}
