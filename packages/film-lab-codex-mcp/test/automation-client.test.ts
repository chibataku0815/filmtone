import { afterEach, expect, test } from "bun:test";
import { chmodSync, existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { AutomationClient, BatchJobManager } from "../src/automation-client.js";
import { filmtoneTools } from "../src/index.js";

const tempDirs: string[] = [];

afterEach(() => {
  while (tempDirs.length > 0) {
    rmSync(tempDirs.pop()!, { recursive: true, force: true });
  }
});

test("tools expose workflow operations only", () => {
  const names = filmtoneTools.map((tool) => tool.name);
  expect(names).toEqual([
    "inspect_sources",
    "prepare_filmtone_answer_context",
    "preview_batch_job",
    "start_batch_job",
    "get_batch_job_status",
    "cancel_batch_job",
    "summarize_batch_job",
  ]);
  expect(names.some((name) => name.includes("set_control"))).toBe(false);
});

test("start requires a preview id", () => {
  const manager = new BatchJobManager(new AutomationClient({ skipBuild: true }));
  expect(() => manager.start("missing-preview")).toThrow("previewId is required");
});

test("unsupported export profiles return a user-facing error before CLI decode", () => {
  const dir = makeTempDir();
  const client = new AutomationClient({
    repoRoot: dir,
    cliPath: join(dir, "missing-filmtone-cli"),
    skipBuild: true,
  });

  expect(() => client.previewBatch({
    paths: [dir],
    profiles: ["proRes422"] as never,
  })).toThrow("ProRes, HEVC, and cloud upload are not supported yet");
});

test("missing automation binary can be built on demand", () => {
  const dir = makeTempDir();
  const cliPath = join(dir, "mock-filmtone-cli");
  const buildScript = join(dir, "build.sh");
  writeExecutable(buildScript, `#!/usr/bin/env bash
cat > "${cliPath}" <<'SCRIPT'
#!/usr/bin/env bash
echo '{"ok":true,"result":{"sources":[],"warnings":[],"analysisLimits":{"answerMode":"state-export-advice"}}}'
SCRIPT
chmod +x "${cliPath}"
`);

  const client = new AutomationClient({
    repoRoot: dir,
    cliPath,
    buildScript,
  });
  expect(existsSync(cliPath)).toBe(false);
  client.ensureBuilt();
  expect(existsSync(cliPath)).toBe(true);
  expect(client.inspectSources({ paths: [dir] })).toEqual({
    sources: [],
    warnings: [],
    analysisLimits: {
      answerMode: "state-export-advice",
    },
  });
});

test("job manager parses JSONL batch progress", async () => {
  const dir = makeTempDir();
  const cliPath = join(dir, "mock-filmtone-cli.cjs");
  writeExecutable(cliPath, `#!/usr/bin/env node
const fs = require("node:fs");
const input = JSON.parse(fs.readFileSync(0, "utf8"));
if (input.command === "previewBatch") {
  console.log(JSON.stringify({ ok: true, result: {
    plan: {
      createdAtIso: "2026-05-15T00:00:00.000Z",
      look: { label: "Stone", presetName: "reset", presetStrength: 1, lookSlug: "filmtone-creative-pack-01-stone" },
      profiles: ["social1080"],
      options: { overwrite: false, continueOnError: true, recursive: false },
      items: [{ sourcePath: "/tmp/in.mov", outputPath: "/tmp/out.mp4", profile: "social1080", status: "ready", warnings: [] }],
      warnings: []
    },
    warnings: [],
    analysisLimits: { answerMode: "state-export-advice" }
  }}));
} else if (input.command === "runBatch") {
  console.log(JSON.stringify({ event: "jobStarted", payload: { totalItems: 1, readyItems: 1 } }));
  console.log(JSON.stringify({ event: "itemProgress", payload: { processedFrames: 1, estimatedTotalFrames: 1, normalized: 1 } }));
  console.log(JSON.stringify({ event: "jobFinished", payload: { succeeded: 1, failed: 0, skipped: 0 } }));
}
`);
  const manager = new BatchJobManager(new AutomationClient({
    repoRoot: dir,
    cliPath,
    skipBuild: true,
  }));

  const { previewId } = manager.createPreview({ paths: [dir] });
  const started = manager.start(previewId);
  expect(started.status).toBe("running");
  await new Promise((resolve) => setTimeout(resolve, 100));
  const summary = manager.summarize(started.jobId) as { status: string; eventCount: number };
  expect(summary.status).toBe("completed");
  expect(summary.eventCount).toBe(3);
});

function makeTempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "filmtone-mcp-test-"));
  tempDirs.push(dir);
  return dir;
}

function writeExecutable(path: string, body: string): void {
  writeFileSync(path, body);
  chmodSync(path, 0o755);
}
