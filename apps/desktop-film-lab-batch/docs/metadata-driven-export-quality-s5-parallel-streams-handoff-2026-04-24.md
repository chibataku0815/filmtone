# Filmtone Metadata-Driven Export Quality — S-5 Parallel Streams Session Handoff

Last updated: 2026-04-24 (evening)
Authoring context: Claude Code desktop session (2026-04-24 PM — life repo driving, work landed in `chibatakumi-portfolio`)
Primary repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
Base branch: `main`
Session scope: `apps/desktop-film-lab-batch` (fixture harness + renderer UX + two design docs). No pixel-changing work, no renderer pipeline changes.

This document is the complete snapshot of the 2026-04-24 S-5 parallel-streams session. Reading this doc alone should be enough to continue the Metadata-Driven Export Quality program in a fresh chat without re-reading S-1..S-4 handoffs. Pointers to those are in §10.

## 1. What this session changed in one sentence

Four parallel Agent Teams streams (A/B/C/D) produced the S-6 entry toolkit: a skip-gracefully fixture-driven integration test harness (A), a canonical PQ→SDR filter chain design doc (B), a canonical HLG→SDR filter chain design doc (C), and a renderer-side inline notice that surfaces `ffmpeg-missing-hdr-filters` to the user with a one-click copy-to-clipboard of the install command (D).

## 2. Program context entering this session

### 2.1 Multi-session initiative
| session | output |
|---|---|
| S-1 | Strategy doc + P0-A (display geometry) + P0-B (source color classification) |
| S-2 | P1-A (sidecar normalization) + P1-B (frame-timing diagnostics) |
| S-3 | P0-C pure helper + sidecar / log visibility |
| S-4 | FFmpeg HDR capability probe + capability-aware policy gating + fixture skeleton |
| **S-5 (this session)** | 4-stream parallel: fixture test harness + PQ design + HLG design + UX surface |

### 2.2 Program invariants (still unbroken)
- Metadata is evidence of capture / container, not a license to override user creative intent.
- No pixel-changing change without real fixtures.
- Camera profile (input LUT) and optical / capture metadata stay separated.
- Export FPS behavior is not touched while metadata diagnostics are in flight.
- Timed telemetry tracks (GPMF / CAMM) are inventory-only.
- Sidecar schema must remain backward-compatible.
- Metadata commits stay separate from the depth-aware cross-filter / ray-angle stream (which is a parallel thread, not in scope here).

### 2.3 State at session start
- On `main`, 18 ahead of `origin/main` (tip: `b09ab70f Add capability-probe session handoff for HDR work`).
- Working tree clean.
- `ffmpeg -hide_banner -filters` still shows only `tonemap` + `colorspace` — `zscale` and `libplacebo` remain absent, i.e. §9.1 of the S-4 handoff is still pending on the user side.
- `fixtures/video/{hdr,sdr}/` directories exist but are empty.

## 3. Decision record for this session

### 3.1 User prompt
User selected the operating mode explicitly:
- "A/B/C/D 4 並列で進めて" — authorized 4-stream parallel Agent Teams execution.
- "推奨で進めてください / 適度なタイミングで次のチャットに引き継ぎたいのでそのタイミングになったら教えてください" — ask for a clean handoff moment once the set is coherent.

### 3.2 Decision 1 — Run the 4 streams in true parallel on `main`
All 4 streams were dispatched as independent `Agent` calls in one message. The expected conflict surfaces (shared `fixtures/README.md`, shared `main` branch) were managed by having each agent `git add` absolute paths (not `.`) and commit only its own files. Stream B landed first, then A, then C, then D. Each picked up the previous tip. No merge conflicts; working tree stayed scoped per stream.

### 3.3 Decision 2 — Commit-per-stream on `main`, no push
Each agent landed its own local commit on `main`. Push was explicitly not performed and is out of scope until the user asks. `main` is now 22 commits ahead of `origin/main`.

