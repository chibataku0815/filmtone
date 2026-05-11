# Active — Phase 2B-3 DepthPayloadManager Extraction

Date: 2026-05-11 JST
Phase: Phase 2B — ExportSession public-surface split (sub-stage 3 of N)
Milestone: Bounded handoff slice. Lift the video-depth reader probe +
per-frame pull bridge out of `FilmtoneExportSession` into an independent
helper under `Export/Internal/`, keeping the per-frame loop's depth
semantics byte-identical.

## Owner directive (carry-over from 2B-2)

The `feedback_no_extension_only_file_for_god_object_split` rule still
applies. Do **not** create an `extension FilmtoneExportSession` file.
The depth helpers go into an **independent internal helper type** under
`Export/Internal/`. Public API of `FilmtoneExportSession` is unchanged.

## Goal

Move three private members of `FilmtoneExportSession.swift` out:

| Symbol | Current lines | Kind |
|---|---|---|
| `private func resolveVideoDepthReader(asset:)` | 2794–2839 (46 lines) | instance fn that gates on `request.depthEnabled` |
| `private enum VideoDepthFramePullResult` | 2845–2849 (5 lines) | result tri-state |
| `private func pullNextVideoDepthFrame(reader:)` | 2851–2871 (21 lines) | pure sync bridge of `reader.nextFrame()` |

Total ~72 lines. Two cross-file readers exist today inside the class
itself only (call sites at `FilmtoneExportSession.swift:758` and `:959`).

Both functions today use only local `DispatchSemaphore`s to sync-bridge
async work from `VideoDepthSourceService` / `VideoDepthFrameReader`. The
only instance-state dependency is `request.depthEnabled` inside
`resolveVideoDepthReader` (line 2795 fast-return).

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  (delete the ~72 lines, rewrite 2 call sites)
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportDepthPayloadManager.swift`
  (new — sole owner of the three symbols)
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  (4-section registration, one entry per new file → +1 to App target)
- `docs/filmtone/ios/feature-architecture-refactor/active.md` (this file)

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md` (commit gate; §3 4-section grep)
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  (Phase 2B target = 6 files; this is sub-stage 3)
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-1-sidecar-formatter-extraction.md`
  (Compatibility Table — `DepthPayloadManager` row + Risk Rank #3)
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-2-source-profile-input-lut-helpers-extraction.md`
  (precedent for independent-helper-type extraction)
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaRuntime.swift`
  (`VideoDepthSourceService` / `VideoDepthFrameReader` definitions — not modified)
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneDepthMap.swift`
  (`FilmtoneDepthMap` payload — not modified)

## Helper type design

### `ExportDepthPayloadManager` (Export/Internal/ExportDepthPayloadManager.swift)

`enum` namespace (no instance state — the only instance-state read,
`request.depthEnabled`, is moved to the parameter list). All members
`static`.

**Public surface to call sites:**

```swift
enum ExportDepthPayloadManager {
    /// Tri-state result of `pullNextFrame` so callers can distinguish
    /// "stream ended" from "transient failure".
    enum PullResult {
        case frame((presentationTime: CMTime, depthMap: FilmtoneDepthMap))
        case endOfStream
        case failure(Error)
    }

    /// Probes the video depth track and opens a `VideoDepthFrameReader`.
    /// Returns nil when depth is disabled by request or when all profile
    /// depth gains are zero (defense-in-depth fast-path). Throws
    /// `FilmtoneMediaError.depthUnsupportedForVideoSource` when the asset
    /// has no depth track despite `depthEnabled == true`.
    static func resolveReader(
        asset: AVAsset,
        depthEnabled: Bool
    ) throws -> VideoDepthFrameReader?

    /// Sync-bridges `VideoDepthFrameReader.nextFrame` for the per-frame
    /// loop on `videoQueue`.
    static func pullNextFrame(
        reader: VideoDepthFrameReader
    ) -> PullResult
}
```

Method renames (vs current `FilmtoneExportSession.swift`):

- `resolveVideoDepthReader(asset:)` → `ExportDepthPayloadManager.resolveReader(asset:depthEnabled:)`
- `pullNextVideoDepthFrame(reader:)` → `ExportDepthPayloadManager.pullNextFrame(reader:)`
- `VideoDepthFramePullResult` (nested inside class today) → `ExportDepthPayloadManager.PullResult`

The shorter names are unambiguous inside the new namespace and keep the
two call sites readable. (Method-name preservation was deliberate in
2B-2 because of 4 call sites + 5 comments; here only 2 call sites
need updating.)

### Rationale for the design

- `enum` namespace (vs `final class`) — no instance state needed; the
  semaphores are scoped to each call, the gate moved to a parameter.
- Move `depthEnabled` to the parameter list so the helper does not need
  `request: Phase0ExportRequestDTO`. The `FilmtonePhase0Generated.hiddenDefaults`
  fast-path read stays inside the helper since it is module-level state,
  not session state.
- `VideoDepthFramePullResult` is renamed to `PullResult` and nested
  inside the namespace so the public surface is `ExportDepthPayloadManager.PullResult`
  at the two call sites — clearer than a bare top-level enum sibling.

## Call-site repair list inside `FilmtoneExportSession.swift`

