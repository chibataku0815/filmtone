# Filmtone iOS 1.8 Complete Context Handoff

Date: 2026-05-10 JST  
Repository:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`

Status note: this handoff records the pre-public submission state from
2026-05-10. A 2026-05-12 truth refresh reports public App Store version `1.8`;
use `docs/filmtone/ios/README.md` and the iOS truth script for current state.

This document is the complete handoff for the Filmtone iOS 1.8 release work,
the post-release documentation cleanup, and the next likely copy task. It is
written so a new chat can continue without relying on memory from the previous
conversation.

## Current Truth

Always re-run the truth checks before stating release status, because public
App Store state and App Store Connect state can diverge.

Commands already run in this session:

```bash
FILMTONE_REPO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone \
  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

Current truth at the last check:

- Local Xcode candidate: `MARKETING_VERSION=1.8`,
  `CURRENT_PROJECT_VERSION=7`.
- Bundle ID: `com.chibatakumi.film.lab.ios`.
- Public App Store lookup still reports `1.7`.
- App Store Connect reports `1.8` build `7` as
  `PENDING_DEVELOPER_RELEASE`.
- This means Apple review has passed, but public release has not happened yet.
- Manual release was not performed in this chat.
- Automatic release was not enabled during submission.

The live ASC verification command used:

```bash
./scripts/bundle.sh exec ruby - <<'RUBY'
require 'spaceship'
app_root = ENV.fetch('FILMTONE_IOS_APP_ROOT', Dir.pwd)
key_opts = { key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'), duration: 1200 }
if ENV['ASC_KEY_CONTENT'] && !ENV['ASC_KEY_CONTENT'].strip.empty?
  key_opts[:key_content] = ENV['ASC_KEY_CONTENT'].gsub('\\n', "\n")
else
  key_opts[:filepath] = File.expand_path(ENV.fetch('ASC_KEY_PATH'), app_root)
end
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(**key_opts)
app = Spaceship::ConnectAPI::App.find('com.chibatakumi.film.lab.ios')
version = app.get_app_store_versions(filter: { platform: Spaceship::ConnectAPI::Platform::IOS }, includes: 'build').find { |v| v.version_string == '1.8' }
abort('1.8 missing') unless version
puts "version=#{version.version_string} state=#{version.app_version_state} build=#{version.build&.version || 'none'}"
version.get_app_store_version_localizations(limit: 20).sort_by(&:locale).each do |loc|
  puts "#{loc.locale}: whatsNewChars=#{loc.whats_new.to_s.length}; first=#{loc.whats_new.to_s.lines.first.to_s.strip}"
end
RUBY
```

Last observed output summary:

```text
version=1.8 state=PENDING_DEVELOPER_RELEASE build=7
en-GB: whatsNewChars=814
en-US: whatsNewChars=814
ja: whatsNewChars=362
```

## User Intent And Constraints

The user asked to release Filmtone iOS and explicitly limited App Store text
changes:

- Update only "What's New" / release notes.
- Do not change title.
- Do not change subtitle.
- Do not change screenshots.

The user later confirmed the release-note content should cover the 1.8 product
changes and asked for documentation cleanup. The latest request is to create a
complete handoff document and then output a high-precision English prompt for
the next chat.

Important working preferences from the user:

- Prioritize core product progress over outer-shell process.
- Keep QA, issue hygiene, and documentation minimal until the product surface
  works or until explicitly requested.
- Do not prioritize conservative hedges over product quality.
- Use `sequential-thinking` for real reasoning branches, release-lane
  decisions, and ambiguous plans.
- If facts are unknown or volatile, verify with local truth scripts, ASC, Gemini,
  or web search before stating them.
- Parallelize independent reads/checks.

Repo-level non-negotiables that mattered here:

- Use `bun`.
- Do not stage, commit, push, or bump portfolio submodules unless explicitly
  asked.
- Do not edit portfolio implementation truth.
- Do not hand-edit generated Swift.
- Preserve dirty worktree changes that are not yours.
- For iOS public/local state, run:
  `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh`.

## How This Session Unfolded

1. Initial routing followed the iOS release lane:
   `apps/capacitor-film-lab-ios/CLAUDE.md` was read, `git status` was checked,
   and iOS truth scripts were run.
2. The assistant initially misunderstood "更新情報のみ" as an ASC metadata-only
   operation and incorrectly treated existing public `1.7` release notes as if
   the release task were complete. The user corrected this.
3. The intended meaning was clarified: prepare the "What's New" text for the
   next release, not title/subtitle/screenshots.
4. The correct release scope was established:
   Filmtone iOS `1.8` / build `7`, with release notes covering actual product
   changes after public `1.7`.