### 3.4 Decision 3 — Design (B, C) now, implement (B, C) later
Streams B and C are pure research + design docs. They name the target ffmpeg filter strings, the capability-branching matrix, and the integration contract (`buildHdrToSdrFilterChain(selection)`), but do not land wiring. Wiring is deferred to S-6 when fixtures + HDR-capable ffmpeg are available. This respects invariant "no pixel-changing change without real fixtures".

### 3.5 Decision 4 — Stream A uses `describe.skipIf` + skip sentinel
Stream A's integration harness must not fail in CI when fixtures are absent. The implementation uses a two-layer approach:
- An always-on describe block for oracle-parser unit tests (zero-fixture-safe).
- A skip-gracefully describe block that only activates when `fixtures/video/**/*.{mov,mp4,mkv}` returns at least one entry, with a skip sentinel test printing guidance when empty.

This means the moment the user drops a fixture + oracle into the repo, the suite auto-fires without further wiring.

### 3.6 Decision 5 — Stream D is amber, not red; inline, not modal
Per the UX quality bar, the "your ffmpeg can't tonemap HDR" notice is rendered as an advisory amber callout (not a red error) inline beneath the probe label, not a blocking modal. SDR exports are unaffected. Copy button uses `navigator.clipboard.writeText` with a textarea fallback for Electron insecure-origin corners. The "open fixture doc" link is opt-in (requires a handler wired from App.tsx, currently deferred — marked as a follow-up).

### 3.7 Decision 6 — End the session here (this doc)
After the 4 streams landed and all three verification commands went green, the natural end-of-session boundary is: close with a handoff doc rather than open more streams. The remaining value-add work (filter-chain stub types, ffmpeg bundling research, fixture-doc link wiring) is better scheduled for S-6 where fixtures + HDR-capable ffmpeg let us work against real data.

## 4. Deliverables landed in this session

Four commits on `main`:

| SHA | subject | stream | files |
|---|---|---|---|
| `08c495a3` | Add PQ-to-SDR filter chain design doc (Stream B / S-5) | B | +311 / -0 (1 new doc) |
| `778565eb` | HDR プレパレーションポリシー用の fixture 駆動インテグレーションテスト基盤を追加 | A | +707 / -16 (2 new tests, 1 new module, 1 README update) |
| `78e61270` | Add HLG-to-SDR filter chain design doc (Stream C / S-5) | C | +413 / -0 (1 new doc) |
| `a59077b3` | Surface ffmpeg-missing-hdr-filters to user with inline install CTA | D | +531 / -4 (1 new component, 1 new test, wiring) |

### 4.1 Stream A — fixture-driven integration test harness

New files:
- `apps/desktop-film-lab-batch/electron/fixture-oracle.ts` (+242)
  - Pure oracle JSON parser and structural subset matcher.
  - `parseFixtureOracle(rawJson) → FixtureOracle` — dependency-free runtime validation.
  - `isStructuralSubset(expected, actual) → string[]` — recursive, path-qualified mismatch reporting.
  - Zero I/O, zero runtime deps.
- `apps/desktop-film-lab-batch/electron/fixture-oracle.test.ts` (+155) — 12 unit tests for the parser and matcher at S-5 boundary; review follow-up raises this to 14. Always-on.
- `apps/desktop-film-lab-batch/electron/fixture-policy.integration.test.ts` (+264) — the skip-gracefully integration runner.

Modified:
- `apps/desktop-film-lab-batch/fixtures/README.md` — new §4 formalizing the oracle schema (required keys, field reference, authoring tips). Review follow-up corrected this to use `expected.policyByCapability`, so the fixture suite injects deterministic capability snapshots instead of depending on the developer or CI machine's installed ffmpeg. Do not flip oracle policy branches after upgrading local ffmpeg.

### 4.2 Stream B — PQ → SDR BT.709 filter chain design doc

New file: `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-pq-filter-chain-design-2026-04-24.md` (3,555 words / 311 lines).

