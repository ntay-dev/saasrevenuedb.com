<template>
  <NuxtLink
    :to="`/products/${product.slug}`"
    class="group flex flex-col gap-3 rounded-xl border border-(--color-border) bg-(--color-surface) p-5 transition-all duration-200 hover:border-(--color-border-hover) hover:shadow-lg hover:shadow-black/20"
  >
    <!-- Header: Logo + Name -->
    <div class="flex items-start gap-3">
      <div
        v-if="product.logo_url"
        class="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-(--color-surface-elevated) ring-1 ring-(--color-border)"
      >
        <img
          :src="product.logo_url"
          :alt="product.name"
          class="h-full w-full object-contain"
          loading="lazy"
        >
      </div>
      <div
        v-else
        class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-emerald-500/10 text-sm font-bold text-emerald-400 ring-1 ring-white/5"
      >
        {{ product.name.charAt(0) }}
      </div>
      <div class="min-w-0 flex-1">
        <h3
          class="truncate text-sm font-semibold text-(--color-text-primary) transition-colors group-hover:text-emerald-400"
        >
          {{ product.name }}
        </h3>
        <p
          v-if="product.company"
          class="truncate text-xs text-(--color-text-muted)"
        >
          {{ product.company }}
        </p>
      </div>
    </div>

    <!-- Meta row: Category + Country -->
    <div class="flex flex-wrap items-center gap-2">
      <span
        v-if="product.category"
        class="inline-flex items-center rounded-full bg-(--color-surface-elevated) px-2.5 py-0.5 text-xs font-medium text-(--color-text-secondary) ring-1 ring-(--color-border)"
      >
        {{ product.category }}
      </span>
      <span
        v-if="product.country_name"
        class="flex items-center gap-1 text-xs text-(--color-text-secondary)"
      >
        <span>{{ countryFlag }}</span>
        {{ product.country_name }}
      </span>
    </div>

    <!-- MRR -->
    <div
      v-if="product.mrr"
      class="text-lg font-semibold tabular-nums text-emerald-400"
    >
      {{ formatCompact(product.mrr) }}
      <span class="text-xs font-normal text-(--color-text-muted)">MRR</span>
    </div>

    <!-- Description -->
    <p
      v-if="product.description"
      class="line-clamp-2 flex-1 text-xs leading-relaxed text-(--color-text-muted)"
    >
      {{ product.description }}
    </p>

    <!-- Footer: Open App + Source -->
    <div class="mt-auto flex items-center justify-between gap-2">
      <a
        v-if="product.website_url"
        :href="product.website_url"
        target="_blank"
        rel="noopener noreferrer"
        class="inline-flex items-center gap-1.5 rounded-md border border-(--color-border) px-2.5 py-1 text-xs font-medium text-(--color-text-secondary) transition-colors hover:border-blue-500/50 hover:text-blue-400"
        @click.stop
      >
        <ExternalLink class="size-3" />
        Open App
      </a>
      <a
        v-if="product.primary_source_url"
        :href="product.primary_source_url"
        target="_blank"
        rel="noopener noreferrer"
        class="inline-flex items-center gap-1 text-xs text-(--color-text-muted) transition-colors hover:text-blue-400"
        @click.stop
      >
        <LinkIcon class="size-3" />
        {{ product.primary_source || "Source" }}
      </a>
      <span
        v-else-if="product.primary_source"
        class="inline-flex items-center gap-1 text-xs text-(--color-text-muted)"
      >
        <LinkIcon class="size-3" />
        {{ product.primary_source }}
      </span>
    </div>
  </NuxtLink>
</template>

<script setup lang="ts">
import { ExternalLink, Link as LinkIcon } from "lucide-vue-next";
import type { ProductView } from "~/types/database.types";
import { formatCompact } from "~/utils/format";

const props = defineProps<{
  product: ProductView;
}>();

function codeToFlag(code: string): string {
  return code
    .toUpperCase()
    .split("")
    .map((c) => String.fromCodePoint(0x1f1e6 + c.charCodeAt(0) - 65))
    .join("");
}

const countryFlag = computed(() => {
  const code = props.product.country_code;
  if (!code) return "";
  return codeToFlag(code);
});
</script>
