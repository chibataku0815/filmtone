import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawn, spawnSync, type ChildProcessWithoutNullStreams } from "node:child_process";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";

export type ExportProfile = "social1080" | "archiveH264";

const supportedExportProfiles: ExportProfile[] = ["social1080", "archiveH264"];

export function validateBatchPlanRequest(request: BatchPlanRequest): void {
  const profiles = (request as { profiles?: unknown }).profiles;
  if (profiles === undefined) return;
  if (!Array.isArray(profiles)) {
    throw new Error(
      "Export profiles must be an array. v1 supports social1080 and archiveH264 only. ProRes, HEVC, and cloud upload are not supported yet."
    );
  }
  const unsupported = profiles.filter((profile) => {
    return typeof profile !== "string"
      || !supportedExportProfiles.includes(profile as ExportProfile);
  });
  if (unsupported.length === 0) return;
  throw new Error([
    `Unsupported export profile${unsupported.length === 1 ? "" : "s"}: ${unsupported.map(String).join(", ")}.`,
    "v1 supports social1080 and archiveH264 only.",
    "ProRes, HEVC, and cloud upload are not supported yet.",
  ].join(" "));
}

export type InspectSourcesRequest = {
  paths: string[];
  recursive?: boolean;
};

export type AnswerContextRequest = {
  question: string;
  paths?: string[];
  recursive?: boolean;
};

export type BatchPlanRequest = {
  paths: string[];
  recursive?: boolean;
  outputDirectory?: string;
  look?: string;
  strength?: number;
  profiles?: ExportProfile[];
  overwrite?: boolean;
  continueOnError?: boolean;
};

export type BatchPlan = {
  createdAtIso: string;
  look: {
    requested?: string;
    label: string;
    presetName: string;
    presetStrength: number;
    lookSlug?: string;
  };
  profiles: ExportProfile[];
  options: {
    overwrite: boolean;
    continueOnError: boolean;
    recursive: boolean;
  };
  items: Array<{
    sourcePath: string;
    outputPath: string;
    profile: ExportProfile;
    status: "ready" | "skipped" | "blocked";
    reason?: string;
    warnings: string[];
  }>;
  warnings: string[];
};

export type AutomationClientOptions = {
  repoRoot?: string;
  cliPath?: string;
  buildScript?: string;
  lutRoot?: string;
  skipBuild?: boolean;
};

type AutomationSuccess<T> = {
  ok: true;
  result: T;
};

type AutomationFailure = {
  ok: false;
  error: {
    code: string;
    message: string;
  };
};

type AutomationResponse<T> = AutomationSuccess<T> | AutomationFailure;

export class AutomationClient {
  readonly repoRoot: string;
  readonly cliPath: string;
  readonly buildScript: string;
  readonly lutRoot: string;
  readonly skipBuild: boolean;

  constructor(options: AutomationClientOptions = {}) {
    this.repoRoot = options.repoRoot
      ?? process.env.FILMTONE_REPO_ROOT
      ?? resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
    this.cliPath = options.cliPath
      ?? process.env.FILMTONE_AUTOMATION_CLI
      ?? resolve(this.repoRoot, "apps/filmtone-desktop-macos/build/automation/FilmtoneAutomationCLI");
    this.buildScript = options.buildScript
      ?? resolve(this.repoRoot, "scripts/build-filmtone-automation.sh");
    this.lutRoot = options.lutRoot
      ?? resolve(this.repoRoot, "apps/filmtone-desktop-macos/FilmtoneDesktop/Resources/CreativeLuts");
    this.skipBuild = options.skipBuild ?? process.env.FILMTONE_AUTOMATION_SKIP_BUILD === "1";
  }

  ensureBuilt(): void {
    if (existsSync(this.cliPath)) return;
    if (this.skipBuild) {
      throw new Error(`Filmtone automation CLI is missing: ${this.cliPath}`);
    }
    const result = spawnSync(this.buildScript, {
      cwd: this.repoRoot,
      encoding: "utf8",
      env: this.env(),
    });
    if (result.status !== 0) {
      throw new Error([
        "Could not build Filmtone automation CLI.",
        result.stdout.trim(),
        result.stderr.trim(),
      ].filter(Boolean).join("\n"));
    }
    if (!existsSync(this.cliPath)) {
      throw new Error(`Build finished but CLI is still missing: ${this.cliPath}`);
    }
  }

  inspectSources(request: InspectSourcesRequest): unknown {
    return this.runJSON("inspectSources", { inspectSources: request });
  }

  answerContext(request: AnswerContextRequest): unknown {
    return this.runJSON("answerContext", { answerContext: request });
  }

  previewBatch(request: BatchPlanRequest): { plan: BatchPlan; warnings: string[]; analysisLimits: unknown } {
    validateBatchPlanRequest(request);
    return this.runJSON("previewBatch", { previewBatch: request }) as {
      plan: BatchPlan;
      warnings: string[];
      analysisLimits: unknown;
    };
  }

