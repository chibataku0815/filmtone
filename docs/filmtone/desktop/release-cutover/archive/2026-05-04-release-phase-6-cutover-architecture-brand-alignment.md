# Phase 6 — Cutover Architecture & Brand Alignment

Date opened: 2026-05-04 JST

## Goal

Lock the cutover-time identity (Bundle ID / Product Name / Version) so the
**next** `scripts/release-macos.sh` run produces an artifact that drop-in
upgrades existing Electron Desktop installs.

This closes the architectural gap surfaced 2026-05-04 — Phase 5 shipped
notarized 0.1.0 with Native v2's internal ID `co.fores-tone.filmtone.desktop`,
but `cutover-architecture.md` decision A pins production to Electron's
`com.chibatakumi.film-lab-desktop` for drop-in upgrade.

## Why this slice (本質)

Without this Phase, every release run produces a `co.fores-tone.*` artifact
that macOS treats as a *different app* from Electron's `com.chibatakumi.*`.
Existing Electron 1.0.3 installs would not auto-upgrade to Native v2; users
would see two separate apps in /Applications. That breaks the explicit "single
product cutover" direction.

The change is doc-light, code-light, but **release-blocking** for cutover.

## Scope

In-scope:

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`:
  - Debug + Release `PRODUCT_BUNDLE_IDENTIFIER` → `com.chibatakumi.film-lab-desktop`
  - Debug + Release `PRODUCT_NAME` → `Filmtone` (override `$(TARGET_NAME)`)
  - Debug + Release `MARKETING_VERSION` → `2.0.0`
- `scripts/release-macos.sh`:
  - `APP_NAME=Filmtone` (was `FilmtoneDesktop`)
  - `BUNDLE_ID=com.chibatakumi.film-lab-desktop` (was `co.fores-tone.filmtone.desktop`)
  - SCHEME stays `FilmtoneDesktop` (internal scheme/target identifier 不変)
- `scripts/package-dmg.sh`:
  - `APP_NAME=Filmtone`
  - DMG output filename `Filmtone-${version}.dmg` (現行 script そのまま、APP_NAME 連動)
- `xcodebuild Debug` smoke verify (build succeeds with new identity)
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`:
  - Goal section の "must remain a parallel lane" 削除 (cutover direction 確定)
  - Constraints L91 "Electron Desktop remains the shipping rail" 削除 / 更新
  - M6 row 状態更新 (Phase 5 deliverable + Phase 6 brand-alignment + cutover gate 明示)
  - Completion Log に Phase 6 entry
  - Interrupt / Decision Log に "Native v2 = Electron 単一置換" 一行追記
- `release-cutover/README.md`:
  - Phase 6 close summary section 追記
  - 環境前提節に新 identity (Bundle ID / Version) 追記
  - cutover-architecture.md への ポインタ

Out-of-scope (other Phases):

- Phase 7 distribution scripts (Vercel Blob upload + update-meta.json) port
- Phase 8 M5-C P0 closure (M5 chat 担当)
- Phase 9 実 2.0.0 release pipeline run (M5-C P0 closure 後)
- Phase 10 Electron 1.0.3 deprecation notice
- TS workspace deprecation 判断 (decision K)
- OQ-1〜OQ-4 (本質に直接影響しない、後続)

## Done conditions

- pbxproj Debug + Release で 3 settings × 2 configs = 6 値が新規値
- 両 scripts の APP_NAME / BUNDLE_ID 更新
- `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` succeeds
- 生成 .app の Info.plist が CFBundleIdentifier=`com.chibatakumi.film-lab-desktop`
  / CFBundleShortVersionString=`2.0.0` / CFBundleName=`Filmtone`
- strategy.md / README.md に Phase 6 反映
- `cutover-architecture.md` (persistent reference doc) ship 済
- 1 commit にまとめる (auditable、INV-7 lane override)

## Verification log

`xcodebuild -project FilmtoneDesktop.xcodeproj -scheme FilmtoneDesktop
-configuration Debug -destination 'generic/platform=macOS' build` →
`** BUILD SUCCEEDED **`。

Build output: `Build/Products/Debug/Filmtone.app` (PRODUCT_NAME-driven
bundle 名変更が裏側で正しく作用、scheme/target 識別子 `FilmtoneDesktop` は
内部で温存)。

生成 Info.plist (`Filmtone.app/Contents/Info.plist`、PlistBuddy 確認):

```
CFBundleIdentifier               = com.chibatakumi.film-lab-desktop  ← decision A
CFBundleShortVersionString       = 2.0.0                              ← decision B
CFBundleVersion                  = 1                                  ← keep
CFBundleName                     = Filmtone                           ← decision D
CFBundleExecutable               = Filmtone                           ← decision D 連動
LSApplicationCategoryType        = public.app-category.photography
LSMinimumSystemVersion           = 26.0                               ← decision C
NSHumanReadableCopyright         = © 2026 Takumi Chiba
```

decision A / B / C / D が `cutover-architecture.md` 通り全 key に反映済。

CodeSign (Debug): `Apple Development: takumi chiba (262F3A4568)` で auto
signing 成功 = bundle ID 変更で Apple Development 証明書チェーンが破綻
していないことを確認。Release 側 (Manual / Developer ID Application) は
`scripts/release-macos.sh` の preflight_signing_cert で fail-fast する設計
だが、Debug auto signing が通っている = Team ID `C3G77H8NM6` で bundle ID
`com.chibatakumi.film-lab-desktop` が問題なく cert chain を取得できる
ことを示す (Developer ID は team-bound、bundle ID 制約なし)。

scripts 側 (`scripts/release-macos.sh` L46-47、`scripts/package-dmg.sh`
L38) も:
- `APP_NAME=Filmtone` (旧 `FilmtoneDesktop`)
- `BUNDLE_ID=com.chibatakumi.film-lab-desktop` (旧 `co.fores-tone.filmtone.desktop`、
  release-macos.sh のみ)
で同期。SCHEME (`FilmtoneDesktop`) は内部識別子のため変更不要。

## Done summary

- pbxproj 3 settings × 2 configs = 6 値全更新済 (replace_all、Debug+Release)
- scripts 3 string 更新済
- xcodebuild Debug → ** BUILD SUCCEEDED **
- 生成 Info.plist 全 key 期待通り
- cutover-architecture.md (persistent reference doc) ship 済 — decision A〜K
  + OQ-1〜OQ-4 列挙
- direction memory `project_native_v2_replaces_electron.md` 永続化済

→ 次の `scripts/release-macos.sh` 実行は **drop-in upgrade artifact** として
Electron 1.0.3 install を上書きできる identity を持つ `Filmtone.app` (notarized
+ stapled、`Filmtone-2.0.0.dmg`) を produce する。

ただし実 2.0.0 release pipeline は M5-C P0 closure 後 (Phase 8 待ち)。
本 chat はここまでで release-cutover lane 物理作業完了。
