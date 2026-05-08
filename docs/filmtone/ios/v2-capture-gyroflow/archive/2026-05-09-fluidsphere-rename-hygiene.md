# Active: Hygiene — FilmtoneFluidSphere → FilmtoneFluidBlobBackdrop rename

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **PASS — archived 2026-05-09**

## Why this active exists

`FilmtoneFluidSphere.{swift,metal}` is a legacy filename from the
M15-final v1 sphere implementation that was rejected. The current
behavior is a full-screen fluid blob backdrop (no sphere mask, no
sphere shape), and the `FilmtoneFluidSphere.swift` doc comment notes
the rename was deferred to keep the M15 iteration focused. Now that
M14 + M15 are closed and the working tree is clean, the rename is a
safe hygiene step that aligns the filename with the implementation.

## Scope

- Rename file `FilmtoneFluidSphere.metal` → `FilmtoneFluidBlobBackdrop.metal`
  + Metal shader function `filmtoneFluidSphere` →
  `filmtoneFluidBlobBackdrop`.
- Rename file `FilmtoneFluidSphere.swift` → `FilmtoneFluidBlobBackdrop.swift`
  + SwiftUI `struct FilmtoneFluidSphere` → `FilmtoneFluidBlobBackdrop`
  + `ShaderLibrary.filmtoneFluidSphere(...)` →
  `.filmtoneFluidBlobBackdrop(...)`.
- Update 2 call sites: `FilmtoneEmptyView.swift` line 27,
  `FilmtoneOnboardingView.swift` line 104 (and its doc-comment ref).
- pbxproj 4-section update (path + lastKnownFileType lines for both
  files).

No behavior changes. Pure rename.

## Verification

```bash
grep -rn 'FilmtoneFluidSphere\|filmtoneFluidSphere' apps/capacitor-film-lab-ios/ios/App/App
# expect 0 hits

grep -c 'FilmtoneFluidBlobBackdrop' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
# expect ≥ 4 (per file)

xcodebuild -workspace ... -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace ... -destination 'generic/platform=iOS' build
xcrun devicectl device install + launch on iPhone 17 Pro #7
```

## Out of Scope

- Behavioral changes to the shader or wrapper.
- Any other renames or refactors.
- Strategy.md updates beyond a 1-line completion note.

## Outcome

PASS. `FilmtoneFluidSphere.{swift,metal}` was renamed to
`FilmtoneFluidBlobBackdrop.{swift,metal}` with matching Swift type,
shader function, call sites, and pbxproj references. Legacy
`FilmtoneFluidSphere` / `filmtoneFluidSphere` references are gone.

Verification:

- `rg 'FilmtoneFluidSphere|filmtoneFluidSphere' apps/capacitor-film-lab-ios/ios/App/App apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` → 0 hits
- `rg 'FilmtoneFluidBlobBackdrop|filmtoneFluidBlobBackdrop' ...` confirms Swift, Metal, call-site, and pbxproj references
- Simulator build: PASS
- `git diff --check`: PASS
