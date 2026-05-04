# Active: Release Phase 1 — M3-fix + Signing + Pipeline + dry-run (partial)

Date opened: 2026-05-04 JST
Lane: release-cutover (parallel to `native-desktop-v2/`)
Owner: Claude (delegated by user)
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`
Status: **Closing** (archiving)

## Goal

Land the M3 canonical-drift fix + the M6 signing infrastructure + the
release pipeline scripts + a partial end-to-end dry-run (archive +
exportArchive) so the only remaining gate before a real public release
is the user-driven notarize submission.

## Stages

- [x] S0 — `FilmtoneGradePipeline.shouldApplyPrintStage`: `abs(p.printContrast)`
      を iOS canonical (`FilmtoneExportSession:2056`) と揃え `p.printContrast > epsilon` に
      → commit `4e72aae`.
- [x] S1 — `FilmtoneDesktop.entitlements` 新規作成 (Hardened Runtime + JIT/unsigned
      memory/library validation/get-task-allow すべて false、Sandbox 採用しない)
      → commit `ac51869`.
- [x] S2 — `project.pbxproj` Debug + Release config 編集 (DEVELOPMENT_TEAM /
      ENABLE_HARDENED_RUNTIME / CODE_SIGN_ENTITLEMENTS、Release のみ Manual signing
      + Developer ID Application + --timestamp) → commit `ac51869`.
- [x] S3 — `xcodebuild Debug build` + `xcodebuild Release build` 両方 BUILD SUCCEEDED、
      `codesign -dvv` で Authority=Developer ID Application、TeamIdentifier=C3G77H8NM6、
      flags=0x10000(runtime)、Timestamp あり、entitlements 4 keys=false 確認。
- [x] S4 — `scripts/release-macos.sh` (archive → exportArchive → notarize → staple →
      spctl assess) と `scripts/package-dmg.sh` (stage → hdiutil → codesign → notarize
      → staple → spctl) と `apps/filmtone-desktop-macos/ExportOptions.plist`
      (developer-id method) を新規作成 → commit `8bd41b4`.
- [x] S5 — `release-cutover/` lane doc tree 開設 → commit `2942f9a`.
- [x] S6 — End-to-end dry-run **partial**: `xcodebuild archive` + `xcodebuild
      -exportArchive` を実機で実行、ARCHIVE SUCCEEDED + EXPORT SUCCEEDED、出力 .app は
      Universal binary (x86_64 + arm64)、Developer ID Application 署名 + Hardened
      Runtime + secure timestamp + entitlements 全 false。残: notarize submit + staple
      + DMG + spctl assess は user の `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_PATH`
      env 設定後、`scripts/release-macos.sh` 1 発で完結する状態。

## Invariants — all satisfied

- Debug build 不変: BUILD SUCCEEDED, Automatic signing 維持, 既存 dev workflow に影響なし。
- Release build が Developer ID で署名され Hardened Runtime + timestamp 付きで
  notarize submit-ready posture (codesign 検証済).
- Sandbox 不採用: file access 摩擦ゼロ、Developer ID + Hardened Runtime + notarize で
  配布要件を満たす posture を選択。
- iOS lane (`apps/capacitor-film-lab-ios/`) は触らず (CLAUDE.md §3 invariant 遵守).
- Generated Swift も非編集 (CLAUDE.md §3 generated-only invariant 遵守).

## Unexpected

- **Xcode auto-injects `com.apple.security.get-task-allow=true` on `xcodebuild build`**
  (non-archive) ですら Release config で挿入された。`xcodebuild archive` 経路では Apple
  ツールが strip するが、entitlements ファイルに明示 `<false/>` を書いておくのが堅牢。
  S1 で追加対応 (initial 3 keys → 4 keys)。
- **`exportArchive` warning**: 「No App Category is set for target 'FilmtoneDesktop'」 —
  notarize blocker ではない (Developer ID 配布で必須でない) が、App Store 化や Spotlight
  ランキングでは category 推奨。Follow-up 化。
- **Stale Xcode credentials warning** for `info@adoyosu.com` 経路 — ローカル keychain
  cache の noise、本 build には無関係。

## Follow-up (post-archive)

- **User-driven full notarize dry-run** (M6-6 残り):
  ```
  ASC_KEY_ID=TM2BK9269B \
  ASC_ISSUER_ID=<your-issuer-uuid> \
  ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_TM2BK9269B.p8 \
  scripts/release-macos.sh
  ```
  実行後、`scripts/package-dmg.sh` で DMG 化 → 全 Gatekeeper assess pass まで確認。
- **App Category** を `Info.plist` (or pbxproj `INFOPLIST_KEY_LSApplicationCategoryType`) で
  設定 (release polish、follow-up active で扱う)。
- **Portfolio submodule bump 手順** を release-cutover/README に追記 (M6-5)。
- **Release notes / public copy** は portfolio スコープ (CLAUDE.md §1)、本 lane 範囲外。

## Result

Phase 1 closed. M3 LOW gap (printContrast canonical drift) closed. M6
signing posture + release pipeline scripts (release-macos.sh,
package-dmg.sh, ExportOptions.plist) landed and archive +
exportArchive 経路は実機 verify 済。残るは user 環境の `ASC_ISSUER_ID`
を渡しての notarize submit (single command 完結) と DMG 生成のみ。

5 commits landed: `4e72aae` (M3-fix), `ac51869` (signing prep),
`2942f9a` (release-cutover doc tree), `8bd41b4` (release pipeline),
+ archive doc commit (this archive).

