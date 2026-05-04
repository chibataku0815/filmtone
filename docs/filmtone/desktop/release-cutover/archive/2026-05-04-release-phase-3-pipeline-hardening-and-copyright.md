# Archive: Release Cutover Phase 3 — Pipeline Hardening + Copyright

Date opened: 2026-05-04 JST
Date closed: 2026-05-04 JST (same-day, scope tiny)
Lane: release-cutover
Worktree: /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
Branch: feature/native-desktop-plan
Classification: Phase 3 (post-archive Phase 2) — substance hardening

## Result

- scripts/release-macos.sh + scripts/package-dmg.sh: dual `ASC_KEY_PATH` /
  `ASC_KEY_CONTENT` env support 追加 (iOS Fastfile parity、CI flow ready)
- temp .p8 cleanup trap を **global var return** に修正 (subshell pitfall 回避)
- `preflight_signing_cert()` で archive 起動前に keychain cert fail-fast
- `~/` tilde expansion in `ASC_KEY_PATH` (defensive)
- pbxproj Debug + Release: `INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026
  Takumi Chiba"` (iOS canonical truth `fastlane/metadata/copyright.txt` 由来、
  推測ではない)
- 検証: `bash -n` syntax pass、空 env / `ASC_KEY_PATH` 不在 / `ASC_KEY_CONTENT`
  end-to-end (notarytool が temp key file を読める段階まで到達) 確認、Debug build
  pass、Info.plist で copyright 反映、cleanup trap 動作 (TMPDIR clean)
- 2 commit でランド (scripts hardening / pbxproj copyright)

## Goal

User が `scripts/release-macos.sh` を初回 run した時、subtle bug や env 形式
非対応で iteration loop しないように pipeline を harden する。あわせて Phase 2
で保留した `NSHumanReadableCopyright` を iOS canonical truth (推測ではない) で
埋める。

## iOS canonical references discovered

| 項目 | iOS source | Desktop 適用先 |
|---|---|---|
| Copyright string | `apps/capacitor-film-lab-ios/fastlane/metadata/copyright.txt = "2026 Takumi Chiba"` | pbxproj `INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 Takumi Chiba"` |
| Dual ASC key env | Fastfile `asc_api_key_configured?` (`ASC_KEY_PATH` ∥ `ASC_KEY_CONTENT`) | scripts/release-macos.sh + scripts/package-dmg.sh |
| Temp .p8 cleanup pattern | Fastfile `resolve_asc_key_file_path!` (mktemp + chmod 600 + cleanup) | scripts helper |

## Scope

| ID | 内容 | 担当 |
|---|---|---|
| P3-1 | scripts/release-macos.sh: `resolve_asc_key_path()` (dual env) + `preflight_signing_cert()` + tilde expansion | 本 chat |
| P3-2 | scripts/package-dmg.sh: 同 helper (duplicate is intentional; abstract後刻) | 本 chat |
| P3-3 | pbxproj: `INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 Takumi Chiba"` (Debug + Release) | 本 chat |
| P3-4 | bash syntax check (`bash -n`) + Debug build verify (`Info.plist` で copyright 反映) | 本 chat |
| P3-5 | commit (scripts と pbxproj は別 commit、auditable) + archive | 本 chat |

## Hardening details

### `resolve_asc_key_path()` (各 script に複製)

- `ASC_KEY_CONTENT` 優先 (CI / GitHub Actions friendly)
  - `\n` literal を real newline に変換 (iOS Fastfile parity)
  - `mktemp` → chmod 600 → `trap '... rm' EXIT`
- `ASC_KEY_PATH` fallback (local dev)
  - `~/` 展開 (bash assignment 時 expansion 漏れ defensive)
  - 絶対パス化、`-f` exists check

### `preflight_signing_cert()`

`security find-identity -v -p codesigning` で `Developer ID Application: takumi
chiba (C3G77H8NM6)` 存在確認、archive 起動前に fail-fast。現状: keychain
喪失時 ~2-3 分の archive 後に CodeSign 段階で失敗 → user iteration cost 大。

## Out of scope

- scripts の helper 抽出 (`scripts/lib/release-helpers.sh`) — 重複 ~15 行 / 用途
  限定 = 외殻、将来別 phase
- `CURRENT_PROJECT_VERSION` auto-bump — release ごと build number 手動 +1 で十分
  (年に数回 release で rote work 微小)
- ASC API key の keychain storage — env 配布で十分

## Done conditions

- 両 scripts `bash -n` syntax check pass
- 両 scripts に dual env helper 反映、env 不在時の error メッセージが新形式
- `xcodebuild Debug build` → BUILD SUCCEEDED、Info.plist で copyright 反映
- 2 commit でランド (scripts hardening / copyright pbxproj)

## INV-7 / commit

本 lane では INV-7 override (user 委任、Phase 1 / 2 同様)。
