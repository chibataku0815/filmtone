# M5-F.1 Inline Button Glass Posture Pass (Pass 5)

Date opened: 2026-05-05 JST (auto-mode、Tier B 5-gap 1 件目)

## Milestone

M5 Native Editing UI / Apple Liquid Glass posture pass。strategy.md
"2026-05-04 user smoke で 5 個の追加ギャップ判明" の **M5-F.1** = 5-gap
3 件目。Pass 1-4 は panel/capsule/scrub/toolbar の **container** posture を
統一済み (M5-B 4 commits)。Pass 5 は **その上に乗る inline button** の
posture を Apple Liquid Glass に揃える。

## Goal

Right-rail panel の inline button が dark-tinted .clear glass container と
posture 整合し、user smoke で「ボタンUIがしょぼすぎる」と判定された
`.borderedProminent` system default の bright blue solid box を排除する。

## Why this slice (本質)

- 1.4 公開時の最終視覚 quality に直接効く。primary action (Export
  Video / Still) は smoke screenshot で容器 (dark glass) と styling 不整合
  だった (system blue solid box vs glass posture)。Apple HIG / macOS 26
  canonical = inline button も Liquid Glass family で揃える。
- `.glassProminent` / `.glass` button style が macOS 26 SwiftUI SDK に
  存在することを検証 (xcodebuild PASS が verify) → 既存 custom
  `.glassEffect` modifier wrapping より Apple canonical を優先。

## Scope

### In

1. **Primary action button → `.glassProminent`**
   - `ExportInspectorPanel.swift:87-88` の `.buttonStyle(.borderedProminent)
     .controlSize(.regular)` → `.buttonStyle(.glassProminent)
     .controlSize(.regular)`
   - これが smoke screenshot で唯一 user 名指しの「しょぼい」blue box
2. **Secondary actions → `.glass`**
   - `ExportInspectorPanel.swift:155-164` Reveal button
   - `ExportInspectorPanel.swift:169-179` Export Again button
   - 両方 `.controlSize(.small)` のまま `.buttonStyle(.glass)` を追加
3. **destructive / cancel → `.glass` (role=.cancel preserve)**
   - `ExportInspectorPanel.swift:100-103` Cancel button
4. **build verify**
   - `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` ✅
   - `.glassProminent` / `.glass` symbols が macOS 26 SDK に存在することを
     確認 (compile failure 時は custom `.glassEffect` modifier wrapping に
     fallback)
5. **commit (single)**

### Out (deferred / out of scope)

- **NSButton (AppKit Share) refactor** — `ShareAnchor`
  (ExportInspectorPanel.swift:228-258) は AppKit NSSharingServicePicker
  anchor のために必要。SwiftUI `ShareLink` に置き換えると anchor 制御を
  失うので変更しない。
- **LookLibraryControls Save Look (.borderless)** — `.borderless` は
  既に minimal posture、smoke 不満 surface していない。変更しない。
- **QuickAdjustControls Reset Quick (small default)** — same。
- **Toolbar Open / Export ButtonGroup (RootWindowView.swift:148-159)** —
  toolbar buttons は macOS 26 system Liquid Glass chrome に属する、
  app 側で buttonStyle 上書きしないのが HIG canonical。変更しない。
- **配色カスタム tint** — Apple canonical `.glassProminent` / `.glass`
  default で十分とまず仮定。不足が visual smoke で判明したら別 slice。

## Approach

```swift
// ExportInspectorPanel.swift (before)
Button { onExportTap() } label: { ... }
.buttonStyle(.borderedProminent)
.controlSize(.regular)

// after
Button { onExportTap() } label: { ... }
.buttonStyle(.glassProminent)
.controlSize(.regular)
```

```swift
// Reveal / Export Again (before)
Button { ... } label: { ... }
.controlSize(.small)

// after
Button { ... } label: { ... }
.buttonStyle(.glass)
.controlSize(.small)
```

`.glassProminent` / `.glass` が macOS 26 SDK で未提供の場合、custom
modifier wrapping に fallback:

```swift
Button { ... } label: { ... }
    .buttonStyle(.plain)
    .padding(.horizontal, 12).padding(.vertical, 6)
    .glassEffect(.clear.tint(.white.opacity(0.15)), in: Capsule())
```

## Done conditions

- ExportInspectorPanel の 4 button (Export primary / Cancel / Reveal /
  Export Again) が glass-family posture に統一
- `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` PASS、
  `Cannot find buttonStyle` 系 error なし
- Swift 6 strict concurrency warning なし
- system blue `.borderedProminent` solid box が右レール chrome から消える
- Visual smoke (button が dark glass container と調和) は user-driven

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift`
  (4 button modifier 変更)

## Read-Only References

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift:39-91`
  (right-rail container posture pattern)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/LookLibraryControls.swift:77-84`
  (.borderless reference, 変更不要)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift:36-39`
  (small default reference, 変更不要)

## Out Of Scope

- LookLibraryControls / QuickAdjustControls / SourceProfileControls の button
  (smoke で名指しされていない、現 minimal posture で OK)
- RootWindowView toolbar buttons (macOS 26 HIG: toolbar default)
- NSButton AppKit Share bridge

## Estimated size

~30-45 分。4 modifier 変更 + xcodebuild + commit。

## Operating mode

Auto-mode: 5-gap Tier B 1 件目。コミットは agent。`.glassProminent` /
`.glass` SDK 存在確認は xcodebuild の compile result に委任 → 失敗時のみ
custom `.glassEffect` fallback。
