<template>
  <div>
    <section class="border-b border-(--color-border) bg-(--color-surface)">
      <div class="mx-auto max-w-380 px-4 py-10 sm:px-6 lg:px-8">
        <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">
          <span class="gradient-text">Raw</span>
          <span class="text-(--color-text-primary)"> Data</span>
        </h1>
        <p class="mt-2 text-base text-(--color-text-secondary)">
          Unprocessed data directly from sources.
          <template v-if="!loading">
            {{ totalCount.toLocaleString() }} records from
            {{ sourceList.length }} sources.
            <span class="text-(--color-text-muted)">· DuckDB-WASM</span>
          </template>
          <template v-else>
            <span v-if="loadingPhase === 'duckdb'">Initializing DuckDB...</span>
            <span v-else-if="loadingPhase === 'fetch'">Loading data...</span>
            <span v-else-if="loadingPhase === 'ingest'"
              >Ingesting into DuckDB...</span
            >
            <span v-else>Loading...</span>
          </template>
        </p>
      </div>
    </section>

    <div class="mx-auto max-w-380 px-4 py-6 sm:px-6 lg:px-8">
      <!-- Source stats -->
      <div v-if="sourceStats.length > 0" class="mb-4 flex gap-2">
        <span
          v-for="stat in sourceStats"
          :key="stat.source_name"
          class="inline-flex items-center gap-1.5 rounded-full border border-(--color-border) bg-(--color-surface) px-2.5 py-1 text-xs text-(--color-text-secondary)"
        >
          <span
            class="size-1.5 rounded-full"
            :class="sourceColor(stat.source_name)"
          />
          {{ stat.source_name }}: {{ Number(stat.cnt).toLocaleString() }}
        </span>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="flex justify-center py-12">
        <div
          class="size-8 animate-spin rounded-full border-2 border-(--color-border) border-t-blue-500"
        />
      </div>

      <!-- AG Grid -->
      <div
        v-else
        class="rounded-lg border border-(--color-border)"
        style="width: 100%; height: 75vh"
      >
        <AgGridVue
          style="width: 100%; height: 100%"
          :row-data="rowData"
          :column-defs="columnDefs"
          :default-col-def="defaultColDef"
          :pagination="true"
          :pagination-page-size="100"
          :pagination-page-size-selector="[50, 100, 250, 500]"
          :row-selection="rowSelection"
          :get-row-id="getRowId"
          :auto-size-strategy="autoSizeStrategy"
          :theme="gridTheme"
          @cell-context-menu="onCellContextMenu"
        />
      </div>
    </div>

    <!-- Custom Context Menu -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition-all duration-100 ease-out"
        leave-active-class="transition-all duration-75 ease-in"
        enter-from-class="opacity-0 scale-95"
        leave-to-class="opacity-0 scale-95"
      >
        <div
          v-if="contextMenu.visible"
          ref="contextMenuEl"
          class="fixed z-200 min-w-48 rounded-lg border border-(--color-border) bg-(--color-surface) py-1 shadow-xl shadow-black/40"
          :style="{ left: contextMenu.x + 'px', top: contextMenu.y + 'px' }"
        >
          <button
            v-if="contextMenu.row?.url"
            class="flex w-full items-center gap-2.5 px-3 py-2 text-left text-sm text-(--color-text-secondary) transition-colors hover:bg-white/5 hover:text-(--color-text-primary)"
            @click="openApp()"
          >
            <ExternalLink class="size-3.5 text-blue-400" />
            Open App
          </button>
          <button
            class="flex w-full items-center gap-2.5 px-3 py-2 text-left text-sm text-(--color-text-secondary) transition-colors hover:bg-white/5 hover:text-(--color-text-primary)"
            @click="showRawData()"
          >
            <Code class="size-3.5 text-emerald-400" />
            Show Raw Data
          </button>
        </div>
      </Transition>

      <!-- Raw Data Dialog Overlay -->
      <Transition
        enter-active-class="transition-all duration-200 ease-out"
        leave-active-class="transition-all duration-150 ease-in"
        enter-from-class="opacity-0"
        leave-to-class="opacity-0"
      >
        <div
          v-if="dialogRecord"
          class="fixed inset-0 z-150 flex items-center justify-center bg-black/60 backdrop-blur-sm"
          @click.self="dialogRecord = null"
        >
          <Transition
            enter-active-class="transition-all duration-200 ease-out"
            leave-active-class="transition-all duration-150 ease-in"
            enter-from-class="opacity-0 scale-95 translate-y-2"
            leave-to-class="opacity-0 scale-95 translate-y-2"
            appear
          >
            <div
              v-if="dialogRecord"
              class="mx-4 flex max-h-[80vh] w-full max-w-3xl flex-col rounded-xl border border-(--color-border) bg-(--color-surface) shadow-2xl shadow-black/50"
            >
              <!-- Dialog Header -->
              <div
                class="flex shrink-0 items-center justify-between border-b border-(--color-border) px-5 py-4"
              >
                <div class="min-w-0 flex-1">
                  <h3
                    class="truncate text-base font-semibold text-(--color-text-primary)"
                  >
                    {{ dialogRecord.name || dialogRecord.external_id }}
                  </h3>
                  <p class="mt-0.5 text-xs text-(--color-text-muted)">
                    {{ dialogRecord.source_name }} ·
                    {{ dialogRecord.external_id }}
                  </p>
                </div>
                <div class="ml-4 flex shrink-0 items-center gap-2">
                  <a
                    v-if="dialogRecord.url"
                    :href="dialogRecord.url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="inline-flex items-center gap-1.5 rounded-md border border-(--color-border) px-2.5 py-1.5 text-xs font-medium text-(--color-text-secondary) transition-colors hover:border-blue-500/50 hover:text-blue-400"
                  >
                    <ExternalLink class="size-3" />
                    Open App
                  </a>
                  <button
                    class="inline-flex items-center gap-1.5 rounded-md border border-(--color-border) px-2.5 py-1.5 text-xs font-medium text-(--color-text-secondary) transition-colors hover:border-emerald-500/50 hover:text-emerald-400"
                    @click="copyJson(dialogRecord.raw_json)"
                  >
                    <Copy class="size-3" />
                    {{ copied ? "Copied!" : "Copy" }}
                  </button>
                  <button
                    class="rounded-md p-1.5 text-(--color-text-muted) transition-colors hover:bg-white/5 hover:text-(--color-text-primary)"
                    @click="dialogRecord = null"
                  >
                    <X class="size-4" />
                  </button>
                </div>
              </div>

              <!-- Dialog Body -->
              <div class="overflow-auto p-5">
                <pre
                  class="rounded-lg bg-(--color-bg) p-4 text-xs leading-relaxed text-(--color-text-secondary)"
                  >{{ dialogRecord.raw_json }}</pre
                >
              </div>
            </div>
          </Transition>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script setup lang="ts">
