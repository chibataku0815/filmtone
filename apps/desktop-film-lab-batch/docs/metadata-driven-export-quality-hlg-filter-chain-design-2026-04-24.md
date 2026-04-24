# Filmtone HLG → SDR BT.709 Filter Chain Design (Stream C / S-5)

Last updated: 2026-04-24
Authoring context: Claude Code desktop session (Stream C of S-5, research + design only, zero pixel changes)
Primary repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
Scope: `apps/desktop-film-lab-batch` — design of the HLG (BT.2100 HLG, `arib-std-b67`) branch of `buildHdrToSdrFilterChain`, which Stream B is contracting. Depends on §6 fixtures and an HDR-capable ffmpeg (zscale and/or libplacebo linked).

This document is paired with the PQ design document produced by Stream B (sibling file: `metadata-driven-export-quality-pq-filter-chain-design-2026-04-24.md`, pending at time of writing). Readers should read both before wiring S-6, because the intended code contract is a single `buildHdrToSdrFilterChain` helper that branches on `sourceVideoMetadata.colorClass`.

---

## 1. Purpose and scope

### 1.1 Purpose
Specify the exact ffmpeg filter chains, parameter meanings, failure modes, capability-aware branching, and integration points required to take an HLG (`color_transfer = arib-std-b67`) source — most commonly from iPhone HDR Video recording — and produce a deterministic, display-referred BT.709 limited-range SDR rendering that Filmtone Desktop's existing WebGL / WebGPU render path can consume without relying on implicit browser tone mapping.

### 1.2 In scope
- HLG (BT.2100 HLG, `arib-std-b67` transfer, `bt2020` primaries, `bt2020nc` matrix).
- The inverse OETF → OOTF → BT.709 primaries / BT.709 OETF flow in an ffmpeg CLI pipeline.
- Two candidate implementations: `zscale+tonemap` canonical, and `libplacebo` alternative.
- Capability-aware branching into `defer-unknown` when neither filter is linked.
- Integration point naming that matches the existing P0-C policy surface in `electron/video-export-source-metadata.ts`.

### 1.3 Out of scope
- PQ (`smpte2084`). Covered by Stream B; different inverse EOTF and different tone mapping shape.
- Dolby Vision (profile 5 / 8.4). iPhone HDR Video tags Dolby Vision Profile 8.4 on top of HLG for broadcast compatibility; Filmtone treats these files as HLG and ignores the DV RPU for now. No DV-aware tone mapping.
- Pixel-changing wiring. This doc is design-only. S-6 wires code against this.
- Bundled ffmpeg in the Electron app. Tracked separately (handoff §9.1 Option D).
- HDR10+ dynamic metadata, ST2094-10/40.
- Export FPS changes (forbidden invariant).

### 1.4 Guardrails (carried forward from plan and handoff)
- Do not wire any pixel-changing HLG path without the `iphone-hlg-1s-<hash>.mov` fixture and its `<basename>.ffprobe.json` oracle in place.
- Do not auto-select camera profile / input LUT from `make` / `model`.
- Do not copy GPMF / CAMM / gyro tracks into rendered exports.
- Sidecar schema evolutions must stay backward-compatible (Zod enum additions only).
- Update all four `HdrPreparationPolicy["reason"]` mirrors when adding variants (source-metadata, preload, desktop-api.d.ts, export-metadata-session Zod).

---

## 2. Why HLG needs different treatment than PQ

HLG is not "PQ with a different transfer curve". The math, the metadata model, and the failure modes all differ.

### 2.1 Scene-referred vs display-referred

- **PQ (`smpte2084`)** is a **display-referred** encoding. A PQ code value maps to an absolute cd/m² display luminance through a fixed inverse EOTF, anchored by the SMPTE ST 2084 curve peaking at 10,000 cd/m². Mastering assumes a specific reference display (typically 1000-nit or 4000-nit), so tone mapping is about **compressing absolute display values** to the target display's capabilities.

- **HLG (`arib-std-b67`)** is a **scene-referred** encoding. The HLG OETF takes linear scene light and produces a code value. To display it, you apply the HLG inverse OETF back to linear scene light, then apply a **system-gamma OOTF** (Opto-Optical Transfer Function) that turns scene-linear into display-linear. The OOTF is where the relative-to-absolute anchoring happens, and it is a function of the **target display's peak luminance**, not the source.

### 2.2 System gamma and OOTF (ITU-R BT.2100-2)

Per Rec. ITU-R BT.2100-2, the HLG OOTF applied to scene-linear RGB is:

