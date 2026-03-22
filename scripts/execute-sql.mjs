#!/usr/bin/env node
/**
 * Executes a SQL file against Supabase via the Management API.
 * Used by GitHub Actions cron jobs for automated data syncs.
 *
 * Usage: SUPABASE_ACCESS_TOKEN=... node scripts/execute-sql.mjs <sql-file>
 *
 * Environment:
 *   SUPABASE_ACCESS_TOKEN — Supabase Management API token (required)
 *   SUPABASE_PROJECT_ID   — Project ID (default: wenerrewidsepasvnlft)
 */

import { readFileSync } from "fs";

const PROJECT_ID = process.env.SUPABASE_PROJECT_ID || "wenerrewidsepasvnlft";
const ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN;

const sqlFile = process.argv[2];

if (!sqlFile) {
  console.error("Usage: node scripts/execute-sql.mjs <sql-file>");
  process.exit(1);
}

if (!ACCESS_TOKEN) {
  console.error("Error: SUPABASE_ACCESS_TOKEN environment variable required");
  process.exit(1);
}

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
  const rawSql = readFileSync(sqlFile, "utf-8");
  console.log(`Executing SQL from: ${sqlFile}`);

  // Split into individual statements
  const statements = [];
  let current = [];
  for (const line of rawSql.split("\n")) {
    if (line.startsWith("--")) continue;
    current.push(line);
    if (line.trimEnd().endsWith(";")) {
      const stmt = current.join("\n").trim();
      if (stmt && stmt !== ";") statements.push(stmt);
      current = [];
    }
  }

  console.log(`Found ${statements.length} SQL statements`);

  // Execute in batches of 10 statements for efficiency
  const batchSize = 10;
  let success = 0;
  let errors = 0;

  for (let i = 0; i < statements.length; i += batchSize) {
    const batch = statements.slice(i, i + batchSize);
    const combinedSql = batch.join("\n");
    const batchNum = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(statements.length / batchSize);

    process.stdout.write(
      `  Batch ${batchNum}/${totalBatches} (${batch.length} statements)... `,
    );

    try {
      await executeSql(combinedSql);
      console.log("OK");
      success += batch.length;
    } catch (err) {
      console.log(`ERROR: ${err.message.substring(0, 200)}`);
      // Retry individual statements on batch failure
      for (const stmt of batch) {
        try {
          await executeSql(stmt);
          success++;
        } catch (stmtErr) {
          console.error(`  FAILED: ${stmt.substring(0, 80)}...`);
          console.error(`  ${stmtErr.message.substring(0, 200)}`);
          errors++;
        }
      }
    }

    // Rate limit: 200ms between batches
    await new Promise((r) => setTimeout(r, 200));
  }

  console.log(
    `\nDone: ${success} OK, ${errors} errors out of ${statements.length} statements`,
  );

  if (errors > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