import { AgGridVue } from "ag-grid-vue3";
import {
  AllCommunityModule,
  ModuleRegistry,
  themeQuartz,
  type CellClassParams,
  type CellContextMenuEvent,
  type ColDef,
  type GetRowIdParams,
  type RowSelectionOptions,
  type SizeColumnsToFitGridStrategy,
  type ValueFormatterParams,
} from "ag-grid-community";
import { ExternalLink, Code, Copy, X } from "lucide-vue-next";
import { formatCurrency } from "~/utils/format";
import AgSetFilter from "~/components/AgSetFilter.vue";

ModuleRegistry.registerModules([AllCommunityModule]);

const gridTheme = themeQuartz.withParams({
  accentColor: "#3b82f6",
  backgroundColor: "#0a0a0f",
  foregroundColor: "#f0f0f5",
  headerTextColor: "#65657a",
  borderColor: "rgba(255, 255, 255, 0.08)",
  selectedRowBackgroundColor: "rgba(59, 130, 246, 0.1)",
  fontFamily: '"Inter", ui-sans-serif, system-ui, sans-serif',
  fontSize: 13,
  borderRadius: 8,
  wrapperBorderRadius: 8,
});

interface GridRow {
  id: string;
  source_name: string;
  name: string;
  external_id: string;
  mrr: number | null;
  category: string | null;
  country: string | null;
  url: string | null;
  fetched_at: string;
  raw_json: string;
}