| Line (current) | Current call | New call |
|---|---|---|
| 758 | `let depthReader = try resolveVideoDepthReader(asset: asset)` | `let depthReader = try ExportDepthPayloadManager.resolveReader(asset: asset, depthEnabled: request.depthEnabled ?? false)` |
| 959 | `switch pullNextVideoDepthFrame(reader: reader)` | `switch ExportDepthPayloadManager.pullNextFrame(reader: reader)` |

(Line numbers will shift as the helpers are removed; the worker reads
the file fresh at edit time. Use the call expression as the anchor, not
the line number.)

The `switch` body uses cases `.frame`, `.endOfStream`, `.failure` — the
case names are unchanged, so the body needs no per-case edit.

## Comment updates outside ExportSession

None expected. `grep -rn "resolveVideoDepthReader\|pullNextVideoDepthFrame\|VideoDepthFramePullResult"`
across `apps/capacitor-film-lab-ios/ios/App/App/` is expected to return
zero non-`FilmtoneExportSession.swift` matches at extraction time
(verify with grep before the move).

## Things deliberately *not* moved in this sub-stage

- `lastDepthFrame` state variable (line 904 inside `exportVideo`) — that
  is per-export-run state owned by the frame loop, not by the depth
  reader. Stays in the writer/loop boundary which is 2B-7 work.
- `VideoDepthSourceService`, `VideoDepthFrameReader` (defined in
  `Source/FilmtoneMediaRuntime.swift`) — already external types; no
  change.
- `FilmtoneDepthPrefilter` (the per-pixel depth math) — separate concern.
- `FilmtoneSharedGradeProcessor`, `FilmtoneMotionBlurAccumulator`,
  `OpticalKernels` (2B-4 bundle).
- `OpticsCompositor` (2B-5) / `GradeRenderPipeline` (2B-6 with 2C
  parity gate) / `ExportMediaWriter` (2B-7 with 2C).

## Checklist

- [ ] Confirm no cross-file readers for the three symbols
  (`grep -rn "resolveVideoDepthReader\|pullNextVideoDepthFrame\|VideoDepthFramePullResult" apps/capacitor-film-lab-ios/ios/App/App/`).
- [ ] Create `Export/Internal/ExportDepthPayloadManager.swift` with the
  three members renamed per the design above.
- [ ] Delete the ~72 lines (current 2794–2871) from `FilmtoneExportSession.swift`.
- [ ] Rewrite the 2 call sites in `FilmtoneExportSession.swift`
  (`resolveVideoDepthReader` → `ExportDepthPayloadManager.resolveReader`,
   `pullNextVideoDepthFrame` → `ExportDepthPayloadManager.pullNextFrame`).
- [ ] Register the new file in `project.pbxproj` (4 sections).
- [ ] `grep -c 'ExportDepthPayloadManager' project.pbxproj` >= 4.
- [ ] `bun run verify:ios` — PASS.
- [ ] `git diff --check` — PASS.

## Verification gates

- pbxproj 4-section registration verified per file
- `bun run verify:ios` green (CLAUDE.md §3; same gate chain as 2B-1/2B-2)
- `git diff --check` clean (whitespace)
- `git diff --stat` shows roughly: −72 in ExportSession.swift,
  +<helper file size> in one new file, +2 call-site rewrites in
  ExportSession
- App target `PBXSourcesBuildPhase` file count changes by exactly +1
- No edit to `FilmtoneMediaRuntime.swift` / `FilmtoneDepthMap.swift` /
  `FilmtoneDepthPrefilter.swift`

## Done Conditions

- `FilmtoneExportSession.swift` no longer contains
  `resolveVideoDepthReader`, `pullNextVideoDepthFrame`, or
  `VideoDepthFramePullResult`.
- `ExportDepthPayloadManager` (`enum` namespace) owns those symbols;
  no `extension FilmtoneExportSession` exists in the new file.
- The per-frame depth pull loop in `exportVideo` (around lines 900–971)
  is unchanged in shape: same case dispatch (`.frame` / `.endOfStream` /
  `.failure`), same `lastDepthFrame` retention, same `depthMapForThisFrame`
  source.
- All gates green.
- No change to public API, sidecar field order, render math, or kernel
  chain order.

## Stop Conditions

- Stop if the helper move requires changing any `FilmtoneExportSession`
  public/internal-default signature.
- Stop if the move requires reordering or guarding the `DispatchSemaphore`
  wait pattern — the per-frame loop currently relies on synchronous
  bridging on `videoQueue`, and that contract must stay byte-identical.
- Stop if the move requires the helper to take a reference to
  `FilmtonePhase0Generated.hiddenDefaults` from outside (it should keep
  reading the module-level constant directly).
- Stop after 3 consecutive build/verification failures.
- Stop if the App target's `PBXSourcesBuildPhase` file count changes by
  anything other than +1.

## Out Of Scope

- Moving `lastDepthFrame` out of the `exportVideo` frame loop.
- Consolidating any depth math (Filter / Prefilter) with the reader path.
- View / Editor / Capture code.
- New tests, new fixtures.
- Renaming `VideoDepthFrameReader` / `VideoDepthSourceService`.

## Unexpected / Follow-up

(empty — worker fills at completion)
