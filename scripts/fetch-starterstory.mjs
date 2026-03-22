#!/usr/bin/env node
/**
 * Fetch StarterStory YouTube channel transcripts and extract SaaS data
 * using GPT-4o-mini for reliable structured extraction.
 *
 * Downloads auto-captions from https://www.youtube.com/@starterstory,
 * sends transcripts to OpenAI for extraction of: product name, founder,
 * revenue, website, description. Loads into Bronze → Silver → Gold pipeline.
 *
 * Requires: yt-dlp (pip install yt-dlp), SUPABASE_ACCESS_TOKEN, OPENAI_API_KEY
 *
 * Usage:
 *   node scripts/fetch-starterstory.mjs              # Fetch new videos only
 *   node scripts/fetch-starterstory.mjs --reparse    # Re-parse ALL existing Bronze records with LLM
 */

import { execSync } from "child_process";
import {
  writeFileSync,
  readFileSync,
  mkdirSync,
  existsSync,
  readdirSync,
} from "fs";
import {
  executeSql,
  startRun,
  loadBronzeRecords,
  transformRun,
  autoCategorize,
  refreshGold,
  completeRun,
  failRun,
} from "./lib/pipeline.mjs";

const CHANNEL_URL = "https://www.youtube.com/@starterstory/videos";
const SUBS_DIR = "/tmp/starterstory-subs";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const REPARSE = process.argv.includes("--reparse");

if (!OPENAI_API_KEY) {
  console.error("Error: OPENAI_API_KEY environment variable required");
  process.exit(1);
}

// ============================================================
// Step 1: List all videos from the channel
// ============================================================

function listVideos() {
  console.log("Listing all StarterStory videos...");
  const output = execSync(
    `yt-dlp --flat-playlist --print "%(id)s|||%(title)s|||%(duration)s" "${CHANNEL_URL}" 2>/dev/null`,
    { encoding: "utf-8", maxBuffer: 10 * 1024 * 1024 },
  );

  const videos = output
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [id, title, duration] = line.split("|||");
      return { id, title, duration: parseFloat(duration) || 0 };
    })
    // Filter out shorts (< 2 min) and non-interview content
    .filter((v) => v.duration > 120);

  console.log(`Found ${videos.length} videos (>2min)`);
  return videos;
}

// ============================================================
// Step 2: Download transcripts via yt-dlp
// ============================================================

function downloadTranscripts(videos) {
  mkdirSync(SUBS_DIR, { recursive: true });

  const existing = new Set(
    readdirSync(SUBS_DIR)
      .filter((f) => f.endsWith(".en.srt"))
      .map((f) => f.replace(".en.srt", "")),
  );

  const toDownload = videos.filter((v) => !existing.has(v.id));
  console.log(
    `Downloading ${toDownload.length} transcripts (${existing.size} cached)...`,
  );

  const batchSize = 10;
  for (let i = 0; i < toDownload.length; i += batchSize) {
    const batch = toDownload.slice(i, i + batchSize);
    const urls = batch.map((v) => `https://www.youtube.com/watch?v=${v.id}`);

    try {
      execSync(
        `yt-dlp --write-auto-sub --sub-lang en --sub-format srt --skip-download ` +
          `--output "${SUBS_DIR}/%(id)s" ${urls.map((u) => `"${u}"`).join(" ")} 2>/dev/null`,
        { encoding: "utf-8", maxBuffer: 10 * 1024 * 1024, timeout: 120000 },
      );
    } catch (err) {
      console.error(`  Batch error at ${i}: ${err.message.substring(0, 100)}`);
    }

    if (i > 0 && i % 50 === 0) {
      console.log(`  Downloaded ${i}/${toDownload.length}...`);
    }
  }
}

function readTranscript(videoId) {
  const path = `${SUBS_DIR}/${videoId}.en.srt`;
  if (!existsSync(path)) return null;

  const raw = readFileSync(path, "utf-8");
  // Strip SRT formatting → plain text
  return raw
    .replace(/<[^>]*>/g, "")
    .split("\n")
    .filter(
      (line) =>
        !/^\d+$/.test(line.trim()) &&
        !/^\d{2}:\d{2}/.test(line.trim()) &&
        line.trim(),
    )
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
}

