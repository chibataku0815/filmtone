import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type CallToolResult,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";
import {
  AutomationClient,
  BatchJobManager,
  type AnswerContextRequest,
  type BatchPlanRequest,
  type InspectSourcesRequest,
} from "./automation-client.js";

const jsonObjectSchema = {
  type: "object",
  additionalProperties: true,
} as const;

export const filmtoneTools: Tool[] = [
  {
    name: "inspect_sources",
    description: "Inspect media paths or folders for Filmtone batch/Q&A context. Returns metadata only; it does not analyze frame content.",
    inputSchema: {
      type: "object",
      required: ["paths"],
      properties: {
        paths: { type: "array", items: { type: "string" } },
        recursive: { type: "boolean" },
      },
      additionalProperties: false,
    },
  },
  {
    name: "prepare_filmtone_answer_context",
    description: "Prepare facts and limits for Codex to answer abstract Filmtone state/export questions. The tool does not call an LLM.",
    inputSchema: {
      type: "object",
      required: ["question"],
      properties: {
        question: { type: "string" },
        paths: { type: "array", items: { type: "string" } },
        recursive: { type: "boolean" },
      },
      additionalProperties: false,
    },
  },
  {
    name: "preview_batch_job",
    description: "Dry-run a Filmtone video batch export plan. Must be called before start_batch_job.",
    inputSchema: {
      type: "object",
      required: ["paths"],
      properties: {
        paths: { type: "array", items: { type: "string" } },
        recursive: { type: "boolean" },
        outputDirectory: { type: "string" },
        look: { type: "string" },
        strength: { type: "number", minimum: 0, maximum: 1 },
        profiles: {
          description: "v1 supports social1080 and archiveH264 only. ProRes, HEVC, and cloud upload are not supported yet.",
          type: "array",
          items: { type: "string", enum: ["social1080", "archiveH264"] },
        },
        overwrite: { type: "boolean" },
        continueOnError: { type: "boolean" },
      },
      additionalProperties: false,
    },
  },
  {
    name: "start_batch_job",
    description: "Start a previously previewed Filmtone video batch export job.",
    inputSchema: {
      type: "object",
      required: ["previewId"],
      properties: {
        previewId: { type: "string" },
        overwrite: { type: "boolean" },
      },
      additionalProperties: false,
    },
  },
  {
    name: "get_batch_job_status",
    description: "Return the current status and events for a running or completed Filmtone batch job.",
    inputSchema: {
      type: "object",
      required: ["jobId"],
      properties: {
        jobId: { type: "string" },
      },
      additionalProperties: false,
    },
  },
  {
    name: "cancel_batch_job",
    description: "Cancel a running Filmtone batch export job.",
    inputSchema: {
      type: "object",
      required: ["jobId"],
      properties: {
        jobId: { type: "string" },
      },
      additionalProperties: false,
    },
  },
  {
    name: "summarize_batch_job",
    description: "Summarize a Filmtone batch job for Codex after completion or failure.",
    inputSchema: {
      type: "object",
      required: ["jobId"],
      properties: {
        jobId: { type: "string" },
      },
      additionalProperties: false,
    },
  },
];

export function createFilmtoneMcpServer(
  manager = new BatchJobManager(new AutomationClient())
): Server {
  const server = new Server(
    {
      name: "filmtone-codex-mcp",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: filmtoneTools,
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args = {} } = request.params;
    try {
      switch (name) {
        case "inspect_sources":
          return jsonResult(manager.client.inspectSources(args as InspectSourcesRequest));
        case "prepare_filmtone_answer_context":
          return jsonResult(manager.client.answerContext(args as AnswerContextRequest));
        case "preview_batch_job":
          return jsonResult(manager.createPreview(args as BatchPlanRequest));
        case "start_batch_job": {
          const payload = args as { previewId?: string; overwrite?: boolean };
          if (!payload.previewId) throw new Error("previewId is required.");
          return jsonResult(manager.start(payload.previewId, payload.overwrite));
        }
        case "get_batch_job_status": {
          const payload = args as { jobId?: string };
          if (!payload.jobId) throw new Error("jobId is required.");
          return jsonResult(manager.status(payload.jobId));
        }
        case "cancel_batch_job": {
          const payload = args as { jobId?: string };
          if (!payload.jobId) throw new Error("jobId is required.");
          return jsonResult(manager.cancel(payload.jobId));
        }
        case "summarize_batch_job": {
          const payload = args as { jobId?: string };
          if (!payload.jobId) throw new Error("jobId is required.");
          return jsonResult(manager.summarize(payload.jobId));
        }
        default:
          throw new Error(`Unknown Filmtone MCP tool: ${name}`);
      }
    } catch (error) {
      return jsonResult({
        error: error instanceof Error ? error.message : String(error),
      }, true);
    }
  });

  return server;
}

function jsonResult(value: unknown, isError = false): CallToolResult {
  return {
    isError,
    content: [
      {
        type: "text",
        text: JSON.stringify(value ?? jsonObjectSchema, null, 2),
      },
    ],
  };
}

if (import.meta.main) {
  const server = createFilmtoneMcpServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}
