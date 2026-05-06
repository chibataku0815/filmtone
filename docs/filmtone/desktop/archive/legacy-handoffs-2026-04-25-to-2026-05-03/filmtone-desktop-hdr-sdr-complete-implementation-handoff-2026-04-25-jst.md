# Filmtone Desktop HDR->SDR Complete Implementation Handoff

- Date: 2026-04-25 JST
- Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- App: `apps/desktop-film-lab-batch`
- Current release truth checked from `life/scripts/check-filmtone-release-truth.sh`: public latest is Desktop `1.0.2`; current work is a `v1.0.3` candidate.
- Purpose: hand off the full context of the HDR warning problem, the interim edits already made, why they are not enough, and what must be implemented next so a normal user never sees developer-only ffmpeg instructions.

## 1. User Problem

The user loaded an HDR source in the local Desktop app and saw this callout:

```text
HDR ソースを検知しましたが、ffmpeg が線形化できません

この動画は HDR（PQ / HLG）ですが、お使いの ffmpeg ビルドには zscale / libplacebo が無いため、書き出し時の HDR→SDR トーンマッピングは保留されます。SDR クリップはそのまま書き出せます。

詳細:Local ffmpeg build lacks HDR transfer filters (zscale, libplacebo); leaving HDR HLG source unchanged until a zscale- or libplacebo-capable ffmpeg is available.

HDR 対応 ffmpeg に切り替えるには以下を実行:

brew tap homebrew-ffmpeg/ffmpeg && brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-zimg --with-libplacebo
```

The user's reaction was correct:

- Filmtone users are not developers.
- They should not be asked to run Homebrew commands.
- `ffmpeg`, `zscale`, `libplacebo`, and "linearize" are implementation details.
- If HDR input is supported, the app should handle it.
- If HDR input is not fully supported, the message must explain the practical effect only.

The user then asked why we did not "just implement it completely." The right answer is:

> Product-best behavior is to implement HDR->SDR conversion inside Filmtone, not to expose ffmpeg setup to users.

## 2. Important Repo State

There are existing dirty files not all owned by the HDR-notice work. Do not revert unrelated files.

Current `git status --short` at handoff time included:

```text
 M apps/desktop-film-lab-batch/electron/main.ts
 M apps/desktop-film-lab-batch/messages/en.json
 M apps/desktop-film-lab-batch/messages/ja.json
 M apps/desktop-film-lab-batch/src/renderer/App.tsx
 M apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.test.tsx
 M apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx
 M apps/desktop-film-lab-batch/test/golden.harness.ts
 M apps/desktop-film-lab-batch/test/golden.spec.ts
 M docs/filmtone-desktop-v1.0.3-qa-handoff-2026-04-24-jst.md
?? apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts
?? apps/desktop-film-lab-batch/src/renderer/effective-export-grade.ts
```

Files clearly touched for this HDR notice / tone-map discussion:

- `apps/desktop-film-lab-batch/electron/main.ts`
- `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx`
- `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.test.tsx`
- `apps/desktop-film-lab-batch/messages/ja.json`
- `apps/desktop-film-lab-batch/messages/en.json`
- `docs/filmtone/desktop/filmtone-desktop-v1.0.3-qa-handoff-2026-04-24-jst.md`

Likely unrelated pre-existing / parallel work:

- `apps/desktop-film-lab-batch/src/renderer/App.tsx`
- `apps/desktop-film-lab-batch/test/golden.harness.ts`
- `apps/desktop-film-lab-batch/test/golden.spec.ts`
- `apps/desktop-film-lab-batch/src/renderer/effective-export-grade.ts`
- `apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts`

There is also an unrelated verification blocker:

```text
packages/film-lab-core/dist/index.d.ts(1529,1): error TS1185: Merge conflict marker encountered.
packages/film-lab-core/dist/index.d.ts(1531,1): error TS1185: Merge conflict marker encountered.
packages/film-lab-core/dist/index.d.ts(1533,1): error TS1185: Merge conflict marker encountered.
packages/film-lab-core/dist/index.d.ts(1535,1): error TS1185: Merge conflict marker encountered.
```

This caused full Desktop `tsc` and `git diff --check` to fail. Treat it as an existing generated-dist conflict-marker issue unless you confirm it belongs to your work.

## 3. What Is Already Implemented In The Codebase

Before this handoff, the codebase already had a substantial partial HDR pipeline:

### 3.1 Source Metadata Detection

