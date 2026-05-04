# M5-C.2a Saved Look Library Foundation And Save Current Look

Date opened: 2026-05-04 JST

## Milestone

M5 Native Editing UI. M5-C.2 from the
`archive/2026-05-04-m5-c-ios-feature-parity-audit.md` parity gap list:
"Look library parity: built-in Looks should live in a real selection
surface, and user-saved Looks need an owning persistence model." Splits
into M5-C.2a (this slice — foundation + Save) and M5-C.2b (favorite /
rename / delete UX).

## Goal

Land the persistence + selection model that lets a user **save the
current Look state to disk and pick it back later**, with built-in Stone
and Urban surfaced through the same library list rather than a hardcoded
Picker enum. iOS canonical (`FilmtoneLibraryStore` + `FilmtoneBuiltInCatalog`)
is the contract; Desktop ports the looks-only subset (no LUT library, no
embedded-LUT GC — those are the M5-C.2c P1 slice).

## Why this slice (本質)

- iOS users can already save and recall Looks. macOS users can pick
  Stone / Urban / None and that's it — there is no "save what I just
  built." That is the next correctness gap below source-profile parity.
- The Library shape (SavedLookEntry, CreativeLutBinding, LibrarySnapshot,
  bundled built-ins materialized into the snapshot) is the substrate
  every later M5-C slice (Adjustments, Export panel) reads from. Saving
  too narrow a foundation here forces a re-port later.
- Built-in Stone/Urban currently live in a hardcoded `lookOptions` array
  inside `GradeControls`. Routing them through the library snapshot is
  what makes "save a custom Look" feel native instead of bolted on.

## Scope

In-scope:

- New `FilmtoneSavedLookSchema.swift` — port the looks-only subset of
  iOS `FilmtoneLibrarySchema.swift`: `FilmtoneLibraryConstants`,
  `SavedLookEntry`, `CreativeLutBinding` (3-flavor enum), `LibraryIndex`,
  `LibrarySnapshot`. Codable / Equatable / Sendable on the wire types,
  including a thin `SavedLookEmbeddedLut` placeholder so the binding
  enum compiles even though the Desktop slice doesn't take the embedded
  path yet (M5-C.2c).
- Codable / Equatable / Sendable conformance extensions on the existing
  `FilmtoneQuickState` and `FilmtonePhase0ParamsPatch` so they can
  round-trip inside `SavedLookEntry`.
- New `FilmtoneSavedLookStore.swift` — actor at
  `~/Library/Application Support/Filmtone/library/looks/{*.json,
  index.json}`. Methods: `loadOrRebuild`, `saveLook`, `loadLook`
  (with built-in dispatch), `deleteLook` (refuses on built-ins),
  `currentSnapshot` (built-ins prepended). Atomic per-entry writes.
  No LUT subtree, no quota check, no orphan GC (P1).
- `FilmtoneCreativePackCatalog` adapter `materializeAsSavedLookEntry`
  (mirrors iOS `FilmtoneBuiltInCatalog.materializeAsSavedLookEntry`)
  so Stone/Urban appear at the head of the snapshot with stable
  bundled UUIDs / immutable / bundledSlug.
- New `LibraryViewModel.swift` — `@MainActor @Observable` wrapper that
  holds the latest `LibrarySnapshot`, owns the `LibraryStoreActor`,
  exposes `bootstrap()` / `saveCurrentLook(name:from:)` / `refresh()`.
- New `LookLibraryControls.swift` — replaces the hardcoded `lookOptions`
  picker with a snapshot-driven Picker (None + built-ins + user-saved)
  plus a "Save Current Look…" button that opens an NSAlert text-field
  prompt. Same Pass 4 dark-tinted `.clear` Liquid Glass posture +
  `.colorScheme(.dark)` Picker.
- `EditorState` extension: `selectedSavedLookId: UUID?` (UI state),
  `applySavedLook(_ entry:)` writes `presetName` / `presetStrength` /
  `lookSlug` (lookSlug derived from `creativeLut.bundledSlug` when the
  binding is `.bundled`, nil otherwise), `currentLookSnapshot()` reads
  the inverse for Save.
- `GradeControls` slimmed: drop the hardcoded Look picker (now lives in
  `LookLibraryControls`); keep the Strength slider as-is.
- `RootWindowView` bootstraps the `LibraryViewModel` (`@State`) and
  injects it into `LookLibraryControls`. Library panel sits above
  `GradeControls`, below `SourceProfileControls`.

Out-of-scope (deferred):

- Favorite toggle UI (M5-C.2b — backend will already wire toggleFavorite
  via `bundledLookFavorites` UserDefaults map for symmetry, but no UI
  surface in this slice).
