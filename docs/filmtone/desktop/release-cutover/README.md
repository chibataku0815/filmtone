# Release Cutover Lane (M3 hardening + M6 release)

このディレクトリは Filmtone Native Desktop v2 の **release cutover lane** の正本。
M5 lane (`docs/filmtone/desktop/native-desktop-v2/`) と並列で動く独立 lane。

## なぜ別 tree か

`native-desktop-v2/` は `Keep only one active.md at a time` 不変条件で運用される
M5 product lane。M3 残り (printContrast canonical drift 等の hardening) と M6
(signing / notarize / DMG / portfolio bump) は M5 機能進行とは独立、parallel
で release 着地までの絶対時間を縮めるために別 tree で持つ。

完了時、M3/M6 の milestone-table 状態は `native-desktop-v2/strategy.md`
Completion Log に短く反映する (本 lane の archive 経由で参照)。

## 担当範囲 (本質優先 / 外殻最小)

| ID | 内容 | 状態 |
|---|---|---|
| M3-fix | iOS canonical との小 drift (printContrast sign-gate) を閉 | **Done** (`4e72aae`) |
| M6-1 | release-cutover lane doc tree 開設 (この文書) | **Done** (`2942f9a`) |
| M6-2 | Hardened Runtime + entitlements + DEVELOPMENT_TEAM 配線 | **Done** (`ac51869`) |
| M6-3 | scripts/release-macos.sh (build/archive/notarize/staple) | **Done** (`8bd41b4`) |
| M6-4 | DMG packaging (hdiutil 直、create-dmg 不要) | **Done** (`8bd41b4`) |
| M6-5 | portfolio submodule bump 手順 (本 README 末尾参照) | **Done** |
| M6-6 | end-to-end dry-run (v0.1.0-rc1) | **Partial** — archive + exportArchive 実機 verify 済 (Phase 4 で M5 最新 commit 群でも再確認 — `flags=0x10000(runtime)` + Authority chain + secure timestamp + 生成 Info.plist 全 key 健全)、notarize は user env 必要 |
| polish | App Category 設定 (notarize blocker でない) | **Done** (Phase 2) |

## Out of scope (本 lane では扱わない)

- Sparkle auto-update — release 後 follow-up (外殻)
- App Sandbox 化 — 配布形式 = Developer ID + Hardened Runtime + notarize 完結、
  Sandbox は file access 摩擦増で本質劣化
- CI 化 (GitHub Actions) — local sh 1 つで完結する形 factor 優先
- Metal CIKernel migration (Open Question) — release 後 hardening
- Camera profile / Input LUT extension — 別 lane
- terminal `cropped` / Creative LUT 残 LOW gap — built-in 4 presets / Stone /
  Urban で no-op 確認済 → release 後 hardening

## Operating rules

- 本 lane の active.md は singleton (本 lane 内)。M5 lane の active.md と並走可。
- 本 chat が commit を行う (user 委任、INV-7 はこの lane では override)。
- archive は `archive/YYYY-MM-DD-{slug}.md`。
- 本質に効かない外殻提案は user 明示要求時のみ採用。
- Apple Developer 環境依存事項 (証明書、ASC API key、notarytool) で blocker に
  当たったら明示 pause、勝手な workaround で品質劣化させない。

## 環境前提 (確認済 2026-05-04)

- Developer ID Application: takumi chiba (Team `C3G77H8NM6`) keychain にあり
- iOS Fastfile が ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_CONTENT or ASC_KEY_PATH
  経由で notarize する pattern を採用済 → macOS lane も同 env で流用
- xcrun notarytool (Xcode 16+) 利用可能
- create-dmg 未インストール → hdiutil で対応 (brew 不要)

## 配布形式 (確定)

| 形式 | 採用 | 理由 |
|---|---|---|
| DMG | ★ | macOS standard、Gatekeeper 親和、staple 可能 |
| zip + staple | × | DMG より UX 劣る (ダウンロード後の解凍ステップが余計) |
| PKG | × | Installer は app の場合 overkill |
| Sparkle | × (外殻) | release 後 follow-up |

## Release version 方針

- `MARKETING_VERSION = 0.1.0` 維持で `0.1.0-rc1` を dry-run、smoke 通過後に
  `0.1.0` で公開 release。
- `CURRENT_PROJECT_VERSION` (build number) は release ごとに +1。

## Release run 手順 (user-driven)

Phase 1 で signing posture + scripts は ship 済。実 release は user の Apple
Developer 環境 env で 1 コマンド実行。

```bash
# ASC API key は ~/.appstoreconnect/private_keys/AuthKey_TM2BK9269B.p8 既配置
export ASC_KEY_ID=TM2BK9269B
export ASC_ISSUER_ID=<App Store Connect の Users and Access > Keys で確認できる UUID>
export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_TM2BK9269B.p8

cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

# 1. archive → notarize → staple → spctl assess
scripts/release-macos.sh

# 2. notarized .app を DMG 化 → DMG も notarize → staple → Gatekeeper assess
scripts/package-dmg.sh
```

出力:

- `apps/filmtone-desktop-macos/build/release/0.1.0/FilmtoneDesktop.app`
  (notarized + stapled)
- `apps/filmtone-desktop-macos/build/release/0.1.0/FilmtoneDesktop-0.1.0.dmg`
  (notarized + stapled、配布可能)

notarize 拒否時は `notarize-rejection.json` が出力される。所要時間は
notarize submit が数分 (Apple 側 queue 次第)。