Main files:

- `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts`
- `apps/desktop-film-lab-batch/electron/main.ts`

Capabilities:

- Reads ffprobe stream metadata.
- Classifies color as:
  - `sdr-bt709`
  - `hdr-pq`
  - `hdr-hlg`
  - `wide-gamut-unknown`
  - `unknown`
- Detects:
  - PQ via `color_transfer=smpte2084`
  - HLG via `color_transfer=arib-std-b67`
  - BT.2020 / HDR-adjacent metadata
  - display rotation
  - source frame-rate trust
- Writes `sourceVideoMetadata` into sidecar JSON.

### 3.2 ffmpeg Capability Probe

Main files:

- `apps/desktop-film-lab-batch/electron/ffmpeg-capability-probe.ts`
- `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts`

Capabilities:

- Runs `ffmpeg -hide_banner -filters`.
- Parses whether local ffmpeg has:
  - `zscale`
  - `libplacebo`
  - `tonemap`
  - `colorspace`
- Existing policy treats HDR conversion as blocked unless either:
  - `zscale && tonemap`, or
  - `libplacebo`

Local observation on this machine:

```bash
/opt/homebrew/bin/ffmpeg -hide_banner -filters 2>/dev/null | rg '\b(zscale|libplacebo|tonemap|colorspace)\b' || true
```

Output:

```text
 TS colorspace        V->V       Convert between colorspaces.
 .S tonemap           V->V       Conversion to/from different dynamic ranges.
```

So the local ffmpeg has `colorspace` and `tonemap`, but not `zscale` or `libplacebo`. That is not enough for the intended HDR->SDR chain.

### 3.3 HDR Policy

Main file:

- `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts`

Core function:

```ts
deriveDesktopHdrPreparationPolicy(...)
```

Important behavior:

- SDR returns `strategy: "none"`.
- HDR PQ / HLG returns `strategy: "prepare-sdr-mezzanine"` when capability is sufficient.
- If capability is insufficient, returns:

```ts
{
  strategy: "defer-unknown",
  reason: "ffmpeg-missing-hdr-filters",
  requiresFixtureValidation: true,
  warning: "Local ffmpeg build lacks ..."
}
```

The `warning` string is useful for logs / sidecar / debugging, but must not be shown directly to normal users.

### 3.4 HDR Filter Chain Builders

Main file:

- `apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.ts`

Core functions:

- `buildHdrToSdrFilterChain(...)`
- `buildFfmpegMezzanineVideoFilter(...)`

Implemented candidate chains:

- PQ via zscale + tonemap:

```text
zscale=tin=smpte2084:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=100,
format=gbrpf32le,
zscale=p=709,
tonemap=tonemap=hable:desat=0,
zscale=t=709:m=709:r=tv,
scale=<outW>:-2,
format=yuv420p
```

- HLG via zscale + tonemap:

```text
zscale=tin=arib-std-b67:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=100,
format=gbrpf32le,
zscale=p=709,
tonemap=tonemap=mobius:desat=0,
zscale=t=709:m=709:r=tv,
scale=<outW>:-2,
format=yuv420p
```

- libplacebo candidate:

```text
libplacebo=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv:tonemapping=bt.2390:gamut_mode=perceptual,
scale=<outW>:-2,
format=yuv420p
```

### 3.5 Mezzanine Transcode Path

Main file:

- `apps/desktop-film-lab-batch/electron/main.ts`

Important function:

```ts
buildFfmpegMezzanineArgs(...)
```

Behavior:

- Creates H.264 all-I-frame mezzanine.
- If `hdrFilterSelection` exists, uses software path and injects HDR->SDR filter chain.
- Adds BT.709 metadata for the mezzanine when HDR filter is used.

Renderer export pipeline:

- `apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts`

It already checks:

```ts
const shouldToneMapHdrToSdr =
  sourceHdrPreparationPolicy?.strategy === "prepare-sdr-mezzanine" &&
  hdrFilterSelection != null;
```

If true, it calls `api.videoExportTranscodeMezzanine(...)`.

## 4. Critical Gap

The existing implementation had two major product gaps:

### Gap A: HDR tone-map was disabled by default

Before interim edit:

```ts
const ENABLE_HDR_TONEMAP =
  process.env.FILM_LAB_ENABLE_HDR_TONEMAP === "1" ||
  process.env.FILM_LAB_ENABLE_HDR_TONEMAP === "true";
```