Key points:
- **Canonical zscale+tonemap chain**:
  `zscale=tin=smpte2084:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=100,format=gbrpf32le,zscale=p=709,tonemap=tonemap=hable:desat=0,zscale=t=709:m=709:r=tv,format=yuv420p`
- **Default tonemap algorithm**: `hable` with `desat=0` (film-like highlight rolloff aligns with Filmtone creative intent).
- **Both-capable tiebreaker (PQ only)**: prefer `libplacebo=tonemapping=bt.2390` when both filters exist (standards-conforming BT.2390 EETF, static-metadata auto-read).
- **npl hard-coded to 100 in v1** — MaxCLL-driven dynamic value deferred to a fixture-comparison study in S-7.
- **Integration contract**: new pure helper `buildHdrToSdrFilterChain(selection)` in `electron/video-export-ffmpeg-args.ts`; policy extended with optional discriminated `filterSelection: { kind: "none" | "zscale-tonemap" | "libplacebo" }`. Mezzanine prep as a separate pass — `buildFfmpegRawvideoExportArgs` is unchanged.
- **12 cited sources** (ffmpeg v8.0.1 filter docs, BT.2390 references, community comparisons, libplacebo options, Trac tickets).
- **6 open questions** deferred: HDR10+ handling, Dolby Vision detection (new reason variant), dynamic npl, default algorithm on zscale-only builds, mezzanine bit depth, libplacebo bundling / notarization.

### 4.3 Stream C — HLG → SDR BT.709 filter chain design doc

New file: `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hlg-filter-chain-design-2026-04-24.md` (4,808 words / 413 lines).

Key points:
- **Canonical zscale+tonemap chain (Candidate A)** — 6-stage pipeline: decode → zscale linearization with input-side `tin=arib-std-b67:pin=2020:min=2020_ncl:rin=tv` → OOTF inverse (system γ=1.2 at Lw=1000) → BT.2020→BT.709 primaries → tonemap `mobius:desat=0` → yuv420p.
- **Candidate B (libplacebo)** — single `libplacebo=tonemapping=bt2390` pass, trusted to handle HLG OOTF + OOTF inverse + gamut correctly.
- **Preference order for HLG is reversed from PQ**: when both capabilities exist, HLG prefers **libplacebo** (Candidate B) because the HLG OOTF math is specifically modeled in libplacebo per BBC reference conversion. Dispatch by `colorClass`.
- **Default tonemap on zscale path**: `mobius` with `desat=0` — softer mid-tone behavior better suited to HLG's scene-referred grading; `hable` is a viable alternative (S-6 can A/B both against fixture).
- **npl default = 1000** (HLG target peak luminance at system γ=1.2). SDR diffuse white anchored at 100 cd/m² on the BT.709 side.
- **16 cited sources** including ITU-R BT.2100-2, BT.2390-8, BBC W3C talk, MovieLabs PQ→HLG best-practices, mpv target-peak discussion thread.
- **10 open questions** documented, 7 with suggested defaults, 3 (`target_peak`, Candidate B preference, per-frame vs stream-level transfer) flagged for S-6 fixture validation.

### 4.4 Stream D — Renderer UX: `<HdrPolicyNotice>` inline install CTA

New files:
- `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx` (+220) — the component.
- `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.test.tsx` (+256) — 27 new tests.

Modified:
- `src/renderer/App.tsx` (+16 / -1) — prop wiring.
- `src/renderer/batch-tab/BatchTabPanel.tsx` (+17 / -1) — renders `<HdrPolicyNotice>` beneath the probe label in the Sources accordion.
- `messages/ja.json` / `messages/en.json` (+11 / -1 each) — i18n strings.

Behavior:
- Returns `null` unless `policy.reason === "ffmpeg-missing-hdr-filters"`.
- Otherwise renders an amber (not red — advisory, not error) inline callout:
  - Title + body explaining the situation.
  - `policy.warning` verbatim (lists which filters are missing).
  - A `<pre>` block with the exact install command:
    `brew tap homebrew-ffmpeg/ffmpeg && brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-zimg --with-libplacebo`
  - "Copy command" / "コマンドをコピー" button using `navigator.clipboard.writeText` with a textarea `document.execCommand('copy')` fallback for Electron insecure-origin corners.
  - "Copied!" / "コピーしました" confirmation for 2 s.
  - Opt-in "Why — HDR fixture status" button (only renders when `onOpenFixtureDoc` handler is passed; currently App.tsx does not pass one — deferred as a follow-up, see §8).

