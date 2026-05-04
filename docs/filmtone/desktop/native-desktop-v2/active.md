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
   - Platforms: macOS 14, iOS 17 (SPM **minimum** — both apps deploy to
     higher targets and consume this package fine; lower bound is chosen so
     the package itself stays portable and doesn't force a platform bump on
     consumers)
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
   - **Phase 1.5 (done)**: Added a 3rd `package` target with
     `accessLevel: "public"` writing to
     `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift`.
     iOS / Desktop targets remain on `accessLevel: "internal"` and emit
     byte-identical output to pre-Phase-1.5 (verified MD5).
   - **Phase 2 (this slice)**: Drop the `macos` target once Desktop
     consumes the package via `import FilmLabSwiftCore`. Generator now
     emits to 2 paths: iOS (internal) + package (public).
   - **Phase 3 (deferred)**: Drop the `ios` target once iOS consumes the
     package. Generator collapses to a single path: package (public).

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
   - Update `apps/filmtone-desktop-macos/Verify/run.sh` to **module-link**
     the package, not source-concatenate. The package uses `public`
     access modifiers + explicit memberwise inits that need real module
     resolution. Steps:
     1. `swift build --package-path "$REPO_ROOT/packages/film-lab-swift-core"`
        first (prefer `-c debug` to match the Desktop Debug build).
     2. `swiftc` with `-I "$PKG_BUILD/Modules"` and `-L "$PKG_BUILD" -l FilmLabSwiftCore`
        (or pass the compiled object files directly), where `$PKG_BUILD`
        is `packages/film-lab-swift-core/.build/<triple>/debug`.
     3. Drop the now-removed Desktop sources from the existing SOURCES
        list. Plain SOURCES additions for the package files **will not**
        compile cleanly.
     4. Pre-flight smoke (Phase 1.5, EXIT 0): `swiftc -typecheck -target
        arm64-apple-macos14.0 -sdk $(xcrun --sdk macosx --show-sdk-path)
        -I .build/arm64-apple-macosx/debug/Modules /tmp/smoke.swift`

6. Wire iOS:
   - **iOS-only Patch / Params methods** (`normalized(over:)`,
     `settingValue(_:for:over:)`, `normalizedPreservingOpticsGlow(over:)`,
     `Phase0Params.asDTO()`) depend on iOS-only
     `FilmtonePhase0Math.clampParam` / `paramEqualityTolerance` and
     `Phase0ParamsDTO`. Keep them as iOS-side **extensions** on the
     package types, not declarations. Only the bare struct definitions
     live in the package.
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
- Cross-device SSD workflow compatibility must be preserved. The shared core
  types extracted here must stay platform-neutral enough that a future workflow
  can move source media by SSD / Files / Finder, carry sidecar + Look intent
  beside the source, use Desktop for master / 4K-capable output, and use iPhone
  for FHD / Postcard output. Do not bake Mac-only Finder paths, iOS-only Photos
  state, or current UI labels into shared core.
- DaVinci highlight-marker handoff is a future sidecar/Connect layer. Do not
  put Resolve-specific marker concepts into Phase0 core in this slice; keep the
  extracted types neutral so a later additive sidecar block can carry
  source-relative marker intent for iOS, Desktop, and DaVinci scripts. Plan:
  `davinci-highlight-marker-handoff-plan.md`.

## Approach

Execute in three phases inside this single active slice. Commit at each
phase boundary so a phase failure can be reverted without losing the
earlier phases.

### Phase 1 — Package skeleton (no app changes) — **DONE 2026-05-04**

1. Write `Package.swift` + `Sources/FilmLabSwiftCore/*.swift` (5 files:
   Generated artifact + 4 data structs). [done]
2. Write `Tests/FilmLabSwiftCoreTests/*.swift` covering Codable + landmark
   assertions. [done — 22 tests across Phase0Codable + GeneratedLandmark]
3. `swift build` + `swift test` from the package directory — green. [done]
4. Commit: bundled with Phase 1.5 (deferred).

### Phase 1.5 — Public API pass — **DONE 2026-05-04**

Public API surface added so Desktop / iOS can `import FilmLabSwiftCore`
without `@testable`. Decision: target-aware emitter (option 2) — package
target emits `accessLevel: "public"`, iOS / Desktop targets stay on
`accessLevel: "internal"` and remain byte-identical until Phase 2 / 3
delete them.

1. Hand-written package types publicized: `FilmtoneQuickState`,
   `FilmtonePhase0Params`, `FilmtonePhase0HiddenDefaults`,
   `Phase0OutputProfileDTO`, `FilmtonePhase0ParamsPatch`. Each got
   `public` stored vars/lets + an explicit `public init(...)` (Swift
   auto-synthesized memberwise inits are internal even when fields are
   public).