This means normal users never got the HDR filter chain unless a developer env var was set.

Interim edit changed it to default-on unless explicitly disabled:

```ts
const ENABLE_HDR_TONEMAP =
  process.env.FILM_LAB_ENABLE_HDR_TONEMAP !== "0" &&
  process.env.FILM_LAB_ENABLE_HDR_TONEMAP !== "false";
```

This is better, but still not complete because the app still depends on the user's local ffmpeg having the right filters.

### Gap B: Filmtone does not guarantee HDR-capable ffmpeg

`apps/desktop-film-lab-batch/electron/ffmpeg-cli-resolve.ts` says explicitly:

```text
@limitations いまは同梱バイナリ（process.resourcesPath 配下）は扱いません。
将来バンドルする場合は、この resolver の優先順位に追加します。
```

Current resolver order:

1. `FILM_LAB_FFMPEG_PATH` / `FILM_LAB_FFPROBE_PATH`
2. fixed GUI `PATH`
3. known Homebrew / system dirs

It does not search app-bundled `ffmpeg` / `ffprobe`.

Therefore a normal installed app can still hit `ffmpeg-missing-hdr-filters`, depending on the user's machine.

This is why the UI-only fix is not a full implementation.

## 5. Interim Edits Already Applied

These edits were made during the conversation. Keep, refine, or replace them intentionally.

### 5.1 Default-enable HDR tone-map selection

File:

- `apps/desktop-film-lab-batch/electron/main.ts`

Change:

```diff
-const ENABLE_HDR_TONEMAP =
-  process.env.FILM_LAB_ENABLE_HDR_TONEMAP === "1" ||
-  process.env.FILM_LAB_ENABLE_HDR_TONEMAP === "true";
+const ENABLE_HDR_TONEMAP =
+  process.env.FILM_LAB_ENABLE_HDR_TONEMAP !== "0" &&
+  process.env.FILM_LAB_ENABLE_HDR_TONEMAP !== "false";
```

Intent:

- Use implemented HDR->SDR filter chain automatically when capabilities are present.
- Preserve an emergency disable with `FILM_LAB_ENABLE_HDR_TONEMAP=0`.

### 5.2 Remove developer-only notice UI

File:

- `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx`

Changes:

- Removed Homebrew install command constant.
- Removed copy-to-clipboard behavior.
- Removed fixture doc button.
- Removed raw `policy.warning` display from the UI.
- Left only a non-blocking, user-facing HDR caution.

Current user-facing copy:

Japanese:

```text
HDR動画を読み込みました

この環境では、HDR動画を標準のSDR動画として正確に変換できない場合があります。書き出しは続行できますが、他のアプリで見ると明るさや色が元動画と違って見えることがあります。正確な色で書き出したい場合は、カメラアプリや編集アプリでSDR動画に変換してから読み込んでください。
```

English:

```text
HDR video loaded

This environment may not be able to convert HDR video into a standard SDR video accurately. You can continue exporting, but brightness or color may look different in other apps. For color-critical exports, convert the clip to SDR in your camera app or editor before importing it.
```

This copy is acceptable only as fallback. It is not the desired final user experience.

### 5.3 Update tests

File:

- `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.test.tsx`

Changes:

- Removed tests for command copy behavior.
- Added assertions that user UI does not contain:
  - `brew`
  - `ffmpeg`
  - `zscale`
  - `libplacebo`
  - command block test id
  - copy button test id
  - fixture doc button test id

### 5.4 Update locale files

Files:

- `apps/desktop-film-lab-batch/messages/ja.json`
- `apps/desktop-film-lab-batch/messages/en.json`

Changes:

- Replaced technical HDR warning copy with user-facing copy.
- Removed unused command/copy/fixture translation keys.

### 5.5 Update QA handoff

File:

- `docs/filmtone/desktop/filmtone-desktop-v1.0.3-qa-handoff-2026-04-24-jst.md`

Changes:

- Removed QA expectation that a Homebrew command appears.
- Updated §5 to expect:
  - non-developer user warning in unsupported environment
  - automatic SDR mezzanine in supported environment
  - no `ffmpeg` / `zscale` / `libplacebo` / `brew` / fixture link in user UI

## 6. Verification Already Run

Command:

```bash
/opt/homebrew/bin/bun run --cwd apps/desktop-film-lab-batch test -- src/renderer/HdrPolicyNotice.test.tsx electron/video-export-source-metadata.test.ts electron/video-export-ffmpeg-args.test.ts
```