```
Yscene = 0.2627·Rscene + 0.6780·Gscene + 0.0593·Bscene     (BT.2020 coefficients)
Rdisplay = alpha · Yscene^(gamma - 1) · Rscene
Gdisplay = alpha · Yscene^(gamma - 1) · Gscene
Bdisplay = alpha · Yscene^(gamma - 1) · Bscene
```

where `alpha = Lw` (the nominal peak luminance of the target display in cd/m²) and `gamma` is the system gamma.

At the reference `Lw = 1000 cd/m²`, `gamma = 1.2` exactly (BT.2100-2).

For other peak luminances, BT.2100-2 defines an adjustment. The commonly cited formula for `Lw > 400 cd/m²`:

```
gamma = 1.2 + 0.42 * log10(Lw / 1000)        (TBD — verify exact form in BT.2100-2 §Table 5
                                              before S-6; searches in §9 return this shape
                                              but do not pin it to a line in the ITU PDF)
```

The practical implication for Filmtone: **the tone-mapping step for HLG depends on the target SDR nominal white / peak we pick**. BT.709 SDR is conventionally anchored at `Lw = 100 cd/m²` diffuse white, but BT.2408-5 prescribes anchoring HLG diffuse-white reference at 203 cd/m² for HDR, with a graphics white range. This is a policy decision (see §8).

### 2.3 Backward-compatibility property

HLG with BT.709 primaries was designed by BBC and NHK so that an SDR display can display an HLG signal without decoding and it will look plausible (somewhat desaturated, gamma slightly off, but not grossly wrong). This is why broadcast adopted HLG. Our Filmtone workflow does **not** exploit this — we do a proper OOTF + primaries conversion — but it is useful to remember because it shapes one failure mode: if you skip the inverse OETF and just treat HLG code values as BT.709 code values, the output will look plausible enough that you might ship the bug. A proper oracle comparison (§6) matters.

### 2.4 Apple HLG quirks (iPhone HDR Video)

From research (§9) and Filmtone's iOS app existing handling:

1. **Transfer, primaries, matrix labels**: Apple HLG captures tag as `color_transfer = arib-std-b67`, `color_primaries = bt2020`, `color_space = bt2020nc`. `color_range = tv` (limited range). Ffprobe returns exactly these in most cases.
2. **Dolby Vision Profile 8.4 side channel**: iPhone 12+ wraps HLG with DV 8.4 (backward-compatible DV). Filmtone **ignores** the DV RPU. The base layer is pure HLG and that is what we convert. DV RPU metadata must not be copied to the rendered output (guardrail §1.4 timed-track rule).
3. **Gain-map / EDR / ambient**: Apple AVFoundation carries side-channel "ambient viewing environment" and optional gain-map hints through AVFoundation APIs but these are **not** in the container's color tags as read by a vanilla `ffprobe -show_streams`. Vanilla tools cannot see them. Filmtone must not depend on them; we treat the base HLG signal as the truth.
4. **Per-frame `bt2020-10` vs stream-level `arib-std-b67`**: some iPhone clips report `arib-std-b67` at the stream level but individual frames' side data may advertise `bt2020-10` transfer. Per research (§9 source 3), some tools re-label output on transcode. Filmtone's policy branch uses the stream-level classification from `classifySourceColorForExport`, which already maps `arib-std-b67 → hdr-hlg`. We do not second-guess per-frame side data — that is below our metadata abstraction.
5. **10-bit and limited range**: the source is typically `yuv420p10le(tv, bt2020nc/bt2020/arib-std-b67)`. The filter chain must preserve 10-bit precision until after the OOTF stage, otherwise 8-bit quantization in linear scene-light produces visible banding in shadows. See §3 parameter notes.

### 2.5 Why one single tone-map algorithm is **not** sufficient

