<template>
  <div class="flex min-h-screen flex-col bg-(--color-bg)">
    <nav class="border-b border-(--color-border) bg-(--color-surface)">
      <div
        class="mx-auto flex max-w-7xl items-center px-4 py-3 sm:px-6 lg:px-8"
      >
        <NuxtLink to="/" class="flex items-center gap-2.5">
          <div
            class="flex h-8 w-8 items-center justify-center rounded-lg bg-linear-to-br from-emerald-500 to-cyan-500 shadow-lg shadow-emerald-500/25"
          >
            <Radar class="size-5 text-white" />
          </div>
          <span
            class="text-lg font-semibold tracking-tight text-(--color-text-primary)"
          >
            Indie<span class="text-emerald-500">Radar</span>
          </span>
        </NuxtLink>
      </div>
    </nav>

    <main class="flex flex-1 items-center justify-center px-4 py-16">
      <div class="text-center">
        <p class="gradient-text text-7xl font-bold">{{ statusCode }}</p>
        <h1 class="mt-4 text-2xl font-bold text-(--color-text-primary)">
          {{ title }}
        </h1>
        <p class="mt-2 text-sm text-(--color-text-secondary)">
          {{ description }}
        </p>
        <button
          class="mt-8 inline-flex items-center gap-2 rounded-lg bg-emerald-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-emerald-700"
          @click="handleError"
        >
          <ArrowLeft class="size-4" />
          Back to Database
        </button>
      </div>
    </main>

    <footer class="border-t border-(--color-border) bg-(--color-surface)">
      <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        <p class="text-center text-sm text-(--color-text-muted)">
          &copy; {{ new Date().getFullYear() }} IndieRadar
        </p>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { ArrowLeft, Radar } from "lucide-vue-next";

const props = defineProps<{
  error: {
    statusCode?: number;
    message?: string;
  };
}>();

const statusCode = computed(() => props.error?.statusCode ?? 500);

const title = computed(() => {
  if (statusCode.value === 404) return "Page not found";
  return "Something went wrong";
});

const description = computed(() => {
  if (statusCode.value === 404)
    return "The page you are looking for does not exist or has been moved.";
  return props.error?.message ?? "Please try again later.";
});

function handleError() {
  clearError({ redirect: "/" });
}

useHead({
  title: `${statusCode.value} — IndieRadar`,
});
</script>
