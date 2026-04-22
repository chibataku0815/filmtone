import { EventEmitter } from "node:events";
import { describe, expect, it } from "vitest";

import {
  createVideoExportPipeController,
  describeVideoExportPipeUnavailable,
} from "./video-export-stdin";

class MockWritable extends EventEmitter {
  writable = true;
  writeReturnValue = true;
  writes: Buffer[] = [];

  write(
    chunk: string | Uint8Array,
    _encoding?:
      | BufferEncoding
      | ((err?: Error | null | undefined) => void),
    _callback?: (err?: Error | null | undefined) => void,
  ): boolean {
    this.writes.push(
      typeof chunk === "string" ? Buffer.from(chunk) : Buffer.from(chunk),
    );
    return this.writeReturnValue;
  }

  end(): this {
    this.writable = false;
    return this;
  }

  destroy(): void {
    this.writable = false;
  }
}

class MockChild extends EventEmitter {
  constructor(public stdin: MockWritable | null) {
    super();
  }
}

describe("createVideoExportPipeController", () => {
  it("captures async stdin EPIPE without crashing and rejects the next write", async () => {
    const stdin = new MockWritable();
    const child = new MockChild(stdin);
    const controller = createVideoExportPipeController(child);

    await controller.write(Buffer.from([1, 2, 3]));

    expect(() => {
      stdin.emit("error", new Error("write EPIPE"));
    }).not.toThrow();

    await expect(controller.write(Buffer.from([4, 5, 6]))).rejects.toThrow(
      "write EPIPE",
    );
  });

  it("stores a pending-drain error and surfaces it on the next public wait", async () => {
    const stdin = new MockWritable();
    stdin.writeReturnValue = false;
    const child = new MockChild(stdin);
    const controller = createVideoExportPipeController(child);

    await controller.write(Buffer.from([1, 2, 3]));
    stdin.emit("error", new Error("write EPIPE"));

    await expect(controller.waitForPendingDrain()).rejects.toThrow(
      "write EPIPE",
    );
  });

  it("completes pending drain and close after finish is requested", async () => {
    const stdin = new MockWritable();
    stdin.writeReturnValue = false;
    const child = new MockChild(stdin);
    const controller = createVideoExportPipeController(child);

    await controller.write(Buffer.from([1, 2, 3]));

    const pendingDrain = controller.waitForPendingDrain();
    stdin.emit("drain");
    await expect(pendingDrain).resolves.toBeUndefined();

    controller.markFinishing();
    const closePromise = controller.waitForClose();
    child.emit("close", 0, null);

    await expect(closePromise).resolves.toMatchObject({
      code: 0,
      signal: null,
    });
  });

  it("remembers close before finish so waitForClose does not hang", async () => {
    const stdin = new MockWritable();
    const child = new MockChild(stdin);
    const controller = createVideoExportPipeController(child);

    child.emit("close", 1, null);

    await expect(controller.waitForClose()).resolves.toMatchObject({
      code: 1,
      signal: null,
    });
    await expect(controller.write(Buffer.from([1]))).rejects.toThrow(
      "ffmpeg exited before finish",
    );
  });

  it("describeVideoExportPipeUnavailable prefers a stored failure", () => {
    const stdin = new MockWritable();
    const child = new MockChild(stdin);
    const controller = createVideoExportPipeController(child);

    stdin.emit("error", new Error("write EPIPE"));

    expect(
      describeVideoExportPipeUnavailable({
        stdin,
        controller,
      }),
    ).toContain("write EPIPE");
  });

  it("describeVideoExportPipeUnavailable falls back to child exit info", () => {
    const stdin = new MockWritable();
    stdin.destroy();
    const child = new MockChild(stdin);
    const controller = createVideoExportPipeController(child);

    expect(
      describeVideoExportPipeUnavailable({
        stdin,
        controller,
        childExitCode: 1,
      }),
    ).toBe("ffmpeg exited before finish (code=1)");
  });

  it("describeVideoExportPipeUnavailable reports closed stdin when exit details are pending", () => {
    const stdin = new MockWritable();
    stdin.destroy();
    const child = new MockChild(stdin);
    const controller = createVideoExportPipeController(child);

    expect(
      describeVideoExportPipeUnavailable({
        stdin,
        controller,
      }),
    ).toBe("ffmpeg stdin はすでに閉じています");
  });
});