interface SourceStat {
  source_name: string;
  cnt: number;
}

const duck = useDuckDB();

const loading = ref(true);
const loadingPhase = ref<"duckdb" | "fetch" | "ingest" | "">("");
const rowData = ref<GridRow[]>([]);
const sourceStats = ref<SourceStat[]>([]);
const sourceList = ref<string[]>([]);
const totalCount = ref(0);

// Context menu state
const contextMenuEl = ref<HTMLElement | null>(null);
const contextMenu = reactive({
  visible: false,
  x: 0,
  y: 0,
  row: null as GridRow | null,
});

// Dialog state
const dialogRecord = ref<GridRow | null>(null);
const copied = ref(false);

useHead({
  title: "Raw Data Explorer",
  meta: [{ name: "robots", content: "noindex, nofollow" }],
});

// --- AG Grid config ---

const columnDefs: ColDef<GridRow>[] = [
  {
    field: "source_name",
    headerName: "Source",
    width: 120,
    filter: AgSetFilter,
    cellClass: "font-mono text-xs",
  },
  {
    field: "name",
    headerName: "Name",
    minWidth: 180,
    filter: "agTextColumnFilter",
  },
  {
    field: "url",
    headerName: "",
    width: 50,
    maxWidth: 50,
    sortable: false,
    filter: false,
    resizable: false,
    cellRenderer: (params: { value: string | null }) => {
      if (!params.value) return "";
      const a = document.createElement("a");
      a.href = params.value;
      a.target = "_blank";
      a.rel = "noopener noreferrer";
      a.title = "Open app";
      a.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-blue-400 hover:text-blue-300"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>`;
      a.style.display = "flex";
      a.style.alignItems = "center";
      a.style.justifyContent = "center";
      a.style.height = "100%";
      a.addEventListener("click", (e) => e.stopPropagation());
      return a;
    },
  },
  {
    field: "external_id",
    headerName: "External ID",
    minWidth: 140,
    filter: "agTextColumnFilter",
    cellClass: "font-mono text-xs text-(--color-text-muted)",
  },
  {
    field: "mrr",
    headerName: "MRR",
    width: 110,
    filter: "agNumberColumnFilter",
    type: "numericColumn",
    valueFormatter: (p: ValueFormatterParams<GridRow, number>) => {
      if (p.value == null || p.value <= 0) return "—";
      return formatCurrency(p.value);
    },
    cellClass: (p: CellClassParams<GridRow>) =>
      p.value && p.value > 0
        ? "text-emerald-400 font-medium"
        : "text-(--color-text-muted)",
  },
  {
    field: "category",
    headerName: "Category",
    width: 140,
    filter: AgSetFilter,
    valueFormatter: (p: ValueFormatterParams<GridRow, string>) =>
      p.value || "—",
  },
  {
    field: "country",
    headerName: "Country",
    width: 100,
    filter: AgSetFilter,
    valueFormatter: (p: ValueFormatterParams<GridRow, string>) =>
      p.value || "—",
  },
  {
    field: "fetched_at",
    headerName: "Fetched",
    width: 120,
    sort: "desc",
    valueFormatter: (p: ValueFormatterParams<GridRow, string>) =>
      p.value ? formatRelative(p.value) : "—",
    comparator: (a: string, b: string) =>
      new Date(a).getTime() - new Date(b).getTime(),
  },
];

const defaultColDef: ColDef = {
  sortable: true,
  resizable: true,
  filter: true,
};