  spawnRunBatch(plan: BatchPlan, overwrite?: boolean): ChildProcessWithoutNullStreams {
    this.ensureBuilt();
    const child = spawn(this.cliPath, {
      cwd: this.repoRoot,
      env: this.env(),
      stdio: ["pipe", "pipe", "pipe"],
    });
    child.stdin.end(JSON.stringify({
      command: "runBatch",
      runBatch: {
        plan,
        overwrite,
      },
    }));
    return child;
  }

  private runJSON(command: string, payload: Record<string, unknown>): unknown {
    this.ensureBuilt();
    const result = spawnSync(this.cliPath, {
      cwd: this.repoRoot,
      input: JSON.stringify({ command, ...payload }),
      encoding: "utf8",
      env: this.env(),
    });
    if (result.status !== 0 && !result.stdout.trim()) {
      throw new Error(result.stderr.trim() || `Filmtone automation command failed: ${command}`);
    }
    const parsed = JSON.parse(result.stdout) as AutomationResponse<unknown>;
    if (!parsed.ok) {
      throw new Error(parsed.error.message);
    }
    return parsed.result;
  }

  private env(): NodeJS.ProcessEnv {
    return {
      ...process.env,
      FILMTONE_REPO_ROOT: this.repoRoot,
      FILMTONE_CREATIVE_LUT_ROOT: this.lutRoot,
    };
  }
}

export type JobStatus = "running" | "completed" | "failed" | "cancelled";

export type BatchJobRecord = {
  id: string;
  status: JobStatus;
  startedAtIso: string;
  finishedAtIso?: string;
  events: unknown[];
  stderr: string;
  process?: ChildProcessWithoutNullStreams;
};

export class BatchJobManager {
  private readonly previews = new Map<string, BatchPlan>();
  private readonly jobs = new Map<string, BatchJobRecord>();

  constructor(readonly client: AutomationClient) {}

  createPreview(request: BatchPlanRequest): { previewId: string; preview: unknown } {
    const preview = this.client.previewBatch(request);
    const previewId = randomUUID();
    this.previews.set(previewId, preview.plan);
    return {
      previewId,
      preview,
    };
  }

  start(previewId: string, overwrite?: boolean): { jobId: string; status: JobStatus } {
    const plan = this.previews.get(previewId);
    if (!plan) {
      throw new Error("previewId is required and must come from preview_batch_job.");
    }
    const jobId = randomUUID();
    const record: BatchJobRecord = {
      id: jobId,
      status: "running",
      startedAtIso: new Date().toISOString(),
      events: [],
      stderr: "",
    };
    const child = this.client.spawnRunBatch(plan, overwrite);
    record.process = child;
    this.jobs.set(jobId, record);

    let stdoutBuffer = "";
    child.stdout.on("data", (chunk: Buffer) => {
      stdoutBuffer += chunk.toString("utf8");
      const lines = stdoutBuffer.split(/\r?\n/);
      stdoutBuffer = lines.pop() ?? "";
      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const event = JSON.parse(line) as { event?: string };
          record.events.push(event);
          if (event.event === "jobFinished") {
            record.status = "completed";
          }
        } catch {
          record.events.push({ event: "unparsed", line });
        }
      }
    });
    child.stderr.on("data", (chunk: Buffer) => {
      record.stderr += chunk.toString("utf8");
    });
    child.on("close", (code) => {
      record.finishedAtIso = new Date().toISOString();
      if (record.status === "cancelled") return;
      if (record.status !== "completed" || code !== 0) {
        record.status = "failed";
      }
    });
    return { jobId, status: record.status };
  }

  status(jobId: string): BatchJobRecord {
    const record = this.jobs.get(jobId);
    if (!record) throw new Error(`Unknown batch job: ${jobId}`);
    return sanitizeJob(record);
  }

  cancel(jobId: string): BatchJobRecord {
    const record = this.jobs.get(jobId);
    if (!record) throw new Error(`Unknown batch job: ${jobId}`);
    if (record.status === "running") {
      record.status = "cancelled";
      record.finishedAtIso = new Date().toISOString();
      record.process?.kill("SIGTERM");
    }
    return sanitizeJob(record);
  }

  summarize(jobId: string): unknown {
    const record = this.status(jobId);
    const last = record.events.at(-1);
    return {
      jobId,
      status: record.status,
      startedAtIso: record.startedAtIso,
      finishedAtIso: record.finishedAtIso,
      eventCount: record.events.length,
      lastEvent: last,
      stderr: record.stderr.trim(),
    };
  }
}

function sanitizeJob(record: BatchJobRecord): BatchJobRecord {
  const { process: _process, ...rest } = record;
  return { ...rest };
}
