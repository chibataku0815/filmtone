# Active: DHM-5 Marker Highlight Reel

Base: `origin/feature/native-desktop-plan` at `2d7d885d`

Goal:

- Turn shared source-relative highlight markers into a one-second, video-only
  highlight reel across iOS, Native Desktop, and DaVinci.
- Keep normal export and Photos save behavior unchanged.
- Use the same segment contract everywhere: center each marker, clamp to source
  bounds, and merge overlaps.

Implementation:

- Add shared `FilmtoneHighlightClipSegment` and `FilmtoneHighlightReelOptions`
  to `FilmLabSwiftCore`.
- Wire iOS and Native Desktop to explicit `Highlight Reel` actions.
- Update DaVinci `Highlight_Auto` to use the same one-second centered ranges.
- Leave release docs, broad QA, and portfolio surfaces out of this slice.

Verification:

- [x] `cd packages/film-lab-swift-core && swift test`
- [x] Focused iOS sidecar / builder check via `sh apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh`
- [x] `bun run verify:ios`
- [x] iOS Debug Simulator build:
  `xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- [x] `apps/filmtone-desktop-macos/Verify/run.sh`
- [x] Native Desktop Debug build:
  `xcodebuild -scheme FilmtoneDesktop -configuration Debug build`
- [x] Native Desktop Debug app launch:
  `/Users/chibatakumi/Library/Developer/Xcode/DerivedData/FilmtoneDesktop-bhqkqbavrixjkseykoyftbdapsrn/Build/Products/Debug/Filmtone.app`
- [x] DaVinci Lua dry-run: marker count 1, highlight reel segment count 1,
  `41.630-42.630s`, frames `1248-1278`.
- [x] DaVinci Resolve smoke:
  `customData=filmtone-highlight-marker:filmtone-marker-001` and
  `Highlight_Auto` timeline item count verified.

Evidence:

- `docs/filmtone/shared-highlight-markers/evidence/2026-05-05-highlight-reel/davinci-highlight-reel-smoke.log`
- `docs/filmtone/shared-highlight-markers/evidence/2026-05-05-highlight-reel/desktop-debug-launch.log`