const autoSizeStrategy: SizeColumnsToFitGridStrategy = {
  type: "fitGridWidth",
};

const rowSelection: RowSelectionOptions = {
  mode: "singleRow",
  enableClickSelection: true,
};

function getRowId(params: GetRowIdParams<GridRow>): string {
  return params.data.id;
}

// --- Context Menu ---

function onCellContextMenu(event: CellContextMenuEvent<GridRow>) {
  if (!event.data) return;

  const e = event.event as MouseEvent;
  e.preventDefault();

  contextMenu.row = event.data;
  contextMenu.x = e.clientX;
  contextMenu.y = e.clientY;
  contextMenu.visible = true;

  // Adjust position if menu would overflow viewport
  nextTick(() => {
    if (!contextMenuEl.value) return;
    const rect = contextMenuEl.value.getBoundingClientRect();
    if (rect.right > window.innerWidth) {
      contextMenu.x = window.innerWidth - rect.width - 8;
    }
    if (rect.bottom > window.innerHeight) {
      contextMenu.y = window.innerHeight - rect.height - 8;
    }
  });
}

function closeContextMenu() {
  contextMenu.visible = false;
  contextMenu.row = null;
}

function openApp() {
  if (contextMenu.row?.url) {
    window.open(contextMenu.row.url, "_blank", "noopener,noreferrer");
  }
  closeContextMenu();
}

function showRawData() {
  if (contextMenu.row) {
    dialogRecord.value = contextMenu.row;
  }
  closeContextMenu();
}

// Close context menu on click anywhere / Escape
function onDocumentClick() {
  if (contextMenu.visible) closeContextMenu();
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === "Escape") {
    if (dialogRecord.value) {
      dialogRecord.value = null;
    } else if (contextMenu.visible) {
      closeContextMenu();
    }
  }
}

onMounted(() => {
  document.addEventListener("click", onDocumentClick);
  document.addEventListener("keydown", onKeydown);
  loadData();
});

onUnmounted(() => {
  document.removeEventListener("click", onDocumentClick);
  document.removeEventListener("keydown", onKeydown);
});

// --- Data loading pipeline ---

async function loadData() {
  loading.value = true;

  // 1. Load bronze data from static JSON into DuckDB
  loadingPhase.value = "fetch";
  await duck.ensureBronze();

  // 2. Query stats from DuckDB
  loadingPhase.value = "ingest";
  const stats = await duck.query<SourceStat>(
    "SELECT source_name, COUNT(*) as cnt FROM bronze GROUP BY source_name ORDER BY cnt DESC",
  );
  sourceStats.value = stats;
  sourceList.value = stats.map((s) => s.source_name);

  const countRows = await duck.query<{ total: number }>(
    "SELECT COUNT(*)::int as total FROM bronze",
  );
  totalCount.value = countRows[0]?.total ?? 0;

  // 3. Load all rows for AG Grid
  const rows = await duck.query<GridRow>(
    "SELECT id, source_name, name, external_id, mrr, category, country, url, fetched_at, raw_json FROM bronze ORDER BY fetched_at DESC",
  );
  rowData.value = rows;

  loading.value = false;
  loadingPhase.value = "";
}

// --- Helpers ---

function sourceColor(name: string): string {
  if (name === "trustmrr") return "bg-blue-500/15 text-blue-400";
  if (name === "indiehackers") return "bg-orange-500/15 text-orange-400";
  return "bg-gray-500/15 text-gray-400";
}

function formatRelative(date: string): string {
  const diff = Date.now() - new Date(date).getTime();
  const hours = Math.floor(diff / (1000 * 60 * 60));
  if (hours < 1) return "just now";
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

async function copyJson(json: string) {
  try {
    await navigator.clipboard.writeText(json);
    copied.value = true;
    setTimeout(() => (copied.value = false), 2000);
  } catch {
    // silent
  }
}
</script>