UX judgment calls recorded in the agent's report:
- Amber, not red — advisory tone.
- Inline, not modal — does not block SDR export.
- Copy, not install — app does not run `brew`; it only helps the user do so.
- Deferred: GitHub-URL hardcoding vs main-process IPC for opening the fixture doc.

### 4.5 Files intentionally NOT changed in this session
- `electron/video-export-source-metadata.ts` — policy logic untouched; B and C reference the `filterSelection` extension as a future change.
- `electron/video-export-ffmpeg-args.ts` — no filter-chain wiring yet; `buildHdrToSdrFilterChain` remains unimplemented per the design docs.
- `electron/main.ts` — capability probe wiring unchanged from S-4.
- `electron/ffmpeg-capability-probe.ts` — unchanged from S-4.
- Sidecar Zod schema (`src/renderer/export-metadata-session.ts`) — unchanged; no new reason variant needed this session.
- iOS app, other desktop apps, film-lab-renderer — untouched.
- Depth-aware cross filter / ray-angle scripts — separate thread, untouched.

## 5. Verification

All three verification steps were green on the final S-5 run (after all 4 stream commits landed):

```bash
bun run --cwd apps/desktop-film-lab-batch test
# Vitest: 33 files / 223 tests passed + 1 skipped (224 total)
# Baseline after S-4: 31 files / 196 tests passed
# Delta: +2 files, +27 tests, +1 skip sentinel (fixture-absent guidance)

bun run --cwd apps/desktop-film-lab-batch build:electron
# passed

bun run --cwd apps/desktop-film-lab-batch build:renderer
# passed (pre-existing chunk-size warning, unrelated)
```

Review follow-up correction on 2026-04-24 updated the oracle schema to `policyByCapability` and re-ran the fast suite:

```bash
bun run --cwd apps/desktop-film-lab-batch test
# Vitest: 33 files / 226 tests passed + 1 skipped (227 total)

bun run --cwd apps/desktop-film-lab-batch build:electron
# passed

bun run --cwd apps/desktop-film-lab-batch build:renderer
# passed (pre-existing chunk-size warning, unrelated)
```

Non-blocking: `bunx tsc -p apps/desktop-film-lab-batch/tsconfig.json --noEmit` still stops on the pre-existing CSS side-effect import issue in `src/renderer/main.tsx`. Verification path is the three commands above.

## 6. Git state

Historical S-5 boundary:

```
Current branch: main
Working tree: clean
main...origin/main [ahead 22]

tip:
  a59077b3 Surface ffmpeg-missing-hdr-filters to user with inline install CTA
  78e61270 Add HLG-to-SDR filter chain design doc (Stream C / S-5)
  778565eb HDR プレパレーションポリシー用の fixture 駆動インテグレーションテスト基盤を追加
  08c495a3 Add PQ-to-SDR filter chain design doc (Stream B / S-5)
  b09ab70f Add capability-probe session handoff for HDR work  ← S-4 boundary
  2ff8f6e2 Document HDR fixture inventory and seed fixtures skeleton
  0add4987 Probe ffmpeg HDR capabilities and gate preparation policy
  1d32b848 Finalize cross filter runtime follow-ups  ← depth-aware thread tip
```

No worktrees used. `push` was not performed at S-5 boundary.

Review-time continuation state before this correction patch:

```
Current branch: main
main...origin/main [ahead 24]

tip:
  96f5d437 Fix ray-angle optics contract and rendering
  221cc82d Add S-5 parallel-streams session handoff
  a59077b3 Surface ffmpeg-missing-hdr-filters to user with inline install CTA
  78e61270 Add HLG-to-SDR filter chain design doc (Stream C / S-5)
  778565eb HDR プレパレーションポリシー用の fixture 駆動インテグレーションテスト基盤を追加
```

