# M5-I.1 Localization / Copy Parity (Native Desktop v2)

Date opened: 2026-05-05 JST
Worktree: `filmtone-native-desktop-m5-i1-localization`
Branch: `feature/native-desktop-m5-i1-localization`

## Milestone

M5 Native Editing UI / iOS canonical parity slice **M5-I.1**. Scope is a thin
copy/localization seam on top of the M5-H.2 Adjust + Library landing.

## Goal

Stop hard-coding English strings inside `AdvancedAdjustCatalog.swift` and the
`AdvancedAdjustEditor` popover. Add a single Desktop-side strings/localization
layer that mirrors the iOS canonical defaults from
`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift` for the
Advanced Adjust surface (group titles, recipe chips, per-key param labels) and
resolves between English and Japanese off `Locale.preferredLanguages` the same
way iOS does.

## Why this slice (本質)

iOS canonical 階調 / なし / 標準 / 強め / 爽やか / 夕景 / 深み chips render in
Japanese on JA locale. Native Desktop currently shows hard-coded English
("Tone", "None", "Default", "Strong", "Standard", "Airy", "Sunset", "Depth")
even on JA locale, breaking the cross-platform consistency 本質 promise made
by M5-H.2. This is a thin, low-risk fix that lifts copy out of the catalog so
later platform-style copy decisions can branch without touching domain code.

## Architectural choice

**Add `FilmtoneDesktopStrings` struct in `Domain/`. Thread it explicitly
through `AdvancedAdjustCatalog.allGroups(strings:)` / `groups(forVideo:strings:)`.
Default convenience accessors call into `.current` so the SwiftUI surface
keeps the existing call shape.**

Reasons:
- Verify needs deterministic English assertions for the existing M5-H.2
  iOS-canonical label drift detector. Threading strings explicitly lets tests
  use `.english` no matter the host locale.
- Production callers (`AdvancedAdjustEditor`, `EditorState+ParamOverrides`)
  read groups via `.current` selector, so JA hosts surface JA copy without
  touching call sites.
- Keep the strings layer Desktop-only and AdvancedAdjust-scoped. Do not lift
  it into the shared package: iOS already owns its own `FilmtoneStrings`, and
  promoting the Desktop variant prematurely would create a parity surface
  that Desktop cannot maintain alone.
- Defer `Localizable.strings` / `.lproj` bundle plumbing. The struct shape is
  a one-line swap if/when Desktop grows real bundle-driven localization.

## Scope

### In

1. **New file** `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneDesktopStrings.swift`
   - `struct FilmtoneDesktopStrings` with: advancedTitle, advancedActiveBadgeFormat,
     advancedResetAllOverrides, advancedClose, advancedClearGroupHelp,
     advancedApplyRecipeHelp, advancedResetParamHelp, group{Basic|Tone|Optics|
     Glow|Grain|Motion}, preset{None|Default|Strong}, tone{Standard|Airy|Sunset|
     Depth}, paramLabels: [String: String], paramLabel(for:).
   - `static let english`, `static let japanese`, `static var current`.
   - `static func prefersJapanese()` mirrors iOS `Locale.preferredLanguages.first`
     check.
2. **Refactor** `AdvancedAdjustCatalog.swift`:
   - Replace `static let allGroups` with `static func allGroups(strings:) -> [Group]`
     and a `static var allGroups: [Group]` convenience using `.current`.
   - Replace `static func groups(forVideo:)` with `static func groups(forVideo:strings:)`
     and convenience using `.current`.
   - Replace every hard-coded label / title / recipe label with strings.* /
     strings.paramLabel(for:) lookups.
3. **Refactor** `AdvancedAdjustEditor.swift`:
   - Pass strings into the popover (init default = `.current`) and use it for
     header title, badge format, close help, recipe chip help, per-row reset
     help, footer "Reset All Overrides" label.
4. **Project + Verify wiring**:
   - Register `FilmtoneDesktopStrings.swift` in `FilmtoneDesktop.xcodeproj`
     (PBXBuildFile + PBXFileReference + Domain group + Sources phase).
   - Add the file to `apps/filmtone-desktop-macos/Verify/run.sh` SOURCES.
