# Active: Highlight Split Output Finished-State UX Polish

Milestone: M5 Native Editing UI

Goal:

- Make iPad split Highlight results clearly read as multiple clips after export.
- Align the iPad finished-state expectation with Desktop's `Files / N clips`
  result clarity without changing the export contract.
- Keep the normal export and one-file Highlight finished states unchanged.

Edit targets:

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportPanel.swift`
- Focused verification for iPad build and iOS export surface.

Read-only references:

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-highlight-reel-duration-split-output.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-highlight-reel-split-output-hardening.md`
- Desktop finished-state behavior in
  `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift`

Checklist:

- [x] Confirm the current iPad finished-state gap and advisor review.
- [x] Add split Highlight clip-count display in the iPad finished state.
- [x] Make the Photos save action label reflect multi-clip save when relevant.
- [x] Run focused verification.
- [x] Record Copy / History Impact and archive this task.

Verification:

- Advisor review pass: Highlight export now reaches the iPad finished state,
  split labels are understandable, and no release-blocking split-output UI/UX
  issue remains. Non-blocking caveat: mode labels remain terse
  (`Reel` / `Clips`, `リール` / `分割`).
- `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace
  -scheme App-iPad -destination 'generic/platform=iOS Simulator'
  -configuration Debug build CODE_SIGNING_ALLOWED=NO` passed.
- `bun run verify:ios` passed.
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.

Completion notes:

- iPad Highlight exports now remain as a local `exportResult` instead of
  immediately sharing and leaving no finished state.
- Split Highlight results show `クリップ / Clips` with the generated clip
  count in the iPad finished state.
- Split Highlight save-to-Photos action now reads `N本を保存` / `Save N Clips`
  before saving, while single-output results keep the existing Save to Photos
  label.
- Advisor-confirmed remaining UI/UX caveat: ready-state mode labels could later
  become more explicit, but they are not release-blocking after the finished
  state now clarifies the multi-file result.

Copy / History Impact:

- No public copy/history impact: this is in-app task copy and result lifecycle
  polish for Highlight export. It does not change release, version, platform,
  privacy, codec, or implementation-history claims.
- Article Opportunity: Release-note only, covered by the Highlight duration /
  split-output feature note.
- Change-History Opportunity: No story.

Done conditions:

- Split Highlight result shows a clip count in the iPad finished state.
- Split Highlight save-to-Photos button indicates all clips will be saved.
- Single-output exports keep the existing finished-state copy and controls.
- Advisor feedback is considered or explicitly recorded as out of scope.
- Verification has passed or a concrete blocker is recorded.

Stop conditions:

- Done conditions met.
- Advisor feedback identifies a product decision that cannot be inferred from
  existing Desktop/iPad export conventions.
- The same verification step fails 3 consecutive times.

Out of scope:

- New Highlight controls or marker algorithms.
- DTO/schema changes.
- Desktop UI changes beyond read-only comparison.
- Public release/version metadata changes.
- Portfolio website updates.
- Legacy Electron Desktop changes.

Unexpected blockers:

- None yet.
