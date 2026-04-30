# Filmtone iOS v1.3 — Built-in Look Pack + Camera Profiles Handoff

> **Purpose**: complete handoff for a fresh chat to pick up Filmtone iOS v1.3 implementation. Covers Item 2 (built-in Filmtone Look pack — Phase A〜D shipped on a feature branch) and Camera Profiles (V-Log / S-Log3 — fully planned, not yet implemented). Item 3 (Library + Saved Looks) has already shipped to local `main` (commit `ced4c215`) and is the foundation both other lanes build on.
>
> **Date**: 2026-04-30 JST
> **Author of this handoff**: chat session that landed Item 2 Phases A〜D on `feat/filmtone-ios-built-in-look-pack`.
>
> **A new chat reading this single document plus the three execution plans should be able to resume implementation without any external context.**

---

## 0. Repo + branch state truth (verified at handoff time)

Run before quoting status — the script is the SSOT:

```sh
bash /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

Verified state at 2026-04-30 JST end of session:

| Axis | Value |
|---|---|
| Public App Store | `Filmtone` v1.1 (currentVersionReleaseDate 2026-04-26) |
| Public bundle ID | `com.chibatakumi.film.lab.ios` |
| Local Xcode `MARKETING_VERSION` | `1.2` (v1.2 ASC submit lane in flight on `main`) |
| Local Xcode `CURRENT_PROJECT_VERSION` | `1` |
| iOS deployment target | `17.0` |
| Branch (this handoff) | `feat/filmtone-ios-built-in-look-pack` |
| Branch parent | `main @ cc01bf52` (4 commits ahead of `origin/main`) |
| Working tree | Clean for tracked files. 3 untracked DaVinci handoff docs in `docs/filmtone/ios/` (unrelated to this work) |

### Local commits not in upstream (reverse chronological)

```
b78f9641 feat(filmtone-ios): render built-in Look chips with FILMTONE badge (Item 2 Phase D)
4230dd9a feat(filmtone-ios): merge built-in Looks into library snapshot (Item 2 Phase C)
6e6b4f27 feat(filmtone-ios): add FilmtoneBuiltInCatalog with 5 Looks (Item 2 Phase B)
37313258 feat(filmtone-ios): add bundled/immutable schema fields (Item 2 Phase A)
b25c08d8 fix(filmtone-ios): wire packageFileUris through DTO + facade for spike
cc01bf52 feat(filmtone-ios): teach the reuse loop via onboarding + help sheet
aa691c1a fix(filmtone-ios): restore explicit return in localExportURIs
ced4c215 feat(filmtone-ios): add LUT library and Saved Looks reuse layer (v1.3 Item 3)
9a1c43e8 feat(filmtone-ios): add DaVinci connect v0 spike
```

`cc01bf52`, `aa691c1a`, `ced4c215`, `9a1c43e8` belong to `main`. The first 5 (above the line) are Item 2 work + a precursor fix on the feature branch.

### Build / test gate state

All green at handoff:

- `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`
- `bun run verify:swift-contract` → all 6 contract tests pass (Phase0 / motion blur / cube parser / cache store / source-color-classifier / ray-angle / sidecar builder)
- `bun run build` → tsc + vite build succeed (large-chunk warning, expected)

Has NOT been pushed. Per CLAUDE.md §11 / plans, push requires explicit user approval.

---

## 1. Three concurrent v1.3 lanes

### Item 3 — Library + Saved Looks (✅ SHIPPED to local main)

- **Commit**: `ced4c215`
- **Plan**: `/Users/chibatakumi/.claude/plans/dreamy-forging-hartmanis.md`
- **Status**: shipped. `LutLibraryEntry`, `SavedLookEntry`, `LibraryStoreActor`, `FilmtoneLibrarySection`, `FilmtoneSavedLookSheet` all live in `apps/capacitor-film-lab-ios/ios/App/App/`.
- **Schema**: `entrySchemaVersion = 2` after Item 2 Phase A bumped it.
- **Storage**: `~/Library/Application Support/Filmtone/library/{luts,looks}/<uuid>.json` (+ `.lutbin` for LUTs, `.json` for looks). `index.json` is rebuildable cache.
- **What it provides**: durable LUT library with content-hash dedup + 200 MB quota, Saved Looks with `applySavedLook` apply path, sidecar additive fields (title / libraryId / sourceHash / savedLook block), Recent LUTs strip + Saved Looks chip strip in the Camera profile card.

### Item 2 — Built-in Filmtone Look Pack (🟡 PHASES A〜D SHIPPED ON FEATURE BRANCH; E〜I REMAIN)

- **Plan**: `/Users/chibatakumi/.claude/plans/dreamy-forging-hartmanis-item2.md`
- **Execution plan (this session resolved D1〜D6)**: `/Users/chibatakumi/.claude/plans/dreamy-forging-hartmanis-item2-execution.md`
- **Status**: 5 of ~9 phases shipped on `feat/filmtone-ios-built-in-look-pack`. See §3.
- **What it adds**: 5 params-only built-in Filmtone Looks (Filmtone Signature / Clean Base / Amber Glow / Soft Blue / Night Soft) rendered as immutable virtual library entries with a `FILMTONE` amber badge, pinned at the head of the chip strip. Zero bundled `.cube` in v1.3.

### Camera Profiles — Source Profile Catalog (📋 PLANNED, NOT IMPLEMENTED)

- **Plan**: `/Users/chibatakumi/.claude/plans/dreamy-forging-hartmanis-camera-profiles.md`
- **Execution plan (this session resolved D-CP1〜D-CP7)**: `/Users/chibatakumi/.claude/plans/dreamy-forging-hartmanis-camera-profiles-execution.md`
- **Status**: fully planned with verified math citations. NO commits.
- **What it adds**: 5-entry Camera Profile catalog — `Auto / Apple Log → SDR / Apple Log 2 → SDR / Panasonic V-Log → Rec.709 / Sony S-Log3 → Rec.709 / Rec.709 / Import .cube…`. (P) native Apple Log paths reuse existing `appleLogPixelToRec709`; (S) synthesized V-Log / S-Log3 introduce a new `FilmtoneSourceProfileMath.swift` module with mandatory accuracy fixtures.

---

## 2. Decisions resolved this session (with CD sign-offs)

### Item 2 — D1〜D6 resolutions

| Gate | Resolution |
|---|---|
| **D1 Source Profile catalog** | NOT in Item 2 scope — entire Source Profile catalog work split into the Camera Profiles plan. Item 2 v1.3 ships only Look pack. |
| **D2 Look catalog** | 5 params-only Looks: Filmtone Signature (`iphone` preset) / Clean Base (`reset`) / Amber Glow (`amberGlow`) / Soft Blue (`softBlue`) / Night Soft (`softBlue` + halation 0.04 / bloom 0.24 / exposure 0.05 / saturation 0.93). **CD signed off via AskUserQuestion 2026-04-30 JST.** Japanese names: フィルムトーン / クリーンベース / アンバーグロー / ソフトブルー / ナイトソフト. **CD signed off.** |
| **D3 `.cube` provenance / licensing / accuracy** | Zero bundled `.cube` ship in v1.3. No `bundled-luts/` directory created, no `LICENSING.md` ships, no asset-pipeline work. v1.4 may revisit if D-CP1's deferred camera profiles reach the gate. |
| **D4 Seed mechanism** | Virtualized at read time via `FilmtoneBuiltInCatalog` static struct. Built-in entries materialize to `SavedLookEntry` on every snapshot read; no persistence. UserDefaults-backed favorites map (`filmtone.builtin.favorites.v1`) for built-in chip favorite state. Schema gains `bundled` / `immutable` / `bundledSlug` fields, `entrySchemaVersion` 1→2. |
| **D5 Source Profile picker UI** | Zero new menu items in v1.3 (Item 2 doesn't change the Camera Profile menu — Camera Profiles plan handles that). The Library Section chip strip gains pinned-left built-in chips with the `FILMTONE` amber badge. |
| **D6 App Store copy delta** | v1.3 fastlane release notes (ja + en) drafted in execution plan §7. Vocabulary-gate compliant (no `短尺動画`, no `short-form video`). Description.txt unchanged. |

### Camera Profiles — D-CP1〜D-CP7 resolutions

| Gate | Resolution |
|---|---|
| **D-CP1 Catalog cut** | v1.3: `(P) Apple Log + (P) Apple Log 2 + (S) Panasonic V-Log + (S) Sony S-Log3 + (nil) Rec.709 + Auto + Import`. Defer `(S) Nikon N-Log / Canon Log 3 / BMD Film Gen 5 / ARRI LogC4` to v1.4. Coverage rationale: V-Log + S-Log3 ≈ 80%+ of Filmtone-target non-iPhone hybrid mirrorless footage. |
| **D-CP2 Schema shape** | **Sibling `CameraProfileCatalogEntry` type, NOT extending `LutLibraryEntry`.** `LutLibraryEntry` is content-addressed (sourceHash + dataRef + size); (P) and (S) Camera Profile entries have no data file. Mixing two ontologies pollutes SSOT. New types live in a fresh `FilmtoneSourceProfileSchema.swift`. Ids are namespaced `String` (`built-in:source-profile.<slug>`), not UUID — avoids collision concern with user `LutLibraryEntry.id: UUID`. |
| **D-CP3 Pipeline strategy** | Reframed: pipeline is Core Image (`CIColorCubeWithColorSpace`), NOT Metal compute. The "Metal function constant vs uniform branch" framing didn't apply. Resolution: integrate at `PreparedLut` generation (mirrors existing `makeAppleLogToRec709Lut` pattern at `FilmtoneExportSession.swift:2331-2362`). Cube data cached per curve in `NSCache`; ~575 KB per curve; ~2.3 MB for v1.3 catalog. |
| **D-CP4 Source-change retention** | Smart retention. New `project.cameraProfile: CameraProfileSelection` field. On source-change: `.auto` always re-derives; `.builtIn(apple-log[-2])` resets to `.auto` if probe doesn't match (with toast notice); `.builtIn(vlog/slog3/rec709)` persists (cannot detect non-Apple log curves from container metadata); `.userImport` clears (existing `inputLut` clear rule extends here). |
| **D-CP5 Accuracy tolerance** | **CD signed off via AskUserQuestion 2026-04-30 JST** on Standard budget: linearization `max \|Δ\| ≤ 1e-3` over 4096-point ramp; full-frame per-channel `max ≤ 2/255, mean ≤ 0.5/255`; Macbeth ΔE2000 `max ≤ 2.0, mean ≤ 1.0`; edge cases (V<0.05 or V>0.95) `max ≤ 4/255 (mean only)`. Build fails if any (S) curve drifts beyond. |
| **D-CP6 Apple Log vs Apple Log 2** | Web-search verified: same EOTF, different gamut (Rec.2020 vs Apple Wide Gamut). Existing `makeAppleLogToRec709Lut` treats both with `rec2020GamutMap: true` — technically incorrect for Apple Log 2 on Apple Wide Gamut sources. **CD signed off** on shipping v1.3 with this known limitation, documented in `docs/source-profile-math/apple-log-2.md`; v1.4 refines via AVFoundation native path or Apple Wide Gamut primaries. |
| **D-CP7 Reference fixture sourcing** | Synthesized ramps via colour-science Python (BSD-3-Clause). Each (S) curve ships `encode-ramp.py` + `source-encoded.png` + `linearization-ramp.json` + `macbeth-patches.json` + `expected-rec709.png` + `provenance.md`. License-clean, reproducible, anchored to peer-reviewed reference rather than manufacturer LUTs (avoids reference-LUT-as-truth circularity). |

### CD sign-off audit trail (AskUserQuestion calls in this session)

1. **2026-04-30 JST — Item 2 D2 catalog**: 5 Looks ship (Night Soft 含む) + 提案どおり JP names. Annotation in execution plan §13.
2. **2026-04-30 JST — Camera Profiles D-CP5 + D-CP6**: Standard tolerance budget + Apple Log 2 known-limitation v1.3 ship. Annotation in Camera Profiles execution plan §7 + §8.

---

## 3. Implementation snapshot — what's shipped on the feature branch

5 commits on `feat/filmtone-ios-built-in-look-pack`. Each phase passes the CLAUDE.md §4 commit gate (xcodebuild build + verify:swift-contract + bun run build).

### `b25c08d8` — Precursor fix: packageFileUris

**Why**: `main` itself was unbuildable. The DaVinci v0 spike (`9a1c43e8`) added two references in `FilmtoneEditorStore.swift` (`exportResult.packageFileUris` at line 1338 + 1431) and a 3-arg `facade.shareOutput(...packageFileURIs:)` call site, but did NOT propagate the field/parameter through `Phase0ExportResultDTO` or `FilmtoneEditorFacade.shareOutput`. Build failed with "extra argument 'packageFileURIs' in call" + "value of type 'Phase0ExportResultDTO' has no member 'packageFileUris'".

**Fix**:
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift:415` — added `let packageFileUris: [String]?` to `Phase0ExportResultDTO` with init param `packageFileUris: [String]? = nil`.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorFacade.swift:146` — added `packageFileURIs: [String]? = nil` parameter to `shareOutput`. When non-empty, resolves URIs via `runtime.resolveFileURL` and routes to the existing `runtime.shareOutput(fileURLs:...)` overload. Falls through to media+sidecar overload otherwise.
- New error string `filmtone.error.share.empty_package` for the "no resolvable URIs" path.

**Spike state**: this commit unblocks build but does NOT complete the DaVinci spike — no production code populates `packageFileUris` yet (the `feature/filmtone-davinci-connect-package` branch contains the spike's full export wiring at commit `63622a8d`).

### `37313258` — Phase A: schema additions (bundled / immutable / bundledSlug)

**Files modified**:
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySchema.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibraryStore.swift`