5. **Verify coverage** (`Verify/main.swift`):
   - Update Test group 10 iOS-canonical label drift detector to use
     `AdvancedAdjustCatalog.allGroups(strings: .english)` so the assertion
     stays deterministic on JA hosts.
   - Update Test group 10 group-title test to read from `.english` strings.
   - Add new Test group: assert
     - `english.groupTone == "Tone"`, `japanese.groupTone == "階調"`.
     - `english.presetNone == "None"`, `japanese.presetNone == "なし"`.
     - `english.presetDefault == "Default"`, `japanese.presetDefault == "標準"`.
     - `english.presetStrong == "Strong"`, `japanese.presetStrong == "強め"`.
     - tone recipe chips Standard/Airy/Sunset/Depth in English vs
       標準/爽やか/夕景/深み in Japanese.
     - `english.paramLabel(for: "exposure") == "Exposure"`,
       `english.paramLabel(for: "shutterAngle") == "Shutter Angle"`,
       `japanese.paramLabel(for: "shutterAngle") == "シャッターアングル"`,
       `japanese.paramLabel(for: "trailIntensity") == "残像の長さ"`.
     - `AdvancedAdjustCatalog.allGroups(strings: .japanese)` produces the JA
       group titles + JA recipe chip labels through the catalog lookup, not
       just the strings struct.
6. **Run** `bun run verify:macos` (xcodebuild Debug) + `apps/filmtone-desktop-macos/
   Verify/run.sh` + `git diff --check`.
7. **Archive** `active.md` to `archive/2026-05-05-m5-i1-localization-copy-parity.md`,
   add 1-3 line completion log to `strategy.md`.

### Out (deferred)

- `Localizable.strings` / `.lproj` bundle plumbing. Struct-based defaults
  match iOS's actual runtime today (most paramLabels still resolve to
  defaultValue on iOS without a translation row).
- Translating param labels iOS does not translate (e.g. `Exposure`,
  `Contrast`, `Saturation`). Match iOS intentionally — only translate keys iOS
  marks `prefersJapanese ? "JA" : "EN"`.
- Compare bar copy, SourceProfileControls / LookLibrary copy, export panel
  copy. Out of scope; this slice is Advanced Adjust only.
- Backlight Veil, Dual LUT, AVPlayer, control polish (other M5 slices).
- M5-G review follow-ups (ExportCoordinator Phase 2, clampParam promote).

## Approach

```swift
// Domain/FilmtoneDesktopStrings.swift (new)
struct FilmtoneDesktopStrings: Sendable {
    let advancedTitle: String
    let groupTone: String
    let presetNone: String
    // ...
    let paramLabels: [String: String]
    func paramLabel(for key: String) -> String { paramLabels[key] ?? key }

    static let english: Self = .init(...)
    static let japanese: Self = .init(...)
    static var current: Self { prefersJapanese() ? .japanese : .english }
    static func prefersJapanese() -> Bool {
        (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("ja")
    }
}

// Domain/AdvancedAdjustCatalog.swift (refactor)
enum AdvancedAdjustCatalog {
    static func allGroups(strings: FilmtoneDesktopStrings) -> [Group] { ... }
    static var allGroups: [Group] { allGroups(strings: .current) }
    static func groups(forVideo: Bool, strings: FilmtoneDesktopStrings = .current) -> [Group] {
        allGroups(strings: strings).filter { !$0.videoOnly || forVideo }
    }
}
```

## Done conditions

- New file landed + registered in pbxproj + Verify sources.
- AdvancedAdjustCatalog has zero hard-coded user-facing labels.
- AdvancedAdjustEditor reads its title/help/footer copy from strings layer.
- `bun run verify:macos` BUILD SUCCEEDED.
- `apps/filmtone-desktop-macos/Verify/run.sh` PASS, count grows to cover the
  new JA/EN parity tests.
- `git diff --check` clean.
- active.md archived, strategy.md completion log appended (1-3 lines).

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneDesktopStrings.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustEditor.swift` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` (add 4 entries)
- `apps/filmtone-desktop-macos/Verify/run.sh` (add 1 SOURCES line)
- `apps/filmtone-desktop-macos/Verify/main.swift` (update Test group 10 + add JA/EN tests)

## Read-Only References

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift:894-1021` — iOS canonical strings + paramLabels
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheetData.swift` — iOS canonical group/recipe wiring
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState+ParamOverrides.swift` — recipe apply path

## Out Of Scope

- iOS-side changes
- Shared package promotion of strings
- Bundle-level localization

## Operating mode

Auto-mode. Single agent. Commit at end after Verify PASS.