## Portfolio submodule bump (release 後の波及)

filmtone main に release commit (or tag) が land した後、portfolio repo の
`vendor/filmtone` submodule pin を bump して公開窓 (landing / support / privacy /
release-notes / journal) に新 release を反映する。

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
git submodule update --remote vendor/filmtone
git add vendor/filmtone
git commit -m "chore(filmtone): bump submodule to 0.1.0"
# (push は user)
```

vercel deploy は portfolio の `apps/web` build に依存するので submodule pin
が古いと公開窓が古いまま。release 完了 = filmtone main land + portfolio bump
+ portfolio push の 3 つ揃って初めて公開反映。

詳細は CLAUDE.md §7 (Submodule update 手順) を参照。

## Phase 1 close summary

5 commits landed (2026-05-04):

1. `4e72aae` fix(macos): M3 printContrast sign-gate match iOS canonical
2. `ac51869` feat(macos): M6 signing prep — Hardened Runtime + Developer ID + entitlements
3. `2942f9a` docs(release-cutover): open parallel release lane
4. `8bd41b4` feat(release): M6 macOS release pipeline — archive / notarize / DMG
5. (this commit) docs(release-cutover): archive Phase 1 + bump手順

Codesign verification on the archived + exportArchive build:

```
Authority=Developer ID Application: takumi chiba (C3G77H8NM6)
Format=app bundle with Mach-O universal (x86_64 arm64)
flags=0x10000(runtime)            # Hardened Runtime active
Timestamp=May 4, 2026              # secure timestamp present
TeamIdentifier=C3G77H8NM6
entitlements: 4 keys all = false
```

## Phase 2 close summary

1 commit landed (2026-05-04):

- pbxproj Debug + Release に `INFOPLIST_KEY_LSApplicationCategoryType =
  "public.app-category.photography"` 追加
- Debug build pass、生成 Info.plist で `LSApplicationCategoryType` 反映確認
- exportArchive の "No App Category" soft warning は次回 release run で消える想定
- archive: `archive/2026-05-04-release-phase-2-app-category.md`

## Phase 3 close summary

2 commit landed (2026-05-04):

- scripts/release-macos.sh + scripts/package-dmg.sh: dual `ASC_KEY_PATH` /
  `ASC_KEY_CONTENT` env support (iOS Fastfile parity、CI flow ready)
- temp .p8 cleanup trap を global var return に修正 (subshell pitfall 回避)
- `preflight_signing_cert()` で keychain cert fail-fast (archive 起動前)
- `~/` tilde expansion in `ASC_KEY_PATH` (defensive)
- pbxproj `INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 Takumi Chiba"`
  (iOS canonical truth `fastlane/metadata/copyright.txt` 由来)
- archive: `archive/2026-05-04-release-phase-3-pipeline-hardening-and-copyright.md`

`CFBundleDocumentTypes` (Finder Open With) は INFOPLIST_KEY_* 経由不可で real
Info.plist file 化 = infra refactor のため引き続き scope 外。

## Phase 4 close summary

実装変更なし、検証 deliverable のみ (2026-05-04):

- ASC env 不要範囲 (archive Step 1 + exportArchive Step 2) を本 chat で実行、
  M5 lane の最近 commit 群 (Pass 3 `.clear` posture / Pass 4 `.clear.tint
  (.black.opacity(0.30))` 仕上げ / M5-A.3 video scrub / F-S6.1-2 toolbar +
  preview Image refactor) が Release build path を壊していないことを確認。
- `xcodebuild ... archive` `** ARCHIVE SUCCEEDED **`、`xcodebuild
  -exportArchive` `** EXPORT SUCCEEDED **`。
- `codesign --verify --deep --strict --verbose=4`: valid on disk + satisfies
  Designated Requirement。
- `codesign -dvvv`: `flags=0x10000(runtime)` ✓ Hardened Runtime active、
  Authority chain (Developer ID Application: takumi chiba (C3G77H8NM6) →
  Developer ID Certification Authority → Apple Root CA) ✓、
  `Timestamp=May 4, 2026 at 13:56:24` ✓ secure timestamp present、
  `Format=app bundle with Mach-O universal (x86_64 arm64)` ✓ universal。
- 生成 Info.plist: `CFBundleShortVersionString=0.1.0` / `CFBundleVersion=1` /
  `CFBundleIdentifier=co.fores-tone.filmtone.desktop` /
  `LSApplicationCategoryType=public.app-category.photography` /
  `NSHumanReadableCopyright=© 2026 Takumi Chiba` /
  `LSMinimumSystemVersion=26.0` 全 OK。
- `spctl --assess --type execute`: `rejected source=Unnotarized Developer ID`
  ← Apple notary chain が未付加なだけの expected reject、cert chain 経路
  自体は受理。user の初回 `scripts/release-macos.sh` 実行時、archive と
  exportArchive は確実に通る = 失敗が起こり得るのは notarytool submit
  と spctl --assess (notarize 後) のみ。
- archive: `archive/2026-05-04-release-phase-4-preflight-readiness.md`

次フェーズ (新 active.md 化、user-driven trigger):
- M6-6 実 notarize end-to-end run (user `ASC_ISSUER_ID` 設定 → `scripts
  /release-macos.sh` → `scripts/package-dmg.sh`)
- 実 run の結果次第で raised issue 対応
- Sparkle 等 auto-update は別 lane (本 lane 範囲外、外殻)
