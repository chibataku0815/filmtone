# Filmtone Metadata-Driven Export Quality — Capability Probe Session Handoff

Last updated: 2026-04-24
Authoring context: Claude Code desktop session (2026-04-24 PM)
Primary repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
Base branch during work: `main`
Session scope: `apps/desktop-film-lab-batch` + shared `film-lab-core` type mirror (no renderer pipeline changes, no pixel-changing work).

This document is the complete snapshot of the 2026-04-24 capability-probe session. Reading this doc alone should be enough to continue the Metadata-Driven Export Quality program in a fresh chat without re-reading the earlier strategy / previous handoff docs. Pointers to those prior docs are collected in §11.

## 1. What this session changed in one sentence

The HDR preparation policy now receives a local-ffmpeg capability snapshot and, for PQ / HLG sources on an ffmpeg build that lacks both `zscale` and `libplacebo`, returns `strategy="defer-unknown"` with reason `"ffmpeg-missing-hdr-filters"` — pixels are still unchanged, but the reason for deferring is now explicit in sidecar, bridge type, and export log.

## 2. Program context entering the session

### 2.1 Multi-session initiative
This session is the fourth in a chain of Codex/Claude sessions under the program “Filmtone Metadata-Driven Export Quality”:

| session | output |
|---|---|
| S-1 | Strategy doc + P0-A (display geometry) + P0-B (source color classification) |
| S-2 | P1-A (sidecar normalization) + P1-B (frame-timing diagnostics) |
| S-3 | P0-C pure helper `deriveDesktopHdrPreparationPolicy` + sidecar/log visibility |
| **S-4 (this session)** | FFmpeg HDR capability probe + capability-aware policy gating + fixture/capability inventory |

S-1..S-3 were Codex sessions. S-4 is a Claude Code session started from the two docs the user pasted at the top of the chat (`...plan-2026-04-24.md` and `...workplan-handoff-2026-04-24.md`).

### 2.2 Program invariants (never broken in this session)
- Metadata is evidence of capture / container, not a license to override user creative intent.
- No pixel-changing change without real fixtures.
- Camera profile (input LUT) and optical / capture metadata stay separated.
- Export FPS behavior is not touched while metadata diagnostics are in flight.
- Timed telemetry tracks (GPMF / CAMM) are inventory-only — never copied to rendered exports.
- Sidecar schema must remain backward-compatible (old sidecars must still parse).

### 2.3 State at session start

Previous handoff claimed:
- On branch `main`, 9 commits ahead of `origin/main`, ending at `aa2a21e5 Surface HDR preparation policy metadata`.
- Non-metadata dirty files pending in `packages/film-lab-renderer/src/webgpu/...`.

What the session actually observed on 2026-04-24:
- On `main`, **17 ahead** of `origin/main` after this session’s two commits.
- The dirty WebGPU files had since been committed into the depth-aware cross filter chain. Working tree was clean when the session started.
- Tip before this session: `1d32b848 Finalize cross filter runtime follow-ups`.

This divergence matters: the "guardrail: do not touch dirty WebGPU files" from the previous handoff was obsolete — the files were no longer dirty. The guardrail itself still applies in spirit (stay scoped to metadata work), but no new reverting was needed.

## 3. Decision record for this session

### 3.1 User prompt
The user pasted two file paths (the prior plan + handoff) and then said "推奨で進めてください / 適度なタイミングで次のチャットに引き継ぎたいのでそのタイミングになったら教えてください / また私の動作確認が必要な際も教えてください".

### 3.2 Decision 1 — Ordering of the three sub-tasks proposed
The assistant presented three candidate next steps:
1. Capability probe + policy degradation (no pixel change)
2. Fixture collection plan (location + naming)
3. Inventory doc consolidating §1 and §2

The user chose "推奨で進めてください" and the recommended order `1 → 3 → 2` was executed.

Rationale recorded in-session:
- Without resolving the ffmpeg build gap (no `zscale`, no `libplacebo`), even perfect HDR fixtures cannot drive a correct pixel path. So capability probing must land first.
- Inventory doc (§3) consolidates the findings immediately, so the next chat has one artifact to read.
- Fixture collection (§2) is last because it needs user action (recording or trimming footage) and cannot be completed inside a single session anyway.

