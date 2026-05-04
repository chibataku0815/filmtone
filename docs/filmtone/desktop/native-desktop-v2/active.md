# M4-B Shared Phase0 Core Package

Date opened: 2026-05-04 JST

## Milestone

M4 Shared Contract Consolidation. Implementation slice that lands the first
shared Swift package per the M4-A boundary decision
(`archive/2026-05-04-m4-a-shared-swift-boundary-cut-line.md`).
M5-C.4 Export Inspector remains paused at
`paused/2026-05-04-m5-c4-export-inspector.md`.

## Goal

Stand up `packages/film-lab-swift-core` as the canonical owner of
Foundation-level Phase 0 core types, and have **both** the Desktop and iOS
Xcode targets consume that package — proving the package boundary works
before more shared code lands.

After this slice, neither app holds a local copy of:

- `FilmtonePhase0Generated.swift`
- `FilmtoneQuickState`
- `FilmtonePhase0Params`
- `FilmtonePhase0ParamsPatch`
- `Phase0OutputProfileDTO`

…and the generator script writes the artifact to **one** location (the
package), not two app-local mirrors.

## Why this slice (本質)

- M4-A established that the highest-value shared boundary is the generated
  Phase 0 artifact + the four pure Swift data types it depends on. Until
  that boundary actually exists in code, every M5-C slice keeps hand-porting
  iOS structures into Desktop-only files.
- The generator already writes byte-identical Swift to both apps
  (`scripts/generate-filmtone-swift.ts` MD5 confirmed). The gap is purely
  packaging.
- Doing this first proves the SPM integration path on both Xcode projects
  with the smallest possible payload, before larger lifts (preset resolve,
  Creative Pack catalog, source profile, sidecar) arrive.

## Scope

### In

1. Create `packages/film-lab-swift-core/Package.swift`
   - swift-tools-version 6.0, no external dependencies
   - One library product `FilmLabSwiftCore`
   - Platforms: macOS 26, iOS 18 (matches current app deployment targets)
   - One test target `FilmLabSwiftCoreTests`

2. Populate `Sources/FilmLabSwiftCore/`:
   - `Generated/FilmtonePhase0Generated.swift` — verbatim copy of the
     current generated artifact (MD5 matches both apps' current copies).
     **Do not hand-edit.**
   - `FilmtoneQuickState.swift` — lift from
     `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift`
     L9 block (Codable + Equatable + Hashable + Sendable posture)
   - `FilmtonePhase0Params.swift` — lift from
     `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift`
     L49 block
   - `Phase0OutputProfileDTO.swift` — lift from
     `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift`
     L87 block
   - `FilmtonePhase0ParamsPatch.swift` — lift from
     `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePhase0ParamsPatch.swift`
     (preserves Codable + Equatable + Hashable + Sendable + the helpers
     `empty`, `apply(to:)`, `merging(_:)`, etc.)

3. Add `Tests/FilmLabSwiftCoreTests/`:
   - Codable round-trip for `FilmtoneQuickState`
   - Codable round-trip for `FilmtonePhase0Params`
   - Codable round-trip for `FilmtonePhase0ParamsPatch`
   - `FilmtonePhase0Generated.paramKeys` landmark assertion (35 keys, first
     `"exposure"`, last `"grainIntensity"`) so accidental generator drift
     trips the package test suite
   - `FilmtonePhase0Generated.defaultQuickState == .zero` (or the equivalent
     literal)
   - `FilmtonePhase0ParamsPatch.empty.apply(to: resetParams) == resetParams`

4. Update `scripts/generate-filmtone-swift.ts`:
   - Remove the two app-local `outputPath` targets.
   - Add one new target writing to
     `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift`.
   - Re-run the generator and confirm only the package file is touched.

5. Wire Desktop:
   - Add `XCLocalSwiftPackageReference` to
     `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
     pointing at `../../packages/film-lab-swift-core`.
   - Add the `FilmLabSwiftCore` product to the `FilmtoneDesktop` target's
     Frameworks build phase.
   - Add `import FilmLabSwiftCore` at the top of Desktop files that
     consume the now-removed types (Phase0Types.swift consumers,
     FilmtonePhase0ParamsPatch consumers, generated artifact consumers).
   - Delete:
     - `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift`
       (or trim to leave only Desktop-specific types if any remain)
     - `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePhase0ParamsPatch.swift`
     - `apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift`
   - Update `apps/filmtone-desktop-macos/Verify/run.sh` SOURCES list:
     drop the deleted files; add the package's source files (Verify is
     swiftc-direct, not SPM, so it consumes paths).

6. Wire iOS:
   - Add `XCLocalSwiftPackageReference` to
     `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
     pointing at `../../../../packages/film-lab-swift-core` (relative from
     `ios/App`).
   - Add the `FilmLabSwiftCore` product to the `App` target's Frameworks
     build phase.
   - Edit `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift`:
     - Delete the `FilmtoneQuickState` declaration (L34 block)
     - Delete the `FilmtonePhase0Params` declaration (L67 block)
     - Delete the `FilmtonePhase0ParamsPatch` declaration (L210 block)
     - Add `import FilmLabSwiftCore` at the top
   - Edit `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`:
     - Delete the `Phase0OutputProfileDTO` declaration (L274 block)
     - Add `import FilmLabSwiftCore`
   - Delete `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift`
   - Verify other iOS files that already declare `import Foundation` see
     the types via Swift's automatic module re-export (no per-file import
     usually required when the consumer file already uses Foundation +
     compiles in the same target — but if the iOS build surfaces
     "cannot find type" errors, add `import FilmLabSwiftCore` per file).

