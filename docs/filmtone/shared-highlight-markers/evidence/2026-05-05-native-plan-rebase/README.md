# Shared Highlight Markers Native Plan Rebase Evidence

Date: 2026-05-05 JST
Branch: feature/shared-highlight-markers
Base incorporated: local feature/native-desktop-plan at f0e81e71

## Verification

- `git rev-list --left-right --count feature/shared-highlight-markers...feature/native-desktop-plan`
  - Result: `5 0`
- `git diff --cached --check`
  - Result: pass
- `git diff --check`
  - Result: pass
- `bun run generate:swift --check`
  - Result: pass
- `cd packages/film-lab-swift-core && swift test`
  - Result: 32/32 passed
- `cd apps/capacitor-film-lab-ios && bun run verify:swift-contract`
  - Result: pass, including sidecar builder tests
- `bun run verify:ios`
  - Result: pass
- `bun run verify:macos`
  - Result: Xcode build succeeded
- `bash apps/filmtone-desktop-macos/Verify/run.sh`
  - Result: 88/88 passed
  - Log: `desktop-verify.log`
- `apps/capacitor-film-lab-ios/scripts/davinci/verify-highlight-marker-import.sh --app-generated-sidecar`
  - Result: pass
  - Log: `davinci-highlight-marker-smoke.log`

## DaVinci Smoke Signal

- App-generated sidecar imported into Resolve.
- Resolve marker customData verified:
  `filmtone-highlight-marker:filmtone-marker-001`
- `Highlight_Auto` timeline verified from the marker pre/post source-relative range.