For PQ, the signal is display-referred and already absolutely scaled. A Hermite-spline EETF like BT.2390 can be applied directly after the inverse PQ EOTF. For HLG, the OOTF itself is the dominant nonlinearity between scene and display. A tone mapper applied without first applying the HLG OOTF to the target peak produces one of two bugs:
- Midtones wash out (OOTF skipped → highlight compression eats midtone contrast).
- Shadows crush (OOTF applied twice → scene-linear gets gamma'd, tonemap gammas again).

The canonical HLG path is therefore:
**inverse OETF → OOTF(to target Lw) → BT.709 primaries → BT.709 OETF**, with an **optional** tone mapper only if the chosen target Lw still exceeds what 8-bit BT.709 can hold headroom-free.

---

## 3. Target filter graph

Below, the `<source>` feeds an ffmpeg `-i` input with HLG tags. The output is consumed downstream by the existing Filmtone export pipeline as a BT.709 limited-range 10-bit (optionally 8-bit) mezzanine. The final `yuv420p`/`yuv420p10le` choice is parallel to PQ's Stream B output format and must match the Filmtone WebGL readback expectation (currently 8-bit BT.709 limited per `electron/video-export-ffmpeg-args.ts:202-216`).

### 3.1 Candidate A — `zscale`-canonical (recommended default)

```
zscale=tin=arib-std-b67:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=1000,
format=gbrpf32le,
zscale=p=709,
tonemap=tonemap=mobius:desat=0,
zscale=t=709:m=709:r=tv,
format=yuv420p
```

Parameter-by-parameter:

| step | filter | parameter | meaning | failure if wrong |
|---|---|---|---|---|
| 1 | `zscale` | `tin=arib-std-b67:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=1000` | **Input-tag reassertion + critical linearization.** The `*in` options describe the source as HLG / BT.2020 / limited-range before conversion, then `t=linear:npl=1000` applies the HLG inverse OETF and the BT.2100 reference OOTF for `Lw = npl` (nominal peak luminance in cd/m²), producing display-linear light. | If `tin` is wrong, `zscale` cannot apply the HLG inverse OETF. If output-side `t/m/p/r` are used here instead of `tin/min/pin/rin`, the recipe rewrites tags rather than describing the input. If `npl` is wrong, the OOTF gamma shifts, producing washed-out midtones or crushed shadows. |
| 2 | `format` | `gbrpf32le` | Planar float32 RGB, required by `tonemap` filter and high enough precision to preserve the 10-bit source through the OOTF stage. | `tonemap` errors out on integer formats, or visible banding appears if the signal is quantized before the float intermediate. |
| 3 | `zscale` | `p=709` | Converts primaries from BT.2020 to BT.709 in linear light (correct place). | If done after OETF (step 5), out-of-gamut BT.2020 values become negative BT.709 after matrix, and OETF clips them — producing cyan shadows / magenta highlights. |
| 4 | `tonemap` | `tonemap=mobius:desat=0` | S-curve luminance compression to bring the post-OOTF display-linear range into BT.709's ~100-nit headroom. `desat=0` keeps chroma unchanged (we defer any saturation shaping to the Filmtone creative stage). | Without it, specular highlights above 100 cd/m² clip to 1.0 in BT.709 — visible as hard white plates on bright skies / reflections. With `hable` instead, midtones darken more (see §4). |
| 5 | `zscale` | `t=709:m=709:r=tv` | Applies the BT.709 OETF (gamma ~2.4 in signal sense) and writes BT.709 matrix, limited range. | Wrong matrix → greenish cast. Wrong range → crushed blacks or lifted whites. |
| 6 | `format` | `yuv420p` | Chroma-subsampled 4:2:0 8-bit, matching the existing Filmtone export output pixel format. | If swapped for `yuv420p10le`, the downstream H.264 encoder branch in `ffmpegVideoCodecArgs` (hardware `h264_videotoolbox` on macOS) may either re-quantize or reject depending on platform. |

**Why `npl=1000` and not `npl=100`**: `npl` in zscale's HLG path is the *nominal peak luminance of the OOTF target display*, i.e. `Lw` in BT.2100. Setting `npl=100` means "apply the OOTF for a 100-nit display" — gamma becomes `gamma = 1.2 + 0.42 * log10(0.1) ≈ 0.78` (inverse gamma, darkens). That is not what BT.709 SDR wants; BT.709 SDR wants the scene rendered with a **system gamma near 1.0** at diffuse white, then tone-mapped. Setting `npl=1000` applies the authoring-intended OOTF (display-linear at 1000 nits), and the subsequent `tonemap=mobius` step is what brings the range down to BT.709.

**Alternative interpretation** (TBD — research pending: the zscale source code `libavfilter/vf_zscale.c` vs zimg's `zimg_graph_builder_params.nominal_peak_luminance` need direct inspection before S-6 commits): some documentation suggests `npl` is also used by the *inverse* OETF step as the HLG display reference. If so, setting `npl=1000` in the first zscale stage means "treat scene-linear values as authored for a 1000-nit display", which is the BT.2100 reference condition. Either interpretation converges on `npl=1000` being the right value for default iPhone HLG. This is an S-6 verification task against real fixtures.

### 3.2 Candidate B — `libplacebo` single-pass

```
format=yuv420p10le,
libplacebo=
  colorspace=bt709:
  color_primaries=bt709:
  color_trc=bt709:
  range=limited:
  tonemapping=bt2390:
  intent=relative,
format=yuv420p
```

Parameter explanation:

| param | meaning | failure mode |
|---|---|---|
| `colorspace=bt709` | Output matrix. | Wrong → color cast. |
| `color_primaries=bt709` | Output primaries. | Wrong → saturation shift. |
| `color_trc=bt709` | Output transfer. | Wrong → gamma mismatch. |
| `range=limited` | Output 16-235 TV range. | Wrong → crushed or elevated black/white. |
| `tonemapping=bt2390` | Tone map algorithm (ITU-R BT.2390 EETF, Hermite spline with linear segment, current broadcast reference). | `hable`/`reinhard` alternatives exist; `bt2390` is the 2025–2026 industry default for "least ugly". |
| `intent=relative` | Rendering intent for gamut mapping (relative colorimetric). | `perceptual` desaturates more; `relative` is closer to SDR grading expectation. |

libplacebo reads input color tags from the decoded frame's color properties; it does **not** need the initial tag-reasserting `zscale`. Internally it applies the HLG inverse OETF, OOTF (auto-targeted), BT.2390 EETF, and BT.709 OETF in a single GPU/CPU shader pass. This is shorter, often faster, and generally produces smoother gradients because the entire pipeline runs in a single linear-light working space without integer intermediates.

Caveats:
- Requires Vulkan (or similar) on the build, plus `libplacebo` linked.
- Auto-target behavior is controlled by libplacebo's internal HDR metadata peak detection. For HLG specifically, libplacebo defaults `target_peak` to `target_contrast`-derived values unless overridden. For deterministic Filmtone output, we should pass explicit `target_peak=100` or similar (TBD — confirm `target_peak` vs deprecated `target_luma` naming against linked libplacebo version per `ffmpeg -h filter=libplacebo` at wiring time).
- libplacebo's `tonemapping_param` tuning knob behaves differently for HLG vs PQ because libplacebo is aware of the source transfer and adjusts target compression. Filmtone should accept libplacebo's defaults and revisit only if fixture QA shows clear regressions.

### 3.3 Output format choice

Filmtone's existing WebGL export path (`buildFfmpegRawvideoExportArgs` at `electron/video-export-ffmpeg-args.ts:150`) takes raw `rgba` from stdin and uses `vflip,scale=in_range=full:out_range=limited` plus BT.709 color tags.

Stream B's and Stream C's filter chains are **not** the export-pipe chain above. They produce a **mezzanine source file** that then feeds the existing WebGL readback. So the right output of the HLG→SDR chain is a BT.709-tagged file whose frames, when decoded by the browser/WebGL source, land in the expected BT.709 limited-range space without further implicit tone mapping.

For S-6:
- Default mezzanine output: `yuv420p` 8-bit BT.709 limited, H.264 encoded, to match downstream assumptions.
- Optional: `yuv420p10le` 10-bit BT.709 limited if the rest of the pipeline supports it (ProRes mezzanine option). Not recommended for v1 because the WebGL readback is 8-bit RGBA and the gain is invisible.

---

## 4. Algorithm choice

### 4.1 Comparison of HLG → SDR approaches

| approach | who applies OOTF | who does tone map | pros | cons | Filmtone verdict |
|---|---|---|---|---|---|
| `colorspace` only | nobody (filter does not touch transfer) | nobody | trivial | silently wrong for HLG | ❌ never |
| `tonemap` only (no `zscale` linearize) | nobody | tonemap | trivial | washed-out (OOTF missing) | ❌ never |
| `zscale` linearize + `tonemap` (Candidate A) | `zscale tin=…:t=linear:npl=…` | `tonemap mobius/hable/reinhard` | canonical, well-documented, works on any zimg build | 6-stage chain, needs correct `npl` and float intermediate | ✅ default when `hasZscale` |
| `libplacebo` single-pass (Candidate B) | libplacebo internal | libplacebo BT.2390 EETF | 1 filter, best gradients, GPU path | requires Vulkan+libplacebo linkage | ✅ preferred when both available, fallback to A otherwise |
| 3D LUT (`lut3d`) | LUT author | LUT author | cheap runtime | LUT is fixed to one authoring display Lw; no OOTF adaptation; bakes in creative choices | ❌ not suitable for a metadata-driven correctness pipeline |
| `colorspace=iall=…:all=…` | in newer ffmpeg builds has HDR support | limited | attractive because it's a single filter | HLG OOTF handling has historically lagged zscale; not trusted as the canonical for 2026 | ❌ not default; reconsider if zscale availability collapses |

### 4.2 Default recommendation

- **When `hasZscale && !hasLibplacebo`** → Candidate A.
- **When `!hasZscale && hasLibplacebo`** → Candidate B.
- **When both available** → Candidate B (`libplacebo`) preferred for smoother gradients in HLG specifically (BT.2390 EETF is what BBC / NHK's own reference conversions use).
- **When neither** → existing `defer-unknown` / `ffmpeg-missing-hdr-filters` path; pixels unchanged.

### 4.3 Tone mapper choice inside Candidate A

Per §9 search result (Eric Park HDR→SDR comparison) and the community's informal consensus:

- `hable` — preserves both shadow and highlight detail; slightly darker overall. Good for broad-range HDR footage.
- `reinhard` — brighter midtones; slightly less detail in shadows.
- `mobius` — steeper S-curve; can oversaturate / shift hues.
- `linear` with `param=` — literal linear clip; avoid.

For iPhone HLG, peak specular highlights are often not extreme (tuned for broadcast-safe delivery), so `mobius` with `desat=0` gives a slightly punchier look that matches the iPhone "photo app" viewing experience. `hable` is a safer conservative choice. Filmtone should:

- Default: `tonemap=mobius:desat=0` (punchier, matches Filmtone's Moving Postcard aesthetic).
- Fixture QA alternative: `tonemap=hable:desat=0` captured as a B-roll comparison in §6.
- TBD: user-facing toggle to swap — deferred to P2; v1 ships one algorithm only.

### 4.4 iPhone-specific considerations

Research (§9 source 3) notes that Apple HLG is *nominally* BBC HLG but:
- The Apple pipeline assumes a 1000-nit reference and applies its own `target_peak` on-device when rendering to an EDR display. Our filter chain should pick `npl=1000` (the default authoring intent), not `npl=500` or similar iPhone-display speculation. The iPhone display's own peak (typically ~1000 nits on Pro models) is incidental; the file is authored to BT.2100 reference.
- Apple attaches "ambient viewing environment" side data for HDR preview rendering on-device. Filmtone **ignores** this — our job is the canonical HLG → SDR conversion, not Apple's adaptive renderer behavior.
- No Apple HLG file should be routed through a PQ-shaped filter chain. The `classifySourceColorForExport` helper at `electron/video-export-source-metadata.ts:254` already dispatches `arib-std-b67 → hdr-hlg` correctly; the branch in `buildHdrToSdrFilterChain` must dispatch on `colorClass === "hdr-hlg"` and **never** fall through to the PQ branch.

---

## 5. Capability-aware branching

Shape is identical to Stream B's, which is the whole point of reusing `buildHdrToSdrFilterChain`. Inside that helper, HLG branches:

```
// pseudocode, not committed
function buildHdrToSdrFilterChain(colorClass, capabilities) {
  if (colorClass === "hdr-hlg") {
    if (capabilities.hasLibplacebo) return hlgChainLibplacebo();  // Candidate B
    if (capabilities.hasZscale)     return hlgChainZscale();      // Candidate A
    return null;                                                   // policy already set defer-unknown
  }
  ...
}
```

Four-cell matrix:

| `hasZscale` | `hasLibplacebo` | chain | policy reason |
|---|---|---|---|
| true | false | Candidate A (zscale+tonemap mobius) | `source-is-hdr-hlg`, `strategy=prepare-sdr-mezzanine` |
| false | true | Candidate B (libplacebo BT.2390) | `source-is-hdr-hlg`, `strategy=prepare-sdr-mezzanine` |
| true | true | Candidate B preferred (libplacebo) | `source-is-hdr-hlg`, `strategy=prepare-sdr-mezzanine` |
| false | false | return `null`; existing policy already `defer-unknown` / `ffmpeg-missing-hdr-filters` | no chain emitted |

Note the preference order (Candidate B wins when both are available) is **reversed** between HLG and PQ in common practice: PQ tends to be fine with either; HLG gradients specifically benefit from libplacebo's BT.2390 implementation over zscale's `tonemap` filter. Stream B should state its preference independently, and the shared helper should dispatch based on `colorClass` so the two branches can hold different preference orders.

---

## 6. Failure modes and test plan

### 6.1 Visual artifacts from wrong OOTF

| symptom | likely cause | how to detect |
|---|---|---|
| Midtones washed out, skin tones pale | OOTF not applied (first zscale stage missing `t=linear` or has wrong `tin=`) | Compare against reference SDR QuickTime Player HLG render; look at 18% grey / skin |
| Shadows crushed, blacks clipping | OOTF applied twice, or `npl` too high | Histogram clipping below code 16 in limited range |
| Highlights hard-clipping to pure white plates | Tone mapper skipped, or Candidate B with `target_peak` unset | Specular reflections / sky lose gradient |
| Greenish / cyan cast | Matrix left as `bt2020nc` at final step | Compare swatches of 50% grey / skin swatch; non-neutral implies matrix error |
| Magenta highlights | Primaries converted after OETF (out-of-gamut handling broken) | Saturated BT.2020 reds (e.g. traffic lights, sunsets) show magenta fringing |
| Saturation shift vs QuickTime SDR preview | `desat` parameter non-zero in `tonemap`, or libplacebo `intent=perceptual` | A/B against QuickTime SDR export — which itself is not canonical but is a useful reference point |

### 6.2 Required fixtures

From `apps/desktop-film-lab-batch/fixtures/README.md`:

- **Required**: `iphone-hlg-1s-<hash>.mov` — 1–2 s iPhone clip with HDR Video ON, ProRes or HEVC. Must include one high-chroma subject (e.g. sunset, bright neon) and one skin/grey subject to drive the midtone-vs-highlight assertions.
- **Oracle**: `<basename>.ffprobe.json` with at minimum:
  ```json
  {
    "streams": [{
      "codec_type": "video",
      "color_range": "tv",
      "color_space": "bt2020nc",
      "color_transfer": "arib-std-b67",
      "color_primaries": "bt2020",
      "pix_fmt": "yuv420p10le"
    }]
  }
  ```
- **Recommended companion**: a QuickTime-rendered SDR `.mov` of the same 1-second window, captured via macOS "Export As → 1080p" (which applies Apple's HLG→SDR internally), for visual A/B sanity. Not a pixel-exact oracle, but catches severe regressions.

### 6.3 Integration-test assertions

At the fixture-validation tier (not unit test), the test should:

1. `ffprobe` the fixture → assert `colorClass === "hdr-hlg"` via existing `classifySourceColorForExport`.
2. `deriveDesktopHdrPreparationPolicy(meta, caps)` → assert `strategy === "prepare-sdr-mezzanine"` when `caps.hasZscale || caps.hasLibplacebo`, else `strategy === "defer-unknown"` + `reason === "ffmpeg-missing-hdr-filters"`.
3. `buildHdrToSdrFilterChain("hdr-hlg", caps)` → assert (a) returns a non-null string when chain is possible, (b) contains `arib-std-b67` or `libplacebo=colorspace=bt709` depending on branch, (c) contains `yuv420p` final format, (d) contains `r=tv` or `range=limited`.
4. Execute the chain against the fixture into an SDR output, ffprobe the output → assert `color_transfer=bt709`, `color_space=bt709`, `color_primaries=bt709`, `color_range=tv`, `pix_fmt=yuv420p`.
5. Sample a handful of pixel positions from known-neutral patches in the fixture → assert luma and chroma are within a tolerance of the QuickTime reference (TBD tolerance — fixture-dependent, set during S-6).

### 6.4 Negative tests

- An SDR BT.709 fixture fed to `buildHdrToSdrFilterChain("sdr-bt709", …)` → must return `null` (SDR path does not emit a chain).
- A PQ fixture must **not** flow through the HLG branch: the dispatch happens on `colorClass`, not on a shared HDR flag.

---

## 7. Integration points in code

All paths relative to `apps/desktop-film-lab-batch/`.

### 7.1 New symbol to add (Stream B owns the skeleton, Stream C provides the HLG branch body)

Location: new file `electron/hdr-to-sdr-filter-chain.ts` (Stream B proposal; follow Stream B's final choice if it lands first).

Exported:
- `buildHdrToSdrFilterChain(colorClass: SourceColorClass, capabilities: FFmpegHdrCapabilities): string | null`
  - `"hdr-hlg"` branch implemented per §3 and §4 of this doc.
  - `"hdr-pq"` branch implemented per Stream B's sibling doc.
  - All other classes → `null`.

### 7.2 Consumer

Location: `electron/main.ts`, downstream of `deriveDesktopHdrPreparationPolicy`. Only invoked when `sourceHdrPreparationPolicy.strategy === "prepare-sdr-mezzanine"`. The chain is inserted into a **mezzanine preparation pass**, not the raw-input export pass.

### 7.3 Existing symbols to leave alone

- `buildFfmpegRawvideoExportArgs` at `electron/video-export-ffmpeg-args.ts:150` — the WebGL readback encoder. Not modified by this design.
- `ffmpegVideoCodecArgs` at `electron/video-export-ffmpeg-args.ts:44` — encoder selection. Not modified.
- `deriveDesktopHdrPreparationPolicy` at `electron/video-export-source-metadata.ts:306` — policy helper. Not modified by S-6 unless a new reason variant is needed (which would require the 4-mirror update per guardrail §1.4). HLG branch does not require a new reason.

### 7.4 Sidecar schema impact

None. The policy reason `source-is-hdr-hlg` already exists. No Zod enum change needed. If Stream B decides to add a new reason like `hdr-chain-emitted` that’s a shared decision, not HLG-specific, and the 4-mirror update applies.

### 7.5 Mezzanine output naming

Suggestion (align with Stream B): `${sourceBasename}.filmtone-sdr-mezzanine.mov` in the same directory, cleaned up after export. If Stream B settles on a different convention, match it; this is cosmetic, not structural.

---

## 8. Open questions

Unresolved items that S-6 must close, with suggested default so implementation is never fully blocked:

1. **Target peak luminance `npl`**
   Fixed at `npl=1000` for v1 (BT.2100 reference), or user-adjustable via preferences?
   Suggested default: fixed at `1000`. Expose later if real-world iPhone HLG fixtures show consistent under- or over-compression.

2. **Target SDR diffuse white anchor — 100 cd/m² classical SDR or 203 cd/m² BT.2408-5 HDR diffuse white?**
   For SDR output, 100 cd/m² is conventional. 203-nit diffuse white is an HDR concept and does not apply to the BT.709 side of the pipeline. Recommendation: anchor at 100 cd/m² diffuse white on the BT.709 side. No code knob needed.

3. **Tone mapper selection in Candidate A**
   `mobius` (punchier) vs `hable` (safer) default.
   Suggested default: `mobius:desat=0`. Capture `hable` as a B-compare in fixture QA.

4. **libplacebo `target_peak` parameter**
   Whether to pass explicit `target_peak=100` or rely on libplacebo's default.
   TBD — resolve at S-6 against linked libplacebo version.

5. **Candidate B vs A preference when both are available**
   HLG specifically: this doc recommends B (libplacebo). Stream B may recommend A or B for PQ. The shared helper should dispatch by `colorClass` so HLG and PQ preferences can diverge.

6. **iPhone Dolby Vision Profile 8.4 metadata handling**
   Confirmed: ignore the DV RPU, treat base layer as pure HLG. Stream C states this explicitly (§2.4). No code change needed — ffmpeg's default behavior is to drop DV RPU unless explicitly asked to propagate it.

7. **Exact BT.2100-2 system-gamma formula at Lw ≠ 1000**
   The common `gamma = 1.2 + 0.42 * log10(Lw/1000)` shape is reported widely (see §9 sources) but the search did not hit a line in the ITU PDF that pins it. Since v1 uses `npl=1000` exclusively, gamma is `1.2` exactly and the formula is irrelevant to the code path. Mark as informational. If v2 ever exposes `npl` to users, cite BT.2100-2 §Table 5 directly.

8. **Handling of HLG source with `color_primaries=bt709` (broadcast-flag HLG)**
   Some broadcast HLG sources are BT.709-primaries (for SDR receiver compatibility) rather than BT.2020-primaries. Rare for iPhone, common for BBC feeds. Candidate A's step 5 primaries conversion becomes a no-op. Candidate B handles it internally. No code change needed; document so S-6 doesn't over-engineer.

9. **Per-frame `bt2020-10` vs stream-level `arib-std-b67` conflict**
   Per §9 source 3. Decision: trust stream-level classification (already set up in `classifySourceColorForExport`). Do not re-probe per-frame.

10. **Should the HLG chain also handle HLG-with-BT.2020-content-light-level metadata?**
    Some iPhone clips carry CLL side data even on HLG (DV 8.4 artifact). The metadata is not used in the filter chain; HLG does not need CLL (it is scene-referred). No change needed.

---

## 9. References

All accessed 2026-04-24 via WebSearch / WebFetch / Gemini CLI during the Stream C research pass.

1. **ITU-R Recommendation BT.2100-2**, "Image parameter values for high dynamic range television for use in production and international programme exchange", [glenwing.github.io/docs/ITU-R-BT.2100-2.pdf](https://glenwing.github.io/docs/ITU-R-BT.2100-2.pdf). Canonical definition of HLG OETF, OOTF, and system gamma `γ = 1.2 at Lw = 1000 cd/m²`.

2. **ITU-R Report BT.2390-8 (02/2020)**, "High dynamic range television for production and international programme exchange", [itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2390-8-2020-PDF-E.pdf](https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2390-8-2020-PDF-E.pdf). Source of the BT.2390 EETF (Hermite spline tone mapping) used by libplacebo.

3. **Wikipedia — Hybrid log–gamma**, [en.wikipedia.org/wiki/Hybrid_log%E2%80%93gamma](https://en.wikipedia.org/wiki/Hybrid_log%E2%80%93gamma). Summary of HLG parameters including the `α·Yscene^(γ-1)` OOTF form, iPhone HLG / DV Profile 8.4 note, and the backward-compatibility rationale.

4. **Wikipedia — Rec. 2100**, [en.wikipedia.org/wiki/Rec._2100](https://en.wikipedia.org/wiki/Rec._2100). Peak-luminance-aware system gamma, nominal 1000 cd/m² reference.

5. **BBC (Andrew Cotton) — An Introduction to Hybrid Log-Gamma HDR, Part 2: Format conversion and compositing**, W3C Wide Color Gamut / HDR Workshop 2021, [w3.org/Graphics/Color/Workshop/slides/talk/cotton2](https://www.w3.org/Graphics/Color/Workshop/slides/talk/cotton2). Original-authoring perspective on HLG conversion, including OOTF positioning relative to tone mapping.

6. **MovieLabs Best Practices for Mapping BT.2100 PQ to HLG**, [movielabs.com/ngvideo/MovieLabs_Mapping_PQ_to_HLG_v1.0.pdf](https://movielabs.com/ngvideo/MovieLabs_Mapping_PQ_to_HLG_v1.0.pdf). Good reference for why HLG and PQ are mapped differently; distinguishes scene-referred vs display-referred workflows.

7. **FFmpeg filter documentation — `zscale`**, [ffmpeg.org/ffmpeg-filters.html](https://www.ffmpeg.org/ffmpeg-filters.html) and v8.0.1 snapshot at [ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Video/zscale.html](https://ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Video/zscale.html). Source of supported transfer/primary/matrix names and `npl` parameter semantics.

8. **FFmpeg source — `libavfilter/vf_zscale.c`**, [ffmpeg.org/doxygen/trunk/vf__zscale_8c_source.html](https://ffmpeg.org/doxygen/trunk/vf__zscale_8c_source.html). Authoritative on the `npl` parameter implementation inside zimg's HLG path. S-6 must cross-check here before wiring.

9. **FFmpeg filter documentation — `libplacebo`**, v8.0.1 snapshot at [ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Video/libplacebo.html](https://ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Video/libplacebo.html). Parameters for `tonemapping=bt2390`, `intent`, `target_peak` etc.

10. **libplacebo options documentation**, [libplacebo.org/options/](https://libplacebo.org/options/). Tone-mapping parameter surface, including `bt2390` EETF description and `knee_offset` default of 1.0 (vs ITU spec 0.5).

11. **FFmpeg mailing list — HDR bt.2020 to SDR bt.709 conversion thread (2023-10)**, [ffmpeg.org/pipermail/ffmpeg-user/2023-October/057045.html](https://ffmpeg.org/pipermail/ffmpeg-user/2023-October/057045.html). Community-canonical zscale+tonemap filter chain. Shows the same linearize → float → gamut convert → tonemap → encode shape this doc adopts, plus a cautionary note on remaining color shifts.

12. **BinaryTides — Color grading HLG videos with FFmpeg**, [binarytides.com/color-grading-hlg-videos-with-ffmpeg/](https://www.binarytides.com/color-grading-hlg-videos-with-ffmpeg/). iPhone-centric HLG workflow, useful as a pragmatic reference; relies on a 3D LUT (`hlg2020_to_rec709.cube`) rather than zscale, which this doc rejects for a metadata-driven pipeline (§4.1).

13. **Eric Park — ffmpeg convert HDR to SDR**, [ericswpark.com/blog/2022/2022-12-14-ffmpeg-convert-hdr-to-sdr/](https://ericswpark.com/blog/2022/2022-12-14-ffmpeg-convert-hdr-to-sdr/). Tonemapper comparison (hable vs reinhard vs mobius) used to justify §4.3 default choice.

14. **mpv Issue #11461 — HLG should be scaled to target-peak following BT.2100 and BT.2390 specifications**, [github.com/mpv-player/mpv/issues/11461](https://github.com/mpv-player/mpv/issues/11461). Long-form discussion of BT.2100 HLG OOTF mechanics in an actual player implementation, with citations back to BT.2100-2 and BT.2390. Grounds the `npl` / target-peak discussion.

15. **Apple AV Foundation — HLG video notes** (via Apple Developer Forums / general doc search). Source of the "Apple HLG tags `arib-std-b67` + `bt2020` + `bt2020nc` + tv-range" behavior and of the Dolby Vision Profile 8.4 layering on iPhone 12+. Specific permalink is fragmented across WWDC video transcripts and forum threads; cite AVFoundation "Working with HDR video" session at WWDC when S-6 documents assumptions.

16. **Gemini CLI research pass (2026-04-24)**: ran `gemini "…ffmpeg で HLG…"` and got the same canonical filter chain shape and BT.2390-via-libplacebo recommendation. Used to cross-check WebSearch results rather than as a primary source. Not directly linkable.

---

End of Stream C design document. Pair with Stream B's PQ document before S-6 wiring. Pixel-changing work blocked on fixtures + HDR-capable ffmpeg (see handoff §9.1, §9.2).