Result:

```text
Test Files  3 passed (3)
Tests       47 passed (47)
```

Full typecheck command:

```bash
/opt/homebrew/bin/bun run --cwd apps/desktop-film-lab-batch tsc -p tsconfig.json --noEmit
```

Result:

```text
failed because packages/film-lab-core/dist/index.d.ts contains merge conflict markers
```

This failure was not caused by the HDR notice edits, but it blocks final verification.

`git diff --check` also failed because of the same conflict markers in `packages/film-lab-core/dist/index.d.ts`.

## 7. What "Complete Implementation" Should Mean

Complete implementation means:

1. A normal user can drop an HDR PQ / HLG video.
2. Filmtone detects HDR source metadata.
3. Filmtone automatically creates an SDR-normalized mezzanine before render/export.
4. The user does not install anything.
5. The user does not see `ffmpeg`, `zscale`, `libplacebo`, Homebrew, or fixture docs.
6. The output is tagged BT.709 SDR.
7. The output does not show obvious HDR failure modes:
   - clipped highlights
   - washed-out color
   - crushed blacks
   - severe gamma shift
8. The path is covered by fixture/integration tests and a manual QA checklist.

The most direct implementation path is:

- Bundle known-good `ffmpeg` and `ffprobe` binaries with Filmtone Desktop.
- Make `ffmpeg-cli-resolve.ts` prefer the bundled binaries.
- Ensure bundled binaries support either:
  - `zscale + tonemap`, or
  - `libplacebo`
- Keep local/system ffmpeg only as fallback or dev override.

## 8. Recommended Technical Plan

### Phase 1: Decide And Document Binary Strategy

Pick one:

1. Bundle `ffmpeg`/`ffprobe` with `zscale + tonemap`.
2. Bundle `ffmpeg`/`ffprobe` with `libplacebo`.
3. Use a native macOS AVFoundation/CoreImage/VideoToolbox HDR->SDR pipeline instead of ffmpeg.

Most practical short path for current code:

- Bundle ffmpeg/ffprobe and keep the existing zscale/libplacebo filter-chain code.

Important:

- Verify licensing before shipping. Bundling ffmpeg can trigger LGPL/GPL obligations depending on build flags. If using GPL components such as libx264 in the bundled binary, comply with GPL or choose an LGPL-compatible build. Do not treat this as a minor packaging detail.
- Verify code signing and notarization. Bundled binaries under `extraResources` must be executable, signed as needed, and usable from a hardened runtime app.

### Phase 2: Add Bundled Binary Resource Layout

Recommended resource layout:

```text
apps/desktop-film-lab-batch/resources/bin/darwin-arm64/ffmpeg
apps/desktop-film-lab-batch/resources/bin/darwin-arm64/ffprobe
```

Then add `extraResources` entries in `apps/desktop-film-lab-batch/package.json`, for example:

```json
{
  "from": "resources/bin/darwin-arm64",
  "to": "bin/darwin-arm64"
}
```

Do not hardcode only dev paths. In packaged app, the binaries should be resolved under `process.resourcesPath`.

### Phase 3: Update CLI Resolver

File:

- `apps/desktop-film-lab-batch/electron/ffmpeg-cli-resolve.ts`

Add resolver priority:

1. Explicit env override:
   - `FILM_LAB_FFMPEG_PATH`
   - `FILM_LAB_FFPROBE_PATH`
2. Bundled resource binary:
   - packaged: `path.join(process.resourcesPath, "bin", "darwin-arm64", binaryName)`
   - dev: likely `path.join(appRoot, "resources", "bin", "darwin-arm64", binaryName)` or an explicit resolver option for tests.
3. PATH search / Homebrew fallback.

Update `ResolvedVideoCliBinary["source"]` union to include something like `"bundled-resource"`.

Add tests in:

- `apps/desktop-film-lab-batch/electron/ffmpeg-cli-resolve.test.ts`

Required tests:

- env override still wins
- bundled binary wins before PATH
- PATH is fallback
- failure message does not tell users to use Homebrew in user-facing UI

### Phase 4: Keep HDR Tone-Map Default On

Keep:

```ts
const ENABLE_HDR_TONEMAP =
  process.env.FILM_LAB_ENABLE_HDR_TONEMAP !== "0" &&
  process.env.FILM_LAB_ENABLE_HDR_TONEMAP !== "false";
```

The env var should be an escape hatch, not a requirement.

### Phase 5: Make Unsupported Fallback Rare

