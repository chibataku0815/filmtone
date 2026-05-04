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
| M3-fix | iOS canonical との小 drift (printContrast sign-gate) を閉 | In progress |
| M6-1 | release-cutover lane doc tree 開設 (この文書) | Done |
| M6-2 | Hardened Runtime + entitlements + DEVELOPMENT_TEAM 配線 | Pending |
| M6-3 | scripts/release-macos.sh (build/archive/notarize/staple) | Pending |
| M6-4 | DMG packaging (hdiutil 直、create-dmg 不要) | Pending |
| M6-5 | portfolio submodule bump 手順 (release flow に) | Pending |
| M6-6 | end-to-end dry-run (v0.1.0-rc1) | Pending |

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