7. Build / verify gates:
   - `cd packages/film-lab-swift-core && swift build && swift test` — green
   - `bun run verify:macos` (xcodebuild Desktop Debug) — green
   - `apps/filmtone-desktop-macos/Verify/run.sh` — 36/36 PASS preserved
   - `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace
     -scheme App -configuration Debug -destination 'generic/platform=iOS'
     build` — green
   - `bun run verify:ios` if defined — green

### Out (deferred to follow-up M4 slices)

- Preset interpolation / resolve / quick application logic
  (Desktop `FilmtonePresetCatalog.swift` 195L vs iOS 38L — file shapes
  diverge enough that this is a separate boundary slice).
- Creative Pack 01 identity catalog (Desktop has
  `FilmtoneCreativePackCatalog.swift` enum; iOS has
  `FilmtoneBuiltInCatalog.swift` with `creativePack01StonePatch` /
  `creativePack01UrbanPatch`. Schema reconciliation is its own slice).
- Source profile catalog + math.
- Sidecar payload schema structs.
- Cube parser.
- Saved Look schema.
- AVFoundation / Core Image / Metal — none of those go into the package, ever.

### Constraints

- iOS canonical behavior must not change. Adding `Hashable + Sendable` to
  `FilmtoneQuickState` / `FilmtonePhase0Params` / `FilmtonePhase0ParamsPatch`
  is purely additive; if Swift 6 strict concurrency surfaces a new error in
  iOS code that previously compiled because the type was non-Sendable,
  treat that error as evidence of an existing latent issue and fix it
  narrowly without changing the user-facing behavior.
- Generated Swift remains generated-only. Do not hand-edit
  `Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift`.
- Sidecar payload schema is unchanged.
- No UI changes.
- M5-C.4 paused work resumes intact after M4-B closes.
- Use `bun` for repo-level commands; `swift` CLI for the package itself.

## Approach

Execute in three phases inside this single active slice. Commit at each
phase boundary so a phase failure can be reverted without losing the
earlier phases.

### Phase 1 — Package skeleton (no app changes)

1. Write `Package.swift` + `Sources/FilmLabSwiftCore/*.swift` (5 files:
   Generated artifact + 4 data structs).
2. Write `Tests/FilmLabSwiftCoreTests/*.swift` covering Codable + landmark
   assertions.
3. `swift build` + `swift test` from the package directory — green.
4. Commit: `feat(swift-core): scaffold film-lab-swift-core package`.

### Phase 2 — Desktop consumption

1. Add `XCLocalSwiftPackageReference` + product link to Desktop pbxproj.
2. Add `import FilmLabSwiftCore` to Desktop consumers.
3. Delete Desktop's local copies of the lifted types.
4. Update `Verify/run.sh` SOURCES.
5. `xcodebuild` Desktop Debug + `Verify/run.sh` 36/36 PASS — green.
6. Manual launch smoke (the M5-C.4 inspector should still render, since
   only declarations moved — no runtime change).
7. Commit: `feat(macos): consume film-lab-swift-core, drop local Phase0 dupes`.

### Phase 3 — iOS consumption + generator simplification

1. Add `XCLocalSwiftPackageReference` + product link to iOS pbxproj.
2. Edit iOS files to delete the lifted struct declarations and add
   `import FilmLabSwiftCore` where needed.
3. Update `scripts/generate-filmtone-swift.ts` to write only the package
   path; re-run; confirm package file unchanged (MD5 stable) and the two
   former app-local files are no longer rewritten.
4. `xcodebuild` iOS Debug — green.
5. Commit: `feat(ios): consume film-lab-swift-core, simplify generator`.

A fourth optional commit can drop the now-unused iOS / Desktop local
files if Phase 2 / 3 left any leftover.

## Done conditions

- `packages/film-lab-swift-core/` exists with a passing `swift test`.
- Desktop consumes `FilmLabSwiftCore` and no longer holds local copies of
  the 4 data structs or the generated artifact.
- iOS consumes `FilmLabSwiftCore` and no longer holds local copies of the
  4 data structs or the generated artifact.
- Generator script has exactly one output target, in the package.
- Desktop xcodebuild + Verify harness 36/36 PASS — green.
- iOS xcodebuild Debug — green.
- M5-C.4 paused doc unchanged; restoring it to `active.md` after M4-B
  closes returns the same state as before pause.

## Edit Targets

