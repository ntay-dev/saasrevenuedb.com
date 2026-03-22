<template>
  <component
    :is="founder.xHandle ? 'a' : 'div'"
    :href="founder.xHandle ? `https://x.com/${founder.xHandle}` : undefined"
    :target="founder.xHandle ? '_blank' : undefined"
    :rel="founder.xHandle ? 'noopener noreferrer' : undefined"
    class="group flex items-center gap-2.5 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2 transition-all hover:border-blue-500/30 hover:bg-blue-500/5"
  >
    <img
      :src="founder.avatarUrl"
      :alt="founder.name"
      class="h-8 w-8 rounded-full object-cover ring-2 ring-white/10 transition-all group-hover:ring-blue-500/30"
      loading="lazy"
      @error="handleImgError"
    />
    <div class="min-w-0">
      <p class="truncate text-sm font-medium text-[var(--color-text-primary)]">
        {{ founder.name }}
      </p>
      <p v-if="founder.xHandle" class="text-xs text-[var(--color-text-muted)]">
        @{{ founder.xHandle }}
      </p>
    </div>
    <ExternalLink
      v-if="founder.xHandle"
      class="ml-auto size-3 text-[var(--color-text-muted)] opacity-0 transition-opacity group-hover:opacity-100"
    />
  </component>
</template>

<script setup lang="ts">
import { ExternalLink } from "lucide-vue-next";

const props = defineProps<{
  founder: {
    name: string;
    xHandle: string;
    avatarUrl: string;
  };
}>();

function handleImgError(event: Event) {
  const img = event.target as HTMLImageElement;
  img.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(props.founder.name)}&size=32&background=3b82f6&color=fff&bold=true`;
}
</script>
