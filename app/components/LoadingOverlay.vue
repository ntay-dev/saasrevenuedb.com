<template>
  <Transition
    enter-active-class="transition-opacity duration-300"
    leave-active-class="transition-opacity duration-500"
    enter-from-class="opacity-0"
    leave-to-class="opacity-0"
  >
    <div
      v-if="visible"
      class="fixed inset-0 z-[100] flex items-center justify-center bg-(--color-bg)"
    >
      <div class="flex flex-col items-center gap-6">
        <!-- Animated radar icon -->
        <div class="relative">
          <div
            class="flex h-16 w-16 items-center justify-center rounded-2xl bg-linear-to-br from-emerald-500 to-cyan-500 shadow-lg shadow-emerald-500/30"
          >
            <Radar class="size-9 text-white" />
          </div>
          <!-- Pulse rings -->
          <div
            class="absolute inset-0 rounded-2xl bg-emerald-500/20"
            :class="store.loadProgress > 0 ? 'animate-ping' : 'animate-pulse'"
            style="animation-duration: 1.5s"
          />
        </div>

        <!-- Counter -->
        <div class="text-center">
          <p class="text-sm font-medium text-(--color-text-secondary)">
            Loading database
          </p>
          <p class="mt-1 text-xs text-(--color-text-muted)">
            Preparing local database…
          </p>
        </div>

        <!-- Progress bar -->
        <div class="h-1 w-48 overflow-hidden rounded-full bg-white/10">
          <div
            class="h-full rounded-full bg-linear-to-r from-emerald-500 to-cyan-400 transition-all duration-300 ease-out"
            :style="{ width: `${store.loadProgress}%` }"
          />
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { Radar } from "lucide-vue-next";
import { useProductsStore } from "~/stores/products";

const store = useProductsStore();

const visible = computed(() => !store.initialized);

// Animated counter that smoothly counts up
const displayCount = ref(0);
let animFrame = 0;

watch(
  () => store.loadedCount,
  (target) => {
    const start = displayCount.value;
    const diff = target - start;
    if (diff <= 0) return;

    const duration = 300; // ms
    const startTime = performance.now();

    function step(now: number) {
      const elapsed = now - startTime;
      const t = Math.min(elapsed / duration, 1);
      // ease-out cubic
      const eased = 1 - (1 - t) ** 3;
      displayCount.value = Math.round(start + diff * eased);

      if (t < 1) {
        animFrame = requestAnimationFrame(step);
      }
    }

    cancelAnimationFrame(animFrame);
    animFrame = requestAnimationFrame(step);
  },
);

onUnmounted(() => cancelAnimationFrame(animFrame));
</script>
