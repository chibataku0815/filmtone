# Native Desktop v2 Active Task

Date opened: 2026-05-12 JST
Milestone: M4/M5 iOS Capture Package Import Parity

## Goal

Make an iOS Filmtone capture package open on Native Desktop as the same
product object: master/proxy intent, selected built-in Look, package-local
custom LUT payload, and export provenance must survive the handoff.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Capture/`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/`
- `apps/filmtone-desktop-macos/Verify/`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `docs/filmtone/desktop/README.md`

## Checklist

- [x] Add iOS package-local custom LUT payload persistence.
- [x] Add Desktop Noir bundled Look parity.
- [x] Add Desktop capture package decoder and source resolver.
- [x] Wire Desktop package open/adoption into editor state.
- [x] Thread package-local custom LUT through Desktop preview/export.
- [x] Emit capture package provenance in Desktop sidecars.
- [x] Add Desktop and iOS package round-trip verification.
- [x] Run verification and record results.

## Verification

- `bun run verify:macos`
- `bun run verify:ios`
- `git diff --check`
- `bun run check:filmtone-copy` only if public/user-facing copy changes.
- `bun run check:filmtone-context` only if public context/history docs change.

## Done Conditions

- Desktop opens `capture-package.json` and a directory containing it.
- When the package master is reachable, Desktop edits/exports from the master.
- When the master is missing, Desktop falls back to proxy and records that fact.
- Stone, Urban, and Noir restore from an iOS package to the same Desktop Look.
- A package-local custom LUT payload affects Desktop preview/export.
- Metadata-only or missing custom LUT payload is surfaced explicitly; it is not
  silently graded as the default Filmtone state.
- Desktop sidecar records capture provenance for imported iOS packages.

## Stop Conditions

- Done conditions met.
- Unexpected package schema conflict with iOS public compatibility.
- Three consecutive verification failures on the same unchanged hypothesis.

## Out Of Scope

- Full Desktop LUT library UI.
- Filmtone Connect package import/export UI.
- Desktop camera capture.
- Release packaging or public metadata changes.

## Unexpected Blockers

- None yet.

## Copy / History Impact

Desktop in-app copy changed only in the Open panel and explicit custom LUT
payload-missing/export-blocking error path. No public LP, App Store, release
metadata, or support copy is changed in this slice; public wording should wait
until the Connect package parity/release-note slice can describe the whole
handoff.

Article Opportunity: Developer note.

Change-History Opportunity: Developer note. The important history point is that
iOS capture packages now carry package-local custom LUT payloads and Native
Desktop treats the package JSON as an import contract with master/proxy
provenance instead of a metadata-only hint.

## Verification Results

- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed: 129/129.
- `bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh` passed.
- `bun run verify:macos` passed.
- `bun run verify:ios` passed after regenerating the fresh worktree's empty
  CocoaPods workspace support files with `pod install`.
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.