- `packages/film-lab-swift-core/Package.swift` (new)
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift` (new)
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneQuickState.swift` (new)
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtonePhase0Params.swift` (new)
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Phase0OutputProfileDTO.swift` (new)
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtonePhase0ParamsPatch.swift` (new)
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/Phase0CodableTests.swift` (new)
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/GeneratedLandmarkTests.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` (extend: XCLocalSwiftPackageReference + product)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift` (delete or trim)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePhase0ParamsPatch.swift` (delete)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift` (delete)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/**/*.swift` (add `import FilmLabSwiftCore` where needed)
- `apps/filmtone-desktop-macos/Verify/run.sh` (SOURCES list update)
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` (extend: XCLocalSwiftPackageReference + product)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift` (delete 3 struct declarations + add import)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift` (delete `Phase0OutputProfileDTO` + add import)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift` (delete)
- `apps/capacitor-film-lab-ios/ios/App/App/**/*.swift` (add imports if SourceKit/xcodebuild surfaces "cannot find type")
- `scripts/generate-filmtone-swift.ts` (single output target)

## Read-Only References

- M4-A archive: `archive/2026-05-04-m4-a-shared-swift-boundary-cut-line.md`
- M5-C.4 paused: `paused/2026-05-04-m5-c4-export-inspector.md`
- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift` L34, L67, L210
- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift` L274
- Desktop current: `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift`
- Desktop current: `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePhase0ParamsPatch.swift`
- Desktop current: `apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift`
- Generator: `scripts/generate-filmtone-swift.ts`
- Generator data source: `packages/film-lab-core/src/ios-swift-payload.ts`

## Risks & Mitigations

- **iOS pbxproj surgery**: this is the first SwiftPM integration in the iOS
  project. Mitigation: do Phase 1 + Phase 2 (Desktop) first to validate the
  package shape; iOS gets the proven product reference after Desktop is
  green. If iOS pbxproj edit fails, M4-B can ship Phase 1 + Phase 2 as a
  Desktop-only checkpoint with iOS deferred to M4-B.b.
- **Conformance widening on iOS**: adding `Hashable + Sendable` to types
  iOS already uses may surface latent Swift 6 strict concurrency errors in
  iOS code. Mitigation: fix narrowly when surfaced; do not relax the
  package's conformance to "match iOS lower" because that would force
  Desktop to drop `Hashable + Sendable` and break M5-C.* code paths.
- **Verify harness depends on direct swiftc paths**: moving sources out of
  the Desktop tree breaks `run.sh` until SOURCES is updated. Mitigation:
  update SOURCES in the same Desktop-consumption commit so `run.sh` never
  enters a half-broken state on the branch.
- **Generator regression**: changing the generator's output target list
  could leave stale files. Mitigation: after the generator change, run
  `git status` and confirm the two former app-local paths show as
  deleted; the package path shows as written.
- **Capacitor / fastlane sensitivity** (iOS): the iOS project has fastlane
  + Capacitor wiring that reads pbxproj. Mitigation: limit the iOS pbxproj
  edit to adding XCLocalSwiftPackageReference + a Frameworks link entry;
  do not touch existing build settings, signing config, or schemes.

## Out Of Scope

- Math changes (Phase 0 math stays in iOS-local file for now).
- Preset / Look catalog extraction.
- Source profile catalog extraction.
- Sidecar schema changes.
- UI changes.
- Public Swift package distribution (this is a repo-local SPM package only).
- Splitting or renaming `FilmtonePhase0Math.swift` beyond removing the
  3 struct declarations and adding one import.

## Estimated size

Multi-hour slice. Phase 1: ~30 min (package + tests). Phase 2: ~1-2 hr
(Desktop pbxproj + Verify harness wiring + smoke). Phase 3: ~1-2 hr (iOS
pbxproj + per-file imports as needed + iOS build). Three commits, one per
phase.

## Operating mode

Auto-mode: implementation may begin immediately per the user's standing
"本質を最優先" directive on 2026-05-04 JST. Commits will be made by the
agent per phase boundary. Compact at the end of Phase 1, Phase 2, and
Phase 3 if context pressure justifies.

iOS pbxproj edit (Phase 3) is the highest-risk step in this slice; if any
ambiguity surfaces while reading the iOS pbxproj structure, ask the user
before mutating it. Phase 1 + Phase 2 carry no iOS-side risk and proceed
without confirmation.

## Checklist

- [ ] Phase 1: package skeleton + tests green
- [ ] Phase 1 commit
- [ ] Phase 2: Desktop wired + xcodebuild + Verify 36/36 green
- [ ] Phase 2 commit
- [ ] Phase 3: iOS wired + xcodebuild green + generator simplified
- [ ] Phase 3 commit
- [ ] Restore `paused/2026-05-04-m5-c4-export-inspector.md` to `active.md`
- [ ] Archive this M4-B active to `archive/2026-05-04-m4-b-shared-phase0-core-package.md`
- [ ] Append 1-3 line Completion Log entry to `strategy.md`

## Verification

- 2026-05-04 JST: M4-B active opened. Implementation has not begun.
- `git diff --check` will be re-run at each phase commit.