### 3.3 Decision 2 — Capability-aware policy shape
Instead of coupling the policy module to a runtime probe (which would pull `node:child_process` into a module imported by the renderer surface), the capability data is modeled as a pure shape:

```ts
export type FFmpegHdrCapabilities = {
  hasZscale: boolean;
  hasLibplacebo: boolean;
  hasTonemap: boolean;
  hasColorspace: boolean;
};
```

Lives in `electron/video-export-source-metadata.ts`. The runtime probe lives in a sibling file and only *imports the type*, keeping the dependency arrow one-way.

### 3.4 Decision 3 — New reason variant, not a new field
Rather than add a new boolean or nested field to `HdrPreparationPolicy`, the extension was a single new reason variant `"ffmpeg-missing-hdr-filters"` on the existing union. This kept the sidecar schema migration trivial (one Zod enum addition in one place) and reuses the existing `warning` string for human-readable detail.

### 3.5 Decision 4 — Lazy, scoped probe
The capability probe is only invoked when `sourceVideoMetadata.colorClass` is `hdr-pq` or `hdr-hlg`. For SDR / unknown / wide-gamut-unknown, no ffmpeg resolution is attempted — so SDR import paths incur zero new cost. Result is cached per `commandPath`.

### 3.6 Decision 5 — No push
User asked for "commit and merge to main". Since work was on `main` already, no merge was needed. `push` was explicitly **not** performed (out of scope per user instructions). All commits remain local.

## 4. FFmpeg capability finding (2026-04-24)

### 4.1 Environment
- binary: `/opt/homebrew/bin/ffmpeg`
- version: `ffmpeg 8.0.1` (Homebrew bottle, default build, Apple Silicon)
- probe command: `ffmpeg -hide_banner -filters`

### 4.2 Available vs missing HDR filters

| filter | status | role in an HDR→SDR chain |
|---|---|---|
| `tonemap` | ✅ available | applies hable/mobius/reinhard tone curves in linear-light GBRAPF32 |
| `colorspace` | ✅ available | matrix/primaries conversion only — **does not handle transfer characteristic** |
| `zscale` | ❌ **missing** | canonical PQ EOTF inverse and HLG OOTF path (requires libzimg linkage) |
| `libplacebo` | ❌ **missing** | BT.2390 tone mapping / GPU-assisted alternative |

### 4.3 Practical implication
Without `zscale` or `libplacebo`, no filter in this ffmpeg build can linearize a PQ source correctly. `colorspace` ignores transfer. `tonemap` expects pre-linearized input. → A pixel-changing HDR-to-SDR preparation cannot be written safely against this build. This was the trigger to land the capability guard *before* any filter-chain wiring.

## 5. Code changes landed in this session

Two commits on `main`:

| SHA | subject | files |
|---|---|---|
| `0add4987` | Probe ffmpeg HDR capabilities and gate preparation policy | 8 files, +518 / -5 |
| `2ff8f6e2` | Document HDR fixture inventory and seed fixtures skeleton | 2 files, +297 |

### 5.1 New files

- `apps/desktop-film-lab-batch/electron/ffmpeg-capability-probe.ts`
  - `parseFfmpegFilterList(stdout) → FFmpegHdrCapabilities` — pure parser for `ffmpeg -hide_banner -filters` lines (`^\s*[.A-Z]{2,4}\s+([A-Za-z0-9_]+)\s+\S+->\S+`).
  - `supportsHdrToSdrPreparation(caps) → boolean` — true iff `hasZscale || hasLibplacebo`.
  - `summarizeMissingHdrFilters(caps) → string` — comma-joined missing names for warning copy.
  - `probeFfmpegHdrCapabilities({ commandPath, env?, runner? }) → Promise<FFmpegHdrCapabilities>` — caches per `commandPath`; failures resolve to an all-false capability rather than throwing.
  - `__resetFfmpegHdrCapabilityCacheForTesting()` — test-only cache reset.

- `apps/desktop-film-lab-batch/electron/ffmpeg-capability-probe.test.ts`
  - Parse cases: Homebrew default (tonemap + colorspace only), zimg-enabled sample, libplacebo-enabled sample, empty output.
  - `supportsHdrToSdrPreparation` truth table for zscale / libplacebo.
  - `summarizeMissingHdrFilters` for both-missing and both-present.
  - `probeFfmpegHdrCapabilities` behavior: injected runner invokes `ffmpeg -hide_banner -filters`, per-path cache prevents re-runs, runner failure returns all-false.