Parallel thread (depth-aware cross filter) tip: `1d32b848`. Commits since then are all metadata-driven-export-quality work. Safe to treat these two threads as independent for any future merge / rebase.

## 7. Program roadmap (updated)

```
[done S-1] P0-A display geometry normalization
[done S-1] P0-B source color / HDR classification (pure)
[done S-2] P1-A source metadata sidecar serialization
[done S-2] P1-B frame-timing diagnostics
[done S-3] P0-C policy pure helper + sidecar / log visibility
[done S-4] FFmpeg HDR capability probe + capability-aware policy downgrade
[done S-5] Fixture-driven integration harness (A)
[done S-5] PQ → SDR filter chain design doc (B)
[done S-5] HLG → SDR filter chain design doc (C)
[done S-5] Renderer inline notice + copy-to-clipboard CTA for missing-filter case (D)
[next    ] User action: install HDR-capable ffmpeg (§8.1) + record privacy-safe fixtures (§8.2).
[next S-6] Implement `buildHdrToSdrFilterChain(selection)` per B's design doc. PQ branch first. Fixture-backed.
[next S-6] Extend policy with `filterSelection` discriminated union; update 4 reason-mirror sites only if a new reason variant is needed (likely not — filterSelection is additive).
[later S-7] HLG branch wiring per C's design doc. A/B test `hable` vs `mobius` on iPhone HLG fixture.
[later S-7] HDR10 MaxCLL-driven dynamic npl (open question from B).
[later   ] Dolby Vision detection + new reason variant (open question from B).
[later   ] HDR10+ dynamic metadata handling decision (open question from B).
[later   ] Wire `onOpenFixtureDoc` handler in App.tsx — either GitHub URL or Electron IPC (deferred from D).
[later   ] P2-A FOV / focal-length-aware optical recommendations.
[later   ] P2-B camera/lens profile research.
[later   ] P3 gyro / IMU / rolling-shutter inventory.
[later   ] ffmpeg bundling inside Electron app for end-user distribution (§9.1 Option D from S-4 handoff).
```

## 8. User action pending (unchanged from S-4, now also unblocks Stream A)

### 8.1 Install an HDR-capable ffmpeg on the dev machine

```bash
brew tap homebrew-ffmpeg/ffmpeg
brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-zimg --with-libplacebo
brew link --overwrite homebrew-ffmpeg/ffmpeg/ffmpeg  # if a previous ffmpeg is linked
ffmpeg -hide_banner -filters | grep -E 'zscale|libplacebo'
```

Both `zscale` and `libplacebo` should appear. After restart of Filmtone Desktop, the next HDR import should log `reason=source-is-hdr-pq` (or `-hlg`) with `strategy=prepare-sdr-mezzanine` instead of `reason=ffmpeg-missing-hdr-filters`. The `<HdrPolicyNotice>` from Stream D then stops rendering for HDR clips on this machine. Pixels still do not change until S-6 implements `buildHdrToSdrFilterChain`.

