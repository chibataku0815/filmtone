import { describe, expect, it } from "vitest";

import {
  guessVideoContentType,
  parseHttpByteRange,
} from "./video-src-protocol";

describe("video-src-protocol", () => {
  it("parses open-ended and suffix byte ranges", () => {
    expect(parseHttpByteRange("bytes=100-", 1000)).toEqual({
      start: 100,
      end: 999,
    });
    expect(parseHttpByteRange("bytes=-200", 1000)).toEqual({
      start: 800,
      end: 999,
    });
  });

  it("rejects invalid ranges", () => {
    expect(parseHttpByteRange("bytes=500-100", 1000)).toBeNull();
    expect(parseHttpByteRange("bytes=1000-", 1000)).toBeNull();
    expect(parseHttpByteRange(null, 1000)).toBeNull();
  });

  it("guesses content types for supported video extensions", () => {
    expect(guessVideoContentType("/tmp/clip.mov")).toBe("video/quicktime");
    expect(guessVideoContentType("/tmp/clip.webm")).toBe("video/webm");
    expect(guessVideoContentType("/tmp/clip.mkv")).toBe("video/x-matroska");
    expect(guessVideoContentType("/tmp/clip.mp4")).toBe("video/mp4");
  });
});