5. Local work already had `1.8` / `7` changes and narrowed Fastlane release
   lanes in the working tree.
6. `bun run verify:ios` passed.
7. `bun run release:archive` created a fresh `Filmtone.ipa`.
8. IPA plist check confirmed:
   `CFBundleShortVersionString=1.8`,
   `CFBundleVersion=7`,
   `CFBundleIdentifier=com.chibatakumi.film.lab.ios`.
9. `bun run release:appstore-binary` uploaded only the binary with
   `skip_metadata=true` and `skip_screenshots=true`.
10. `bun run release:release-notes` synced only localized `What's New` text.
11. Build `7` became `VALID`.
12. `bun run release:submit-review-notes` selected build `7` and submitted for
    review with `skip_metadata=true`, `skip_screenshots=true`, and
    `skip_binary_upload=true`.
13. ASC state first showed `WAITING_FOR_REVIEW`.
14. Post-submission documentation cleanup archived the completed capture active
    task and updated iOS docs.
15. Copy gate found one Japanese release-note issue:
    `撮影後` matched the `obvious-premise` rule.
16. Japanese release notes were rewritten to be more concrete and then
    `bun run release:release-notes` resynced the revised text to ASC.
17. ASC later advanced to `PENDING_DEVELOPER_RELEASE`, meaning Apple review
    passed and manual release is pending.

## Product Changes In Filmtone iOS 1.8

These are the user-facing changes that belong in 1.8 release communications:

- Multi-take capture flow:
  users can keep shooting multiple takes and then choose which take to open in
  the editor instead of being forced out of capture after every clip.
- Focused take picker / preview:
  multiple takes are inspected with a focused large preview and lightweight
  selector rather than a heavy multi-row preview sheet.
- Lightweight recording monitor:
  when stabilization and a Look are active together, live preview uses a visible
  lightweight monitor path (`Live Look · Light`) while full-quality rendering
  remains in editor/export.
- Custom `.cube` creative LUTs in capture:
  the capture Look sheet can import/select user creative LUTs, preserve them
  through package/editor/export provenance, and warn on likely technical
  transform LUTs because Filmtone handles Apple Log 2 conversion before the
  creative Look slot.
- New Noir Look:
  Creative Pack 01 now includes a toned monochrome `Noir` Look.
- SSD/storage handling:
  external SSD capture supports a 5-minute cap, internal capture stays short,
  and storage-pressure warnings are visible.
- Orientation/package stability:
  orientation handling and capture package stability were tightened.
- Apple Log 2 availability gate:
  unsupported environments are stopped clearly rather than silently offering an
  invalid capture route.

Do not lead with internal refactors, React/Capacitor purge, Fastlane changes, or
documentation changes in public-facing copy. Those are implementation context,
not the product story.

## App Store "What's New" Text

Source files:

- `apps/capacitor-film-lab-ios/fastlane/metadata/ja/release_notes.txt`
- `apps/capacitor-film-lab-ios/fastlane/metadata/en-US/release_notes.txt`
- `apps/capacitor-film-lab-ios/fastlane/metadata/en-GB/release_notes.txt`

Current Japanese text:

```text
このリリースでは、撮影を続けながら複数のテイクを残し、あとで選んで編集へ進める流れを整えました。1本録り終えても編集画面へ強制移動せず、そのまま次の録画へ進めます。テイク一覧では大きなプレビューで内容を確認できます。

録画中のプレビューも軽くしました。手ぶれ補正と Look を同時に使う場面では、書き出し品質の処理は保ったまま、撮影モニター向けの軽い表示に切り替え、状態を画面上で確認できます。

Stone / Urban / Noir などの Look と、読み込んだ .cube LUT を撮影画面で選べるようにしました。技術変換用に見える LUT には注意を出し、撮影から編集、書き出しの流れで選択が引き継がれます。

そのほか、縦横の向きの扱い、保存容量が少ない時の警告、撮影パッケージの安定性を調整しました。
```

Current English text:

```text
This release improves the native capture flow for real shooting sessions. You can keep recording multiple takes, then choose the take to open in the editor with a focused preview instead of being forced out of capture after each clip.

Recording preview is lighter in the hot path. When stabilization and a Look are active together, Filmtone uses a visible lightweight monitor mode for capture while preserving the full-quality rendering path for editing and export.

Stone, Urban, Noir, and imported .cube creative LUTs can now be selected from the capture screen. LUTs that look like technical transform LUTs are flagged, and the selected direction carries through capture, editing, and export provenance.

This update also tightens capture orientation handling, storage-pressure warnings, and package stability.
```

The en-GB text is the same except for British spelling of "stabilisation".

## Fastlane Release Lane Changes

