<template>
  <div class="flex min-h-screen flex-col bg-(--color-bg)">
    <!-- Navigation -->
    <header
      class="sticky top-0 z-50 border-b border-(--color-border) bg-(--color-surface)/80 backdrop-blur-xl"
    >
      <nav
        class="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6 lg:px-8"
      >
        <!-- Logo -->
        <NuxtLink to="/" class="flex items-center gap-2.5">
          <div
            class="flex h-8 w-8 items-center justify-center rounded-lg bg-linear-to-br from-emerald-500 to-cyan-500 shadow-lg shadow-emerald-500/25"
          >
            <Radar class="size-5 text-white" />
          </div>
          <span
            class="text-lg font-semibold tracking-tight text-(--color-text-primary)"
          >
            SaaS<span class="text-emerald-500">RevenueDB</span>
          </span>
        </NuxtLink>

        <!-- Desktop Nav -->
        <div class="hidden items-center gap-1 md:flex">
          <NuxtLink
            v-for="link in navLinks"
            :key="link.to"
            :to="link.to"
            class="rounded-lg px-3 py-2 text-sm font-medium text-(--color-text-secondary) transition-colors hover:bg-white/5 hover:text-(--color-text-primary)"
            active-class="!bg-white/10 !text-(--color-text-primary)"
          >
            {{ link.label }}
          </NuxtLink>
          <a
            href="https://x.com/ntay_dev"
            target="_blank"
            rel="noopener noreferrer"
            class="ml-2 inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-sm font-medium text-(--color-text-secondary) transition-all hover:border-blue-500/30 hover:text-blue-400"
          >
            <Twitter class="size-3.5" />
            Follow
          </a>
        </div>

        <!-- Mobile hamburger -->
        <button
          type="button"
          class="inline-flex items-center justify-center rounded-lg p-2 text-(--color-text-secondary) hover:bg-white/5 md:hidden"
          aria-label="Toggle navigation"
          @click="mobileMenuOpen = !mobileMenuOpen"
        >
          <Menu v-if="!mobileMenuOpen" class="size-5" />
          <X v-else class="size-5" />
        </button>
      </nav>

      <!-- Mobile Nav -->
      <Transition
        enter-active-class="transition-all duration-200 ease-out"
        leave-active-class="transition-all duration-150 ease-in"
        enter-from-class="opacity-0 -translate-y-1"
        leave-to-class="opacity-0 -translate-y-1"
      >
        <div
          v-if="mobileMenuOpen"
          class="border-t border-(--color-border) md:hidden"
        >
          <div class="px-4 pb-4 pt-2">
            <div class="flex flex-col gap-1">
              <NuxtLink
                v-for="link in navLinks"
                :key="link.to"
                :to="link.to"
                class="rounded-lg px-3 py-2.5 text-sm font-medium text-(--color-text-secondary) transition-colors hover:bg-white/5 hover:text-(--color-text-primary)"
                active-class="!bg-white/10 !text-(--color-text-primary)"
                @click="mobileMenuOpen = false"
              >
                {{ link.label }}
              </NuxtLink>
              <a
                href="https://x.com/ntay_dev"
                target="_blank"
                rel="noopener noreferrer"
                class="mt-1 inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-2.5 text-sm font-medium text-(--color-text-secondary) transition-all hover:border-blue-500/30 hover:text-blue-400"
              >
                <Twitter class="size-3.5" />
                Follow on X
              </a>
            </div>
          </div>
        </div>
      </Transition>
    </header>

    <!-- Initial loading overlay -->
    <LoadingOverlay />

    <!-- Content -->
    <main class="flex-1">
      <slot />
    </main>

    <!-- Footer -->
    <footer class="border-t border-(--color-border) bg-(--color-surface)">
      <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div
          class="flex flex-col items-center justify-between gap-4 sm:flex-row"
        >
          <div
            class="flex items-center gap-2 text-sm text-(--color-text-muted)"
          >
            <span>&copy; {{ new Date().getFullYear() }} SaaSRevenueDB</span>
            <span class="text-white/10">|</span>
            <span class="text-xs">
              v{{ config.public.appVersion }} · built
              {{ formatBuildTime(config.public.buildTime as string) }}
            </span>
          </div>
          <div class="flex gap-6 text-sm">
            <NuxtLink
              to="/impressum"
              class="text-(--color-text-muted) transition-colors hover:text-(--color-text-secondary)"
            >
              Imprint
            </NuxtLink>
            <NuxtLink
              to="/privacy"
              class="text-(--color-text-muted) transition-colors hover:text-(--color-text-secondary)"
            >
              Privacy
            </NuxtLink>
            <NuxtLink
              to="/terms"
              class="text-(--color-text-muted) transition-colors hover:text-(--color-text-secondary)"
            >
              Terms
            </NuxtLink>
          </div>
        </div>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { Radar, Twitter, Menu, X } from "lucide-vue-next";
import { useProductsStore } from "~/stores/products";

const config = useRuntimeConfig();
const mobileMenuOpen = ref(false);
const store = useProductsStore();

// Eagerly start loading data so the overlay shows progress
onMounted(() => store.initialize());

const router = useRouter();
router.afterEach(() => {
  mobileMenuOpen.value = false;
});

const navLinks = [
  { to: "/", label: "Home" },
  { to: "/products", label: "Products" },
  { to: "/analytics", label: "Analytics" },
  { to: "/bronze", label: "Raw Data" },
];

function formatBuildTime(iso: string): string {
  try {
    const date = new Date(iso);
    return date.toLocaleDateString("en-US", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}
</script>