2. Emitter updated: `renderFilmtoneIosSwiftPayload(payload, { accessLevel })`.
   Default `internal` preserves legacy iOS / Desktop output shape;
   `public` prefixes the enum + every static let. Invariant test pins
   that stripping `public ` from the public output yields the internal
   output byte-for-byte.
3. Generator updated: 3rd `package` target emits public to
   `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift`.
   iOS App + Desktop SharedGenerated copies remain byte-identical to
   pre-Phase-1.5 (verified MD5).
4. Tests: `@testable import` → plain `import` in Phase0CodableTests +
   GeneratedLandmarkTests. New `PublicImportSmokeTests.swift` (5 tests)
   pins the cross-module surface (`zero`, `resetParams.exposure`,
   `Patch.empty`, `Phase0OutputProfileDTO(...)` explicit init,
   `hiddenDefaults.depthRayAngleGamma`).
5. Verification: `swift build` + `swift test` 27/27 green; external
   typecheck smoke `swiftc -typecheck -I .build/.../Modules /tmp/smoke.swift`
   EXIT 0 with 22 public symbol references; `git diff --check` clean;
   generator `--check` EXIT 0.
6. Commit: bundled with Phase 1 (single `feat(swift-core): scaffold + public API` commit, deferred until user requests git operations).

`FilmtoneDynamicCodingKey` deliberately **kept fileprivate** — Patch's
public Codable methods cover the round-trip surface, no need to expose
the CodingKey type itself.

### Phase 2 — Desktop consumption — **DONE 2026-05-04**

1. Added `XCLocalSwiftPackageReference` (relativePath `../../packages/film-lab-swift-core`)
   + `XCSwiftPackageProductDependency` (`FilmLabSwiftCore`) to Desktop
   pbxproj. New sections at the bottom; `PBXProject.packageReferences` +
   `PBXNativeTarget.packageProductDependencies` wired; product link added
   to the existing `Frameworks` build phase. [done]
2. Added `import FilmLabSwiftCore` (alphabetical position) to 13 Desktop
   consumer files: Color/{CreativePackCatalog, GradePipeline, PresetCatalog,
   RayAngleOptics, SavedLookSchema, SavedLookStore}, Export/{SidecarTypes,
   SidecarWriter, StillExporter, VideoExporter}, State/EditorState,
   UI/{PreviewSurface, QuickAdjustControls}. Verify/main.swift also got
   the import. [done]
3. Deleted Desktop local copies: `Domain/Phase0Types.swift` (115 lines),
   `Color/FilmtonePhase0ParamsPatch.swift` (89 lines), and
   `SharedGenerated/FilmtonePhase0Generated.swift` (260 lines) plus the
   now-empty `SharedGenerated/` directory itself. pbxproj entries
   (PBXBuildFile + PBXFileReference + Sources phase + group children +
   the `SharedGenerated` group node) all removed. [done]
4. Rewrote `Verify/run.sh` to module-link the package: `swift build -c
   debug --package-path packages/film-lab-swift-core` first, then
   `swiftc -I $PKG_BIN_PATH/Modules` against the remaining Foundation-only
   Desktop sources, linking the SwiftPM-emitted `.o` objects directly
   (SwiftPM doesn't produce a .a/.dylib for library products by default,
   so `-L .. -lFilmLabSwiftCore` failed; passing the 5 `.swift.o` objects
   under `FilmLabSwiftCore.build/` works). [done]
5. Generator updated: `macos` target dropped (Desktop now consumes the
   package). Output count: 3 → 2 (iOS internal + package public).
   `bun run scripts/generate-filmtone-swift.ts --check` EXIT 0. [done]
6. Verification: `xcodebuild -scheme FilmtoneDesktop -configuration Debug
   build` ✅ BUILD SUCCEEDED (stale Phase0Types.o / FilmtonePhase0Generated.o /
   FilmtonePhase0ParamsPatch.o intermediates auto-cleaned). `Verify/run.sh`
   ✅ 36/36 PASS. `git diff --check` ✅ EXIT 0. `plutil -lint
   project.pbxproj` ✅ OK. [done]
7. Manual launch smoke deferred to user (no runtime change — only
   declarations moved between modules; package types are byte-identical
   to the deleted Desktop ones, with conformances strictly widened).
8. Commit: deferred until user requests git operations (per CLAUDE.md §9
   "Git 操作は user が行う").

### Phase 3 — iOS consumption + generator simplification

1. Add `XCLocalSwiftPackageReference` + product link to iOS pbxproj.
2. Edit iOS files to delete the lifted struct declarations and add
   `import FilmLabSwiftCore` where needed. Keep iOS-only Patch / Params
   methods (`normalized(over:)`, `settingValue(_:for:over:)`,
   `normalizedPreservingOpticsGlow(over:)`, `Phase0Params.asDTO()`) as
   iOS-side **extensions** on the package types — they depend on iOS-only
   `FilmtonePhase0Math.clampParam` / `paramEqualityTolerance` and
   `Phase0ParamsDTO`, which stay app-local.
