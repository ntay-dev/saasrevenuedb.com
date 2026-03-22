// Mock Nuxt auto-imports for vitest
import { ref, computed, type Ref } from "vue";

export { ref, computed };
export type { Ref };

// Nuxt composables
export function useNuxtApp() {
  return {
    $supabase: {},
    $supabaseUser: ref(null),
    $supabaseSession: ref(null),
  };
}

export function useRuntimeConfig() {
  return {
    public: {
      supabaseUrl: "https://test.supabase.co",
      supabaseKey: "test-key",
    },
  };
}

export function useState<T>(key: string, init: () => T): Ref<T> {
  return ref(init()) as Ref<T>;
}

export function defineNuxtPlugin(plugin: any) {
  return plugin;
}
