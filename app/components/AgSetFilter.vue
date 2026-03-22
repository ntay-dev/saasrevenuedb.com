<template>
  <div class="ag-set-filter">
    <div class="ag-set-filter-search">
      <input
        v-model="search"
        type="text"
        placeholder="Search..."
        class="ag-set-filter-input"
      />
    </div>
    <div class="ag-set-filter-actions">
      <button class="ag-set-filter-btn" @click="selectAll">All</button>
      <button class="ag-set-filter-btn" @click="selectNone">None</button>
    </div>
    <div class="ag-set-filter-list">
      <label
        v-for="val in filteredValues"
        :key="val ?? '__null__'"
        class="ag-set-filter-item"
      >
        <input
          type="checkbox"
          :checked="selected.has(val)"
          @change="toggle(val)"
        />
        <span class="ag-set-filter-label">{{ val || "(empty)" }}</span>
      </label>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { IFilterParams, IDoesFilterPassParams } from "ag-grid-community";

const props = defineProps<{ params: IFilterParams }>();

const search = ref("");
const allValues = ref<(string | null)[]>([]);
const selected = ref<Set<string | null>>(new Set());

const filteredValues = computed(() => {
  if (!search.value) return allValues.value;
  const q = search.value.toLowerCase();
  return allValues.value.filter((v) => (v ?? "").toLowerCase().includes(q));
});

function collectValues() {
  const vals = new Set<string | null>();
  props.params.api.forEachNode((node) => {
    if (node.data) {
      const v = node.data[props.params.colDef.field as string];
      vals.add(v ?? null);
    }
  });
  const sorted = [...vals].sort((a, b) => {
    if (a === null) return 1;
    if (b === null) return -1;
    return String(a).localeCompare(String(b));
  });
  allValues.value = sorted;
  selected.value = new Set(sorted);
}

function toggle(val: string | null) {
  const s = new Set(selected.value);
  if (s.has(val)) s.delete(val);
  else s.add(val);
  selected.value = s;
  props.params.filterChangedCallback();
}

function selectAll() {
  selected.value = new Set(allValues.value);
  props.params.filterChangedCallback();
}

function selectNone() {
  selected.value = new Set();
  props.params.filterChangedCallback();
}

function doesFilterPass(params: IDoesFilterPassParams): boolean {
  const val = params.data[props.params.colDef.field as string] ?? null;
  return selected.value.has(val);
}

function isFilterActive(): boolean {
  return selected.value.size !== allValues.value.length;
}

function getModel() {
  if (!isFilterActive()) return null;
  return { values: [...selected.value] };
}

function setModel(model: { values: (string | null)[] } | null) {
  if (!model) {
    selected.value = new Set(allValues.value);
  } else {
    selected.value = new Set(model.values);
  }
}

onMounted(() => collectValues());

defineExpose({ doesFilterPass, isFilterActive, getModel, setModel });
</script>

<style>
.ag-set-filter {
  padding: 8px;
  min-width: 180px;
  max-height: 300px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 12px;
  color: #f0f0f5;
}

.ag-set-filter-search {
  padding-bottom: 4px;
}

.ag-set-filter-input {
  width: 100%;
  padding: 4px 8px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.05);
  color: #f0f0f5;
  font-size: 12px;
  outline: none;
}

.ag-set-filter-input:focus {
  border-color: #3b82f6;
}

.ag-set-filter-actions {
  display: flex;
  gap: 6px;
  padding-bottom: 4px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.ag-set-filter-btn {
  padding: 2px 8px;
  border-radius: 3px;
  background: rgba(255, 255, 255, 0.06);
  color: #9ca3af;
  cursor: pointer;
  border: none;
  font-size: 11px;
}

.ag-set-filter-btn:hover {
  background: rgba(255, 255, 255, 0.12);
  color: #f0f0f5;
}

.ag-set-filter-list {
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.ag-set-filter-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 3px 4px;
  border-radius: 3px;
  cursor: pointer;
}

.ag-set-filter-item:hover {
  background: rgba(255, 255, 255, 0.05);
}

.ag-set-filter-item input[type="checkbox"] {
  accent-color: #3b82f6;
  cursor: pointer;
}

.ag-set-filter-label {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
