<template>
  <TooltipProvider v-if="sourcedAt">
    <Tooltip>
      <TooltipTrigger as-child>
        <span
          class="inline-flex items-center gap-1 text-[0.65rem]"
          :class="isStale ? 'text-orange-400' : 'text-(--color-text-muted)'"
        >
          <AlertTriangle v-if="isStale" class="size-3" />
          <Clock v-else class="size-3" />
          {{ relativeTime }}
        </span>
      </TooltipTrigger>
      <TooltipContent>
        {{ fullDate }}
      </TooltipContent>
    </Tooltip>
  </TooltipProvider>
</template>

<script setup lang="ts">
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "~/components/ui/tooltip";
import { AlertTriangle, Clock } from "lucide-vue-next";
import { formatDistanceToNow, parseISO, differenceInMonths } from "date-fns";
import { enUS } from "date-fns/locale";

const props = defineProps<{
  sourcedAt: string | null;
  staleMonths?: number;
}>();

const staleThreshold = computed(() => props.staleMonths ?? 6);

const parsedDate = computed(() => {
  if (!props.sourcedAt) return null;
  try {
    return parseISO(props.sourcedAt);
  } catch {
    return null;
  }
});

const relativeTime = computed(() => {
  if (!parsedDate.value) return "";
  return formatDistanceToNow(parsedDate.value, {
    addSuffix: true,
    locale: enUS,
  });
});

const fullDate = computed(() => {
  if (!parsedDate.value) return "";
  const label = isStale.value ? "Outdated! " : "";
  return `${label}Last updated: ${parsedDate.value.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}`;
});

const isStale = computed(() => {
  if (!parsedDate.value) return false;
  return (
    differenceInMonths(new Date(), parsedDate.value) >= staleThreshold.value
  );
});
</script>