After bundled ffmpeg exists, `ffmpeg-missing-hdr-filters` should happen only if:

- bundled binary missing/corrupt
- user explicitly overrides ffmpeg to a limited build
- unsupported platform
- packaged resource cannot execute

In that rare path, the simplified user notice is acceptable.

### Phase 6: Verify The Actual Pixel Path

Use existing fixtures:

```text
apps/desktop-film-lab-batch/fixtures/video/hdr/synthetic-pq-1s-20260424.mp4
apps/desktop-film-lab-batch/fixtures/video/hdr/synthetic-hlg-1s-20260424.mp4
apps/desktop-film-lab-batch/fixtures/video/sdr/synthetic-bt709-1s-20260424.mp4
```

Add/extend tests to verify:

- bundled ffmpeg capability probe sees required filters
- HDR PQ policy gets `prepare-sdr-mezzanine`
- HDR HLG policy gets `prepare-sdr-mezzanine`
- `filterSelection` is present
- `videoExportTranscodeMezzanine` receives source metadata and builds a filter chain
- output mezzanine metadata is BT.709 SDR

Manual QA:

- Load `HDR-PQ`
- Confirm no developer warning when bundled binary works
- Export
- Confirm log contains `HDR→SDR tone-map ... mezzanine`
- Confirm sidecar includes:
  - `sourceVideoMetadata.colorClass = hdr-pq`
  - `hdrPreparationPolicy.strategy = prepare-sdr-mezzanine`
  - `hdrPreparationPolicy.filterSelection`
- Inspect output visually for clipping/washout
- Repeat for `HDR-HLG`
- Repeat an SDR clip and confirm no HDR notice and no tone-map path

## 9. Recommended UX Policy

Final desired UX:

- If bundled HDR conversion works:
  - no warning
  - maybe a subtle log/status: "HDR video converted for standard SDR export"
- If conversion fails:
  - user-facing non-blocking warning only
  - no install command
  - no internal filter names
  - no fixture doc link
- If color-critical work:
  - tell user to use SDR source or convert in camera/editor only as fallback

Do not show:

- `ffmpeg`
- `ffprobe`
- `zscale`
- `libplacebo`
- `brew`
- `linearize`
- raw `policy.warning`

## 10. Why The Interim Work Was Not Enough

The interim work fixed two visible problems:

1. It removed developer-only command UI.
2. It made the existing HDR filter selection default-on when the local environment supports it.

But it did not guarantee the core capability. The app still relies on a machine-local ffmpeg. On this machine, local ffmpeg lacks `zscale` and `libplacebo`, so the actual full HDR->SDR conversion cannot run through the existing chain.

Therefore:

- UI text fix = necessary but not sufficient.
- Default-on flag = necessary but not sufficient.
- Bundled or native HDR conversion engine = required for product-complete implementation.

## 11. Commands For Next Agent

Run targeted tests:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch test -- src/renderer/HdrPolicyNotice.test.tsx electron/video-export-source-metadata.test.ts electron/video-export-ffmpeg-args.test.ts
```

Run Desktop typecheck after resolving the unrelated dist conflict marker:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch tsc -p tsconfig.json --noEmit
```

Run local Desktop app:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch dev
```

Check local ffmpeg filters:

```bash
/opt/homebrew/bin/ffmpeg -hide_banner -filters 2>/dev/null | rg '\b(zscale|libplacebo|tonemap|colorspace)\b' || true
```

## 12. Do Not Do

- Do not revert unrelated dirty files.
- Do not leave Homebrew commands in user-facing UI.
- Do not make HDR tone-map depend on an opt-in dev env var.
- Do not call this complete until the app guarantees the conversion engine.
- Do not claim pixel correctness without running real PQ and HLG fixture output through the export path.
- Do not silently pass HDR through unchanged while presenting the output as accurate SDR.

## 13. Highest-Precision Handoff Prompt

Use the following prompt in a new chat:

```text
You are working in the repo:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

Goal:
Finish Filmtone Desktop HDR->SDR handling for the v1.0.3 candidate so normal users never see developer-only ffmpeg/Homebrew instructions and HDR PQ/HLG sources are converted automatically when exported.

Read this handoff first:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone-desktop-hdr-sdr-complete-implementation-handoff-2026-04-25-jst.md

