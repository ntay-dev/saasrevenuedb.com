import type { SupabaseClient, User, Session } from "@supabase/supabase-js";
import type { Ref } from "vue";
import type { Database } from "./database.types";

declare module "#app" {
  interface NuxtApp {
    $supabase: SupabaseClient<Database>;
    $supabaseUser: Ref<User | null>;
    $supabaseSession: Ref<Session | null>;
  }
}

declare module "vue" {
  interface ComponentCustomProperties {
    $supabase: SupabaseClient<Database>;
  }
}

export {};
