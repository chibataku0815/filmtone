# Filmtone Metadata-Driven Export Quality — PQ → SDR BT.709 Filter Chain Design

Last updated: 2026-04-24
Authoring context: Claude Code desktop session (Stream B / S-5, design only)
Primary repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
Scope: `apps/desktop-film-lab-batch` HDR preparation policy, PQ branch only.

> This is a **design document**. It specifies the canonical filter chain, algorithm choice, capability branching, failure modes, and integration points so that the next implementation session (S-6) can wire the filter chain with typing alone, no additional design decisions. **No pixel-changing code** is introduced by this document.

## 1. Purpose and scope

### 1.1 What this solves

Filmtone Desktop currently treats HDR10 / BT.2100 PQ source material the same way as SDR BT.709 sources when the local `ffmpeg` build lacks both `zscale` and `libplacebo`: `deriveDesktopHdrPreparationPolicy` returns `strategy: "defer-unknown"` / `reason: "ffmpeg-missing-hdr-filters"` (see `electron/video-export-source-metadata.ts:306-332`). Pixels flow through unchanged. Players then either apply an implicit tone map (which differs across platforms), crush the highlights, or produce washed-out color depending on the downstream path.

This document specifies the **canonical ffmpeg filter chain** that must be wired — once capability and fixtures are in place — to deterministically convert a PQ (SMPTE ST 2084 / BT.2100 PQ) source into a BT.709 limited-range SDR mezzanine before the WebGL / WebGPU render path sees it.

### 1.2 What this does NOT cover

| Out of scope | Handled where |
|---|---|
| HLG (`arib-std-b67`) → SDR BT.709 | Stream C design doc (separate session) |
| HDR10+ dynamic metadata per-frame adaptation | See §7 — open question; v1 uses static tonemap |
| Dolby Vision profiles (5 / 7 / 8.1) | Out of Filmtone v1 scope |
| User creative controls (strength / knee / target nits UI) | Out of v1; recipe is fixed |
| Camera profile / input-LUT selection | Explicitly prohibited by P2-B plan guardrails |
| Export FPS changes | Frozen at 24 fps CFR per plan §5 P1-B |
| Bundled ffmpeg packaging for end users | Out of S-5; tracked under inventory §3 Option D |

### 1.3 Preconditions

This design is **implementable** only when all three of these are true:

1. Local `ffmpeg` build has `zscale` available (preferred) or `libplacebo` available (alternative). Current dev machine has **neither** — see inventory doc §2.2 and session handoff §4.2.
2. At least one PQ fixture exists under `apps/desktop-film-lab-batch/fixtures/video/hdr/generic-pq-1s-<hash>.mp4` with its `<basename>.ffprobe.json` oracle.
3. `deriveDesktopHdrPreparationPolicy` returns `strategy: "prepare-sdr-mezzanine"` / `reason: "source-is-hdr-pq"` for that fixture (which it will, once capabilities flip — today's capability gate downgrades to `defer-unknown`).

If any of the three is missing, the next session must not wire pixel-changing code. It should continue to seed fixtures, upgrade ffmpeg, or add integration tests — not apply this recipe blindly.

## 2. Target filter graph (canonical recipe)

### 2.1 Primary recipe — zscale + tonemap (CPU)

The canonical CPU recipe that works on any ffmpeg built with `libzimg`:

```text
zscale=tin=smpte2084:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=100,
format=gbrpf32le,
zscale=p=709,
tonemap=tonemap=hable:desat=0,
zscale=t=709:m=709:r=tv,
format=yuv420p
```

As a single `-vf` argument (comma-separated, escape colons inside -filter_complex if used):

```text
-vf "zscale=tin=smpte2084:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=100,format=gbrpf32le,zscale=p=709,tonemap=tonemap=hable:desat=0,zscale=t=709:m=709:r=tv,format=yuv420p"
```

### 2.2 Stage-by-stage annotation

| Stage | Filter | Purpose | What breaks if wrong |
|---|---|---|---|
| 1 | `zscale=tin=smpte2084:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=100` | **Tag + linearize.** Tells zscale the input is BT.2020/PQ TV-range (in case tags are missing from container — belt-and-suspenders), then inverts the PQ EOTF into linear light, scaling PQ's 10,000-nit coding range to an SDR-referenced nominal of 100 cd/m². | Wrong `tin` → crushed highlights or green tint. Wrong `rin` → clipped blacks or washed-out output. Missing `npl` → output is either near-black (if ffmpeg assumes a high default peak) or clipped (if low). |
| 2 | `format=gbrpf32le` | Forces 32-bit float GBR planar. `tonemap` requires single-precision float linear light (see `tonemap` filter docs). | `tonemap` errors out or silently produces banding if fed integer YUV. |
| 3 | `zscale=p=709` | **Gamut convert.** Converts primaries from BT.2020 to BT.709 *while still in linear float*, so out-of-gamut saturation is preserved as negative / >1 values rather than clipped. | Skipping this → tonemap runs in BT.2020 primaries, then the final zscale bakes BT.709 tags on a BT.2020-primaries image → oversaturated, out-of-gamut clipping on the final encoder. |
| 4 | `tonemap=tonemap=hable:desat=0` | **Compress dynamic range.** Maps linear-light values >1.0 (superwhites) back into the 0–1 SDR range. `desat=0` means: do not additionally desaturate on top of the tone curve — the upstream `zscale=p=709` already handled gamut. | `desat` too high → washed out. Wrong algorithm → see §3. |
| 5 | `zscale=t=709:m=709:r=tv` | **Encode transfer + matrix + range.** Applies BT.1886 / BT.709 gamma on the compressed linear signal, converts to BT.709 matrix (Y'CbCr 709), and TV (limited) range. | Missing `r=tv` → full-range YUV tagged as limited → grey blacks / clipped whites on H.264 players. Missing `m=709` → defaults leak BT.2020 matrix tags into the limited-range 8-bit output. |
| 6 | `format=yuv420p` | Output pixel format the H.264 / `h264_videotoolbox` encoder path expects. | Encoder rejects or silently promotes to yuv422p with parity issues on some builds. |

### 2.3 Alternate recipe — libplacebo (GPU-assisted, single filter)

On ffmpeg builds with `libplacebo` (Vulkan-backed), the entire chain collapses into one filter invocation:

```text
-vf "libplacebo=tonemapping=bt.2390:colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv:format=yuv420p"
```

Notes:

- libplacebo **reads source HDR tags directly** from the demuxer (mastering display max luminance, MaxCLL, MaxFALL) if present, and adapts the tone curve using its built-in frame analysis. No explicit `npl` parameter is required for HDR10 sources.
- libplacebo supports BT.2390 EETF natively (hermite spline roll-off with linear segment) — the canonical HDR10 → SDR tone curve published by ITU-R.
- Vulkan backend is required; on macOS Homebrew bottles this is linked via MoltenVK when available.
- **Dynamic metadata (HDR10+ ST 2094-40)**: libplacebo ≥ 5.x reads HDR10+ metadata when present and produces per-frame tone adaptation. `zscale` + `tonemap` ignore dynamic metadata entirely — see §7.

### 2.4 Signal range interaction with policy

Source signal range for PQ (limited `tv` vs full-range `pc`) must be read from `SourceColorMetadata.colorRange` and threaded into the zscale `rin=` parameter:

| `sourceVideoMetadata.color.colorRange` | zscale `rin=` | Notes |
|---|---|---|
| `"tv"` (typical HDR10 from cameras / broadcast) | `tv` | Default path. iPhone ProRes LOG HDR10 = tv. |
| `"pc"` (full-range) | `pc` | Rare for HDR10; some synthetic sources only. |
| `null` | `tv` | BT.2100 PQ defaults to limited per ITU-R. Treat `null` as `tv`. |

The `rin=` override is only necessary if we suspect container tags are wrong. With PQ this is rarely the case, but the recipe above threads the value through explicitly so that a `pc`-range fixture does not silently produce an illegal-range intermediate.

## 3. Algorithm choice

### 3.1 Recommendation

- **Default when only `zscale`+`tonemap` available**: `tonemap=hable:desat=0`.
- **Default when `libplacebo` available**: `libplacebo=tonemapping=bt.2390`.
- **Prefer libplacebo** when both are present. See §4.

### 3.2 Rationale (with citations, access date 2026-04-24)

The `tonemap` filter exposes three algorithms relevant to HDR10 → SDR:

| Algorithm | Curve shape | Behavior | Source |
|---|---|---|---|
| `hable` | Filmic S-curve (the Uncharted 2 curve) | Preserves shadow and highlight detail; slight overall darkening. Most commonly cited as "in-line with original SDR source" in comparison tests. | BinaryTides 2023 guide, Jellyfin #415 thread (2018–2023) |
| `mobius` | Generalized Reinhard with linear mid-section | Less highlight compression; colors can look oversaturated relative to the source. | FFmpeg `tonemap` filter docs |
| `reinhard` | Basic Reinhard `x / (x+1)` | Simplest; produces brighter but flatter output. Historically Jellyfin's default, but known to wash out saturated highlights. | Jellyfin #415 |
| `clip` (in `tonemap`) | Hard clip at 1.0 | Only useful if source is already near-SDR peak. Loses all highlight detail. | FFmpeg `tonemap` filter docs |

The Filmtone style target is Moving Postcard — we preserve texture at both ends (CLAUDE.md "feedback_film_mode_default_on"). `hable` is the best fit: it keeps specular highlights readable and does not wash out the image.

`libplacebo`'s `bt.2390` implements the ITU-R BT.2390 EETF — the canonical recommendation from ITU for HDR10 → SDR conversion. It uses a hermite-spline roll-off with a linear segment and is explicitly designed to respect the `MaxCLL` / mastering display metadata present in HDR10. When libplacebo is available, this algorithm is preferred over `hable` because it is standards-driven rather than filmic-aesthetic-driven, and it handles per-source peak luminance automatically via metadata reading.

### 3.3 `desat` parameter

`desat` in the `tonemap` filter is an **additional** desaturation factor applied during the curve. Since we already perform gamut conversion BT.2020 → BT.709 in a prior zscale stage (§2.2 step 3), setting `desat=0` avoids double-desaturating. Common community default is `0` (Jellyfin hable recipe, BinaryTides guide). We adopt `desat=0` as the fixed default.

If a future fixture shows saturated highlights clipping into the BT.709 gamut, `desat` can be raised to `2` (the ffmpeg documentation's example) — but only after a side-by-side fixture comparison confirms the change. **Do not change the default without fixture evidence.**

### 3.4 `npl` parameter

`npl` (nominal peak luminance) tells zscale what real-world luminance the linear output represents after the inverse PQ EOTF. Setting `npl=100` says: "treat 100 cd/m² as full scale (1.0)." For HDR10 content mastered to 1000 nits or 4000 nits, `npl=100` means linear values of 10.0 or 40.0 respectively are possible pre-tonemap — exactly what `tonemap=hable` is designed to compress.

Do not set `npl` higher than 100 unless the target display is an HDR display (it is not — we target SDR BT.709). Do not set `npl` lower than 100 (this would clip legal SDR highlights before tonemap sees them).

## 4. Capability-aware branching

The new `FFmpegHdrCapabilities` shape (defined in `electron/video-export-source-metadata.ts:57-62`) provides a four-cell truth table:

| `hasZscale` | `hasLibplacebo` | Strategy for `hdr-pq` | Recipe |
|---|---|---|---|
| true | false | `prepare-sdr-mezzanine` | §2.1 zscale + tonemap recipe |
| false | true | `prepare-sdr-mezzanine` | §2.3 libplacebo single-filter recipe |
| true | true | `prepare-sdr-mezzanine` | **§2.3 libplacebo** (see below) |
| false | false | `defer-unknown` / `ffmpeg-missing-hdr-filters` | Pixels unchanged — current behavior |

### 4.1 Tiebreaker: prefer libplacebo when both are present

Rationale:

1. libplacebo implements the standards-conforming BT.2390 EETF; `tonemap=hable` is an aesthetic filmic curve.
2. libplacebo reads HDR10 static metadata (`MaxCLL`, mastering display) automatically and adapts peak luminance; the zscale recipe hard-codes `npl=100` and ignores mastering display metadata.
3. libplacebo's frame-analysis path produces better results on mixed-content clips (dark interior cut to bright exterior) than a global static curve.
4. Single-filter invocation reduces the surface area for parameter typos.

The only downside is the Vulkan/MoltenVK dependency — if libplacebo is present in the filter list it means the build linked it, so that concern is already satisfied.

### 4.2 Fourth cell (neither filter)

Already handled by `ffmpegCapabilityBlocksHdrPrep` in `video-export-source-metadata.ts:299-304`. The policy returns `strategy: "defer-unknown"` / `reason: "ffmpeg-missing-hdr-filters"` and the args builder must produce the unmodified SDR args (i.e. no `-vf` HDR filter injection). S-5 does not change this branch.

## 5. Failure modes and test plan

### 5.1 Visual artifacts → root cause map

| Visual symptom | Most likely cause |
|---|---|
| Overall green or magenta cast | Matrix mismatch — usually `zscale=t=709` applied without `m=709`, or BT.2020 non-constant-luminance matrix left on the output tag. |
| Crushed blacks, posterized mid-greys | Integer-precision intermediate (step 2 format conversion missing). `tonemap` fed YUV instead of `gbrpf32le`. |
| Washed-out highlights, low contrast | `npl` too high (e.g. 1000) or `desat` too aggressive (≥ 2). |
| Clipped highlights (lost cloud detail) | No tonemap stage at all — signal jumped from linear-2020 straight to bt709 transfer, clipping at 1.0. |
| Oversaturated reds and blues | Gamut conversion (`zscale=p=709`) missing or placed *after* tonemap. Preserved OOG data became in-gamut-saturated. |
| TV-level blacks showing as 16/255 grey in browser | `-color_range tv` metadata tag missing from the encoder args. Verify `buildFfmpegRawvideoExportArgs` still emits `-color_range tv`, `-colorspace bt709`, etc. |

### 5.2 Fixture requirements

Minimum set (matches inventory §4.2):

- `apps/desktop-film-lab-batch/fixtures/video/hdr/generic-pq-1s-<hash>.mp4` — required for baseline PQ → SDR verification.

Stretch set (nice-to-have, not blocking):

- `generic-pq-1s-400nit-<hash>.mp4` — typical camera HDR10 peak
- `generic-pq-1s-1000nit-<hash>.mp4` — broadcast HDR10 peak
- `generic-pq-1s-4000nit-<hash>.mp4` — mastering-grade peak

Different peak luminances stress the `npl` / MaxCLL path differently. If only one fixture is available, prefer the 1000-nit mastering level (most common HDR10 broadcast / streaming master).

Each fixture must have:
- `<basename>.ffprobe.json` with expected `color_transfer: "smpte2084"`, `color_primaries: "bt2020"`, `color_space: "bt2020nc"`, `color_range: "tv"`.
- No people, no identifiable landmarks, GPS stripped (see `fixtures/README.md`).

### 5.3 Integration test plan (S-6 deliverable, not S-5)

Tests to add once fixtures land:

1. **Classification** — ffprobe the fixture, feed JSON into `deriveSourceColorMetadataFromFfprobeStream` + `classifySourceColorForExport`. Assert `colorClass === "hdr-pq"`.
2. **Policy** — call `deriveDesktopHdrPreparationPolicy(metadata, { hasZscale: true, hasLibplacebo: false, hasTonemap: true, hasColorspace: true })`. Assert `strategy === "prepare-sdr-mezzanine"` and `reason === "source-is-hdr-pq"`.
3. **Filter-chain construction (pure)** — call `buildHdrToSdrFilterChain(policy, capabilities)` (new in S-6; see §6). Assert exact expected `vf` string matches §2.1.
4. **Filter-chain fallback to libplacebo** — with `{ hasZscale: false, hasLibplacebo: true }`, assert the returned `vf` matches §2.3.
5. **Visual sanity (end-to-end, opt-in)** — if the CI / dev machine has a capable ffmpeg, run the full export against the fixture into a tmp mp4 and assert:
   - `ffprobe` on the output reports `color_transfer: "bt709"`, `color_primaries: "bt709"`, `color_space: "bt709"`, `color_range: "tv"`.
   - `ffmpeg -i <out> -vf signalstats -f null -` mean Y is within `[40, 200]` on limited range (no fully-crushed or fully-saturated frames).
   - No `out_of_range` counts in signalstats `YDIF`/`UDIF`/`VDIF` (rough gamut check).

Checksum-based comparison is explicitly **not** used because tonemap output varies with minor libzimg version changes. Range / mean-luminance assertions are the primary visual sanity oracles.

## 6. Integration points in code

### 6.1 New function in `electron/video-export-ffmpeg-args.ts`

```ts
// Shape only — implementation is S-6 work.
export type HdrToSdrFilterSelection =
  | { kind: "none" }
  | { kind: "zscale-tonemap"; tonemap: "hable" | "mobius" | "reinhard"; desat: number; npl: number; signalRange: "tv" | "pc" }
  | { kind: "libplacebo"; tonemapping: "bt.2390" | "mobius" | "spline"; signalRange: "tv" | "pc" };

export type HdrToSdrFilterChain = {
  /** Comma-joined filter-chain fragment, NO trailing comma, NO surrounding `-vf`. */
  vf: string;
  /** Metadata to attach to the policy / sidecar so that a future QA pass can reproduce the exact recipe. */
  metadata: {
    recipe: "zscale-tonemap" | "libplacebo" | "none";
    algorithm: string | null;
    npl: number | null;
    desat: number | null;
    signalRange: "tv" | "pc" | null;
  };
};

export function buildHdrToSdrFilterChain(
  selection: HdrToSdrFilterSelection,
): HdrToSdrFilterChain;
```

Rules:

- Pure function. No process spawn. No I/O. Takes a `selection` and returns a string.
- `kind: "none"` returns `{ vf: "", metadata: { recipe: "none", ... } }`. Caller must handle empty-string `vf` (do not emit `-vf` at all in that case).
- Colons inside the `vf` string are left unescaped because this function returns a filter-chain string, not a filter-graph. The caller still uses `-vf` (not `-filter_complex`), so no escaping is needed.
- Signal range ties directly into zscale `rin=`. Default is `tv`.

### 6.2 Extend `deriveDesktopHdrPreparationPolicy` to return the selection

Option A (recommended): add a new optional field `filterSelection?: HdrToSdrFilterSelection` to `HdrPreparationPolicy` and populate it only when `strategy === "prepare-sdr-mezzanine"`.

Option B: keep policy unchanged, and add a sibling helper `selectHdrToSdrFilter(policy, capabilities)` that the electron layer calls before building args.

Recommendation: **Option A**, because the sidecar is the single source of truth for "what did we do and why", and having the filter selection in the policy lets the sidecar record the recipe name + parameters without a separate schema migration path. A future `selection.kind = "libplacebo-bt2390"` entry will appear directly in the sidecar and be replayable.

Zod schema update (required if Option A is chosen):

- `src/renderer/export-metadata-session.ts` — add the discriminated union as an optional field on `hdrPreparationPolicySchema`.
- `electron/preload.ts` — mirror the same optional field on the IPC bridge type.
- `src/renderer/desktop-api.d.ts` — mirror the renderer ambient type.
- `electron/video-export-source-metadata.ts` — add `filterSelection` to `HdrPreparationPolicy` and populate only the PQ branches.

### 6.3 Wiring the result into the args builder

`buildFfmpegRawvideoExportArgs` in `electron/video-export-ffmpeg-args.ts` currently builds `colorFilterChain` with only `vflip,scale=in_range=full:out_range=limited[,select…]`. The HDR preparation chain must be prepended to that filter chain (before `vflip`) only when:

- The export source is **not** the rawvideo pipe (because the raw frames coming in through `pipe:0` are already SDR WebGL output — they must not be re-tonemapped).
- The source-metadata sidecar says `strategy: "prepare-sdr-mezzanine"` for the HDR input side.

In other words: the HDR preparation chain applies to a **separate mezzanine pass** that runs before the WebGL / WebGPU renderer ever sees the frames — not to the final `-c:v h264_videotoolbox` encoder pass. S-6 will need a new code path distinct from `buildFfmpegRawvideoExportArgs`, probably `buildFfmpegHdrMezzaninePrepArgs(inputPath, outputPath, selection)`.

**Invariant:** `buildFfmpegRawvideoExportArgs` does **not** need to know about HDR. The HDR→SDR preparation happens upstream, produces an SDR BT.709 intermediate file, and the renderer + final encode work exactly as today.

### 6.4 No renderer changes needed

The renderer already consumes `hdrPreparationPolicy` from the bridge and surfaces it via `export-metadata-session.ts` into the sidecar. Adding `filterSelection` to the policy flows through that existing path without any renderer code change beyond the Zod enum extension.

## 7. Open questions

These are intentionally left unresolved in S-5; S-6 (or a parallel research thread) should answer them with fixtures in hand.

1. **HDR10+ dynamic metadata (ST 2094-40)**: HDR10+ stores per-frame target peak / mastering-display hints. `zscale` + `tonemap` ignore dynamic metadata entirely — the output is a single static curve across the whole clip. `libplacebo` reads HDR10+ metadata when present and adapts per frame. Decision pending: do we (a) strip HDR10+ metadata at demux and treat as HDR10, or (b) document that HDR10+ fallback is a best-effort static tonemap on zscale-only builds? Note: no Filmtone user has asked for HDR10+ as of 2026-04-24.

2. **Dolby Vision**: Profile 5 (IPTPQc2, no fallback) fails classification because the PQ is encoded under a proprietary color space. Profile 7 / 8.1 have HDR10 fallback and will classify as `hdr-pq`. Decision pending: do we detect `dolby_vision_metadata` side data and refuse to run the recipe (return `defer-unknown` / new reason `source-has-dolby-vision`), or proceed on the HDR10 base layer? Recommend the former for correctness.

3. **`npl` vs MaxCLL**: For zscale-only recipes, should we read `MaxCLL` from ffprobe side data and use it as `npl`? The theory says yes (per-source calibration), but practice says it's risky — many cameras set MaxCLL inaccurately (e.g. `1000` when the real peak is 400). A hard-coded `npl=100` ignores source metadata but is deterministic. Decision pending: fixture-backed comparison of `npl=100` vs `npl=MaxCLL/10` (divide by 10 because npl is in "SDR references", not cd/m²). **For S-6 v1: hard-code `npl=100`. Revisit in S-7+.**

4. **BT.2390 implementation in `zscale` path**: `tonemap=hable` is not BT.2390. If the standards-conformance argument matters more than the Filmtone aesthetic, we should consider `tonemap=reinhard` (closer to BT.2390's knee behavior than hable) or switch to a custom EETF via `geq`/`lutrgb`. For S-6 v1: stay with hable. Flag as research for S-7.

5. **Output bit depth**: Should the mezzanine intermediate be 10-bit (`yuv420p10le`) to preserve tonemap precision, or 8-bit (`yuv420p`) for WebGL readback simplicity? Recommendation: keep 8-bit `yuv420p` for v1 because the WebGL / WebGPU render path is 8-bit internally — promoting to 10-bit upstream only shifts the truncation point, it does not prevent it. If a future WebGPU pipeline is truly 10-bit end-to-end, re-evaluate.

6. **macOS signing / notarization implications of bundled libplacebo**: out of scope for S-6; tracked under inventory §3 Option D.

## 8. References

All access dates: 2026-04-24.

- [FFmpeg zscale filter reference (v8.0.1)](https://ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Video/zscale.html) — canonical parameter list (`t`, `tin`, `p`, `pin`, `m`, `min`, `r`, `rin`, `npl`, `d`). Used to confirm parameter shortcuts and enum values for the §2.1 recipe.
- [FFmpeg tonemap filter reference (v6.0.1 mirror)](https://ayosec.github.io/ffmpeg-filters-docs/6.0/Filters/Video/tonemap.html) — algorithm list (`hable`, `mobius`, `reinhard`, `clip`, `linear`), `desat` semantics, and the requirement that input be single-precision float linear light.
- [FFmpeg libplacebo filter reference (v8.0.1)](https://ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Video/libplacebo.html) — confirms `tonemapping=bt.2390` support, automatic HDR10 metadata reading, and HDR10+ dynamic metadata awareness.
- [BinaryTides — How to convert HDR video to SDR with ffmpeg](https://www.binarytides.com/convert-hdr-video-to-sdr-with-ffmpeg/) — widely-cited practical recipe; source for the "zscale t=linear → gbrpf32le → tonemap → zscale t=bt709" five-stage pattern.
- [Eric Park — ffmpeg: convert HDR to SDR (2022-12-14)](https://ericswpark.com/blog/2022/2022-12-14-ffmpeg-convert-hdr-to-sdr/) — side-by-side algorithm comparison; basis for hable-over-reinhard preference.
- [Jellyfin Issue #415 — Add tonemapping filter to convert HDR10 content to SDR](https://github.com/jellyfin/jellyfin/issues/415) — long thread (2018–2024) with practical `hable desat=0` consensus and explanation of `desat` parameter semantics.
- [GitHub Gist — goyuix/033d35846b05733d77f568b754e7c3ea — FFMPEG HDR to SDR](https://gist.github.com/goyuix/033d35846b05733d77f568b754e7c3ea) — HDR10+ context, confirms `zscale`+`tonemap` ignores dynamic metadata.
- [FFmpeg mailing list — HDR bt.2020 to SDR bt.709 conversion (2023-10)](https://ffmpeg.org/pipermail/ffmpeg-user/2023-October/057045.html) — contemporary filter-chain discussion used to cross-verify the primaries-before-tonemap ordering.
- [FFmpeg Trac #6132 — SMPTE 2084 support in colorspace filter](https://trac.ffmpeg.org/ticket/6132) — confirms `colorspace` filter does not handle transfer; reinforces the "zscale is mandatory for PQ linearization" position.
- [libplacebo options documentation](https://libplacebo.org/options/) — authoritative list of `tonemapping` values including `bt.2390` (spline), `spline`, `mobius`.
- [Tony Tascioglu Wiki — AV1 encoding with HDR to SDR tonemapping](https://wiki.tonytascioglu.com/scripts/ffmpeg/av1_hdr_sdr) — alternate practical recipe; useful sanity check on filter ordering.
- Gemini CLI synthesis (2026-04-24, model: gemini-2.5-pro) — confirms 2026-current "prefer libplacebo when available" community consensus. Cross-verified against the zscale / libplacebo / tonemap docs above.

### Cited but not used

- [Blender PQ test content (tears_of_steel_4k_HDR10)](https://mango.blender.org/) — candidate future fixture source. Not adopted in S-5; see inventory §4.3.

---

End of PQ → SDR BT.709 filter chain design doc. No code changes accompany this document.
