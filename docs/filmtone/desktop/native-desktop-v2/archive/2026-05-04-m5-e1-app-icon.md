# M5-E.1 App Icon Asset Population

Date opened: 2026-05-04 JST (auto-mode、user smoke で surface した
5 ギャップの Tier A 1 件目)

## Milestone

M5 Native Editing UI / brand identity slice。strategy.md "2026-05-04
user smoke で 5 個の追加ギャップ判明" の **M5-E.1**。

## Goal

Filmtone Desktop 起動時 / Finder / Dock / About box に Filmtone の
正しい app icon が表示される状態にする。現在は
`apps/filmtone-desktop-macos/FilmtoneDesktop/Assets.xcassets/AppIcon.appiconset/`
に Contents.json (10 entry 宣言) はあるが .png ファイル 0 個 = Xcode が
placeholder icon を fallback している。

## Why this slice (本質)

- ブランド identity は最初の 0.1 秒の judgement。release-cutover Phase 6
  の brand-alignment でも検出漏れだった (cutover-architecture.md は
  bundle ID / product name / version policy だけで asset 不在を見落とし)。
- 1.4 公開 gate の対象。placeholder icon で notarize 提出すると Apple の
  reviewer 印象も悪い。

## Scope

### In

1. **icon source acquisition**
   - iOS `apps/capacitor-film-lab-ios/ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png`
     (1024×1024 想定) を source とする。サイズ確認 → 1024 でなければ
     `sips -z 1024 1024` で正規化。
2. **macOS 用 10 size 生成**
   - `sips` で 16×16, 32×32, 128×128, 256×256, 512×512 を 1x / 2x で計 10 枚生成。
   - 命名規則: `icon_16x16.png`, `icon_16x16@2x.png`, `icon_32x32.png`,
     `icon_32x32@2x.png`, `icon_128x128.png`, `icon_128x128@2x.png`,
     `icon_256x256.png`, `icon_256x256@2x.png`, `icon_512x512.png`,
     `icon_512x512@2x.png` (Apple HIG 標準命名)。
3. **Contents.json 更新**
   - 既存 10 entry に `filename` キーを追加してファイル名を bind。
4. **build verify**
   - `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` ✅
   - DerivedData 内 `Filmtone.app/Contents/Resources/AppIcon.icns` が
     生成されること確認 (`ls -la .../AppIcon.icns`)
   - 起動して Dock + Finder Get Info で正しい icon 確認 (visual smoke)

### Out (deferred)

- iOS と完全に異なる Filmtone Desktop 専用 icon design — 現段階では iOS
  source 流用で OK (両方とも Filmtone ブランド)。専用 mac chrome icon
  design は brand 全体で再構築する別 slice
- Tinted icon variant (macOS 26 standard) — `Contents.json` の "tinted"
  appearance entry は現状なし、追加対象外
- Dark-mode 専用 icon variant — same

## Approach

```bash
SRC=apps/capacitor-film-lab-ios/ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png
DST=apps/filmtone-desktop-macos/FilmtoneDesktop/Assets.xcassets/AppIcon.appiconset

# 1. source 1024 確認
sips -g pixelWidth -g pixelHeight "$SRC"

# 2. 10 size 生成
for sz in 16 32 128 256 512; do
  sips -z $sz $sz "$SRC" --out "$DST/icon_${sz}x${sz}.png"
  sips -z $((sz*2)) $((sz*2)) "$SRC" --out "$DST/icon_${sz}x${sz}@2x.png"
done

# 3. Contents.json 更新 (jq or 手書き)
# 4. xcodebuild build → AppIcon.icns 生成確認
```

## Done conditions

- `Assets.xcassets/AppIcon.appiconset/` に 10 個の .png が存在
- Contents.json の 10 entry が `filename` で対応する .png を指す
- `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` が
  PASS、warnings に "could not find image resource" 系がない
- ビルドされた `Filmtone.app/Contents/Resources/AppIcon.icns` が存在
- Dock / Finder / About box 全てに Filmtone icon が表示される (visual
  smoke は user-driven、code-level は build artifact 確認で OK)

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Assets.xcassets/AppIcon.appiconset/Contents.json` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Assets.xcassets/AppIcon.appiconset/icon_*.png` (10 new files)

## Read-Only References

- `apps/capacitor-film-lab-ios/ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` (source)
- `apps/capacitor-film-lab-ios/ios/App/App/Assets.xcassets/AppIcon.appiconset/Contents.json` (single-image macOS / iOS pattern reference)

## Out Of Scope

- pbxproj 編集 — `Assets.xcassets` 自体は既に project に登録済み、
  `Contents.json` + 同 directory 内 .png 追加で Xcode が自動 pick up
- App Category / Spotlight metadata — release-cutover lane の領分

## Estimated size

~20-30 分。short slice、commit 1 回。

## Operating mode

Auto-mode: user の "計画書更新が終わったらcompactしてアクティブタスクを
進めてましょう" 指示に従い、/compact 後に implementation 開始。
コミットは agent。