(Stream D's notice itself copies this exact command when the user clicks Copy — slightly meta.)

### 8.2 Record fixtures

Target: `apps/desktop-film-lab-batch/fixtures/video/{hdr,sdr}/`. Exact recipes in `apps/desktop-film-lab-batch/fixtures/README.md`.

Minimum set:
- `iphone-hlg-1s-<hash>.mov` — iPhone with HDR Video ON. HLG. 1–2 s.
- `generic-pq-1s-<hash>.mp4` — any HDR10 / PQ source. S1II is NOT PQ-capable. iPhone 15 Pro+ ProRes LOG is a practical source; or external test clip.
- `s1ii-bt709-1s-<hash>.mp4` — any BT.709 SDR clip.

Each fixture must have a matching `<basename>.ffprobe.json` oracle following the §4 schema in `fixtures/README.md`. Structure:

```json
{
  "expected": {
    "colorClass": "hdr-hlg",
    "policyByCapability": {
      "missingHdrFilters": {
        "strategy": "defer-unknown",
        "reason": "ffmpeg-missing-hdr-filters"
      },
      "zscaleOnly": {
        "strategy": "prepare-sdr-mezzanine",
        "reason": "source-is-hdr-hlg"
      },
      "libplaceboOnly": {
        "strategy": "prepare-sdr-mezzanine",
        "reason": "source-is-hdr-hlg"
      },
      "zscaleAndLibplacebo": {
        "strategy": "prepare-sdr-mezzanine",
        "reason": "source-is-hdr-hlg"
      }
    }
  },
  "ffprobe": {
    "streams": [{ "color_transfer": "arib-std-b67", "color_primaries": "bt2020", "color_space": "bt2020nc", "pix_fmt": "yuv420p10le" }]
  }
}
```

§4.3 documents that oracle policy branches are stable across machines: `missingHdrFilters` stays `defer-unknown` / `ffmpeg-missing-hdr-filters`, and capability-present branches stay `prepare-sdr-mezzanine` / `source-is-hdr-hlg|pq`.

No people, no landmarks. Strip GPS with `exiftool -GPS*:all= fixture.mov` before committing.

### 8.3 Push vs keep local

At S-5 boundary `main...origin/main [ahead 22]`; at review-time continuation `main...origin/main [ahead 24]`. Not pushed. When the user wants CI coverage or remote backup, push; otherwise local is fine.

## 9. Guardrails for the next chat (consolidated)

From S-3 / S-4 and still in force, plus S-5 additions:

1. Do not wire any pixel-changing HDR tone mapping without real PQ/HLG fixtures.
2. Do not change export FPS behavior. 24fps CFR remains the default.
3. Do not auto-select camera profile / input LUT from `make` / `model` tags.
4. Do not copy GPMF / CAMM / gyro tracks into rendered exports.
5. Do not mix depth-aware cross-filter / ray-angle work into metadata commits.
6. Sidecar schema evolutions must stay backward-compatible (new Zod enum variants OK; removing variants not).
7. Keep the source-metadata module pure; inject side-channel data (like ffmpeg capability) as arguments.
8. Runtime probes must cache per keyable identity and fail *soft* (return null / all-false).
9. When adding a reason variant, update all 4 mirrors: `video-export-source-metadata.ts`, `preload.ts`, `src/renderer/desktop-api.d.ts`, `src/renderer/export-metadata-session.ts` (Zod).
10. Verification = `bun run --cwd apps/desktop-film-lab-batch test` + `build:electron` + `build:renderer`. `tsc --noEmit` is not the verification path.
11. **[S-5 new]** When S-6 implements `buildHdrToSdrFilterChain`, the function must be a pure helper returning a filter string; do not reach into the probe module from it, receive the capability snapshot as argument.
12. **[S-5 new]** Fixture integration tests (Stream A harness) must stay skip-gracefully. Do not convert them to required tests before fixtures are checked in.
13. **[S-5 new]** When landing new design decisions that close open questions from the B or C doc, update that doc's §7 (open questions) in the same commit as the code that resolved it.
14. **[S-5 new]** `git push` only on explicit user request.

## 10. Document chain and pointers

Read in this order if joining fresh:

1. **This doc** (session-level handoff, self-contained).
2. `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-plan-2026-04-24.md` — full strategy (P0..P3).
3. `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-pq-filter-chain-design-2026-04-24.md` — Stream B's PQ design.
4. `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hlg-filter-chain-design-2026-04-24.md` — Stream C's HLG design.
5. `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hdr-fixture-inventory-2026-04-24.md` — capability + fixture inventory.
6. `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-capability-probe-session-handoff-2026-04-24.md` — S-4 handoff.
7. `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-workplan-handoff-2026-04-24.md` — S-3 handoff (guardrails about dirty WebGPU files are stale).

Implementation entry points (S-5 state):
- `apps/desktop-film-lab-batch/electron/ffmpeg-capability-probe.ts` — capability probe (S-4).
- `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts` — policy (S-4; `filterSelection` extension pending in S-6).
- `apps/desktop-film-lab-batch/electron/main.ts` — `resolveFfmpegHdrCapabilitiesIfNeeded` wiring (S-4).
- `apps/desktop-film-lab-batch/electron/fixture-oracle.ts` — oracle parser (S-5 A).
- `apps/desktop-film-lab-batch/electron/fixture-policy.integration.test.ts` — fixture-driven integration harness (S-5 A).
- `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx` — renderer UX (S-5 D).
- `apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.ts` — filter-chain wiring target for S-6 (currently unchanged since S-4).

## 11. Self-contained handoff prompt for the next chat

Paste the block below into a fresh chat to continue. Everything the next chat needs is either in this prompt or in the docs it points to.

```text
Filmtone Metadata-Driven Export Quality の続きをお願いします。
対象 repo: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
Branch: main (review 時点で origin/main の 24 コミット先行。push は未実行。)

直前セッション (S-5, 4 ストリーム並列) の成果:
- Stream A (778565eb): fixture 駆動 integration test 基盤。
  electron/fixture-oracle.ts (pure oracle parser + subset matcher)、
  electron/fixture-oracle.test.ts (S-5 境界 12 unit tests、review follow-up 後 14 unit tests、常時実行)、
  electron/fixture-policy.integration.test.ts (describe.skipIf で fixture 到着時のみ発火)、
  fixtures/README.md §4 に oracle schema を形式化。
- Stream B (08c495a3): PQ→SDR filter chain design doc。
  zscale+tonemap=hable:desat=0 chain を確定、
  libplacebo=bt.2390 を both-capable 時の優先路に、
  integration 接点は buildHdrToSdrFilterChain(selection) + policy.filterSelection union、
  open questions 6 件 (HDR10+ / DoVi / dynamic npl / default alg / mezz bit depth / bundling)。
- Stream C (78e61270): HLG→SDR filter chain design doc。
  zscale+OOTF inverse+tonemap=mobius:desat=0 chain (Candidate A, 6 stages, input-side tin/pin/min/rin)、
  libplacebo bt2390 (Candidate B, HLG では B を優先)、
  npl=1000 system γ=1.2、SDR diffuse white=100 cd/m²、
  open questions 10 件、7 件に default 推奨あり。
- Stream D (a59077b3): renderer 側 <HdrPolicyNotice> 実装。
  policy.reason === "ffmpeg-missing-hdr-filters" の時だけ amber inline callout を
  BatchTabPanel の Sources アコーディオンに描画、
  brew tap homebrew-ffmpeg/ffmpeg 〜 の install コマンドを one-click コピー、
  navigator.clipboard + textarea fallback、+27 tests。

検証: S-5 境界では 33 files / 223 tests passed + 1 skipped。review follow-up 後は 33 files / 226 tests passed + 1 skipped。build:electron / build:renderer green。
commit は 4 本、main に stack。push なし。worktree 未使用。

唯一のフル session-level handoff ドキュメント:
apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-s5-parallel-streams-handoff-2026-04-24.md

次にやる作業 (優先順):
1. ユーザが §8.1 の HDR-capable ffmpeg を dev 機に入れたかを確認。
   入っていれば capability probe の出力が変わり、<HdrPolicyNotice> が HDR clip で出なくなる。
2. fixtures/video/{hdr,sdr}/ に実ファイル + <basename>.ffprobe.json oracle が到着したら、
   Stream A の integration suite が自動発火する (skipIf 解除)。
   oracle は fixtures/README.md §4 の `policyByCapability` スキーマで capability 別に固定する。
   ffmpeg 対応完了後も oracle は flip しない。integration suite が capability snapshot を注入する。
3. 揃ったら Stream B の design doc に従って PQ 1 branch だけ fixture-backed で wire:
   - electron/video-export-ffmpeg-args.ts に buildHdrToSdrFilterChain(selection) を実装
   - policy に filterSelection discriminated union (kind: "none" | "zscale-tonemap" | "libplacebo") を追加
   - 4 mirror 更新 (source-metadata.ts / preload.ts / desktop-api.d.ts / zod)
   - fixture-backed integration test が全 branch 検証
4. 続いて HLG を Stream C の design doc に従って wire。
   HLG は libplacebo 優先 (PQ と逆)、dispatch は colorClass で。
5. depth-aware cross filter / ray angle 系 (scripts/filmtone_*) と commit を混ぜない。

禁止事項:
- fixture 無しで PQ / HLG の filter chain を wire しない。
- camera profile / input LUT の自動切替をしない。
- export FPS 挙動を変えない。
- make/model からの distortion correction・LUT 選択をしない。
- GPMF / CAMM / gyro を rendered export に copy しない。
- reason union 追加時は 4 mirror 全てを更新する。
- Stream A の integration suite を fixture 無しで required にしない (skipIf を解除しない)。
- git push は明示依頼が無い限りしない。

検証コマンド (tsc --noEmit は CSS import 問題で止まるので不可):
bun run --cwd apps/desktop-film-lab-batch test
bun run --cwd apps/desktop-film-lab-batch build:electron
bun run --cwd apps/desktop-film-lab-batch build:renderer

参照 (読書順):
- この session の handoff: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-s5-parallel-streams-handoff-2026-04-24.md
- strategy: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-plan-2026-04-24.md
- PQ design: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-pq-filter-chain-design-2026-04-24.md
- HLG design: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hlg-filter-chain-design-2026-04-24.md
- capability/fixture inventory: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hdr-fixture-inventory-2026-04-24.md
- S-4 handoff: apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-capability-probe-session-handoff-2026-04-24.md
```

## 12. Sanity checklist for the first 3 minutes of the next chat

```bash
# 1) Branch + clean tree
git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio rev-parse --abbrev-ref HEAD
# expect: main

git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio status --short
# expect: empty unless review-fix work or user changes are still uncommitted

# 2) Tip of main
git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio log --oneline -5
# expect:
#   96f5d437 Fix ray-angle optics contract and rendering
#   221cc82d Add S-5 parallel-streams session handoff
#   a59077b3 Surface ffmpeg-missing-hdr-filters to user with inline install CTA
#   78e61270 Add HLG-to-SDR filter chain design doc (Stream C / S-5)
#   778565eb HDR プレパレーションポリシー用の fixture 駆動インテグレーションテスト基盤を追加

# 3) FFmpeg capability truth (decides next phase)
ffmpeg -hide_banner -filters | grep -E '\b(zscale|libplacebo)\b' || echo "still missing — §8.1 runbook pending"

# 4) Fixture presence (decides whether integration suite activates)
ls apps/desktop-film-lab-batch/fixtures/video/hdr apps/desktop-film-lab-batch/fixtures/video/sdr 2>/dev/null

# 5) Fast verify
bun run --cwd apps/desktop-film-lab-batch test
# expect after review follow-up: 33 files / 226 passed + 1 skipped
```

Decision tree:
- If `3` still reports missing filters AND `4` returns empty: next chat stays in "wait for user action + polish" mode. Consider Stream E (filter chain stub + type contract), F (ffmpeg bundling research), or H (onOpenFixtureDoc wiring).
- If `3` reports both filters AND `4` has fixtures: next chat is **S-6 — wire `buildHdrToSdrFilterChain` for PQ**, fixture-backed, per the B design doc.
- If `3` reports both but `4` empty: ffmpeg ready, still waiting on fixtures. Test the capability probe under a real HDR-capable ffmpeg; fixture oracles remain stable because `policyByCapability` covers both missing-filter and capable-filter branches.
- If `3` missing but `4` has fixtures: exercise the fixture suite; HDR oracles should still pass because the policy test injects deterministic capability snapshots rather than reading local ffmpeg.

---

End of S-5 session handoff.