- Rename / delete UX (M5-C.2b).
- Custom LUT import / library subtree / quota / orphan GC (M5-C.2c, P1).
- Per-parameter Adjustments editing (M5-C.3 P0). `paramOverrides` on a
  user-saved entry is `.empty` until that slice lands.
- Sidecar additive `savedLookId` / `savedLookName` provenance — Desktop
  sidecar already encodes the canonical built-in slug via `lookId`
  (`filmtone:builtin:<slug>:<v>`), and user-saved looks don't yet
  introduce new identity beyond preset+strength+lookSlug. Add when
  M5-C.3 paramOverrides go live and the look identity diverges from
  `(presetName, lookSlug, strength)`.
- Built-in catalog UUIDs other than Stone (B6) / Urban (B7) — M5-C.2a
  follows the iOS canonical pruning; deprecated `...000001` …
  `...000005` UUIDs stay reserved (no reuse).

## Approach

1. Codable conformance on `FilmtoneQuickState` and
   `FilmtonePhase0ParamsPatch` (additive, in the new schema file —
   keeps `Domain/Phase0Types.swift` untouched per its delete-when-SPM
   note).
2. Schema lift verbatim from iOS, with `SavedLookEmbeddedLut` reduced to
   the field shape (no usage path). `CreativeLutBinding.bundledSlug`
   accessor mirrors iOS so the (future) sidecar can stamp it.
3. `FilmtoneSavedLookStore` is the looks-only subset of iOS
   `LibraryStoreActor`. Built-in dispatch in `loadLook(id:)` routes
   Stone/Urban canonical UUIDs through `FilmtoneCreativePackCatalog`'s
   new `materializeAsSavedLookEntry`. `currentSnapshot()` prepends the
   materialized built-ins exactly as iOS does, with the Pack 01 freeze
   date pinned for stable timestamps.
4. `LibraryViewModel` does the actor bridging: bootstrap on appear,
   refresh after every mutation, surface errors via a `@Published`-style
   `error: String?` for an inline NSAlert.
5. `LookLibraryControls` Picker tag is `LibraryLookSelection` enum
   (`.none` / `.saved(UUID)`). `onChange` dispatches:
   - `.none` → clear `lookSlug` + `selectedSavedLookId`
   - `.saved(uuid)` → `vm.store.loadLook(id:)` → `state.applySavedLook(entry)`
6. "Save Current Look…" button pops an NSAlert with text input,
   defaulting to a deduped name (`Look 1`, `Look 2`, …) computed from
   the current snapshot. On commit: `vm.saveCurrentLook(name:from:)` →
   refresh → auto-select the new entry so the user sees confirmation
   visually.
7. `EditorState.applySavedLook` is a single-method dispatch — it never
   reaches into the store or VM, so the state stays UI-framework-free.

## Done conditions

- `xcodebuild -scheme FilmtoneDesktop -configuration Debug` passes
  clean (Swift 6 strict concurrency).
- Open a still / video, pick Stone, drag Strength to ~0.6, click "Save
  Current Look…", name it (e.g. "Stone Soft"). The new entry appears at
  the head of the user-saved section. Switch the Picker to None, then
  back to "Stone Soft" — preview returns to Stone @ 0.6.
- Built-in Stone / Urban remain selectable from the same Picker with
  identical render output to pre-M5-C.2a (their `.bundled` cube +
  paramOverrides patch are unchanged).
- Saved Looks survive an app relaunch (loadOrRebuild rescans the
  `looks/` directory). Built-in entries do not get persisted to disk.
- Switching Source Profile (M5-C.1) does not affect saved Look behavior
  — Looks live above the source-input transform.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSavedLookSchema.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSavedLookStore.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCreativePackCatalog.swift` (extend with materialize adapter)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/LibraryViewModel.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift` (selectedSavedLookId + applySavedLook)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/LookLibraryControls.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/GradeControls.swift` (drop Look picker)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift` (bootstrap VM + place panel)
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` (4 new file refs)
- `docs/filmtone/desktop/native-desktop-v2/active.md` (this file)
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` (1–3 line completion entry)

## Read-Only References

- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySchema.swift`
- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibraryStore.swift`
- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift`
- M5-C audit: `archive/2026-05-04-m5-c-ios-feature-parity-audit.md`
- M5-C.1 archived active: `archive/2026-05-04-m5-c1-native-source-profile-source-gate-parity.md`

## Out Of Scope

- M5-C.2b (favorite / rename / delete UI), M5-C.2c (LUT import library)
- M5-C.3 Adjustments parameter editing (paramOverrides UX)
- M5-C.4 Export panel parity
- iOS canonical UUIDs `...000001` – `...000005` (deprecated reservations
  stay reserved)

## Unexpected / Blockers

- Codable / Sendable cannot be added to `FilmtoneQuickState` /
  `FilmtonePhase0ParamsPatch` via cross-file extension (Swift compiler
  refuses synthesis, and Sendable explicitly requires same-file
  declaration). Resolved by adding the conformances directly on the
  struct decls in `Phase0Types.swift` /
  `Color/FilmtonePhase0ParamsPatch.swift`. Both decls are slated to
  disappear when `packages/film-lab-swift-core` SPM lands, so this is
  not a long-term shape concern.

## Completion (this active is ready to archive)

- `xcodebuild -scheme FilmtoneDesktop -configuration Debug
  -destination 'platform=macOS' build` passes clean (Swift 6 strict
  concurrency; only pre-existing CI-kernel deprecation warnings on
  `FilmtoneGradeKernels.swift` — unrelated to this slice).
- Library schema (`FilmtoneSavedLookSchema.swift`) ports the looks-only
  subset of iOS canonical: `SavedLookEntry`, `CreativeLutBinding`
  (3-flavor), `SavedLookEmbeddedLut` (decode-only placeholder),
  `LibraryIndex`, `LibrarySnapshot`, `FilmtoneLibraryConstants`. v1.3
  additive fields (`bundled` / `immutable` / `bundledSlug`) round-trip
  via explicit Codable so v1.2-shaped saves decode cleanly.
- `FilmtoneSavedLookStore` actor lives at
  `~/Library/Application Support/Filmtone/library/{looks/*.json,
  index.json}` — same root as iOS for path-compat with future sync.
  Methods: `loadOrRebuild`, `saveLook`, `loadLook`, `deleteLook`,
  `snapshot`. Built-in dispatch in `loadLook` routes Stone / Urban
  canonical UUIDs through `FilmtoneCreativePackCatalog`. Atomic
  per-entry writes; rebuildable index; built-ins prepended in
  `currentSnapshot`.
- `FilmtoneCreativePackCatalog` now exposes `find(canonicalUUID:)` +
  `materializeAsSavedLookEntry(_:)` (Pack 01 freeze date pinned to
  2026-04-30 JST for stable timestamps, mirroring iOS).
- `LibraryViewModel` (@MainActor @Observable) bridges the actor.
  Bootstrap via `task { await library.bootstrap() }` in RootWindowView;
  errors surface to a `lastError: String?` that drives an inline
  alert in `LookLibraryControls`.
- `LookLibraryControls` replaces the hardcoded `lookOptions` Picker
  previously baked into `GradeControls`: snapshot-driven Picker with
  `Section("Built-in")` (Stone / Urban) + `Section("Saved")` (user
  looks), plus a "Save Current Look…" Button that opens an
  `NSAlert` text-field prompt. Same Pass 4 dark-tinted `.clear`
  Liquid Glass + `.colorScheme(.dark)` posture.
- `EditorState` gains `selectedSavedLookId: UUID?`, `applySavedLook`
  (writes `presetName` / `presetStrength` / `lookSlug` from
  `creativeLut.bundledSlug`), `clearSavedLookSelection`, and
  `currentLookSavePayload()` for the inverse Save path.
- `GradeControls` slimmed to the Strength slider only — Look
  selection now lives entirely in `LookLibraryControls`.
- `RootWindowView` bootstraps the VM via `@State private var
  library = LibraryViewModel()` and a `.task { await
  library.bootstrap() }` modifier; LookLibraryControls panel is
  inserted between `SourceProfileControls` and `GradeControls`
  inside the existing GlassEffectContainer right rail.
- Built-ins remain selectable with identical render output to
  pre-M5-C.2a (their `.bundled` cube + `paramOverridesPatch` are
  unchanged; the Picker just routes through the snapshot now).
- Domain conformances widened: `FilmtoneQuickState` and
  `FilmtonePhase0ParamsPatch` are now `Codable + Equatable +
  Sendable` so `SavedLookEntry` synthesis works without retroactive
  conformance hacks.

User to verify visually: open a still / video, pick Stone, drag
Strength to ~0.6, click "Save Current Look…", name it. The new
entry should appear at the head of the user-saved section. Switch
the Picker to None, then back to the saved entry — preview should
return to Stone @ 0.6. Saved Looks should survive an app relaunch.

This active.md moves to archive when the next slice (M5-C.2b
favorite / rename / delete UX, M5-C.2c LUT library import, or
M5-C.3 Adjustments parameter editing) opens.