**Changes**:
- `FilmtoneLibraryConstants.entrySchemaVersion` 1 → **2**. `loadLutEntry` / `loadLookEntry` (lines 489-504) do NOT gate on per-entry schemaVersion, so the bump is purely a semantic marker; v1.2-written entries still decode.
- `LutLibraryEntry` gains `var bundled: Bool = false`, `var immutable: Bool = false`, `var bundledSlug: String? = nil`. Custom Codable in extension (`init(from decoder:)` + `func encode(to encoder:)`) uses `decodeIfPresent ?? default` for the three new fields so v1.2 saves round-trip cleanly. Memberwise init preserved (extension Codable, not main-body).
- `SavedLookEntry` gains the same three fields with the same Codable pattern.
- `LibraryStoreActor.StoreError` gains `case immutableEntry(slug: String)` with localized error description.

**Critical Codable detail**: Swift's synthesized `init(from decoder:)` does NOT honor stored-property defaults — every Codable property must be present in the encoded data unless Optional. Putting custom `init(from:)` / `encode(to:)` in an `extension` (not main body) preserves the synthesized memberwise init, so existing call sites at `FilmtoneLibraryStore.swift:208` and `:375` continue to compile without naming the three new fields (they pick up the property defaults).

### `6e6b4f27` — Phase B: FilmtoneBuiltInCatalog.swift