Current product decision:
- Best solution is complete implementation, not warning users to install ffmpeg.
- Filmtone should own the HDR->SDR conversion path.
- User-facing UI must not mention ffmpeg, zscale, libplacebo, Homebrew, fixture docs, or raw internal warnings.
- If HDR conversion is unavailable, show only a practical non-blocking warning about possible color/brightness differences and suggest importing SDR for color-critical work.

Important existing architecture:
- Source metadata classification lives in apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts.
- ffmpeg capability probe lives in apps/desktop-film-lab-batch/electron/ffmpeg-capability-probe.ts.
- ffmpeg args / HDR filter chain builders live in apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.ts.
- Mezzanine transcode path lives in apps/desktop-film-lab-batch/electron/main.ts.
- Video export pipeline triggers HDR mezzanine when sourceHdrPreparationPolicy.strategy === "prepare-sdr-mezzanine" and filterSelection exists.
- HdrPolicyNotice lives in apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx.
- Locale strings live in apps/desktop-film-lab-batch/messages/ja.json and en.json.

Current interim edits already applied:
- main.ts changed FILM_LAB_ENABLE_HDR_TONEMAP to default-on unless set to 0/false.
- HdrPolicyNotice.tsx removed Homebrew command/copy/fixture-doc/raw-warning UI.
- ja/en strings changed to user-facing HDR fallback copy.
- HdrPolicyNotice.test.tsx now asserts no brew/ffmpeg/zscale/libplacebo/command UI leaks.
- docs/filmtone-desktop-v1.0.3-qa-handoff-2026-04-24-jst.md was updated to remove command-copy QA and expect automatic tone-map where supported.

Current verification:
- Targeted tests passed:
  /opt/homebrew/bin/bun run --cwd apps/desktop-film-lab-batch test -- src/renderer/HdrPolicyNotice.test.tsx electron/video-export-source-metadata.test.ts electron/video-export-ffmpeg-args.test.ts
  Result: 3 files passed, 47 tests passed.
- Full tsc currently fails because packages/film-lab-core/dist/index.d.ts contains merge conflict markers at lines around 1529/1531/1533/1535. Treat this as an existing generated-dist conflict issue unless proven otherwise.
- Local /opt/homebrew/bin/ffmpeg has colorspace and tonemap but lacks zscale/libplacebo, so it cannot validate the intended HDR chain.

Dirty worktree caution:
Do not revert unrelated dirty files. Current dirty files include App.tsx, golden harness/spec, and new effective-export-grade files that are likely unrelated/parallel work.

Implementation target:
1. Bundle or otherwise provide a known-good HDR-capable ffmpeg/ffprobe with the Desktop app, or implement an equivalent native macOS HDR->SDR conversion engine.
2. Prefer the bundled conversion engine in ffmpeg-cli-resolve.ts before PATH/Homebrew, while keeping env override first.
3. Ensure bundled binary supports zscale+tonemap or libplacebo.
4. Preserve FILM_LAB_ENABLE_HDR_TONEMAP=0 as an emergency disable, but default HDR conversion on.
5. Verify HDR PQ and HLG produce prepare-sdr-mezzanine with filterSelection and create an SDR BT.709 mezzanine before export.
6. Keep user-facing UI free of implementation details.
7. Update tests and QA docs accordingly.

Recommended concrete implementation path:
- Add resource layout under apps/desktop-film-lab-batch/resources/bin/darwin-arm64/ffmpeg and ffprobe, or equivalent.
- Add package.json extraResources entry to package those binaries.
- Update ffmpeg-cli-resolve.ts source union to include "bundled-resource".
- Add resolver tests proving env override wins, bundled binary beats PATH, PATH remains fallback.
- Add capability/policy tests proving bundled-capable ffmpeg leads to source-is-hdr-pq/source-is-hdr-hlg with filterSelection.
- Run real fixture smoke for synthetic-pq-1s and synthetic-hlg-1s.
- Make sure packaged app signing/notarization can execute the bundled binaries.
- Check ffmpeg licensing before shipping. If using GPL components, comply or choose an LGPL-compatible build.

Verification commands:
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch test -- src/renderer/HdrPolicyNotice.test.tsx electron/video-export-source-metadata.test.ts electron/video-export-ffmpeg-args.test.ts
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch tsc -p tsconfig.json --noEmit
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch dev

Deliverable:
Implement the complete HDR->SDR path so a normal Desktop user can load/export HDR PQ/HLG without installing tools or seeing developer instructions. Then provide a concise summary of files changed, tests run, and any remaining product/packaging/licensing blockers.
```