// ============================================================
// Step 3: Parse transcript via OpenAI GPT-4o-mini
// ============================================================

async function parseWithLLM(transcript, title) {
  // Use first ~6000 chars of transcript (enough for context, keeps cost low)
  const truncated = transcript.substring(0, 6000);

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: `You extract structured SaaS product data from YouTube interview transcripts.
Return a JSON object with these fields (use null if not found/unclear):
- "productName": The actual SaaS product/app/tool name (NOT the founder's name, NOT generic words like "Tech" or "MVP"). Must be a real product name.
- "founderName": Full name of the founder being interviewed.
- "mrr": Monthly recurring revenue in USD (number). Convert yearly to monthly (/12). Convert "K" to thousands. If multiple revenue figures, use the most recent/current one.
- "description": One-sentence description of what the product does (max 150 chars).
- "websiteUrl": The product's website URL if mentioned (full URL with https://).

Be strict about productName — only return it if you're confident it's the actual product name. If the transcript is unclear or seems like a non-SaaS video, set productName to null.`,
        },
        {
          role: "user",
          content: `Video title: "${title}"\n\nTranscript (first part):\n${truncated}`,
        },
      ],
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(
      `OpenAI API error (${response.status}): ${err.substring(0, 200)}`,
    );
  }

  const data = await response.json();
  const content = data.choices[0]?.message?.content;
  if (!content) return {};

  try {
    const parsed = JSON.parse(content);
    // Sanitize
    return {
      productName:
        typeof parsed.productName === "string"
          ? parsed.productName.trim()
          : null,
      founderName:
        typeof parsed.founderName === "string"
          ? parsed.founderName.trim()
          : null,
      mrr:
        typeof parsed.mrr === "number" && parsed.mrr > 0
          ? Math.round(parsed.mrr)
          : null,
      description:
        typeof parsed.description === "string"
          ? parsed.description.trim().substring(0, 200)
          : null,
      websiteUrl:
        typeof parsed.websiteUrl === "string" &&
        parsed.websiteUrl.startsWith("http")
          ? parsed.websiteUrl.trim()
          : null,
    };
  } catch {
    console.error(
      `  Failed to parse LLM response: ${content.substring(0, 100)}`,
    );
    return {};
  }
}

// ============================================================
// Reparse mode: re-extract from existing Bronze records
// ============================================================

