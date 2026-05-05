# Active Task: Release Cutover Phase 4 — Pre-flight readiness audit (no ASC env)

Date opened: 2026-05-04 JST
Lane: release-cutover (parallel to M5 lane)
Worktree: /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
Branch: feature/native-desktop-plan
Classification: Phase 4 (post-Phase 3) — substance pre-flight, ASC env 不要

## Goal

Phase 1–3 で signing posture / scripts / category / copyright が ship 済。
M6-6 実 notarize は user の `ASC_ISSUER_ID` 設定待ちで私からは未実行。

その間に、parallel M5 lane で着地した最近 commit 群 (M5-A.3 video scrub /
M5-B Pass 3 `.clear` Liquid Glass posture / M5-B F-S6.1-2 toolbar +
preview Image refactor / Pass 4 `.clear.tint(.black.opacity(0.30))` 仕上げ)
が **Release configuration の archive build path を壊していない** ことを
私側で先回りに証明する。

これは user が初回 `scripts/release-macos.sh` 実行時、archive 段階で
止まらない (= 失敗が起きるなら notarize / spctl のみ) ことの保証。

## Why this slice (本質)

- `scripts/release-macos.sh` は `ASC_ISSUER_ID` を最初に require するので
  user は env を整えるまで script 全体を流せない。
- archive build (Step 1) と exportArchive (Step 2) は ASC env 非依存で、
  Release configuration の build greenness と Developer ID signing posture
  を検証できる。
- M5 lane で着地した SwiftUI / AppKit / pipeline 変更が Release build を
  壊していないか先回りに証明することで、user の初回 release run の
  iteration cost を消す (本質: 配布までの実時間短縮)。

## Scope (本 active で扱う)

| ID | 内容 | 担当 |
|---|---|---|
| P4-1 | Release configuration の clean archive (xcodebuild archive) | 本 chat |
| P4-2 | exportArchive で developer-id .app 生成 | 本 chat |
| P4-3 | codesign --verify --deep --strict --verbose=4 で署名検証 | 本 chat |
| P4-4 | codesign -dvvv で flags=0x10000(runtime) + secure timestamp 確認 | 本 chat |
| P4-5 | Generated Info.plist で copyright + category + version 反映確認 | 本 chat |
| P4-6 | spctl --assess --type execute で Gatekeeper 受理確認 (notarize 前なので unsigned-by-Apple 判定可、cert chain 経路だけ検証) | 本 chat |
| P4-7 | 結果を本 active に記録 → archive (実装変更なし、検証 deliverable のみ) | 本 chat |

## Out of scope (本 lane では扱わない)

- 実 notarize (M6-6、user `ASC_ISSUER_ID` 設定待ち)
- DMG packaging (notarized .app 前提、Phase 5 候補)
- portfolio submodule bump (release land 後)
- CFBundleDocumentTypes Info.plist 化 (Phase 3 で明示 punt、infra refactor)
- Sparkle 等 auto-update (lane 範囲外、外殻)
- M5 lane (parallel chat 領域、不可侵)

## Done conditions

- xcodebuild archive (Release) が BUILD SUCCEEDED
- xcodebuild -exportArchive で `FilmtoneDesktop.app` 生成
- codesign --verify --deep --strict が pass
- codesign -dvvv 出力に:
  - `Authority=Developer ID Application: takumi chiba (C3G77H8NM6)`
  - `flags=0x10000(runtime)` (Hardened Runtime active)
  - `Timestamp=...` (secure timestamp present)
  - `TeamIdentifier=C3G77H8NM6`
- Info.plist (生成) に:
  - `CFBundleShortVersionString = 0.1.0`
  - `CFBundleVersion = 1`
  - `LSApplicationCategoryType = public.app-category.photography`
  - `NSHumanReadableCopyright = © 2026 Takumi Chiba`
- 全 done の場合: 結果を本 active に追記 → archive、strategy.md 1 行追記
- 失敗時: 失敗箇所を Unexpected/Blockers に記録、user に報告して judgment 仰ぐ

## INV-7 / commit

本 lane では INV-7 override (user 委任、Phase 1/2/3 同様)。
本 active は **検証 only** (実装変更なし) なので、archive 完了時に
docs (active.md → archive、strategy.md 1 行) のみ commit。

## Verification log

実行 2026-05-04 13:55-13:57 JST、本 worktree (`feature/native-desktop-plan`、
last commit `fe675f33`) で:

### P4-1 archive (Release configuration)

```
xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj \
  -scheme FilmtoneDesktop -configuration Release \
  -archivePath apps/filmtone-desktop-macos/build/release-phase4/FilmtoneDesktop.xcarchive \
  -destination 'generic/platform=macOS' archive \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
```