3. Drop the `ios` target from `scripts/generate-filmtone-swift.ts` (final
   collapse to single output: package public). Confirm package file
   unchanged (MD5 stable) and the former app-local iOS file is no longer
   rewritten.
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
- The extracted shared types do not encode platform-specific output ownership;
  Desktop-master / iPhone-FHD remains a future output-profile layer, not an
  accidental constraint in Phase0 core.

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
  the Desktop tree breaks `run.sh`. Plain SOURCES list additions for the
  package files **will not** compile cleanly because the package uses
  module-scoped `public` API + explicit memberwise inits. Mitigation:
  `run.sh` runs `swift build -c debug --package-path packages/film-lab-swift-core`
  first, then invokes `swiftc -I $PKG_BIN_PATH/Modules` against the
  remaining Desktop sources and links the 5 SwiftPM-emitted
  `$PKG_BIN_PATH/FilmLabSwiftCore.build/*.swift.o` objects directly,
  because SwiftPM doesn't emit a `libFilmLabSwiftCore.a` / `.dylib` for
  library products by default (only per-file `.swift.o`). Smoke validated
  in Phase 1.5: `swiftc -typecheck` against the package's
  `.build/arm64-apple-macosx/debug/Modules` returned EXIT 0 with 22 public
  symbol references resolving cleanly. Implementation locked in Phase 2
  commit so the harness never enters a half-broken state.
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

- [x] Phase 1: package skeleton + tests green (22 tests: Phase0Codable + GeneratedLandmark)
- [x] Phase 1.5: emitter `accessLevel: "public"` + 5 hand-written types publicized + PublicImportSmokeTests (5 tests). Total: 27/27 green
- [ ] Phase 1 + 1.5 bundled commit (deferred — user-controlled git)
- [x] Phase 2: Desktop wired (pbxproj + 13 imports + 3 deletions) + Verify rewritten to module-link + Verify 36/36 PASS + xcodebuild Debug ✅ + generator macos target dropped (3→2 outputs)
- [ ] Phase 2 commit (deferred — user-controlled git)
- [ ] Phase 3: iOS wired + xcodebuild green + generator collapsed to single output
- [ ] Phase 3 commit
- [ ] Restore `paused/2026-05-04-m5-c4-export-inspector.md` to `active.md`
- [ ] Archive this M4-B active to `archive/2026-05-04-m4-b-shared-phase0-core-package.md`
- [ ] Append 1-3 line Completion Log entry to `strategy.md`

## Verification

- 2026-05-04 JST: M4-B active opened. Implementation has not begun.
- 2026-05-04 JST: Phase 1 complete. `swift build` + `swift test` 22/22 green.
- 2026-05-04 JST: Phase 1.5 complete. Emitter target-aware
  (`accessLevel: "internal" | "public"`). 5 hand-written package types
  publicized + `PublicImportSmokeTests` (5 tests) added. Total package
  tests: 27/27. iOS / Desktop generated artifact byte-identical (still
  internal). External typecheck smoke through `.build/.../Modules`
  EXIT 0 with 22 public symbol references. `git diff --check` clean.
  Pre-existing emitter test drift (CONTRACT_DEFAULTS 33 keys vs
  CONTRACT_DEFAULT_KEY_ORDER 19, hiddenDefaults struct 19) is
  out-of-scope — separate generator/struct/tests sync lane.
- 2026-05-04 JST: Phase 2 complete. Desktop wired:
  XCLocalSwiftPackageReference + XCSwiftPackageProductDependency added to
  `FilmtoneDesktop.xcodeproj/project.pbxproj`; `import FilmLabSwiftCore`
  added to 13 Desktop consumer files + Verify/main.swift; Desktop local
  copies deleted (`Domain/Phase0Types.swift`, `Color/FilmtonePhase0ParamsPatch.swift`,
  `SharedGenerated/FilmtonePhase0Generated.swift` plus the `SharedGenerated/`
  group); `Verify/run.sh` rewritten to module-link the package (`swift
  build -c debug` first, then `swiftc -I $PKG_BIN_PATH/Modules` against
  remaining sources, linking the 5 SwiftPM-emitted `.swift.o` objects
  directly because SwiftPM doesn't produce a .a/.dylib for library
  products). Generator updated: `macos` target dropped — 3 outputs
  collapsed to 2 (iOS internal + package public). All gates green:
  `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` ✅
  BUILD SUCCEEDED, `Verify/run.sh` ✅ 36/36 PASS, generator `--check`
  EXIT 0, `plutil -lint project.pbxproj` ✅ OK, `git diff --check` clean.
- `git diff --check` will be re-run at the remaining phase commit (Phase 3).
