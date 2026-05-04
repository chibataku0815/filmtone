# M5-D.1 Video Scrub Bar Visibility (dark-tinted clear posture)

Date opened: 2026-05-05 JST (auto-mode、Tier A 5-gap 2 件目)

## Milestone

M5 Native Editing UI / Apple Liquid Glass posture pass。strategy.md
"2026-05-04 user smoke で 5 個の追加ギャップ判明" の **M5-D.1**。

## Goal

Bottom-anchored Video Scrub Bar が bright / dark どちらの preview backdrop
でも一目で発見できる visibility を確保する。現状は `.glassEffect(.clear, …)`
素 posture のため、明るい frame の上では glass が source pixel を refract
する以外の visual cue がなくほぼ消失。発見されないため user smoke で
「シーク機能がない」と誤認された。

## Why this slice (本質)

- Tier A Visibility は本質: 機能が landed していても discoverable で
  なければ存在しないのと同じ (memory `feedback_diagnostic_first_when_modifier_invisible`
  と同根の visibility-first 判断)。
- 右レール panel 5 個 (`SourceProfile` / `LookLibrary` / `QuickAdjust` /
  `Grade` / `ExportInspector`) はすべて Pass 4 で `.clear.tint(.black.opacity(0.30))`
  に統一済み (`RootWindowView.swift:39-91`)。scrub bar だけ素 `.clear` で
  posture 整合性が崩れている → 同 posture に揃える 1 行修正。
- M5-D.2 (Native Video Playback / Play-Pause) は Tier B、user 判断 (raw
  decode vs. decode+grade) 後に着手。本 slice の scope ではない。

## Scope

### In

1. **scrub-bar capsule posture を右レール panel と統一**
   - `RootWindowView.swift:112-115` の `.glassEffect(.clear, in: …)` を
     `.glassEffect(.clear.tint(.black.opacity(0.30)), in: …)` に変更。
   - 既存の `cornerRadius: 12` / 内側 padding (horizontal 14, vertical 8) /
     外側 `.padding(.bottom, 60)` は無変更。
2. **build verify**
   - `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` ✅
   - Swift 6 strict concurrency warning 無し
3. **commit**
   - 単一 commit。CLI smoke 不要 (modifier 引数変更、export / preview
     pipeline に linkage 無し)。

### Out (deferred)

- **M5-D.2 Play/Pause + AVPlayer 駆動の time observer** — Tier B、user
  judgment (realtime grade vs raw decode tradeoff) が前提
- Scrub bar layout 変更 (height / cornerRadius / padding) — 現 capsule で
  視覚的に十分 (右レール統一だけで visibility 解決見込み)
- Slider thumb / track のカスタム描画 — SwiftUI 既定で OK
- Frame number / timecode chip 追加 — 別 slice
- Keyboard shortcut (Space / arrow keys) — M5-D.2 で playback と一緒に

## Approach

```swift
// RootWindowView.swift:112-115 (before)
.glassEffect(
    .clear,
    in: RoundedRectangle(cornerRadius: 12)
)

// after
.glassEffect(
    .clear.tint(.black.opacity(0.30)),
    in: RoundedRectangle(cornerRadius: 12)
)
```

右レール panel の posture comment (Pass 4 dark tint = stable luminance
baseline for visibility) を referencing する短い inline comment を追加。

## Done conditions

- `RootWindowView.swift:112-115` が `.clear.tint(.black.opacity(0.30))`
  posture を保持
- `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` PASS、
  warnings なし
- 右レール panel 5 個 + scrub bar が同一 dark-tint clear posture で揃う
- Visual smoke (bright / dark preview 両方で scrub bar が見える) は
  user-driven、code-level は posture consistency check で OK

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  (modify, 一箇所)

## Read-Only References

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift:39-91`
  (right-rail panel posture pattern)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift:371-404`
  (VideoScrubBar 実装 — 変更不要)

## Out Of Scope

- VideoScrubBar 内部レイアウト変更
- AVPlayer / playback wiring (M5-D.2 で別途)
- Toolbar / window chrome のさらなる Pass 5 (M5-F.1 で)

## Estimated size

~10-15 分。one-line modifier 変更 + xcodebuild + commit。

## Operating mode

Auto-mode: 5-gap Tier A 連続着手の 2 件目。コミットは agent。