→ `** ARCHIVE SUCCEEDED **` (exit 0)
→ CodeSign step in archive 出力で `Signing Identity: "Developer ID Application:
   takumi chiba (C3G77H8NM6)"` と `--timestamp -o runtime` flag、entitlements
   DER 生成を確認。M5 lane 最近 commit (Pass 3 / Pass 4 / scrub bar / F-S6.1-2)
   は Release build path を壊していない。

### P4-2 exportArchive (developer-id)

```
xcodebuild -exportArchive \
  -archivePath apps/filmtone-desktop-macos/build/release-phase4/FilmtoneDesktop.xcarchive \
  -exportPath apps/filmtone-desktop-macos/build/release-phase4/export \
  -exportOptionsPlist apps/filmtone-desktop-macos/ExportOptions.plist
```

→ `** EXPORT SUCCEEDED **`
→ `apps/filmtone-desktop-macos/build/release-phase4/export/FilmtoneDesktop.app`
   生成 (build/ は .gitignore L27 で track 外)。

### P4-3 codesign --verify --deep --strict --verbose=4

```
FilmtoneDesktop.app: valid on disk
FilmtoneDesktop.app: satisfies its Designated Requirement
```

### P4-4 codesign -dvvv (Hardened Runtime + secure timestamp + chain)

```
Identifier=co.fores-tone.filmtone.desktop
Format=app bundle with Mach-O universal (x86_64 arm64)
CodeDirectory v=20500 size=1290 flags=0x10000(runtime) hashes=29+7 location=embedded
Authority=Developer ID Application: takumi chiba (C3G77H8NM6)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
Timestamp=May 4, 2026 at 13:56:24
TeamIdentifier=C3G77H8NM6
Sealed Resources version=2 rules=13 files=2
```

判定:
- `flags=0x10000(runtime)` ✓ Hardened Runtime active
- Authority chain: Developer ID Application → Developer ID CA → Apple Root CA ✓
- `Timestamp=May 4, 2026 at 13:56:24` ✓ secure timestamp present
- `TeamIdentifier=C3G77H8NM6` ✓
- `Format=app bundle with Mach-O universal (x86_64 arm64)` ✓ universal

### P4-5 Info.plist (生成)

```
CFBundleShortVersionString:   0.1.0
CFBundleVersion:              1
CFBundleIdentifier:           co.fores-tone.filmtone.desktop
CFBundleName:                 FilmtoneDesktop
LSApplicationCategoryType:    public.app-category.photography
NSHumanReadableCopyright:     © 2026 Takumi Chiba
LSMinimumSystemVersion:       26.0
CFBundleDocumentTypes:        (not present — Phase 3 で明示 punt、infra refactor scope 外)
```

### P4-6 spctl --assess (notarize 前 baseline)

```
FilmtoneDesktop.app: rejected
source=Unnotarized Developer ID
```

判定: 期待通りの failure mode。`source=Unnotarized Developer ID` は Apple notary
chain が未付加であることだけを示しており、cert chain 経路 (Developer ID
identity + Hardened Runtime + secure timestamp) は受理されている = user の
初回 `scripts/release-macos.sh` 実行時、archive (Step 1) と exportArchive
(Step 2) は確実に通る。失敗が起こり得るのは notarytool submit (Step 4) と
spctl --assess (Step 6) のみ。

## Result

全 done condition pass。M5 lane の最近 commit 群は Release build path を
壊していない、Developer ID signing posture は健全、Hardened Runtime +
secure timestamp は適用される、生成 Info.plist の version / category /
copyright / minimum-system は正しい。

user 側で必要な作業は M6-6 のみ:

```bash
export ASC_KEY_ID=TM2BK9269B
export ASC_ISSUER_ID=<App Store Connect の Users and Access > Keys>
export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_TM2BK9269B.p8

cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
scripts/release-macos.sh   # archive → notarize → staple → spctl
scripts/package-dmg.sh     # DMG → notarize → staple → Gatekeeper
```

`MARKETING_VERSION = 0.1.0` のまま rc1 dry-run → smoke 通過後 0.1.0 公開。
`CURRENT_PROJECT_VERSION` (= build number) は release ごとに +1。

## Unexpected / Blockers

- DVTDeveloperAccountManager warning `Failed to load credentials for
  info@adoyosu.com: Invalid credentials in keychain ... missing Xcode-Token` が
  exportArchive ログに出るが、これは Xcode 内部の Apple ID session 管理が
  expired しているだけで、Manual signing + Developer ID の cert chain には
  影響なし (本 export は keychain の Developer ID Application identity から
  直接署名している)。release-macos.sh の挙動にも影響なし。

## Cleanup

`apps/filmtone-desktop-macos/build/release-phase4/` は .gitignore 27 行目
(`apps/filmtone-desktop-macos/build/`) で除外済 — track 外、commit 不要。
ローカルでは保持して次回 archive 時に上書きさせる (DerivedData cache 効く)。