- `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hdr-fixture-inventory-2026-04-24.md`
  - Capability state + fixture state + §6 user runbook for upgrading ffmpeg.

- `apps/desktop-film-lab-batch/fixtures/README.md`
  - Directory layout `fixtures/video/{hdr,sdr}/`.
  - Fixture requirements (length ≤ 2 s, size < 5 MB, no people/GPS).
  - Per-fixture sidecar: `<basename>.ffprobe.json` with a minimal expected ffprobe snippet.
  - Capture recipes for iPhone HLG, HDR10/PQ, SDR BT.709.
  - Privacy/licensing rules.

### 5.2 Modified files

- `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts`
  - Added `FFmpegHdrCapabilities` type.
  - Added reason variant `"ffmpeg-missing-hdr-filters"` to `HdrPreparationPolicy["reason"]`.
  - Added private helpers `missingHdrFilterList(caps)` and `ffmpegCapabilityBlocksHdrPrep(caps)` (latter is true only when caps is non-null and both zscale and libplacebo are missing — so a null capability leaves existing behavior intact).
  - `deriveDesktopHdrPreparationPolicy` signature is now `(sourceVideoMetadata, capabilities?)`. PQ and HLG branches consult capabilities; when blocked, they return `strategy: "defer-unknown"` / `reason: "ffmpeg-missing-hdr-filters"` / `requiresFixtureValidation: true` / a warning that lists the missing filters and names the transfer (PQ or HLG).

- `apps/desktop-film-lab-batch/electron/video-export-source-metadata.test.ts`
  - Five new cases in the `desktop HDR preparation policy` describe: PQ-missing, HLG-missing, PQ-zscale-present, HLG-libplacebo-present, SDR-ignores-capabilities.

- `apps/desktop-film-lab-batch/electron/main.ts`
  - New helper `resolveFfmpegHdrCapabilitiesIfNeeded(colorClass)` — returns `null` for non-HDR classes; for `hdr-pq` / `hdr-hlg`, calls `resolveVideoCliBinary("ffmpeg")` and `probeFfmpegHdrCapabilities`. Failures are logged under `DEBUG_VIDEO_EXPORT_MAIN` and return `null` (preserving existing behavior).
  - Wired into `ffprobeVideoMeta` just before `deriveDesktopHdrPreparationPolicy` is called.
  - Imports: added `FFmpegHdrCapabilities` type + `probeFfmpegHdrCapabilities` runtime function.

- `apps/desktop-film-lab-batch/electron/preload.ts`
  - Added `"ffmpeg-missing-hdr-filters"` to the `HdrPreparationPolicy` reason union (IPC type mirror).

- `apps/desktop-film-lab-batch/src/renderer/desktop-api.d.ts`
  - Same reason-union addition (ambient type for renderer).

- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts`
  - Added `"ffmpeg-missing-hdr-filters"` to the Zod enum `hdrPreparationPolicySchema.reason`. Backward compatibility of existing sidecars is preserved (the enum only *adds* a variant).

### 5.3 Files intentionally NOT changed

- `apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.ts` — no filter-chain change.
- `apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts` — log line continues to describe policy opaquely; the new reason variant flows through `reason=${...}` untouched.
- iOS app, other desktop apps, film-lab-renderer — untouched.

## 6. Verification

All three verification steps green on the last run before committing:

```bash
bun run --cwd apps/desktop-film-lab-batch test
# Vitest: 31 files / 196 tests passed (+17 tests vs S-3: 179 → 196)

bun run --cwd apps/desktop-film-lab-batch build:electron
# passed

bun run --cwd apps/desktop-film-lab-batch build:renderer
# passed (chunk-size warning is pre-existing, not related to this session)
```

Known non-blocking: `bunx tsc -p apps/desktop-film-lab-batch/tsconfig.json --noEmit` is still not the verification path — it stops on the pre-existing CSS side-effect import issue in `src/renderer/main.tsx`. Keep using the three commands above.

## 7. Git state at the end of the session

```
Current branch: main
Working tree: clean
main...origin/main [ahead 17]

