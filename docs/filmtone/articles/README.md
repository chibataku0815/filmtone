# Filmtone Article Publishing Rules

This directory is the operating rulebook for Filmtone article publishing.
It covers editorial planning for external article platforms only. Do not
expand it into broad social/video distribution unless the owner explicitly
asks for that lane.

## Fixed Article Platforms

Use these five platforms as the default article set:

| Platform | Role | Primary proof |
|---|---|---|
| note | Japanese product story hub | release story, before/after, case study, product intent |
| Zenn | Japanese engineering proof | SwiftUI, AVFoundation, color pipeline, export, verification |
| Medium | English product/design story | product direction, design intent, release narrative |
| Hashnode | English engineering proof | architecture, implementation details, developer lessons |
| Behance | Design and visual case study proof | UI, before/after, visual quality, project narrative |

Do not add Product Hunt, YouTube, Instagram, TikTok, X Articles, DEV, Qiita,
Substack, or other surfaces to the default set. They can be one-off follow-ups,
but they are not part of the five-platform article plan.

## Publishing Model

Do not publish the same full article everywhere. Start from one source brief and
adapt only the surfaces that fit the article type.

| Article type | Primary platform | Secondary platforms |
|---|---|---|
| Release story | note | Medium, Behance when visual proof exists |
| Before/after case study | note | Behance, Medium |
| Technical note | Zenn | Hashnode, note only if a non-technical explanation helps |
| Implementation history | Zenn or note | Hashnode or Medium depending on reader |
| Design case study | Behance | note, Medium |

Each article must have one primary reader, one next action, and one claim class
before drafting. Use the copy brief shape from
`docs/filmtone/filmtone-copy-quality-harness.md`.

## Claim Truth Gates

Before writing or revising any article that mentions release state, version,
App Store state, download availability, platform support, codec/export behavior,
privacy/account/cloud behavior, or implementation history:

1. Read `docs/filmtone/filmtone-copy-quality-harness.md`.
2. For implementation-history claims, read
   `docs/filmtone/filmtone-implementation-history.md`.
3. For Desktop/iOS version claims, run:

```sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

4. Treat public state and local candidate state as separate axes.
5. If a release is not public yet, mark the article as `candidate draft` and do
   not use publish-language such as `公開しました`, `出しました`, `available`,
   or `released`.

Truth scripts override old handoffs, article drafts, and release planning docs.

## Latest True Release Rule

`latest true release` means the public release state returned by the truth
scripts, not the newest local Xcode version, local release notes, App Store
Connect review state, upload state, or an unpublished DMG.

For a combined Desktop + iOS release article:

- The article can say both releases are public only after:
  - Desktop release truth reports the intended public `latestVersion`.
  - iOS truth reports the intended public App Store `public_version`.
- If only one platform is public, either:
  - publish a single-platform article for the public platform, or
  - keep the combined article as a candidate draft until both public truths are
    true.
- Never collapse Desktop public version, Desktop local candidate version, iOS
  public App Store version, and iOS local candidate version into one value.

## First Article Theme

The first article theme is locked:

```text
Latest true Filmtone release across Desktop and iOS.
```

As of 2026-05-12 JST, the source state is:

- Desktop public truth: `1.6`.
- Desktop local candidate: `1.7` build `4`.
- Desktop candidate draft:
  `docs/filmtone/desktop/native-desktop-v2/2026-05-12-filmtone-desktop-v1-7-article-jp.md`.
- Desktop release notes:
  `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.7.md`.
- iOS public App Store truth: `1.8`.
- iOS local candidate: `1.9` build `8`.
- iOS App Store Connect state at handoff time: `WAITING_FOR_REVIEW`.
- iOS candidate draft:
  `docs/filmtone/ios/2026-05-12-filmtone-ios-1.9-x-article-jp.md`.
- iOS release handoff:
  `docs/filmtone/ios/2026-05-12-filmtone-ios-1.9-release-handoff.md`.

Do not publish the first combined article until the truth scripts report
Desktop public `1.7` and iOS public `1.9`. Until then, keep all five-platform
variants as candidate drafts.

## First Article Angle

The shared release angle is:

```text
音と細部を見直した Filmtone。
```

Use the angle differently by platform:

| Platform | First article role |
|---|---|
| note | Main Japanese release story for Desktop + iOS after both are public |
| Zenn | Engineering note about audio preservation, Texture Softness, and completed-output validation |
| Medium | English product/design story about making export feel more trustworthy |
| Hashnode | English implementation note about native runtime quality and shared color truth |
| Behance | Case-study article showing before/after, UI/control surfaces, and visual proof |

Required claim boundaries:

- Audio: say `normal video export` only. Highlight-reel export remains
  source-audio disabled.
- Texture Softness: describe it as a control for easing hard digital fine
  detail. Do not claim universal quality, manufacturer-certified transforms,
  or perfect results for every source.
- Source detail compensation: say it is conservative, runtime-only, and not
  saved into Looks.
- Implementation history: React + Capacitor was the early route for reusing
  the WebGPU/WebGL renderer path; native SwiftUI/AVFoundation exists because
  capture/export runtime quality needed native control. Do not frame it as
  `Capacitor was a mistake` or `WebGPU was abandoned`.

## Draft Storage

Use this structure for new article packs:

```text
docs/filmtone/articles/YYYY-MM-DD-{slug}/
├── brief.md
├── source-facts.md
├── note-ja.md
├── zenn-ja.md
├── medium-en.md
├── hashnode-en.md
├── behance-case.md
└── assets/
```

`source-facts.md` must include the truth-script outputs or a short dated
summary of them. If a platform variant is not appropriate for that article,
write `Not used: <reason>` in the relevant file instead of forcing a draft.

## Verification Before Publishing

Before publishing or handing an article pack to the owner:

```sh
bun run check:filmtone-copy
bun run check:filmtone-context
git diff --check
```

For public release/version claims, rerun both truth scripts immediately before
finalizing the article text.
