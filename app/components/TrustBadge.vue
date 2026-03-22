<template>
  <TooltipProvider>
    <Tooltip>
      <TooltipTrigger as-child>
        <span
          class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[0.65rem] font-medium"
          :class="badgeClass"
        >
          <component :is="icon" class="size-3" />
          {{ label }}
          <span v-if="showLevel" class="ml-0.5 tabular-nums opacity-70">{{
            level
          }}</span>
        </span>
      </TooltipTrigger>
      <TooltipContent>
        {{ tooltipText }}
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
import { BadgeCheck, CheckCircle, Info, HelpCircle } from "lucide-vue-next";

const props = withDefaults(
  defineProps<{
    level: number;
    showLevel?: boolean;
  }>(),
  {
    showLevel: false,
  },
);

const label = computed(() => {
  if (props.level >= 80) return "Verified";
  if (props.level >= 50) return "Medium";
  if (props.level >= 20) return "Low";
  return "Unknown";
});

const badgeClass = computed(() => {
  if (props.level >= 80)
    return "bg-green-500/10 text-green-400 ring-1 ring-green-500/20";
  if (props.level >= 50)
    return "bg-amber-500/10 text-amber-400 ring-1 ring-amber-500/20";
  if (props.level >= 20)
    return "bg-orange-500/10 text-orange-400 ring-1 ring-orange-500/20";
  return "bg-white/5 text-(--color-text-muted) ring-1 ring-white/10";
});

const icon = computed(() => {
  if (props.level >= 80) return BadgeCheck;
  if (props.level >= 50) return CheckCircle;
  if (props.level >= 20) return Info;
  return HelpCircle;
});

const tooltipText = computed(() => {
  if (props.level >= 90)
    return `Trust Level ${props.level}: Official company data, SEC filings`;
  if (props.level >= 80)
    return `Trust Level ${props.level}: Stripe-verified, Crunchbase, PitchBook`;
  if (props.level >= 70)
    return `Trust Level ${props.level}: LinkedIn, Wikipedia, G2`;
  if (props.level >= 50)
    return `Trust Level ${props.level}: News articles, press releases`;
  if (props.level >= 20)
    return `Trust Level ${props.level}: Community data, estimates`;
  return `Trust Level ${props.level}: Unverified data`;
});
</script>
