# Filmtone Marketing IA / ASO / LP Brief

- Date: 2026-04-30 JST
- Scope: App Store metadata candidates, Filmtone LP copy, feature-page copy
- Current public truth: iOS `1.2`, Desktop `1.0.3`, Web demo
- Local candidate truth: iOS `1.3 (2)` is submitted / waiting for review
- ASC rule: do not upload metadata, screenshots, or submission changes until ASC is read again with API credentials and the user approves.

## Product Definition

JA:

> Filmtone は、ルックを選び、再生や Before/After で色を確かめ、iPhone・Mac・ブラウザの役割に合わせて保存・書き出しへ進める仕上げツールです。

EN:

> Filmtone is a finishing tool for choosing a look, checking the grade in playback or before/after, and saving or exporting through the right surface: iPhone, Mac, or browser.

## Positioning Spine

Filmtone should lead with concrete workflow, not abstract mood.

1. Start from a preset or Filmtone Look.
2. Adjust brightness, contrast, and saturation with Quick controls.
3. Compare before/after or judge while playing video.
4. Export, save, or share from the surface that fits the job.

Surface roles:

| Surface | Role | Public-safe claim |
|---|---|---|
| Web | Try first | Open your own media in the browser and test the look. Web video export is beta and browser-dependent. |
| iPhone | Finish locally | Choose a look, adjust it, export, save, and share from the iPhone workflow without a login/cloud-sync main path. |
| Mac | Deeper finish/export | Public `1.0.3` Apple Silicon DMG for playback, comparison, LUT/profile work, and stronger export workflow. |

## Claim Matrix

Safe public claims:

- iOS public version is `1.2`; Desktop public version is `1.0.3`; Web is a browser demo.
- iPhone app supports local photo/video editing, presets, Quick controls, Before/After, export, save, share, and `.cube` LUT import/apply slots.
- Desktop is macOS Apple Silicon only and distributed as a signed/notarized DMG.
- Web can open user media and audition looks; video export is beta, no-audio, and browser-dependent.

v1.3-gated claims:

- Five built-in Filmtone Looks.
- Imported `.cube` LUT reuse and Saved Looks.
- Camera Profile picker: Auto, Apple Log, Apple Log 2, V-Log, S-Log3, Rec.709, Import `.cube`.
- Sidecar provenance for Saved Look and Camera Profile.

Forbidden until separately shipped and verified:

- `.cube` export or combined LUT export.
- Public sidecar schema page.
- DaVinci public workflow or "DaVinci replacement" positioning.
- ProRes 422 output.
- Full Web production export, Safari video export, or "works everywhere" export claims.

## Copy Quality Rules

Use when tied to action or result:

- `プリセット`, `Quick調整`, `Before/After`, `書き出し`, `保存・共有`
- `film-look`, `film-inspired`, `フィルム調` when tied to an action or result
- `素材`, `media`, `footage` in body copy when a concrete imported item is being discussed

Avoid or replace:

- `撮った写真`, `撮った後`, `撮影後`, `after you shoot`, `device you shot with`, `capture device`
- `写真も動画も`, `写真と動画`, `写真や動画`, `photos and videos`, `photo & video` as hero/subtitle/promo/headline value
- `短尺動画`, `短い動画`, `short videos`, `short clips`
- `映画の色から、使い捨てカメラまで。`
- `安心して仕上げられる`
- Standalone `世界観`, `雰囲気`, `空気感`, `atmosphere`, `world` unless the sentence also says what the product does.

Before changing public copy, read `docs/filmtone/filmtone-copy-quality-harness.md` and run `bun run check:filmtone-copy`.

## Local Metadata Candidate

This repo can hold improved candidate metadata, but ASC remains the current submitted truth until a read-only ASC fetch proves otherwise.

JA:

- Name: `Filmtone - ルックを選んで書き出し`
- Subtitle: `iPhoneでフィルム調に仕上げる`
- Promo: `プリセットやFilmtone Lookで色の方向を決め、Before/Afterで確認。iPhone上でローカルに書き出して保存・共有できます。`

EN:

- Name: `Filmtone: iPhone Film Looks`
- Subtitle: `Film looks, local export`
- Promo: `Choose a film look, tune it with Quick controls, compare before/after, then export locally from iPhone to save or share.`

## QA Gate

Before upload:

1. Re-run iOS truth and ASC read-only fetch.
2. Compare ASC metadata against local metadata.
3. Count App Store name/subtitle/promo/keyword/description limits.
4. Run `bun run check:filmtone-copy`.
5. Upload only after explicit user approval.