The normal `release:appstore` lane uploads binary, metadata, and screenshots.
That was not suitable because the user specifically asked not to change title,
subtitle, or screenshots.

New narrow lanes were added in
`apps/capacitor-film-lab-ios/fastlane/Fastfile` and exposed through
`apps/capacitor-film-lab-ios/package.json`:

- `bun run release:release-notes`
  - Finds the target ASC app/version.
  - Reads only `fastlane/metadata/*/release_notes.txt`.
  - Updates only `appStoreVersionLocalizations.whatsNew`.
- `bun run release:appstore-binary`
  - Uploads only the IPA.
  - Uses `skip_metadata=true`.
  - Uses `skip_screenshots=true`.
  - Does not submit for review.
- `bun run release:submit-review-notes`
  - Re-syncs only `What's New`.
  - Selects current Xcode build number (`7`) unless `BUILD_NUMBER` is set.
  - Submits the already uploaded build for review with metadata/screenshots and
    binary upload skipped.

These lanes exist to keep future release actions narrow and avoid accidental
title/subtitle/screenshot churn.

## Verification And Commands Run

Successful checks/actions:

```bash
git diff --check
ruby -c apps/capacitor-film-lab-ios/fastlane/Fastfile
bun run verify:ios
bun run release:archive
bun run release:appstore-binary
bun run release:release-notes
bun run release:submit-review-notes
bun run check:filmtone-copy
bun run release:release-notes
```

`bun run verify:ios` passed. It emitted existing Swift warnings around
Sendable/deprecated APIs, but build and contract tests completed successfully.

IPA check command used:

```bash
tmpdir=$(mktemp -d)
unzip -q apps/capacitor-film-lab-ios/build/fastlane/Filmtone.ipa -d "$tmpdir"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$tmpdir/Payload/App.app/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$tmpdir/Payload/App.app/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$tmpdir/Payload/App.app/Info.plist"
rm -rf "$tmpdir"
```

Observed output:

```text
1.8
7
com.chibatakumi.film.lab.ios
```

Build artifacts:

- `apps/capacitor-film-lab-ios/build/fastlane/Filmtone.ipa`
- `apps/capacitor-film-lab-ios/build/fastlane/Filmtone.app.dSYM.zip`

These are generated artifacts and are not the main source of truth.

## Documentation Cleanup Already Done

Created/updated:

- `docs/filmtone/ios/2026-05-10-filmtone-ios-1.8-release-handoff.md`
- `docs/filmtone/ios/README.md`
- `docs/filmtone/ios/capture-practicality/strategy.md`
- `docs/filmtone/ios/capture-practicality/archive/2026-05-10-s5-recording-preview-performance.md`

Moved:

- `docs/filmtone/ios/capture-practicality/active.md`
  to
  `docs/filmtone/ios/capture-practicality/archive/2026-05-10-s5-recording-preview-performance.md`.

Current capture-practicality status:

- No active `active.md`.
- Completed release work is archived.
- Remaining paused owner-smoke items are still under:
  `docs/filmtone/ios/capture-practicality/paused/`.
- Reopen exactly one new `active.md` only after the user picks the next product
  subtask.

## Current Git State

Last observed:

```text
## main...origin/main [ahead 54]
 M apps/capacitor-film-lab-ios/RELEASE.md
 M apps/capacitor-film-lab-ios/fastlane/Fastfile
 M apps/capacitor-film-lab-ios/fastlane/README.md
 M apps/capacitor-film-lab-ios/fastlane/metadata/en-GB/release_notes.txt
 M apps/capacitor-film-lab-ios/fastlane/metadata/en-US/release_notes.txt
 M apps/capacitor-film-lab-ios/fastlane/metadata/ja/release_notes.txt
 M apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
 M apps/capacitor-film-lab-ios/package.json
 M docs/filmtone/ios/README.md
 D docs/filmtone/ios/capture-practicality/active.md
 M docs/filmtone/ios/capture-practicality/strategy.md
?? docs/filmtone/ios/2026-05-10-filmtone-ios-1.8-release-handoff.md
?? docs/filmtone/ios/capture-practicality/archive/
```

After this complete handoff is added, there will also be this new untracked file:

- `docs/filmtone/ios/2026-05-10-filmtone-ios-1.8-complete-context-handoff.md`

Do not stage, commit, or push unless the user explicitly asks.

## Important Pitfalls

- Do not say iOS `1.8` is public unless the public lookup reports `1.8`.
  It currently reports public `1.7`.
- Do not say review is still waiting without checking ASC. The latest live ASC
  state is `PENDING_DEVELOPER_RELEASE`.
- Do not run broad `release:appstore` unless the user explicitly wants the full
  metadata/screenshot upload path.