tip:
  2ff8f6e2 Document HDR fixture inventory and seed fixtures skeleton
  0add4987 Probe ffmpeg HDR capabilities and gate preparation policy
  1d32b848 Finalize cross filter runtime follow-ups
  ff9bcc0b Cover cross filter hidden control schema defaults
  9916ae38 Pass depth controls into cross filter streak pass
```

No worktrees were used (confirmed with `git worktree list` — single entry pointing at the main checkout). `push` was not performed and is out of scope until the user asks.

Important cross-reference: commits since S-3 (`aa2a21e5`) that are **not** metadata-driven-export related:
- `6f41a3e6 Tune depth-aware optical rendering controls`
- `19e30188 Wire depth-aware cross filter shader controls`
- `9916ae38 Pass depth controls into cross filter streak pass`
- `ff9bcc0b Cover cross filter hidden control schema defaults`
- `1d32b848 Finalize cross filter runtime follow-ups`

These are the depth-aware cross-filter stream and should not be mixed into metadata work. Next sessions should continue to treat these as a separate parallel thread (they're also tracked on the life repo as untracked `scripts/filmtone_cross_filter_probe.py` / `scripts/filmtone_ray_angle_probe.py` / related plan docs).

## 8. Program roadmap (updated)

```
[done S-1] P0-A display geometry normalization
[done S-1] P0-B source color / HDR classification (pure)
[done S-2] P1-A source metadata sidecar serialization
[done S-2] P1-B frame-timing diagnostics
[done S-3] P0-C policy pure helper + sidecar / log visibility
[done S-4] FFmpeg HDR capability probe + capability-aware policy downgrade
[next    ] User action: install HDR-capable ffmpeg on dev machine (§9.1) — optional for fixture collection; mandatory before any pixel-changing HDR wiring.
[next    ] User action: capture privacy-safe 1–2 s fixtures for HLG, PQ, SDR BT.709.
[next    ] Integration test that ffprobes each fixture and asserts classification + policy branch.
[later   ] P0-C pixel-changing wiring: start with PQ alone, fixture-backed. Do not touch export FPS.
[later   ] P2-A FOV / focal-length-aware optical recommendations (recommendation-only, opt-in, never change input LUT).
[later   ] P2-B camera/lens profile research (needs per-family fixtures).
[later   ] P3 gyro / IMU / rolling-shutter inventory (inventory-only unless Filmtone expands into motion-metadata processing).
```

## 9. User action pending (what must happen before the next implementation push)

### 9.1 Install an HDR-capable ffmpeg on the dev machine (runbook)

Homebrew’s default `ffmpeg` bottle no longer ships `libzimg` or `libplacebo`. Options:

**Option A — homebrew-ffmpeg tap (recommended for the dev machine)**

```bash
brew tap homebrew-ffmpeg/ffmpeg
brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-libzimg --with-libplacebo
brew link --overwrite homebrew-ffmpeg/ffmpeg/ffmpeg   # if a previous ffmpeg is linked
ffmpeg -filters | grep -E 'zscale|libplacebo'
```

Both `zscale` and `libplacebo` should appear. After restarting Filmtone Desktop, the next HDR import should log `reason=source-is-hdr-pq` (or `-hlg`) with `strategy=prepare-sdr-mezzanine` instead of `reason=ffmpeg-missing-hdr-filters`. Pixels still do not change until the filter chain is wired.

**Option B — static build (BtbN / johnvansickle)**
- Reproducible, includes zimg+libplacebo.
- Manual install, licensing check needed for redistribution.

**Option C — self-compile with `--enable-libzimg --enable-libplacebo`**
- Full control, high maintenance cost.

**Option D — bundle ffmpeg inside the Electron app**
- End-user transparent, but app-size / signing / notarization overhead.
- Requires extending `ffmpeg-cli-resolve.ts` to prefer `process.resourcesPath` first.
- Not for this phase — document as the eventual production answer separately.

The final answer for end-user Filmtone Desktop is out of scope for this session. Dev-machine Option A is the unblocker for the next step.

**Environment overrides** (already supported — no change needed):
```bash
export FILM_LAB_FFMPEG_PATH=/path/to/custom/ffmpeg
export FILM_LAB_FFPROBE_PATH=/path/to/custom/ffprobe
```

### 9.2 Record fixtures

Target directory: `apps/desktop-film-lab-batch/fixtures/video/{hdr,sdr}/`.
Exact recipes are in `apps/desktop-film-lab-batch/fixtures/README.md`.

Minimum set (one of each):
- `iphone-hlg-1s-<hash>.mov` — iPhone with HDR Video ON. HLG transfer. 1–2 s.
- `generic-pq-1s-<hash>.mp4` — any HDR10 / PQ source (iPhone ProRes LOG on 15 Pro+, or another PQ-capable camera; S1II is **not** PQ-capable).
- `s1ii-bt709-1s-<hash>.mp4` — any BT.709 SDR clip.

Each fixture must be accompanied by `<basename>.ffprobe.json` with the minimal expected stream / format snippet used as the oracle.

No people, no identifiable landmarks. Strip GPS with `exiftool -GPS*:all= fixture.mov` before committing.

### 9.3 Push vs keep local

Currently `main...origin/main [ahead 17]`. Push is not done. When the user wants CI coverage, push; otherwise keep local is fine for subsequent sessions.

## 10. Guardrails for the next chat (consolidated)

From S-3 and still in force, plus S-4 additions:

1. Do not wire any pixel-changing HDR tone mapping without real PQ/HLG fixtures.
2. Do not change export FPS behavior. 24fps CFR remains the default.
3. Do not auto-select camera profile / input LUT from `make` / `model` tags.
4. Do not copy GPMF / CAMM / gyro tracks into rendered exports.
5. Do not mix depth-aware cross-filter / ray-angle work into metadata commits; they are a separate parallel thread.
6. Sidecar schema evolutions must stay backward-compatible (new Zod enum variants are OK; removing variants is not).
7. When the policy requires data from a side-channel (like ffmpeg capability), keep the source-metadata module pure and inject data as arguments — do not pull `node:child_process` into modules shared with the renderer surface.
8. Any new runtime probe must cache per keyable identity (here: `commandPath`) and fail *soft* — returning `null` or an all-false snapshot — so import paths stay robust.
9. Update all four reason-union mirrors when adding a variant: `video-export-source-metadata.ts`, `preload.ts`, `src/renderer/desktop-api.d.ts`, `src/renderer/export-metadata-session.ts` (Zod).
10. Verification = `bun run --cwd apps/desktop-film-lab-batch test` + `build:electron` + `build:renderer`. `tsc --noEmit` is not the verification path because of the pre-existing CSS import typing issue in `main.tsx`.

## 11. Document chain and pointers

Read in this order if joining fresh:

1. **This doc** (session-level handoff, self-contained).
2. `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-plan-2026-04-24.md` — full strategy (P0..P3 roadmap).
3. `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hdr-fixture-inventory-2026-04-24.md` — capability + fixture inventory (§6 runbook duplicated here under §9.1 but the inventory doc stays as the standalone technical reference).
4. `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-workplan-handoff-2026-04-24.md` — previous (S-3) handoff. Some guardrails there about dirty WebGPU files are now stale — they have since been committed. Retain for historical continuity.

Implementation entry points:
- `apps/desktop-film-lab-batch/electron/ffmpeg-capability-probe.ts` — probe runtime + pure parser.
- `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts` — policy (now capability-aware) and all metadata types.
- `apps/desktop-film-lab-batch/electron/main.ts` — `resolveFfmpegHdrCapabilitiesIfNeeded` + `ffprobeVideoMeta`.
- `apps/desktop-film-lab-batch/electron/preload.ts` — IPC type mirror.
- `apps/desktop-film-lab-batch/src/renderer/desktop-api.d.ts` — renderer ambient type.
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts` — Zod schema mirror.
- `apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts` — consumes `sourceHdrPreparationPolicy` for export logs.

