#!/usr/bin/env node
/**
 * Standalone script to re-run Silver transformation and/or Gold refresh.
 *
 * Usage:
 *   SUPABASE_ACCESS_TOKEN=... node scripts/transform-and-refresh.mjs              # transform latest pending + refresh gold
 *   SUPABASE_ACCESS_TOKEN=... node scripts/transform-and-refresh.mjs <run-id>     # transform specific run + refresh gold
 *   SUPABASE_ACCESS_TOKEN=... node scripts/transform-and-refresh.mjs --gold-only  # only refresh gold view
 */

import { transformRun, autoCategorize, refreshGold } from "./lib/pipeline.mjs";

const PROJECT_ID = process.env.SUPABASE_PROJECT_ID || "wenerrewidsepasvnlft";
const ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN;

async function executeSql(sql) {
  const res = await fetch(
    `https://api.supabase.com/v1/projects/${PROJECT_ID}/database/query`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${ACCESS_TOKEN}`,
      },
      body: JSON.stringify({ query: sql }),
    },
  );
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`SQL error (${res.status}): ${text.substring(0, 500)}`);
  }
  return res.json();
}

async function main() {
  const arg = process.argv[2];

  if (arg === "--gold-only") {
    console.log("Auto-categorizing + Refreshing Gold view...");
    await autoCategorize();
    await refreshGold();
    console.log("Done.");
    return;
  }

  let runId = arg;

  if (!runId) {
    // Find latest completed pipeline run that hasn't been transformed yet,
    // or the most recent run
    console.log("Finding latest pipeline run...");
    const runs = await executeSql(`
      SELECT id, source_name, status, started_at
      FROM public.pipeline_runs
      ORDER BY started_at DESC
      LIMIT 5;
    `);

    if (runs.length === 0) {
      console.log("No pipeline runs found.");
      return;
    }

    console.log("Recent runs:");
    for (const r of runs) {
      console.log(
        `  ${r.id} | ${r.source_name} | ${r.status} | ${r.started_at}`,
      );
    }

    runId = runs[0].id;
    console.log(`\nUsing latest run: ${runId}`);
  }

  const result = await transformRun(runId);
  console.log(`Transform result: ${JSON.stringify(result)}`);

  await autoCategorize();
  await refreshGold();

  // Show Gold stats
  const goldStats = await executeSql(`
    SELECT count(*) AS total,
           count(mrr) AS with_mrr,
           max(mrr) AS max_mrr
    FROM public.products_gold;
  `);
  console.log("Gold view stats:", goldStats[0]);
}

main().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