- Do not change title, subtitle, screenshots, description, marketing URL,
  support URL, or privacy URL for this release unless the user explicitly
  changes scope.
- Do not manually release `1.8` unless the user explicitly asks to release it.
  The state is now ready for manual developer release.
- Do not treat old `WAITING_FOR_REVIEW` handoffs as current truth.
- The earlier assistant response that implied the release was already complete
  before the actual binary upload/submission was wrong. The actual completed
  work is documented in this file.

## Likely Next Actions

1. Ask the user whether to manually release App Store Connect `1.8` build `7`
   now, or hold it.
2. If the user says release now, verify ASC state again first. Then use the
   appropriate ASC/Fastlane/Spaceship release request path. Do not infer the
   API from memory; inspect Fastlane/Spaceship or use ASC UI if needed.
3. If the user returns to the X article request, draft Japanese X thread copy
   for developers and colorists. It should be conversational and gentle, not
   ASO-like. Lead with the engineering/color decisions:
   native capture flow, Apple Log 2, non-destructive Look pipeline, lightweight
   monitoring vs full-quality export, custom creative LUTs, and multi-take
   shooting.
4. If writing copy, use the `japanese-product-copy` skill and run its copy
   checks for final candidate text if practical.
5. If changing App Store copy again, run `bun run check:filmtone-copy` and then
   `bun run release:release-notes` if only `What's New` changed.

## English Handoff Prompt For The Next Chat

Use this prompt to continue with high precision:

```text
You are continuing work in the Filmtone repository at:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Read and follow the repo AGENTS/CLAUDE instructions. This is the standalone
implementation source of truth for Filmtone iOS/Desktop/shared packages. Use
bun. Do not stage, commit, push, or edit the portfolio repo unless explicitly
asked. Preserve existing dirty worktree changes.

Current task context:
- Filmtone iOS 1.8 build 7 was archived, uploaded, release notes synced, and
  submitted to App Store review.
- App Store Connect later reported version 1.8 build 7 as
  PENDING_DEVELOPER_RELEASE. Public App Store lookup still reports version 1.7.
- Automatic release was not enabled. Manual release has not been performed.
- Title, subtitle, screenshots, descriptions, URLs, and public metadata other
  than What's New were intentionally not changed or re-uploaded.
- Narrow Fastlane lanes were added for release-notes-only sync,
  binary-only upload, and review submission without metadata/screenshot churn.
- Completed capture-practicality active work was archived; there is currently
  no docs/filmtone/ios/capture-practicality/active.md.

Before making any release-state claim, run:
FILMTONE_REPO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone \
  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh

Also verify App Store Connect state directly if deciding anything about manual
release. Do not rely on old handoffs that say WAITING_FOR_REVIEW.

Important files to read first:
- docs/filmtone/ios/2026-05-10-filmtone-ios-1.8-complete-context-handoff.md
- docs/filmtone/ios/2026-05-10-filmtone-ios-1.8-release-handoff.md
- docs/filmtone/ios/README.md
- docs/filmtone/ios/capture-practicality/strategy.md
- apps/capacitor-film-lab-ios/CLAUDE.md
- apps/capacitor-film-lab-ios/RELEASE.md
- apps/capacitor-film-lab-ios/fastlane/Fastfile

Current likely next decision:
Ask whether to manually release App Store Connect version 1.8 build 7 now or
hold it. If the user asks for release, verify ASC state again and use the
correct manual release path. Do not change title/subtitle/screenshots.

Alternative pending task:
The user previously wanted an X/Twitter update post in Japanese for developers
and colorists, with a conversational and gentle tone. If asked to write it, use
the japanese-product-copy skill. Focus on the product/engineering/color story:
native capture sessions, multi-take flow, Apple Log 2, lightweight Live Look
monitoring during recording, full-quality editor/export rendering, custom .cube
creative LUTs with transform-LUT warning, Noir, external SSD/storage handling,
and package/orientation stability. Do not overclaim; 1.8 is not public until
manual release completes.

Verification already completed:
- git diff --check passed
- ruby -c apps/capacitor-film-lab-ios/fastlane/Fastfile passed
- bun run verify:ios passed
- bun run release:archive passed
- IPA plist check confirmed 1.8 / build 7 / com.chibatakumi.film.lab.ios
- bun run release:appstore-binary passed
- bun run release:release-notes passed
- bun run release:submit-review-notes passed
- bun run check:filmtone-copy passed after Japanese What's New copy adjustment
- The adjusted Japanese What's New was resynced to ASC with
  bun run release:release-notes

Be precise about public vs ASC state:
- Public App Store: 1.7
- ASC local/release candidate: 1.8 build 7, PENDING_DEVELOPER_RELEASE
```
