# Archived: M14-A — Master Availability + Master/Proxy Decision in Export Path

Status: **PASS** — owner accepted 2026-05-09 ("OK"). New
`ExportSourceDecision` enum + `resolveExportSource()` in
`FilmtoneEditorStore`, two-gate (fileExists → facade.probeSource)
master detection, decision-aware success toasts, internal-Documents
masters now export from master, SSD-mounted master export remained as
proxy fallback at this step (no security-scoped resource held at
editor time — addressed in M14-B), Photos / Files edits unchanged.
2 new strings (`toastExportUsedMaster`,
`toastExportUsedProxyMasterUnavailable`).

Acceptance authorized M14-B (security-scoped bookmark management
for SSD masters) as next step.

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **installed on iPhone 17 Pro #7, ready for owner walk** — autonomous execution complete 2026-05-09 01:37 JST

## Why this active exists

M13 (cockpit + Liquid Glass + ruler scrubber) closed 2026-05-09 with
owner acceptance over the M13-K → M13-L → M13-M-1 → M13-M-2 → M13-M-3 +
M13-M-4 chain. Implementation work moves to M14 (Master / Proxy Export
Truth) per strategy.md.

Today's export path (`FilmtoneEditorStore.export()` →
`FilmtonePhase0Math.buildExportRequest(source: ...)` →
`facade.runExport(request: ...)`) **always uses the proxy** when the
editor is sourcing from a capture package: `adoptCaptureResult(_:)`
sets `self.source = SourceInfoDTO(uri: package.proxyURL.absoluteString, ...)`
and never re-resolves the master. This is an honest "proxy-only" pipeline
today, but M14 wants the master to be the export source whenever it is
reachable so the final artifact preserves ProRes 422 HQ / Apple Log 2 /
4K resolution rather than the proxy's 1080p H.264.

M14-A is the foundational sub-task: insert a master-availability
**decision** into the export trigger so:

1. Internal-Documents masters (always reachable on the device) are used
   for export by default.
2. External-SSD masters: if the SSD is mounted at the same path, the
   master is used; if unmounted, the export falls back to the proxy
   with an explicit user-visible notice instead of silently exporting
   the lower-quality file.
3. Photos / Files-sourced edits (no `lastCapturePackage`) keep their
   existing single-source path unchanged.

## Decision: probe twice, fall back loudly

```
resolveExportSource() → (SourceInfoDTO, SourceProbeDTO, ExportSourceDecision)
```

Algorithm:

1. If `lastCapturePackage` is nil → return current `source` + `probe`
   + `.noCapturePackage` decision. (Photos / Files edits unchanged.)
2. Compute `masterURL = lastCapturePackage.masterURL`. Build a master
   `SourceInfoDTO` with `uri = masterURL.absoluteString`,
   `filename = masterURL.lastPathComponent`, `kind = .video`,
   `mimeType = "video/quicktime"`.
3. Existence gate: `FileManager.default.fileExists(atPath: masterURL.path)`.
   - false → return proxy `source` + proxy `probe` +
     `.usingProxyMasterMissing` decision.
4. Readability gate: `try facade.probeSource(masterSource)`.
   - throws → return proxy `source` + proxy `probe` +
     `.usingProxyMasterUnreadable(reason: errMessage)` decision.
   - succeeds → return master source + master probe + `.usingMaster`
     decision.

The double gate (existence + probe) catches both internal-deletion and
SSD-permission failures without opening a security-scoped reacquire
path (deferred to M14-B). Today's owner workflow records masters into
internal Documents by default; SSD path is the failure case M14-A
surfaces without trying to silently fix.

## User-visible decision feedback

Add 2 toast strings to `FilmtoneStrings`:

- `toastExportUsedMaster` — `"マスターから書き出しました"` /
  `"Exported from master"`. Replaces the generic
  `toastExportComplete` toast on master export. Prevents the owner
  from wondering "did I just export the proxy?"
- `toastExportUsedProxyMasterUnavailable` —
  `"プロキシから書き出し(マスターが見つかりません)"` /
  `"Exported from proxy — master not reachable"`. Shown after a
  successful proxy fallback. Makes the proxy fallback explicit so the
  owner knows the artifact is 1080p H.264 rather than 4K ProRes.

`.noCapturePackage` decision keeps the existing `toastExportComplete`
toast so Photos / Files edits do not get a confusing "master /
proxy" wording.

## In Scope

- New `enum ExportSourceDecision` in `FilmtoneEditorStore.swift`
  (file-private, near the other export-related types).
- New `private func resolveExportSource()` in `FilmtoneEditorStore.swift`
  that returns the resolved source + probe + decision.
- Update `func export()` and `func exportAndSave()` to call
  `resolveExportSource()` at the top, build the request from the
  resolved source + probe, and present the decision-aware toast on
  success.
- 2 new strings in `FilmtoneStrings.swift`
  (`toastExportUsedMaster`, `toastExportUsedProxyMasterUnavailable`).
