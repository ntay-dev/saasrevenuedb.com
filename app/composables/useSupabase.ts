import type { Ref } from "vue";
import type { SupabaseClient, User, Session } from "@supabase/supabase-js";
import type { Database } from "~/types/database.types";

export function useSupabaseClient(): SupabaseClient<Database> {
  const { $supabase } = useNuxtApp();
  return $supabase;
}

export function useSupabaseUser(): Ref<User | null> {
  const { $supabaseUser } = useNuxtApp();
  return $supabaseUser;
}

export function useSupabaseSession(): Ref<Session | null> {
  const { $supabaseSession } = useNuxtApp();
  return $supabaseSession;
}