## 12. Self-contained handoff prompt for the next chat

Paste the block below into a fresh chat to continue. Everything the next chat needs is either in this prompt or in the docs it points to.

```text
Filmtone Metadata-Driven Export Quality の続きをお願いします。
対象 repo: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
Branch: main (origin/main の 17 コミット先行。push は未実行。)

直前セッション (S-4) の成果:
- FFmpeg HDR capability probe (electron/ffmpeg-capability-probe.ts) を新設。
  zscale / libplacebo の有無を ffmpeg -hide_banner -filters から検出、commandPath で cache。
- deriveDesktopHdrPreparationPolicy(sourceVideoMetadata, capabilities?) を拡張。
  hdr-pq / hdr-hlg で zscale も libplacebo も無い ffmpeg ビルドでは
  strategy="defer-unknown", reason="ffmpeg-missing-hdr-filters", 欠落 filter を warning に列挙。
  pixel は一切変えていない。
- reason union を 4 箇所 (video-export-source-metadata.ts / preload.ts /
  src/renderer/desktop-api.d.ts / export-metadata-session.ts の Zod enum) にミラー。
- main.ts に lazy capability probe (resolveFfmpegHdrCapabilitiesIfNeeded) を wire。
  SDR / unknown / wide-gamut-unknown では ffmpeg 解決もしない。
- apps/desktop-film-lab-batch/fixtures/ skeleton + README.md を追加 (HDR/SDR/capture recipe)。
- apps/desktop-film-lab-batch/docs/ に:
    * metadata-driven-export-quality-hdr-fixture-inventory-2026-04-24.md
    * metadata-driven-export-quality-capability-probe-session-handoff-2026-04-24.md (この prompt の元)
  を追加。
- コミット 2 本: 0add4987 + 2ff8f6e2。worktree 未使用。
- 検証: 31 files / 196 tests passed, build:electron / build:renderer 緑。

唯一のフル session-level handoff ドキュメント:
apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-capability-probe-session-handoff-2026-04-24.md

次にやる作業 (優先順):
1. ユーザが HDR-capable ffmpeg を dev 機に入れたかを確認
   (§9.1 runbook: homebrew-ffmpeg tap → zscale + libplacebo 両対応)。
   入っていれば capability probe の出力が変わる。
2. fixtures/video/{hdr,sdr}/ に実ファイルが到着したら、
   各 fixture の <basename>.ffprobe.json を作り、
   ffprobe → classify → policy の integration test を 1 本追加。
3. 揃ったら PQ 1 branch だけ fixture-backed で filter chain を wire する設計を起こす。
   export FPS は触らない。sidecar schema は backward-compatible のまま。
4. 並行して走っている depth-aware cross filter / ray angle 系 (scripts/filmtone_*) とは
   commit を混ぜない。metadata と filter chain の commit は必ず独立させる。

禁止事項:
- fixture 無しで PQ / HLG の filter chain を wire しない。
- camera profile / input LUT の自動切替をしない。
- export FPS 挙動を変えない。
- make/model からの distortion correction・LUT 選択をしない。
- GPMF / CAMM / gyro を rendered export に copy しない。
- reason union 追加時は 4 mirror (source-metadata / preload / desktop-api.d.ts / zod) 全てを更新する。
- git push は明示依頼が無い限りしない。

検証コマンド (tsc --noEmit は main.tsx の CSS import 型問題で止まるので不可):
bun run --cwd apps/desktop-film-lab-batch test
bun run --cwd apps/desktop-film-lab-batch build:electron
bun run --cwd apps/desktop-film-lab-batch build:renderer

参照:
- strategy: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-plan-2026-04-24.md
- 前回 (S-3) handoff: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-workplan-handoff-2026-04-24.md
- capability/fixture inventory: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hdr-fixture-inventory-2026-04-24.md
- この session の handoff: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-capability-probe-session-handoff-2026-04-24.md
```

## 13. Sanity checklist for the first 3 minutes of the next chat

Run these four commands. If any of them disagrees with the expected output below, pause and reconcile before writing code.

```bash
# 1) Branch + clean tree
git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio rev-parse --abbrev-ref HEAD
# expect: main

git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio status --short
# expect: (empty — unless user added fixtures or unrelated WIP)

# 2) Tip of main
git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio log --oneline -2
# expect:
#   2ff8f6e2 Document HDR fixture inventory and seed fixtures skeleton
#   0add4987 Probe ffmpeg HDR capabilities and gate preparation policy

# 3) FFmpeg capability truth
ffmpeg -hide_banner -filters | grep -E '\b(zscale|libplacebo)\b' || echo "still missing — §9.1 runbook pending"

# 4) Fast verify
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
bun run --cwd apps/desktop-film-lab-batch test
# expect: 31 files / 196 tests passed (baseline after S-4 — fixture-backed tests will raise this)
```

If `3` still reports missing filters, the next chat is in “inventory and fixture collection phase”. If it reports both, the next chat may move on to the PQ filter-chain design phase.

---

End of session handoff.
