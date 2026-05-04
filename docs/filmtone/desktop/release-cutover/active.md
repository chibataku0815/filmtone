# Active: Release Phase 1 — M3-fix + Signing prep

Date opened: 2026-05-04 JST
Lane: release-cutover (parallel to `native-desktop-v2/`)
Owner: Claude (delegated by user)
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Goal

Land the M3 canonical-drift fix + the M6 signing infrastructure in one
shippable commit-set so the next phase (release script + DMG + dry-run)
is unblocked. 本質: 製品が Gatekeeper / notarize 経路に乗る pbxproj
posture を持つこと。

## Stages

- [x] S0 — `FilmtoneGradePipeline.shouldApplyPrintStage` の `abs(p.printContrast)`
      を iOS canonical (`FilmtoneExportSession:2056`) と揃え `p.printContrast > epsilon`
      に。built-in 4 + Stone / Urban で no-op 維持、negative パラメータで kernel
      が動かない gate を回復。
- [ ] S1 — `apps/filmtone-desktop-macos/FilmtoneDesktop/FilmtoneDesktop.entitlements`
      新規作成。Hardened Runtime 必須項目のみ:
      - `com.apple.security.cs.allow-jit` = NO (要らない、許可で attack surface 広がる)
      - `com.apple.security.cs.allow-unsigned-executable-memory` = NO
      - `com.apple.security.cs.disable-library-validation` = NO
      - Sandbox 関連は **書かない** (Sandbox 不採用、file access 自由)
- [ ] S2 — `project.pbxproj` 編集:
      - `DEVELOPMENT_TEAM = C3G77H8NM6` を Debug + Release configuration に追加
      - `ENABLE_HARDENED_RUNTIME = YES` を Release のみに追加
      - `CODE_SIGN_ENTITLEMENTS = FilmtoneDesktop/FilmtoneDesktop.entitlements`
      - `CODE_SIGN_IDENTITY = "Developer ID Application"` を Release config に
      - `OTHER_CODE_SIGN_FLAGS = "--timestamp"` (notarize 必須)
      - Debug は Automatic + Apple Development 維持
- [ ] S3 — `xcodebuild -scheme FilmtoneDesktop -configuration Release build`
      で BUILD SUCCEEDED 確認 (まだ archive まではいかない、archive は M6-3 で)。
      Debug build も並行で再確認。
- [ ] S4 — commit 1 (M3-fix only) + commit 2 (M6-2 signing prep) に分けて
      commit。INV-7 は本 lane では user 委任で本 chat が実行。

## Invariants

- Debug build behaviour 不変。Release build が Developer ID で署名できる
  posture を満たす (実署名は M6-3 archive スクリプト経路で行う)。
- Sandbox 採用しない (file access の摩擦最小化、Developer ID + Hardened
  Runtime + notarize で配布要件を満たす)。
- iOS lane の pbxproj は触らない (CLAUDE.md §3 invariant)。

## Unexpected

(filled during work)

## Follow-up

- M6-3 release-macos.sh (next active phase)
- M6-4 DMG packaging
- M6-6 dry-run

## Result

(filled at close)