**File created**:
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift` (165 lines)

**pbxproj registered in 4 sections** (PBXBuildFile + PBXFileReference + PBXGroup + PBXSourcesBuildPhase) at IDs:
- PBXBuildFile: `D20000010000000000000017`
- PBXFileReference: `C20000010000000000000017`

Verify with: `grep -c "FilmtoneBuiltInCatalog.swift" apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` → must return ≥ 4.

**Catalog content** (`FilmtoneBuiltInCatalog.allLooks`):

| # | Slug | EN Name | JP Name | Preset base | Strength | Quick state | Param patches |
|---|---|---|---|---|---|---|---|
| 1 | `filmtone-signature` | Filmtone Signature | フィルムトーン | `iphone` | 1.0 | `.zero` | none |
| 2 | `clean-base` | Clean Base | クリーンベース | `reset` | 1.0 | `.zero` | none |
| 3 | `amber-glow` | Amber Glow | アンバーグロー | `amberGlow` | 1.0 | `.zero` | none |
| 4 | `soft-blue` | Soft Blue | ソフトブルー | `softBlue` | 1.0 | `.zero` | none |
| 5 | `night-soft` | Night Soft | ナイトソフト | `softBlue` | 1.0 | `.zero` | `halationIntensity: 0.04, bloomStrength: 0.24, exposure: 0.05, saturation: 0.93` |

**Canonical UUIDs** (FB1A namespace, stable across versions, never collide with random user UUIDv4):
- Filmtone Signature: `FB1A0001-0000-4000-8000-000000000001`
- Clean Base: `FB1A0001-0000-4000-8000-000000000002`
- Amber Glow: `FB1A0001-0000-4000-8000-000000000003`
- Soft Blue: `FB1A0001-0000-4000-8000-000000000004`
- Night Soft: `FB1A0001-0000-4000-8000-000000000005`

**Helpers exposed**:
- `static func look(matching id: UUID) -> BuiltInLook?`
- `static func slug(for id: UUID) -> String?`
- `static func materializeAsSavedLookEntry(_:favoriteOverride:asOf:) -> SavedLookEntry`
- `static let allLuts: [BuiltInLook] = []` — empty in v1.3; v1.4 may add bundled `.cube` Camera Profiles via this slot.

**Camera Profile coordination**: Camera Profiles (separate plan) uses a sibling `FilmtoneSourceProfileCatalog`, NOT this catalog. Item 2 ↔ Camera Profiles share only the `bundled` / `immutable` flag *concept*; the actual implementation surfaces are independent.

### `4230dd9a` — Phase C: library merge / dispatch / immutability

**File modified**:
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibraryStore.swift`

**Changes**:
- `currentSnapshot()` prepends materialized built-in Looks to user-saved Looks. Built-ins always pin first; user looks sort by favorite/updatedAt as before.
- `loadLook(id:)` dispatches to `FilmtoneBuiltInCatalog.look(matching: id)` first (no disk I/O); falls through to in-memory `looks[id]` for user entries.
- `renameLook(id:, name:)` and `deleteLook(id:)` check `FilmtoneBuiltInCatalog.slug(for: id)` and throw `StoreError.immutableEntry(slug:)` for built-ins.
- `toggleFavoriteLook(id:)` routes built-ins to UserDefaults map `filmtone.builtin.favorites.v1` (`[String: Bool]` keyed by slug); user looks update on-disk JSON entry as before.
- New helpers: `loadBuiltInLookFavorites()`, `writeBuiltInLookFavorite(slug:favorite:)`, `builtInLookAsOfDate` (frozen at 2026-04-30 JST so re-launches don't shuffle).
- LUT-side methods (`renameLut`, `toggleFavoriteLut`, `deleteLut`) NOT extended — `FilmtoneBuiltInCatalog.allLuts == []` in v1.3, so the guard would be a no-op. v1.4 Camera Profile (B) bundled-cube case will need to add LUT-side guards then.

### `b78f9641` — Phase D: UI chip + strings

**Files modified**:
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift` — adds 5 localized look names + badge label + `builtInLookName(for slug:) -> String?` and `displayName(for look:) -> String` helpers (extension on `FilmtoneStrings`).
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySection.swift`:
  - `FilmtoneLibraryChip` gains optional `badgeText: String?`. When non-nil, fills with `Color.filmtoneAmber.opacity(0.18)`, strokes with amber 0.32, and overlays a top-right caption2 `FILMTONE` pill on a `Color.black.opacity(0.42)` capsule.
  - `FilmtoneSavedLooksStrip`:
    - Uses `strings.displayName(for: entry)` instead of `entry.name` (resolves Japanese names for built-ins via slug lookup).
    - Passes `badgeText: entry.bundled ? strings.builtInBadgeLabel : nil`.
    - Hides `Rename` and `Delete` context-menu buttons when `entry.immutable` is true.
- Both files in same commit.

**Localized strings added** (`FilmtoneStrings`):
- `builtInLookFilmtoneSignature: String` — JP: フィルムトーン / EN: Filmtone Signature
- `builtInLookCleanBase: String` — JP: クリーンベース / EN: Clean Base
- `builtInLookAmberGlow: String` — JP: アンバーグロー / EN: Amber Glow
- `builtInLookSoftBlue: String` — JP: ソフトブルー / EN: Soft Blue
- `builtInLookNightSoft: String` — JP: ナイトソフト / EN: Night Soft
- `builtInBadgeLabel: String` — same in JP and EN: `FILMTONE` (brand glyph, not translatable)

**Strings keys** (NSLocalizedString-style for `Localizable.xcstrings`):
- `filmtone.builtin_look.filmtone_signature`
- `filmtone.builtin_look.clean_base`
- `filmtone.builtin_look.amber_glow`
- `filmtone.builtin_look.soft_blue`
- `filmtone.builtin_look.night_soft`
- `filmtone.builtin_look.badge`

---

## 4. What remains (this is the work for the next chat)

### Item 2 remaining phases

**Phase E — Sidecar additive built-in fields** (1 commit)

Modified file: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`

The sidecar's `savedLook` block (added in Item 3) currently emits `{ id, name, updatedAtIso }`. Item 2 adds two additive optional fields per the execution plan §8 Phase E:

```swift
struct SidecarSavedLookRef: Encodable {
    let id: String
    let name: String
    let updatedAtIso: String
    let bundled: Bool?       // NEW v1.3 (Item 2); nil for user looks (omitted by encoder)
    let bundledSlug: String? // NEW v1.3 (Item 2); nil for user looks
}
```

In `makePayload`, when constructing `SidecarSavedLookRef` from `EditorStore.appliedSavedLookId` (Item 3 transient property), check `FilmtoneBuiltInCatalog.builtInLookSlug(matching: id)` (or use `FilmtoneBuiltInCatalog.slug(for: id)` directly from Phase B helpers) and populate `bundled` + `bundledSlug` accordingly.

Sidecar schemaVersion stays at 1 (CLAUDE.md §5 V1 contract — additive optional fields don't bump V1).

**Verification**: contract test under `scripts/swift/test-sidecar-builder.swift` should still pass (additive field, V1 readers ignore unknown keys). May need to add a positive assertion that `bundled` / `bundledSlug` round-trip when populated.

**Phase F — Unit tests (Polish, optional in v1.3)**

New file: `apps/capacitor-film-lab-ios/ios/App/AppTests/FilmtoneBuiltInCatalogTests.swift`

Tests:
- `test_allLooks_haveDeterministicCanonicalUUIDs()` — each Look's UUID matches the hardcoded constants; UUIDs are unique across the catalog.
- `test_allLooks_useLockedPresetNames()` — every `presetName` is in `FilmtonePhase0Generated.paramsByName.keys`.
- `test_materialize_isPure()` — materializing the same Look twice produces identical `SavedLookEntry` (modulo `createdAt`/`updatedAt`).
- Extension to `FilmtoneLibraryStoreTests.swift` (Item 3 introduces this if it doesn't exist):
  - `test_savedLooksMerged_pinsBuiltInsFirst()`
  - `test_renameSavedLook_refusesBuiltIn()`
  - `test_deleteSavedLook_refusesBuiltIn()`
  - `test_toggleFavoriteLook_built_in_persistsToUserDefaults()`
  - `test_loadSavedLook_dispatchesToBuiltInWithoutDiskIO()`

If `FilmtoneLibraryStoreTests.swift` doesn't exist yet (Item 3 may have skipped it), this is an opportunity to add it — but check first.

pbxproj register `FilmtoneBuiltInCatalogTests.swift` in 4 sections of the AppTests target.

**Phase G — Snapshot tests (Polish, optional in v1.3)**

Lock device: iPhone 17 Pro Max iOS 26.2 (UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`) per CLAUDE.md §5.