- NSLog instrumentation: log the decision at export start so device
  console traces master / proxy pick.

## Out of Scope (M14-B and later)

- Security-scoped bookmark management for SSD masters that need a
  re-acquire across capture-teardown → editor session boundary.
- Reconnect-prompt UI for master-unavailable case (toast notice only
  in M14-A).
- Sidecar provenance fields recording master/proxy decision (M14-C).
- Per-stage progress UI changes for the longer master export.
- Highlight reel export (`exportHighlightReel`) — same pattern but
  separate cycle.
- ASC verify scripts / release truth.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
  — add `ExportSourceDecision`, `resolveExportSource()`, update
  `export()` + `exportAndSave()` decision-aware toast emission.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
  — add 2 toast strings.

Do NOT edit:
- `FilmtoneCaptureSession.swift` (capture pipeline unchanged).
- `FilmtoneMediaRuntime.swift` / `FilmtoneEditorFacade.swift`
  (export internals unchanged — M14-A operates above the facade
  boundary).
- `FilmtoneCapturePackagePersistence.swift` (no schema change).
- `FilmtoneExportSidecarBuilder.swift` (sidecar provenance is M14-C).

No new files → no `project.pbxproj` 4-section grep needed.

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion
git diff --check

# Simulator + device build
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -derivedDataPath /tmp/filmtone-m14a-dd build

# Install + launch
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-m14a-dd/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Owner walk (acceptance gate)

Each must be clearly true before M14-A archives:

1. **Internal-Documents capture exports from master** — record a clip
   without picking SSD (internal mode), edit a Look in the editor,
   tap export. Toast reads "Exported from master". Resulting `.mov`
   is the ProRes 422 HQ / Apple Log 2 quality (or whatever the export
   pipeline produces from the master), not the 1080p H.264 proxy.
2. **External-SSD master, SSD mounted, exports from master** — record
   to SSD, keep the SSD mounted, edit + export. Toast reads
   "Exported from master".
3. **External-SSD master, SSD unmounted, falls back to proxy** —
   record to SSD, unmount the SSD, edit + export. Toast reads
   "Exported from proxy — master not reachable". Resulting `.mov`
   is the proxy export. No silent failure, no stuck busy state.
4. **Photos / Files edits unaffected** — open a Photos source and
   export. Toast reads "書き出し完了" / "Export complete" exactly as
   it did before M14-A. No master / proxy wording for non-capture
   sources.

If any FAIL: iterate before commit.

## Stop Conditions

- Any edit to capture session / writer / package / proxy generation /
  facade internals.
- Two simulator build failures from the same root cause.
- Master export output regression (e.g., wrong codec, wrong
  resolution) compared to a proxy export of the same package.
- Owner says the toast wording surprises them or the fallback path is
  confusing.

## Execution log (autonomous run 2026-05-09)

- 01:18-01:37 JST: Step 1-5 executed continuously per active scope.
- M13 closed in strategy.md Completion Log + Sub-milestones list +
  Done conditions reworded around the cockpit (no drawer language).
  M13-M-3 active.md archived as PASS to
  `archive/2026-05-09-m13-m-3-ruler-scrubber-and-drawer-cleanup.md`.
- 2 new strings in `FilmtoneStrings.swift`:
  `toastExportUsedMaster` ("マスターから書き出しました" / "Exported from master")
  + `toastExportUsedProxyMasterUnavailable` ("プロキシから書き出し
  (マスターが見つかりません)" / "Exported from proxy — master not reachable").
- `FilmtoneEditorStore.swift` (~80 lines added):
  - new `enum ExportSourceDecision { case noCapturePackage, usingMaster, usingProxyMasterMissing, usingProxyMasterUnreadable(reason:) }`
  - new `struct ResolvedExportSource { let source, probe, decision }`
  - new `private func resolveExportSource() -> ResolvedExportSource`
    with two-gate resolution (`fileExists` → `facade.probeSource`)
  - new `private func toastForDecision(_:) -> String`
  - `func export()` and `func exportAndSave()` now call
    `resolveExportSource()` first, build the request from the resolved
    source + probe, and present the decision-aware toast on success.
- NSLog instrumentation: `[M14-A]` lines log master path + decision
  for device console diagnostics.
- Simulator build: PASS.
- Device build: PASS (signed).
- Install + launch: PASS — running on iPhone 17 Pro #7.
- No new files; pbxproj 4-section gate not applicable.

## Owner walk pending — four reads

(See "Owner walk (acceptance gate)" above.) The 4 reads validate
internal-Documents master export, SSD-mounted master export, SSD-
unmounted proxy fallback, and Photos / Files non-capture parity.

If all 4 PASS: archive this active.md →
`2026-05-09-m14-a-master-proxy-decision.md`, append 1-3 line
strategy.md Completion Log entry, open M14-B (security-scoped bookmark
management for SSD masters or sidecar provenance — owner picks the
priority).

If any FAIL: iterate before commit.

## Outcome

(Filled at archive time after owner walk acceptance.)