async function reparseExisting() {
  console.log(
    "=== REPARSE MODE: Re-extracting all StarterStory data with LLM ===\n",
  );

  // 1. Delete existing Silver data for StarterStory
  console.log("Cleaning up old Silver data...");
  await executeSql(`
    DELETE FROM public.product_data_points
    WHERE source_id = (SELECT id FROM public.sources WHERE name = 'StarterStory YouTube' LIMIT 1);
  `);
  await executeSql(`
    DELETE FROM public.saas_products
    WHERE slug IN (
      SELECT DISTINCT pt.product_slug FROM public.pipeline_transformations pt
      JOIN public.pipeline_runs pr ON pt.pipeline_run_id = pr.id
      WHERE pr.source_name = 'starterstory'
    );
  `);
  console.log("Old Silver data deleted.");

  // 2. Fetch all Bronze records
  const bronzeRecords = await executeSql(`
    SELECT id, external_id, raw_data, pipeline_run_id
    FROM public.bronze_raw_records
    WHERE source_name = 'starterstory'
    ORDER BY fetched_at
  `);

  console.log(`Found ${bronzeRecords.length} Bronze records to reparse.\n`);

  let reparsed = 0;
  let withProduct = 0;
  let withRevenue = 0;
  let llmErrors = 0;

  for (const record of bronzeRecords) {
    const raw = record.raw_data;
    const videoId = raw.videoId || record.external_id;
    const title = raw.videoTitle || "";

    // Read transcript from cache
    const transcript = readTranscript(videoId);
    if (!transcript) {
      console.log(
        `  [${reparsed + 1}/${bronzeRecords.length}] ${videoId} — no transcript, skipping`,
      );
      reparsed++;
      continue;
    }

    try {
      const parsed = await parseWithLLM(transcript, title);

      // Update Bronze record with new parsed data
      const newRaw = {
        ...raw,
        productName: parsed.productName,
        founderName: parsed.founderName,
        mrr: parsed.mrr,
        description: parsed.description,
        websiteUrl: parsed.websiteUrl,
        llmParsed: true,
      };

      const jsonStr = JSON.stringify(newRaw).replace(/'/g, "''");
      await executeSql(`
        UPDATE public.bronze_raw_records
        SET raw_data = '${jsonStr}'::jsonb,
            checksum = md5('${jsonStr}')
        WHERE id = '${record.id}';
      `);

      if (parsed.productName) withProduct++;
      if (parsed.mrr) withRevenue++;

      console.log(
        `  [${reparsed + 1}/${bronzeRecords.length}] ${parsed.productName || "?"} — $${parsed.mrr || "?"}\/mo — ${parsed.founderName || "?"}`,
      );
    } catch (err) {
      console.error(
        `  [${reparsed + 1}/${bronzeRecords.length}] LLM error for ${videoId}: ${err.message.substring(0, 100)}`,
      );
      llmErrors++;
    }

    reparsed++;

    // Rate limit: ~3 requests/sec to stay well within OpenAI limits
    await new Promise((r) => setTimeout(r, 350));
  }

  console.log(
    `\nReparse complete: ${reparsed} processed, ${withProduct} with product name, ${withRevenue} with revenue, ${llmErrors} errors`,
  );

  // 3. Now re-transform all StarterStory data through Silver/Gold
  // Get the most recent run ID for starterstory (we'll re-use it for transform)
  const runs = await executeSql(`
    SELECT id FROM public.pipeline_runs
    WHERE source_name = 'starterstory'
    ORDER BY started_at DESC
    LIMIT 1
  `);

  if (runs.length > 0) {
    console.log("\nRe-transforming Bronze → Silver...");
    const transformResult = await transformRun(runs[0].id);
    await autoCategorize();
    await refreshGold();
    console.log(
      `Transform: ${transformResult.inserts} inserts, ${transformResult.updates} updates`,
    );
  }

  console.log("\n=== REPARSE COMPLETE ===");
}

// ============================================================
// Main: fetch new videos
// ============================================================

async function main() {
  // Check yt-dlp is available
  try {
    execSync("which yt-dlp", { encoding: "utf-8" });
  } catch {
    console.error("Error: yt-dlp is not installed. Run: pip install yt-dlp");
    process.exit(1);
  }

  if (REPARSE) {
    await reparseExisting();
    return;
  }

  // Step 0: Check which videos are already in Bronze
  console.log("Checking existing records in Bronze...");
  const existingRows = await executeSql(
    `SELECT DISTINCT external_id FROM public.bronze_raw_records WHERE source_name = 'starterstory'`,
  );
  const existingIds = new Set(existingRows.map((r) => r.external_id));
  console.log(`Already in Bronze: ${existingIds.size} videos`);

  // Step 1: List videos
  const allVideos = listVideos();
  const videos = allVideos.filter((v) => !existingIds.has(v.id));
  console.log(
    `New videos to fetch: ${videos.length} (skipping ${allVideos.length - videos.length} existing)`,
  );

  if (videos.length === 0) {
    console.log("\nNo new videos to fetch. Done.");
    process.exit(0);
  }

  const run = await startRun("starterstory");

  try {
    // Step 2: Download transcripts
    downloadTranscripts(videos);

    // Step 3: Parse each transcript with LLM
    console.log("\nParsing transcripts with GPT-4o-mini...");
    const records = [];
    let noTranscript = 0;
    let withRevenue = 0;
    let withProduct = 0;
    let llmErrors = 0;

    for (let i = 0; i < videos.length; i++) {
      const video = videos[i];
      const transcript = readTranscript(video.id);

      if (!transcript) {
        noTranscript++;
        continue;
      }

      let parsed = {};
      try {
        parsed = await parseWithLLM(transcript, video.title);
      } catch (err) {
        console.error(
          `  LLM error for ${video.id}: ${err.message.substring(0, 100)}`,
        );
        llmErrors++;
      }

      if (parsed.mrr) withRevenue++;
      if (parsed.productName) withProduct++;

      records.push({
        externalId: video.id,
        rawData: {
          videoId: video.id,
          videoTitle: video.title,
          videoDuration: video.duration,
          videoUrl: `https://www.youtube.com/watch?v=${video.id}`,
          starterStoryUrl: `https://www.youtube.com/watch?v=${video.id}`,
          productName: parsed.productName || null,
          founderName: parsed.founderName || null,
          mrr: parsed.mrr || null,
          description: parsed.description || null,
          websiteUrl: parsed.websiteUrl || null,
          llmParsed: true,
        },
      });

      console.log(
        `  [${i + 1}/${videos.length}] ${parsed.productName || "?"} — $${parsed.mrr || "?"}\/mo — ${parsed.founderName || "?"}`,
      );

      // Rate limit: ~3 req/sec
      await new Promise((r) => setTimeout(r, 350));
    }

    console.log(`\nParsed ${records.length} videos:`);
    console.log(`  With product name: ${withProduct}`);
    console.log(`  With revenue: ${withRevenue}`);
    console.log(`  No transcript: ${noTranscript}`);
    console.log(`  LLM errors: ${llmErrors}`);

    // Save JSON backup
    const scriptDir = new URL(".", import.meta.url).pathname;
    const repoRoot = scriptDir.replace(/\/scripts\/$/, "");
    try {
      writeFileSync(
        `${repoRoot}/data/starterstory_videos.json`,
        JSON.stringify(
          {
            meta: {
              fetchedAt: new Date().toISOString(),
              totalVideos: videos.length,
              parsed: records.length,
              withRevenue,
              withProduct,
              noTranscript,
              llmErrors,
            },
            videos: records.map((r) => r.rawData),
          },
          null,
          2,
        ),
      );
      console.log("Saved JSON backup: data/starterstory_videos.json");
    } catch {
      console.log("Skipped JSON backup");
    }

    // Step 4: Load into Bronze
    const bronzeResult = await loadBronzeRecords(
      run.runId,
      "starterstory",
      records,
    );

    // Step 5: Transform + Gold
    const transformResult = await transformRun(run.runId);
    await autoCategorize();
    await refreshGold();

    await completeRun(run.runId, {
      fetched: records.length,
      loaded: bronzeResult.loaded,
      errors: bronzeResult.errors + transformResult.errors,
      metadata: {
        totalVideos: videos.length,
        parsed: records.length,
        withRevenue,
        withProduct,
        noTranscript,
        llmErrors,
        transformInserts: transformResult.inserts,
        transformUpdates: transformResult.updates,
        transformSkips: transformResult.skips,
      },
    });

    console.log("\n=== COMPLETE ===");
    console.log(
      `Bronze: ${bronzeResult.loaded} loaded, ${bronzeResult.errors} errors`,
    );
    console.log(
      `Silver: ${transformResult.inserts} inserts, ${transformResult.updates} updates`,
    );

    // Top 10 by revenue
    const sorted = records
      .filter((r) => r.rawData.mrr)
      .sort((a, b) => b.rawData.mrr - a.rawData.mrr);
    console.log(`\nTop 10 by MRR:`);
    sorted.slice(0, 10).forEach((r, i) => {
      console.log(
        `  ${i + 1}. ${r.rawData.productName || "?"} by ${r.rawData.founderName || "?"} — $${r.rawData.mrr.toLocaleString()}/mo`,
      );
    });
  } catch (err) {
    await failRun(run.runId, err.message);
    throw err;
  }
}

main().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