New scenes in `apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift`:
- `library_section_with_built_ins` — chip strip showing all 5 built-in Filmtone Looks with badges.
- `library_section_built_in_long_press_menu` — action sheet on built-in chip shows only `Apply` + `Toggle Favorite`, NOT `Rename` / `Delete`.
- `look_applied_filmtone_signature` — preview reflects `iphone` preset visual after applying Filmtone Signature.

Re-baseline existing v1.2 scenes if the chip strip layout shifted (it shouldn't — bundled chips have the same outer dimensions as user chips, just different fill/badge).

**Phase H — Documentation cleanup**

Modified files:

- `apps/capacitor-film-lab-ios/src/presets/luts/README.md` — rewrite per execution plan §8 Phase H. Replace the historical "vlog-to-rec709.cube + filmtone-signature.cube" intent with: "v1.3 ships zero bundled `.cube`. Camera profiles handled via native Apple Log/Apple Log 2 detection (`HdrPreparationPolicyDeriver`) and Rec.709 default. Built-in Looks are params-only via `FilmtoneBuiltInCatalog.swift`. v1.4 may revisit bundled V-Log/S-Log3 conversion `.cube` files pending licensing + calibrated-ramp accuracy."

- `apps/capacitor-film-lab-ios/src/presets/signature.ts` — update `SIGNATURE_PRESET_BUNDLE_NOTE` to reference `FilmtoneBuiltInCatalog` (Swift native). Keep `SIGNATURE_LUT_PLAN.bundledRelPath: null` on both slots.

- `apps/capacitor-film-lab-ios/CLAUDE.md` — add §13 "Built-in Catalog (v1.3+)": pointer to `FilmtoneBuiltInCatalog.swift`, canonical UUID table, immutability rule, UserDefaults favorites key. Keep under 30 lines (CLAUDE.md is harness budget).

- `apps/capacitor-film-lab-ios/fastlane/metadata/ja/release_notes.txt` and `en-US/release_notes.txt` — replace v1.2 text with v1.3 draft from execution plan §7. Vocabulary-gate compliant. Coordinated with Camera Profiles release notes (if Camera Profiles also ship in v1.3, both lanes' bullets fold into one paragraph).

ja draft (v1.3, Item 2 only):
```
v1.3 では、起動直後から Filmtone のトーンを選べるようにしました。Look には Filmtone Signature を含む 5 種類の組み込みフィルムルックを追加し、各 Look は強さ 0–100% で調整できます。インポートした .cube LUT はライブラリで再利用でき、現在のグレードを Look として保存して、別の素材に同じトーンを当てられます。Camera Profile は Apple Log / Apple Log 2 の素材を引き続き自動検出します。
```

en draft (v1.3, Item 2 only):
```
v1.3 makes Filmtone usable from first launch. Five built-in Filmtone Looks — including Filmtone Signature — are available immediately, each with 0–100% intensity. Imported .cube LUTs are reusable from the library, and you can save the current grade as a Look to apply the same tone to another clip. Apple Log and Apple Log 2 sources continue to be detected automatically by the Camera Profile.
```

**Phase I — Release rail**

After v1.2 ASC submit lane closes (currently in flight, separate concern):
- Bump Xcode `MARKETING_VERSION` 1.2 → 1.3 (in build settings, NOT direct Info.plist edit).
- Bump `CURRENT_PROJECT_VERSION` 1 → 2 for v1.3 build 1.
- Confirm `FilmtoneExportActivity` version stays aligned with main app per `apps/capacitor-film-lab-ios/RELEASE.md` checklist.
- Follow `RELEASE.md` for v1.3 archive / TestFlight / submission. Do NOT push without user approval.

### Camera Profiles — all phases remaining

Plan: `/Users/chibatakumi/.claude/plans/dreamy-forging-hartmanis-camera-profiles-execution.md`

Phase ordering per the execution plan §10:

| Phase | What | Files |
|---|---|---|
| A | Schema slot | New `FilmtoneSourceProfileSchema.swift`. Modify `FilmtonePhase0Math.swift` `FilmtoneProjectState` to add `cameraProfile: CameraProfileSelection = .auto`. |
| B | V-Log math + fixture + test | New `FilmtoneSourceProfileMath.swift` (V-Log first). New `apps/capacitor-film-lab-ios/Tests/FilmtoneSourceProfileMathTests.swift`. New `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/panasonic-vlog/`. New `apps/capacitor-film-lab-ios/docs/source-profile-math/panasonic-vlog.md`. **filmtoneSdrShoulder SSOT migration** from `FilmtoneExportSession.swift:2418` to the new math module — verify byte-identical Apple Log output before/after via existing snapshot tests. |
| C | S-Log3 math + fixture + test | Add slog3Decode + slog3PixelToRec709 to `FilmtoneSourceProfileMath.swift`. New `Tests/Fixtures/source-profile/sony-slog3/`. New `docs/source-profile-math/sony-slog3.md`. New tests added to `FilmtoneSourceProfileMathTests`. |
| D | Catalog registration | New `FilmtoneSourceProfileCatalog.swift`. New strings in `FilmtoneStrings.swift` (cameraVLog, cameraSLog3, cameraRec709, cameraDetectedSuffix, cameraProfileResetNotApplicable, builtInSourceProfileName helper). |
| E | Pipeline dispatch | Rename `makeAutomaticInputLut` → `makeActiveInputLut(for selection:probe:)` in `FilmtoneExportSession.swift`. Add `cameraProfile` to `Phase0ExportRequestDTO` and `iosPhase0ExportPayloadSchema`. |
| F | UI: picker + row label | Modify `FilmtoneRootView.swift` `cameraProfileCard` Menu (lines 362-372). Modify `FilmtoneEditorStore.swift` `cameraProfileLabel` (lines 596-609) + add `applyCameraProfile`, `applyCameraProfileSourceChangeRule(probe:)`. |
| G | Sidecar additive `cameraProfile` block | Modify `FilmtoneExportSidecarBuilder.swift`. |
| H | Snapshot tests | iPhone 17 Pro Max iOS 26.2 scenes for picker, detected suffix, V-Log applied, source-change reset notice. |
| I | Docs cleanup | `apps/capacitor-film-lab-ios/src/presets/luts/README.md` rewrite; `apps/capacitor-film-lab-ios/CLAUDE.md` §13; fastlane release notes coordinated with Item 2. |
| J | Release rail | Coordinated with Item 2 Phase I. |

**Critical hard gate**: every (S) curve PR MUST include math doc + accuracy fixture + accuracy test. No silent fallback. Build fails on drift beyond D-CP5 tolerance.

---

## 5. Critical invariants and conventions (do not violate)

### Schema / contract invariants

- **`Profile.version` stays at `4`**. (CLAUDE.md §5)
- **Sidecar V1 stays additive only.** New fields are Codable optional, V1 readers ignore unknown keys, no V2 bump. (CLAUDE.md §5)
- **iOS preset names locked**: `["reset", "iphone", "softBlue", "amberGlow"]` in `FILMTONE_IOS_PRESET_NAMES` (`packages/film-lab-core/src/ios-preset-overrides.ts:10`). Any new preset name breaks the Zod-enforced `iosPhase0PresetIdSchema`. Built-in Looks compose existing presets with custom Quick state + paramOverrides — they do NOT introduce new preset names.
- **`FilmtoneLibraryConstants.entrySchemaVersion`** is the single global per-entry schema version constant (NOT per-entry literal). Bumped to `2` in Phase A.
- **Built-in canonical UUIDs** are stable across versions. Bump `FilmtonePhase0Math.presetVersion` (a `String`, not Int) when a built-in's recipe meaningfully changes — never change the UUID.
- **`presetVersion` field type is `String`**, not `Int` (corrected from earlier Item 2 plan; actual ships as `String` referencing `FilmtonePhase0Generated.presetVersion`).
- **`paramOverrides` is `FilmtonePhase0ParamsPatch`** (a key-value patch dict), not full `params: Phase0ParamsDTO` (also corrected from earlier plan text).
- **`FilmtoneQuickState`** axes are `filmCharacter` / `era` / `dynamics` (NOT `brightness` / `contrast` / `saturation` — those are placeholder names from earlier plan drafts). All v1.3 built-in Looks use `.zero` Quick state; differentiation lives in `paramOverrides`.

### Build / commit / push rules

- **Use `bun`, not `npm`**. Global user CLAUDE.md mandates this. iOS app uses `bun run build`, `bun run verify:swift-contract`, `bun run cap:sync:ios`, `bun run release:archive`, etc.
- **CLAUDE.md §4 commit gate** — every commit must pass:
  1. `bun run build` (tsc --noEmit + vite build) succeeds.
  2. `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` produces `** BUILD SUCCEEDED **`.
  3. Affected Phase 0 contract test (`bun run verify:swift-contract`) passes.
  4. Any new `.swift` file is registered in **all 4 pbxproj sections** (`PBXBuildFile`, `PBXFileReference`, `PBXSourcesBuildPhase`, `PBXGroup`). Verify via `grep -c "<filename>" apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` ≥ 4.
- **No silent fallbacks** (CLAUDE.md §11 `feedback_no_fallback_bug_hotbed`). If a curve fails accuracy verification, fail the build, do NOT silently degrade.
- **Do NOT push without explicit user approval** (CLAUDE.md §11). Commits OK after the user says proceed; pushes need a separate approval per the prior chat / plan instructions.
- **No `--no-verify` / `--no-gpg-sign`** unless user explicitly requests.

### Localization conventions

- `FilmtoneStrings` uses `prefersJapanese` ternary in `defaultValue` of `filmtoneLocalized(...)`. Mirror this when adding new strings.
- ASCII arrows (`->`) over Unicode (`→`) in existing strings (e.g. `cameraAutoAppleLogDetected = "Auto -> Apple Log detected"`). Match the convention when adding new strings.
- Forbidden vocabulary (Filmtone copy gate per `docs/guides/film-lab-current-index.md`):
  - JP: do NOT use `短尺動画`. Use `動画` instead.
  - EN: do NOT use `short-form video` / `short-form clips` / `short clips`. Use `video` / `videos` / `footage` / `clip`.
- App Store description / fastlane release notes both subject to the gate.

### File path / naming conventions

- Handoff docs: `docs/filmtone/ios/<topic>-handoff-<date>-jst.md` (per-feature) OR `docs/guides/<date>-filmtone-ios-<topic>-handoff.md` (cross-feature lane). This handoff uses the latter.
- Plan files: `/Users/chibatakumi/.claude/plans/<harness-assigned-name>.md` (the harness names them; do not invent paths).
- Snapshot test device: iPhone 17 Pro Max iOS 26.2, UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`. Locked per CLAUDE.md §5; no fallback / runtime discovery.

### Codable backward-compat pattern

Phase A adopted this pattern; reuse when adding more optional fields:

```swift
struct SomeEntry: Codable, Equatable, Sendable {
    // existing fields ...
    var newField: Bool = false      // default in stored property → memberwise init picks it up
    var newOptional: String? = nil
}

extension SomeEntry {
    private enum CodingKeys: String, CodingKey { /* all fields */ }

    init(from decoder: Decoder) throws {
        // ... decode existing fields ...
        self.newField = try c.decodeIfPresent(Bool.self, forKey: .newField) ?? false
        self.newOptional = try c.decodeIfPresent(String.self, forKey: .newOptional)
    }

    func encode(to encoder: Encoder) throws {
        // ... encode existing fields ...
        try c.encode(newField, forKey: .newField)
        try c.encodeIfPresent(newOptional, forKey: .newOptional)
    }
}
```

Why extension: putting custom Codable in `extension` (not main body) preserves the synthesized memberwise init. Existing call sites that don't pass the new fields still compile because the stored-property defaults flow through the memberwise init. v1.2 saves decode cleanly because `decodeIfPresent ?? default` handles missing keys.

---

## 6. Verification commands (canonical)

Run from `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` (root of monorepo) unless noted:

```sh
# 1. Truth check (run before reporting status)
bash /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh

# 2. TS layer
cd apps/capacitor-film-lab-ios
bun run build                  # tsc --noEmit + vite build
bun test src/lib/phase0-state.test.ts
bun run verify:swift-contract  # ./scripts/verify-phase0-contract.sh

# 3. iOS Swift layer (all gates must be green before commit)
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO

# 4. iOS unit tests (after Phase F)
xcodebuild test -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'platform=iOS Simulator,id=D3011FE4-52CA-4B7F-B181-A55D9998E192' \
  -only-testing:AppTests

# 5. iOS snapshot tests (after Phase G — same UDID lock)
xcodebuild test -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'platform=iOS Simulator,id=D3011FE4-52CA-4B7F-B181-A55D9998E192' \
  -only-testing:FilmtoneSnapshotsUITests

# 6. pbxproj registration check (after each new .swift file)
for f in <NewFile1> <NewFile2>; do
  echo -n "$f: "; grep -c "$f.swift" ios/App/App.xcodeproj/project.pbxproj
done
# each must report ≥ 4
```

### Stale-cache trap (encountered this session)

xcodebuild's incremental cache occasionally caches a stale module hash. Symptom: "Undefined symbols for architecture x86_64" with `init(...sidecarUri: String?)` (i.e., the OLD signature) referenced from a file that should have been recompiled.

**Fix**: clean build:
```sh
xcodebuild -workspace ios/App/App.xcworkspace -scheme App clean
xcodebuild ... build CODE_SIGNING_ALLOWED=NO  # rebuild fresh
```

Encountered after Phase A precursor fix → resolved with one clean.

---

## 7. Key file inventory (working tree as of handoff)

### Plans (in `/Users/chibatakumi/.claude/plans/`)

- `dreamy-forging-hartmanis.md` — Item 3 plan (Library + Saved Looks). Item 3 has shipped; this is the schema reference.
- `dreamy-forging-hartmanis-item2.md` — Item 2 plan (Look pack scope, gates, Recommended approach).
- `dreamy-forging-hartmanis-item2-execution.md` — Item 2 execution plan written this session, all D1-D6 resolved.
- `dreamy-forging-hartmanis-camera-profiles.md` — Camera Profiles plan (D-CP1〜D-CP7 originally proposed).
- `dreamy-forging-hartmanis-camera-profiles-execution.md` — Camera Profiles execution plan written this session, all D-CP1〜D-CP7 resolved with verified spec citations.

### iOS Swift files modified or created on this branch

| File | Phase | Change |
|---|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift` | precursor | + `packageFileUris: [String]?` on `Phase0ExportResultDTO` |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorFacade.swift` | precursor | + `packageFileURIs:` parameter on `shareOutput` |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySchema.swift` | A | `entrySchemaVersion` 1→2; + `bundled` / `immutable` / `bundledSlug` on both entries; custom Codable in extension |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibraryStore.swift` | A | + `StoreError.immutableEntry(slug:)` |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift` | B | NEW — 5 built-in Looks + materialize helper |
| `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | B | + 4 sections for FilmtoneBuiltInCatalog.swift |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibraryStore.swift` | C | merge / dispatch / immutability / UserDefaults favorites |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift` | D | + 5 built-in look name strings + badge label + helpers |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySection.swift` | D | + `badgeText` on chip + bundled-aware action sheet + display name resolution |

### Critical Item 3 surfaces (already shipped, do not touch unnecessarily)

- `FilmtoneLibrarySchema.swift` — schema (extended in Phase A).
- `FilmtoneLibraryStore.swift` — actor (extended in Phase A + C).
- `FilmtoneLibrarySection.swift` — UI strips (extended in Phase D).
- `FilmtoneSavedLookSheet.swift` — Save Current Look modal.
- `FilmtoneLutBlobCodec.swift` — Float32 binary LUT codec + SHA-256 hashing.
- `FilmtoneEditorStore.swift` — `applyLibraryLut`, `applySavedLook`, `appliedSavedLookId` transient property, source-change branch (line 1474-1477).
- `FilmtoneExportSidecarBuilder.swift` — `SidecarSavedLookRef` (Phase E will extend with `bundled` / `bundledSlug`).

### Critical existing functions (pre-existing reference points)

- `FilmtoneExportSession.swift:2331-2362` — `makeAppleLogToRec709Lut(size:rec2020GamutMap:)`. **Phase B + C of Camera Profiles must mirror this pattern for V-Log / S-Log3.**
- `FilmtoneExportSession.swift:2364-2386` — `appleLogPixelToRec709`. The pixel-level pipeline `linearize → gamut map → Filmtone shoulder → rec709 encode`. Camera Profiles (S) curves use the identical pipeline structure.
- `FilmtoneExportSession.swift:2388-2404` — `appleLogDecode`. Pure linearization function; analog of the `vlogDecode` / `slog3Decode` to be added.
- `FilmtoneExportSession.swift:2406-2415` — `rec2020ToRec709`. Camera Profiles (S) curves use pre-computed `vgamutToRec709` / `sgamut3CineToRec709` matrices instead.
- `FilmtoneExportSession.swift:2418-2422` — `filmtoneSdrShoulder`. **SSOT for Filmtone identity SDR roll-off.** Camera Profiles plan moves this to `FilmtoneSourceProfileMath.swift` as a shared module-level function — do this migration as a no-behavior-change refactor, verify byte-identical output before continuing.
- `FilmtoneExportSession.swift:2424-2430` — `rec709Encode`. Same pattern as filmtoneSdrShoulder.
- `FilmtoneExportSession.swift:2292-2301` — `makeAutomaticInputLut(for:)`. Renamed to `makeActiveInputLut(for selection:probe:)` in Camera Profiles Phase E.
- `FilmtoneExportSession.swift:1573-1592` — `applyLut`. The CIFilter call (`CIColorCubeWithColorSpace`). All Camera Profile cubes flow through this unchanged.
- `FilmtoneEditorStore.swift:596-609` — `cameraProfileLabel`. Already detection-aware for Apple Log / Apple Log 2.
- `FilmtoneEditorStore.swift:1468-1490` — `applyProbe`. Source-change branch at line 1474-1477 clears `project.inputLut`. Camera Profiles Phase F adds `applyCameraProfileSourceChangeRule(probe:)` here.
- `FilmtoneRootView.swift:350-429` — `cameraProfileCard`. Camera Profiles Phase F extends the picker Menu (lines 362-372 for Camera; 396-406 for Look — Item 3 already added Save current Look here).

---

## 8. Camera Profiles spec citations (transcribed verbatim from manufacturer docs)

These are the exact values that go into `FilmtoneSourceProfileMath.swift` per-curve doc files when Camera Profiles is implemented. Source: web-fetched from manufacturer URLs + verified mirrors at 2026-04-30 JST.

### Apple Log (existing — for reference)

Source: existing `appleLogDecode` shipping in `FilmtoneExportSession.swift:2388-2404`. Apple has not published a machine-readable spec; constants are transcribed from the shipping code:

```
r0    = -0.05641088
rt    =  0.01
sigma =  47.28711236
beta  =  0.00964052
gamma =  0.08550479
delta =  0.69336945
pt    = sigma * (rt - r0)^2

Decoding (V → linear):
  if V >= pt:           L = 2^((V - delta) / gamma) - beta
  if 0 <= V < pt:       L = sqrt(max(V / sigma, 0)) + r0
  if V < 0:             L = r0
```

Gamut: Rec.2020 / BT.2020. Apply existing `rec2020ToRec709` matrix.

### Apple Log 2

Same EOTF as Apple Log (web-search verified via gamut.io 2026-04-30). Gamut is Apple Wide Gamut, NOT Rec.2020 — current implementation approximates with Rec.2020 matrix. v1.3 ships this as documented known-limitation.

### Panasonic V-Log

**Source**: Panasonic, *V-Log/V-Gamut REFERENCE MANUAL*, November 28, 2014.
- URL: https://pro-av.panasonic.net/en/cinema_camera_varicam_eva/support/pdf/VARICAM_V-Log_V-Gamut.pdf
- Verified mirror: https://antlerpost.com/colour-spaces/VGamut.html (constants match manufacturer)

```
Constants:
  cut1 = 0.01
  cut2 = 0.181
  b    = 0.00873
  c    = 0.241514
  d    = 0.598206

Decoding (V → linear, what we implement):
  if V < cut2:   L = (V - 0.125) / 5.6
  if V >= cut2:  L = 10^((V - d) / c) - b

V-Gamut → XYZ matrix (D65):
  [[ 0.679644,  0.152211,  0.118600],
   [ 0.260686,  0.774894, -0.035580],
   [-0.009310, -0.004612,  1.102980]]

V-Gamut → Rec.709 matrix (precomputed, D65 → D65, no chromatic adaptation):
  [[ 1.7398, -0.6727, -0.0671],
   [-0.1956,  1.2473, -0.0518],
   [-0.0114, -0.0440,  1.0554]]
```

The V-Gamut → Rec.709 matrix is the product of XYZ→Rec.709 (standard) and V-Gamut→XYZ. Verify via unit test that the matrix product equals the precomputed values.

### Sony S-Log3

**Source**: Sony, *Technical Summary for S-Gamut3.Cine/S-Log3 and S-Gamut3/S-Log3*.
- URL: https://pro.sony/s3/cms-static-content/uploadfile/06/1237494271406.pdf
- Verified mirror: https://antlerpost.com/colour-spaces/SLog3.html (equations match manufacturer)

```
Decoding (V is normalized 0..1, V → linear):
  threshold = 171.2102946929 / 1023.0       (≈ 0.16739734...)

  if V < threshold:
    L = ((V * 1023 - 95) * 0.01125) / (171.2102946929 - 95)
  if V >= threshold:
    L = 10^((V * 1023 - 420) / 261.5) * (0.18 + 0.01) - 0.01

S-Gamut3.Cine → XYZ matrix (D65):
  [[ 0.5990839208,  0.2489255161,  0.1024464902],
   [ 0.2150758201,  0.8850685017, -0.1001443219],
   [-0.0320658495, -0.0276583907,  1.1487819910]]

S-Gamut3.Cine → Rec.709 matrix (precomputed):
  [[ 1.6269, -0.5365, -0.0904],
   [-0.1078,  1.1628, -0.0550],
   [-0.0140, -0.0240,  1.0379]]
```

S-Gamut3 (non-Cine) variant rarely used outside FX9/Venice; deferred to v1.4.

### Filmtone shoulder (shared display mapping, identical across all curves)

```swift
private static func filmtoneSdrShoulder(_ linear: Double) -> Double {
    let exposed = max(0, linear * 1.18)
    let shoulder = exposed / (1 + max(exposed - 0.18, 0) * 0.42)
    return clamp(shoulder, min: 0, max: 1)
}
```

All Camera Profile curves apply this identical shoulder before `rec709Encode`. Cross-curve consistency test asserts byte-identical output for matched linear inputs.

---

## 9. Risks and known limitations

| Risk | Status / mitigation |
|---|---|
| `main` is broken on `packageFileUris` references from DaVinci v0 spike | **Resolved** in this branch by precursor fix `b25c08d8`. Upstream `main` still has the issue until this branch merges. |
| Apple Log 2 gamut treated as Rec.2020 (technically Apple Wide Gamut) | **Documented known limitation**. v1.3 ships as-is; v1.4 refines. CD signed off via AskUserQuestion 2026-04-30. |
| DaVinci spike feature branch (`feature/filmtone-davinci-connect-package` @ `63622a8d`) carries the full `packageFileUris` wiring | Coordinate before merging this branch. The minimal precursor fix here just adds the field/parameter so build works; the full DaVinci feature ships later. |
| Library `LutLibraryEntry` immutability guards not yet applied in `renameLut` / `deleteLut` / `toggleFavoriteLut` | Acceptable in v1.3 since `FilmtoneBuiltInCatalog.allLuts == []`. v1.4 Camera Profile (B) bundled-cube case must add LUT-side guards before shipping bundled `.cube`. |
| Synthesized math errors (V-Log gain/offset typo) when Camera Profiles ships | Mandatory accuracy fixture per (S) curve; build fails on drift. CD-approved tolerance budget is the gate. |
| Filmtone shoulder SSOT migration during Camera Profiles Phase B | Move from `FilmtoneExportSession.swift` to `FilmtoneSourceProfileMath.swift` as a no-behavior-change refactor. Verify byte-identical Apple Log output via existing snapshot tests before continuing. If diff appears, revert and split. |
| User picks wrong Camera Profile (V-Log on S-Log3 footage) | UI choice obvious + reversible. NO silent auto-detect for non-Apple log curves (per established premise). |
| Reference LUT used in fixtures is itself wrong (circularity) | Synthesized fixtures via colour-science Python (BSD-3-Clause), NOT manufacturer LUT. Cross-check vs manufacturer LUT once at curve introduction; CI uses colour-science only. |
| Snapshot tests break on chip strip layout shift | Re-baseline at locked iPhone 17 Pro Max iOS 26.2 UDID. Item 2 chip dimensions match user chip dimensions; only fill/badge differ — re-baseline minimal. |

---

## 10. Pre-existing issues NOT touched

- **DaVinci spike completion**: out of scope. The precursor fix only unblocks build; the full export pipeline lives on `feature/filmtone-davinci-connect-package`.
- **3 untracked DaVinci handoff docs** in `docs/filmtone/ios/`:
  - `filmtone-connect-davinci-overall-plan-2026-04-30-jst.md`
  - `filmtone-connect-davinci-real-package-export-handoff-2026-04-30-jst.md`
  - `filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md`

  These belong to the DaVinci spike author. Do not commit / move / delete them.

- **v1.2 ASC submit lane**: in flight on `main`. v1.3 release rail (Item 2 Phase I + Camera Profiles Phase J) waits for v1.2 to close.

---

## 11. Suggested next-chat starting paths (pick one based on user direction)

| Path | Recommended | Rationale |
|---|---|---|
| **Item 2 Phase E (sidecar)** | 🔵 yes | Smallest, completes the Item 2 round-trip (apply built-in → export → sidecar records `bundled: true, bundledSlug: <slug>`). 1 commit, ~30 lines, additive to V1 sidecar. Closes the visible Item 2 surface. |
| **Item 2 Phase H (docs cleanup) + I (release rail)** | 🟢 also yes | Required before v1.3 ship anyway. Phase H is just markdown edits; Phase I waits for v1.2 ASC closure. |
| **Camera Profiles Phase A (schema slot)** | 🟡 lower priority | Smallest Camera Profiles phase. Independent of Item 2. New file + add `cameraProfile` field to `FilmtoneProjectState`. |
| **Camera Profiles Phase B (V-Log math)** | 🟡 high effort | Largest single phase: math file + colour-science Python script + 3 fixture artifacts + accuracy test + per-curve doc + filmtoneSdrShoulder SSOT migration. Hold for user direction. |
| Item 2 Phase F + G (tests + snapshots) | 🟢 polish | Optional in v1.3 per execution plan §13. Can ship Phase E without these and add tests in v1.4 if scope tight. |

Conservative order: **E → H → I**, then **Camera Profiles A → B → C** in fresh chat or extended session.

---

## 12. Final handoff prompt (paste into a new chat)

```
We are in /Volumes/SamsungPortableSSDX5001/documents/life.

Task: Continue Filmtone iOS v1.3 implementation from the handoff at
docs/guides/2026-04-30-filmtone-ios-v1.3-built-in-pack-camera-profiles-handoff.md
in the chibatakumi-portfolio repo. Item 2 Phases A〜D + a precursor packageFileUris
fix have shipped to the feature branch feat/filmtone-ios-built-in-look-pack
(5 commits ahead of main). Item 3 (LUT Library + Saved Looks) is already shipped
on local main. Camera Profiles is fully planned but not implemented.

REQUIRED FIRST STEPS (in order, do not skip):
1. Read /Volumes/SamsungPortableSSDX5001/documents/life/AGENTS.md.
2. Run: node /Volumes/SamsungPortableSSDX5001/documents/life/scripts/life-route.mjs "filmtone ios v1.3 built-in look pack camera profiles"
3. Read /Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/film-lab-current-index.md
4. Run: bash /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
   — confirm public/local axes. Public is App Store v1.1; local Xcode is v1.2; targeting v1.3.
5. **Read the handoff doc fully** —
   /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/guides/2026-04-30-filmtone-ios-v1.3-built-in-pack-camera-profiles-handoff.md
   This single document contains everything: branch state, all 5 commits' content, all
   D-decision resolutions for Item 2 D1〜D6 and Camera Profiles D-CP1〜D-CP7, CD sign-offs,
   spec citations, file inventory, and remaining-work breakdown.
6. Read the three execution plans for full implementation detail:
   - /Users/chibatakumi/.claude/plans/dreamy-forging-hartmanis-item2-execution.md (Item 2 Phase E〜I detail)
   - /Users/chibatakumi/.claude/plans/dreamy-forging-hartmanis-camera-profiles-execution.md (Camera Profiles Phase A〜J detail with verified spec citations)
   - /Users/chibatakumi/.claude/plans/dreamy-forging-hartmanis.md (Item 3 schema reference — already shipped)

Target implementation repo:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios

Working branch already exists: feat/filmtone-ios-built-in-look-pack
Switch to it before starting work:
  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
  git checkout feat/filmtone-ios-built-in-look-pack

Verify build is green from the previous chat:
  cd apps/capacitor-film-lab-ios
  xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug build CODE_SIGNING_ALLOWED=NO
  bun run verify:swift-contract
  bun run build
All three must pass before proceeding.

Suggested next phase (confirm with user):
- Item 2 Phase E (sidecar additive bundled / bundledSlug fields) — smallest remaining commit
  to fully close Item 2's apply → export → sidecar round-trip. ~30 lines in
  FilmtoneExportSidecarBuilder.swift.
- Then Item 2 Phase H (docs cleanup) + Phase I (release rail bump 1.2 → 1.3 after v1.2 ASC
  closure).
- Then Camera Profiles Phase A (schema slot) → Phase B (V-Log math + fixture + accuracy test)
  per the Camera Profiles execution plan §10. Each (S) curve PR MUST land math doc + fixture
  + accuracy test in the same PR (hard ship gate).

Session-specific guidance (from the user across both prior chats):
- 本質優先 / 外殻最小. Catalog accuracy beats catalog breadth. Each (S) curve must be
  defended on a calibrated ramp before shipping.
- 保守的な意見は優先せず、プロダクト品質を最優先する.
- 思考すべきところは必ず sequential-thinking で考える (mcp__sequential-thinking).
- わからないことは検索 (gemini-search または WebSearch). 記憶ベースの断言は禁止.
- 並列実行できる独立操作はまとめて invoke する.
- 時間がかかってもよいので正確に推論する; こちらの思考力は気にせず計算資源を最大限使う.

Hard constraints (CLAUDE.md §4 / §5 / §11; do NOT violate):
- 本質優先 / 外殻最小: catalog accuracy beats catalog breadth.
- Math is not copyrightable; manufacturer documents are reference, not redistributable assets.
  The (S) Synthesized route avoids the licensing/asset gate.
- Each (S) entry MUST land with math doc + reference fixture + accuracy test in the SAME PR.
  No shipping unverified curves. Build fails on drift beyond D-CP5 tolerance.
- Sidecar V1 stays additive only; no V2 bump.
- Built-in id namespace must not collide with user UUID format. Item 2 uses canonical UUIDs
  in the FB1A prefix (collision prob 2^-120). Camera Profiles uses string namespace
  "built-in:source-profile.<slug>" to avoid UUID confusion entirely.
- Profile.version stays at 4. FilmtonePersistenceSnapshot schema untouched.
- TS path (MobilePhase0Editor, phase0-storage) is dead code on iOS — do not modify.
- No silent fallbacks.
- Snapshot tests locked to iPhone 17 Pro Max iOS 26.2 UDID D3011FE4-52CA-4B7F-B181-A55D9998E192.
- Use bun, not npm, throughout.
- Commit gate per CLAUDE.md §4: bun run build + xcodebuild build + verify:swift-contract +
  pbxproj 4-section registration for any new .swift file.
- Custom Codable in extension (NOT main body) when adding additive optional fields, so the
  synthesized memberwise init is preserved. See Phase A precedent at
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySchema.swift.
- Commit messages in English (match existing repo voice). Include
  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  on every commit.
- Do NOT push without explicit user approval. Do NOT use --no-verify / --no-gpg-sign.
- Vocabulary gate: do not use 短尺動画 in JP copy or short-form video in EN copy. Use 動画 / video.
- The 3 untracked DaVinci handoff docs in docs/filmtone/ios/ belong to the DaVinci spike author —
  do not commit / move / delete them.

CD sign-offs already received (preserve in any subsequent decision):
- 5 built-in Looks ship including Night Soft (curated softBlue variant).
- Japanese names: フィルムトーン / クリーンベース / アンバーグロー / ソフトブルー / ナイトソフト.
- Camera Profiles accuracy budget: linearization ≤ 1e-3, full-frame ≤ 2/255, Macbeth ΔE2000 ≤ 2.0
  max / 1.0 mean. Edge cases ≤ 4/255 mean only.
- Apple Log 2 v1.3 ships with Rec.2020-matrix-as-approximation (known limitation), v1.4 refines.

Ask the user only when the answer changes implementation and cannot be discovered locally
or via search. The CD sign-offs above are settled — do not re-litigate.

When ready to commit each phase, follow CLAUDE.md §4 commit gate, write the commit message
in English matching prior commits' voice (see git log b78f9641 for the most recent style),
and STOP for explicit user approval before pushing.
```

---

## 13. Single-line "remember this" summary

> Item 2 Phases A〜D + a packageFileUris precursor fix shipped on `feat/filmtone-ios-built-in-look-pack` (5 commits, all gates green). 5 built-in Filmtone Looks render with `FILMTONE` amber badges; built-ins refuse rename / delete; favorites map persisted via UserDefaults. Item 2 Phase E (sidecar additive `bundled` / `bundledSlug`) + Phase H (docs) + Phase I (release rail) remain. Camera Profiles (V-Log + S-Log3 + (P) Apple Log fronts) fully planned with verified spec citations, zero commits. Push pending explicit user approval.
