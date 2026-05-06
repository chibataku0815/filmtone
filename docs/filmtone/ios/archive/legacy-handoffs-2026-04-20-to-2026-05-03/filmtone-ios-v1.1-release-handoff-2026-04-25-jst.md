# Filmtone iOS v1.1 Release Handoff

- Last updated: 2026-04-25 JST
- Writer: previous chat (Wave 1–3 implementer)
- Target chat: release-focused chat to take v1.1 from "merged on local main" to "live on App Store"
- Treat this document as **the primary source of truth**. Read it end to end before any action.
- Supersedes: none (v1.0 release doc is historical: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md`)

---

## 0. 前提 (この chat だけを読む人向け)

- プロダクト: **Filmtone iOS** (Capacitor + Swift / SwiftUI ハイブリッド、SwiftUI root が本線、Capacitor/WebView は補助)
- リポ: `chibatakumi-portfolio` (monorepo)
  - iOS app: `apps/capacitor-film-lab-ios/`
  - 共有 contract: `packages/film-lab-core/`
  - Desktop 姉妹アプリ: `apps/desktop-film-lab-batch/` (同 repo 内)
- 作業機: macOS (darwin 25.4.0 / Apple Silicon)
- 大前提:
  - v1.0 は App Store Connect "Waiting for Review" 状態で submit 済み (2026-04-20 初版 release handoff 参照)
  - v1.1 **Desktop v1.0.3 parity bundle (T1–T6)** は main に merge 済 (commit `035486fb`、2026-04-25 JST)
  - **v1.0 が App Store に public release される前に v1.1 を submit しない方針**。tag 打ち・ASC upload・TestFlight は v1.0 公開後に実行する

---

## 1. Executive Status

### 🟢 完了
- **v1.1 T1–T6 parity bundle が main に merge 済** (commit `035486fb merge: Filmtone iOS v1.1 T1-T6 parity bundle`)
- **Xcode build green**: `xcodebuild -workspace ios/App/App.xcworkspace -scheme App -sdk iphonesimulator -configuration Debug build` → BUILD SUCCEEDED / 0 errors
- **Contract verify green**: `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract` → 4 test groups pass (canonical + classifier + ray-angle + sidecar)
- **TS tests green**: `bun test packages/film-lab-core` → 110 pass / 0 fail / 505 expect()
- **Generator drift check green**: `bun run generate:filmtone-ios-swift --check` → no drift
- **Release blockers fixed** (previous chat の精査で発見されて即修正済):
  - vignette kernel 中心黒化バグ (mask 乗算位置修正)
  - Xcode target 未登録 8 Swift files (project.pbxproj 4 section に登録)

### 🟡 これから (next chat)
- v1.0 App Store public release 完了を確認
- **MARKETING_VERSION を 1.0 → 1.1 に bump** (iOS project 内 4 箇所)
- CURRENT_PROJECT_VERSION を 1 → 2 (またはビルド番号ポリシーに従う)
- 日本語 / 英語 release notes を v1.1 用に書き換え
- `git push origin main` (現在 local-only)
- `ios-v1.1.0` tag 打ち (下記 §5 のタグ運用確認後)
- Fastlane lanes: `release:archive` → `release:screenshots` (必要なら) → `release:metadata` → `release:appstore`
- ASC 上で `SUBMIT_FOR_REVIEW=1 AUTOMATIC_RELEASE=1` 運用か、手動提出かを user と確認

### 🟣 後続 PR (release blocker ではない、v1.1.x または v1.2 で良い)
- UI snapshots (`FilmtoneSnapshotsUITests` に HDR notice / metadata optics label / assumed-vignette byte-identical の 3 state を追加)
- Manual fixture smoke (実機 SDR / HLG / PQ / wide-gamut / portrait / VFR / share 2-item / sidecar round-trip)
- Capacitor/WebView share path の sidecar 対応 (`FilmtoneMediaPlugin.swift:287` + `filmtoneMedia.ts:24` が `uri` のみ運ぶ。SwiftUI root が本線なので release gate ではないが、WebView UI を維持するなら follow-up で対応)
- 小画面 iPhone (12 mini / SE 第3世代) レイアウト確認 (HDR notice 縦伸び、optics MetricCard、previewMetaLabel overflow のリスクあり — Stream 3 agent が flag 済)

---

## 2. v1.1 で着地した内容 (T1–T6)

Parent plan: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`
Gap analysis: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-parity-gap-vs-desktop-v1.0.3-2026-04-24-jst.md`
Task index: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/ios-v1.1-tasks/README.md` (T1–T10; v1.1 bundle は T1–T6 のみ)

主旨: **Desktop v1.0.3 で増えた "silent な処理" を iOS でも可視化**する。HDR / optics / source metadata / sidecar の透明性。画作り parity (Cross Filter native, depth coupling) は意図的に v1.2 へ分離。

| Task | Priority | 内容 | 主な新規/修正ファイル |
|------|----------|------|------------|
| T1 | P0 | HDR source visibility + policy notice | `SourceColorMetadataNormalizer.swift` (新) / `SourceColorClassifier.swift` (新) / `HdrPreparationPolicyDeriver.swift` (新) / `FilmtoneHdrPolicyNotice.swift` (新) / `FormatExtensionReader.swift` (新) / `SourceProbeService.swift` (拡張) / `FilmtoneMediaTypes.swift` (7 DTO 追加) / `FilmtoneRootView.swift` (notice 挿入) |
| T2 | P0 | Export sidecar JSON | `FilmtoneExportSidecarBuilder.swift` (新、UIKit 非依存 DI) / `FilmtoneExportSession.swift` (run() 内で sidecar 書き出し + `sidecarUri` 返却) / `FilmtoneMediaRuntime.swift` (result 再構築で sidecarUri 継承) / `ShareSheetService.swift` (`share(fileURLs: [URL])` 化) / `FilmtoneEditorFacade.swift` (`shareOutput(mediaURI:sidecarURI:)`) / `FilmtoneEditorStore.swift` (forward sidecarUri) / schema: `filmtone-ios-export-session-v1` |
| T3 | P1 | Camera optics renderer wiring (vignette のみ) | `FilmtoneRayAngleOptics.swift` (新、Desktop `rayAngleOptics.ts` の Swift port) / `FilmtoneExportSession.swift` (vignette kernel 拡張、`applyMask=1` only when `cameraOptics.source == "metadata"`) |
| T4 | P1 | Source video metadata DTO + rotation + nominal-only FPS trust | `SourceProbeService.swift` (color attachments / preferredTransform / timing を読み、`SourceVideoMetadataDTO` を populate) / `FilmtoneMediaTypes.swift` |
| T5 | P1 | Camera optics UI label | `FilmtoneCameraOpticsFormatter.swift` (新、Desktop `video-probe-label.ts` Swift port) / `FilmtoneExportPanel.swift` (MetricCard) / `FilmtonePreviewView.swift` (previewMetaLabel) / `FilmtoneStrings.swift` + `Localizable.xcstrings` (jp/en 11 新規キー) |
| T6 | P1 | Contract regeneration guardrails | `presets.ts` (`CONTRACT_DEFAULTS` + `ContractDefaultKey` を export 化) / `ios-swift-payload.ts` (`hiddenDefaults` emission、`CONTRACT_DEFAULT_KEY_ORDER` で決定論的出力) / `FilmtonePhase0Generated.swift` (再生成) / `FilmtonePhase0Math.swift` (`FilmtonePhase0HiddenDefaults` struct) / `verify-phase0-contract.swift` (hidden defaults + preset count + HLG fixture guards) / `verify-phase0-contract.sh` (3 new test scripts wired) / `scripts/verify-ios.sh` (worktree 固定解除 + `generate --check` as first step) |

### 共通契約 (凍結済)

**Swift DTO (FilmtoneMediaTypes.swift):** `SourceColorClassDTO`, `HdrPreparationStrategyDTO`, `HdrPreparationPolicyDTO`, `SourceColorMetadataDTO`, `SourceDisplayGeometryDTO`, `SourceVideoTimingMetadataDTO`, `SourceVideoMetadataDTO` を追加。`SourceProbeDTO.sourceVideoMetadata?` と `Phase0ExportResultDTO.sidecarUri?` は default nil 引数で後方互換維持。

**Sidecar schema:** `<outputURL>.filmtone-ios-export-session-v1.json`。Photos 非保存、share sheet で media + sidecar 2 items。LUT data 配列は非埋込 (size + intensity のみ)。

**Hidden defaults (19 keys, SSOT = `packages/film-lab-core/src/presets.ts::CONTRACT_DEFAULTS`):**
`depthMistGain` 0 / `depthGlowGain` 0 / `depthRayAngleGamma` 1.4 / `depthRayAngleInnerThreshold` 0.1 / `depthMistRayAngleGain` 0.35 / `depthBloomRayAngleGain` 0.25 / `depthHalationRayAngleGain` 0.18 / `depthMistFieldPsfGain` 1 / `depthBloomFieldPsfGain` 1 / `depthHalationFieldPsfGain` 1 / `depthMistFieldPsfRadiusPx` 18 / `depthBloomFieldPsfRadiusPx` 9 / `depthHalationFieldPsfRadiusPx` 12 / `crossFilterDepthGain` 0.25 / `crossFilterAngleGain` 0.35 / `crossFilterAngleGamma` 1.4 / `crossFilterAngleInnerThreshold` 0.1 / `crossFilterEdgeLengthGain` 0.45 / `crossFilterEdgeStrengthGain` 0.25.

**Ray-angle constant:** `tan(65 * π / 360) ≈ 0.6370702608`. (earlier draft had incorrect `0.6009` — do not regress.)

**Vignette math (center-black バグ回避):**
```
effectiveMask = mix(1.0, mask, applyMask)
vig = 1.0 - intensity * dist * dist * effectiveMask
color.rgb *= clamp(vig, 0.0, 1.0)
```
`applyMask=0` では原式 `1 - intensity * dist²` に collapse → assumed/fallback byte-identical 担保 (Stream 2 acceptance)。

---

## 3. Commit graph / branches / worktrees

### main 最新 10 commits (現在 `035486fb` at HEAD)

```
035486fb merge: Filmtone iOS v1.1 T1-T6 parity bundle            ← v1.1 merge commit
86186713 fix(filmtone-ios): vignette math + Xcode target wiring (release blockers)
903f9691 fix(filmtone): cap film grain intensity                  ← 別 stream の Desktop 側小 fix
57d22310 chore(filmtone-ios): point vignette ray-angle defaults to hiddenDefaults SSOT
8a951b5b merge(filmtone-ios): Stream 5 export sidecar + share chain (T2)
594a72c2 merge(filmtone-ios): Stream 3 HDR notice + optics UI (T1 UI + T5)
124cac0e merge(filmtone-ios): Stream 2 ray-angle optics wiring (T3)
0f208897 merge(filmtone-ios): Stream 4 contract guardrails (T6)
00c73ace feat(filmtone-ios): add export sidecar JSON + share chain (T2, Stream 5)
f379e42d feat(filmtone-ios): expand hidden defaults contract + wire verify tests (T6, Stream 4)
```

### 残置 branches (履歴として保持、worktree は全削除済)

```
main                                (tip: 035486fb)
filmtone-ios-v11-foundation         (tip: 86186713)   <- merge parent
filmtone-ios-v11-optics             (tip: c133877d)   <- Stream 2 feature
filmtone-ios-v11-ui                 (tip: c74a73ce)   <- Stream 3 feature
filmtone-ios-v11-contract           (tip: f379e42d)   <- Stream 4 feature
filmtone-ios-v11-sidecar            (tip: 00c73ace)   <- Stream 5 feature
```

v1.1 release を tag した後、5 feature branches は `git branch -d` で削除してよい (main に全 commit 到達済)。ただし user の memory feedback § worktree_vs_branch_preservation に従い、branch は履歴として残しても害はない。

### ⚠️ 重要: main clone の uncommitted WIP

**これは Desktop 側の別ストリームの進行中作業で、v1.1 iOS merge とは無関係。触ってはいけない。**

```
modified:   apps/desktop-film-lab-batch/electron/main.ts
modified:   apps/desktop-film-lab-batch/messages/en.json
modified:   apps/desktop-film-lab-batch/messages/ja.json
modified:   apps/desktop-film-lab-batch/src/renderer/App.tsx
modified:   apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.test.tsx
modified:   apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx
modified:   apps/desktop-film-lab-batch/test/golden.harness.ts
modified:   apps/desktop-film-lab-batch/test/golden.spec.ts
modified:   docs/filmtone-desktop-v1.0.3-qa-handoff-2026-04-24-jst.md
untracked:  apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts
untracked:  apps/desktop-film-lab-batch/src/renderer/effective-export-grade.ts
```

前 chat で検証時に "overlap 0" を確認済で merge 安全だった。v1.1 の release work (`apps/capacitor-film-lab-ios/` と fastlane) もこれらとは無関係。もし次 chat で `git stash` したい衝動があっても WIP を破壊しないこと。stash するなら必ず `git stash pop` 後の状態を確認する。

---

## 4. 検証ゲート (merge 後に全部再確認済)

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

# 1. Swift contract verify (includes 3 streams' test scripts)
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
# Expected output (all 4 groups):
#   Phase0 contract fixtures verified
#   ==> source-color-classifier test
#   Source color classifier + normalizer + HDR policy tests passed
#   ==> ray-angle optics test
#   Ray-angle optics tests passed
#   ==> sidecar builder test
#   Sidecar builder tests passed

# 2. Shared package TS tests
bun test packages/film-lab-core
# Expected: 110 pass / 0 fail / 505 expect()

# 3. Generator drift (iOS payload regeneration consistency)
bun run generate:filmtone-ios-swift --check
# Expected: exit 0, no output

# 4. Full Xcode build (requires bun install + Homebrew Ruby for cap:sync:ios)
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bun install --frozen-lockfile
bun run --cwd apps/capacitor-film-lab-ios build           # web build
bun run --cwd apps/capacitor-film-lab-ios cap:sync:ios    # sync to iOS
cd apps/capacitor-film-lab-ios/ios/App
xcodebuild -workspace App.xcworkspace -scheme App \
  -sdk iphonesimulator -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD "
# Expected: no error lines, final "** BUILD SUCCEEDED **"
```

---

## 5. Release 手順 (next chat の主作業)

### 5.0 Pre-flight

- [ ] **v1.0 が App Store 上で public release 済か確認** (ASC ダッシュボード)
  - 未公開なら v1.1 release 作業は保留
  - App Store Connect の submit + 自動 release 設定は v1.0 側で済み (`filmtone_ios_v1_0_submitted_for_review.md` 参照)
- [ ] 現在の main tip が `035486fb` であること
  - `cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio && git log -1 --oneline main`
- [ ] main clone の Desktop WIP が保持されていること (§3 の 11 file を破壊しない)

### 5.1 Version bump

iOS project の版管理は xcconfig inline:
- **MARKETING_VERSION**: `1.0` → `1.1` (Info.plist の `CFBundleShortVersionString` が参照)
- **CURRENT_PROJECT_VERSION**: `1` → `2` (または前 v1.0 の最終 build number + 1。初版なので 1 であるはず → 2 が妥当。ただし submit 時に ASC が拒否したら 3 以上にインクリメント)

編集箇所 (4 ヶ所、`apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`):
```
$ grep -n "MARKETING_VERSION = 1.0" apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
```
Debug 2 箇所 + Release 2 箇所 (App target + UI test target の Debug/Release 各) を一括置換。同時に `CURRENT_PROJECT_VERSION = 1` も同数箇所あるので揃える。

bun/Swift 側 `package.json` の `"version": "0.1.0"` は marketing とは別系で無関係、そのままでも可 (user 判断)。

### 5.2 Release notes

`apps/capacitor-film-lab-ios/fastlane/metadata/ja/release_notes.txt` / `en-US/release_notes.txt` を v1.1 用に書き換え。v1.0 既存文言:
- ja: "最初の公開版です。プリセット、Quick 3 軸、Camera Profile / Film Look の dual LUT、書き出し、写真への保存 / 共有を利用できます。"
- en-US: "Initial release with presets, Quick controls, dual LUT slots, export, and save/share to Photos."

v1.1 の文面方針 (user 承認必要):
- **ユーザーに見える主要 feature**: HDR source notice / optics UI label (metadata vs assumed) / export sidecar (AirDrop で media + JSON 2 items)
- **ユーザーに直接見えないが裏では効く**: 広角/望遠 metadata 付き iPhone クリップで vignette が光学的に正確化 / ray-angle 補正 / source video metadata DTO 整備 / HDR policy の transparency
- 「HDR 変換」「tone-map」等の断言は避ける (Stream 3 feedback: "必ず tone-map される" とは書かない)

ドラフト案 (ja):
> v1.1 は iPhone ソースの透明性アップデートです。HDR や広色域を含むクリップを読み込んだとき、iOS の書き出し処理の扱いを画面上で確認できます。カメラと光学メタデータを取り込み、対応クリップではビネット表現を光学的に正確化。書き出しには grade / preset / カメラ情報を含む sidecar JSON が同梱され、デスクトップ版との往復が容易になりました。

ドラフト案 (en-US):
> v1.1 brings source transparency to iPhone clips. HDR and wide-gamut sources now show an in-app notice so you can see how iOS will handle them. Camera and optics metadata flow into the vignette model for more physically accurate corner falloff on supported clips. Exports now include a sidecar JSON alongside the media, so the grade, preset, and camera context round-trip cleanly with the desktop app.

### 5.3 Screenshots

v1.0 の screenshots (ja + en-US 各 5 枚) は `apps/capacitor-film-lab-ios/fastlane/screenshots/` に staged 済。v1.1 で UI が実質変わるのは:
- HDR policy notice (HLG ソース import 時のみ表示)
- Camera optics label (export panel の MetricCard に追加)

v1.0 screenshot は SDR source で撮っているなら HDR notice は非表示のはずで、引き続き使える可能性が高い。ただし `FilmtoneExportPanel` の MetricCard 数が増えたので、export panel shot だけ撮り直しが望ましい。

選択肢:
1. **既存 screenshots を流用** (すぐ release 可能、ただし v1.1 新機能が image 上で見えない)
2. **`bun run release:screenshots` で全 11 枚再撮影** (v1.0 同様のデタミニスティック UI test 経由、所要時間 ~5 min、UI test が通ることが前提)
3. **export panel shot 1 枚だけ差し替え** (手動、fastlane 経由でなくても良い)

user 判断必要。1 で start → ASC reject があれば 2 へ回す運用を推奨。

### 5.4 Archive → TestFlight → AppStore

app-local scripts (from `apps/capacitor-film-lab-ios/RELEASE.md`):
```sh
cd apps/capacitor-film-lab-ios

# ASC API 認証環境変数 (user の shell に既設定の想定)
export ASC_KEY_ID=...
export ASC_ISSUER_ID=...
export ASC_KEY_PATH=...     # or ASC_KEY_CONTENT
export REVIEW_PHONE='+81-...'

# 1) Web shell build
bun run build

# 2) Archive (IPA 作成)
bun run release:archive
# writes build/fastlane/Filmtone.ipa

# 3) Screenshots (skip if §5.3 で 1 を選んだ)
bun run release:screenshots

# 4) Metadata upload
bun run release:metadata

# 5) TestFlight (optional, internal QA 用)
IPA_PATH=build/fastlane/Filmtone.ipa bun run release:beta

# 6) App Store 提出 (submit + 自動 release)
IPA_PATH=build/fastlane/Filmtone.ipa \
  SUBMIT_FOR_REVIEW=1 AUTOMATIC_RELEASE=1 \
  REVIEW_PHONE='+81-...' \
  bun run release:appstore
```

`SUBMIT_FOR_REVIEW` / `AUTOMATIC_RELEASE` を opt-out してドライラン (metadata / binary upload のみで review 未提出) も可能。user の好みで決める。

### 5.5 Git tagging + push

v1.0 の tag 運用は未確認 (portfolio の tag 一覧に `ios-v*` が無い)。候補:
- `ios-v1.1.0` (プラットフォーム prefix、v1.0 を同じ prefix で後付け tag するなら整合)
- `filmtone-ios-v1.1.0` (app 名 prefix、Desktop と分離)
- `v1.1.0-ios` (バージョン先頭)

user 確認。未定ならまず push だけして tag は user 指示を待つのが安全。

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
git push origin main
# tag は user 判断後:
# git tag -a filmtone-ios-v1.1.0 035486fb -m "Filmtone iOS v1.1 — metadata & sidecar parity"
# git push origin filmtone-ios-v1.1.0
```

ASC submit が成功した後に tag を打つパターンも安全 (失敗したら tag を打たずに bump やり直し)。

### 5.6 Post-release

- Life repo の memory `filmtone_ios_v1_1_T1_T6_landed.md` を "merged on main / pushed / tagged / released" に更新
- `filmtone-ios-v11-foundation / optics / ui / contract / sidecar` feature branches は merge 到達済なので `git branch -d` で削除可 (user 判断)
- 残作業 (§1 🟣) を Issue として起票

---

## 6. Infrastructure quirks (つまずきポイント)

### 6.1 `cap sync ios` は Homebrew Ruby が必須

System Ruby (`/usr/bin/ruby` 2.6) は `/Library/Ruby/Gems/2.6.0` の write 権限がなく fail する。回避:
```sh
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
```
これを付ければ `bun run cap:sync:ios` が green に。`RELEASE.md` でも `./scripts/bundle.sh` が Homebrew Ruby を prefer する設計になっている。

### 6.2 新 Swift files を iOS target に追加する時

`xcrun swiftc -typecheck` が通っても **Xcode Archive では silent exclusion** される。`project.pbxproj` の 4 section 全てに登録が必要:
1. `PBXBuildFile` section
2. `PBXFileReference` section
3. `PBXGroup children` (App group)
4. `PBXSourcesBuildPhase.files` (Sources build phase)

v1.1 で追加した 8 Swift files は commit `86186713` で登録済み。次回 v1.2 以降で同じ罠を踏まないよう、user memory `feedback_review_release_blockers_deep_pass.md` 参照。

### 6.3 worktree は `bun install` / `pod install` 非共有

`.worktrees/...` を作ると `node_modules` と `Pods/` は worktree ごとに fresh install が必要。`bun install --frozen-lockfile` で ~10s、`pod install` で ~15s。v1.1 Wave 2 で 4 並列 worktree それぞれで実行済。

### 6.4 `dist/index.d.ts` は tracked で merge conflict しやすい

`packages/film-lab-core/dist/index.d.ts` は tsup の生成物だが git 管理下。複数 branch で並行に再生成すると merge conflict を起こす。解決法:
```sh
git checkout --theirs packages/film-lab-core/dist/index.d.ts
bun run --cwd packages/film-lab-core build
git add packages/film-lab-core/dist/
```
v1.1 main merge でも同じ conflict を踏んだが、上記で resolve 済。

### 6.5 `verify-phase0-contract.sh` が呼ぶ Swift test scripts

`apps/capacitor-film-lab-ios/scripts/swift/` 配下の `*.swift` は host macOS 上で `xcrun swiftc` で compile + 実行される。iOS target ではなく host 想定のため、UIKit / CoreImage 依存させない。`FilmtoneExportSidecarBuilder.swift` は v1.1 で `SidecarDeviceIdentity` DI 化して UIKit 非依存にしてあるので再利用可能。

### 6.6 App Store Connect API 認証

v1.0 handoff (§3.3 of `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md`) で整備済。`ASC_KEY_ID` / `ASC_ISSUER_ID` / (`ASC_KEY_PATH` or `ASC_KEY_CONTENT`) が必須。user の shell に persist されているはず。

---

## 7. Critical file map

### iOS native (新規 v1.1)
- `apps/capacitor-film-lab-ios/ios/App/App/SourceColorMetadataNormalizer.swift` — CoreMedia token → ffprobe vocab
- `apps/capacitor-film-lab-ios/ios/App/App/SourceColorClassifier.swift` — 5-branch classify
- `apps/capacitor-film-lab-ios/ios/App/App/HdrPreparationPolicyDeriver.swift` — strategy mapping
- `apps/capacitor-film-lab-ios/ios/App/App/FormatExtensionReader.swift` — CFString + String key dual lookup
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRayAngleOptics.swift` — Desktop `rayAngleOptics.ts` port
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneHdrPolicyNotice.swift` — SwiftUI non-blocking notice
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCameraOpticsFormatter.swift` — probe label formatter
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift` — `filmtone-ios-export-session-v1` builder (UIKit 非依存 DI)

### iOS native (修正 v1.1)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift` — 7 new DTOs + backward-compat inits
- `apps/capacitor-film-lab-ios/ios/App/App/SourceProbeService.swift` — probeVideo 拡張
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift` — vignette kernel + sidecar hook in run()
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift` — `hdrPolicy` observable + shareOutput forward sidecarUri
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorFacade.swift` — `shareOutput(mediaURI:sidecarURI:)`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift` — result 再構築で sidecarUri 継承
- `apps/capacitor-film-lab-ios/ios/App/App/ShareSheetService.swift` — `share(fileURLs: [URL])`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift` — Capacitor bridge call site (fileURLs 対応)
- `apps/capacitor-film-lab-ios/ios/App/App/PhotoLibraryService.swift` — コメント追記のみ
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift` — HDR notice 挿入
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift` — Optics MetricCard
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePreviewView.swift` — previewMetaLabel に optics append
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift` — `FilmtonePhase0HiddenDefaults` struct
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift` — 再生成、hiddenDefaults block 含む
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift` — 11 新規 strings
- `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings` — jp/en 11 ペア
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` — 8 new Swift files 登録

### Contract / fixtures (v1.1)
- `apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift` — DTO mirror
- `apps/capacitor-film-lab-ios/scripts/swift/verify-phase0-contract.swift` — hidden defaults + HLG guards
- `apps/capacitor-film-lab-ios/scripts/swift/test-source-color-classifier.swift` (new) — 30+ assertions
- `apps/capacitor-film-lab-ios/scripts/swift/test-ray-angle-optics.swift` (new) — 7 assertion groups
- `apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift` (new) — schema / LUT / HDR checks
- `apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh` — 3 new test scripts wired
- `apps/capacitor-film-lab-ios/scripts/fixtures/phase0-contract/canonical-export-request.json` — SDR BT.709 example
- `apps/capacitor-film-lab-ios/scripts/fixtures/phase0-contract/hlg-export-request.json` (new) — HLG example

### Shared contract
- `packages/film-lab-core/src/presets.ts` — `CONTRACT_DEFAULTS` + `ContractDefaultKey` export 化
- `packages/film-lab-core/src/ios-swift-payload.ts` — `hiddenDefaults` emission + `CONTRACT_DEFAULT_KEY_ORDER`
- `packages/film-lab-core/src/ios-swift-payload.test.ts` — +5 tests (deep-equal / render block / key order / monotonic offset / override isolation)
- `packages/film-lab-core/src/native-bridge.ts` — `SourceProbe.sourceVideoMetadata?` + `Phase0ExportResult.sidecarUri?` + 6 new types
- `packages/film-lab-core/src/index.ts` — 6 new type re-exports

### Repo-level scripts
- `scripts/verify-ios.sh` — worktree 固定解除 + `generate:filmtone-ios-swift --check` as first step

### 関連 docs (read-only refs)
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md` (parent plan)
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/ios-v1.1-tasks/*.md` (T1–T10 task specs)
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-parity-gap-vs-desktop-v1.0.3-2026-04-24-jst.md` (gap analysis)
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md` (v1.0 release rail)
- `/Volumes/SamsungPortableSSDX5001/documents/life/.claude/plans/sorted-juggling-garden.md` (本 v1.1 実装計画 rev 3)

### Life memory references
- `~/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/filmtone_ios_v1_1_T1_T6_landed.md` — 最新 project memory
- `~/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/feedback_review_release_blockers_deep_pass.md` — Agent Teams 後の deep pass 教訓
- `~/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/fastlane_ios_first_release_bootstrap_pattern.md` — 初回 iOS release pattern (5 大罠)
- `~/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/ios_app_transfer_procedure.md` — ASC 関連 reference
- `~/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/chrome_mcp_react_managed_input_pattern.md` — ASC 操作で使える

---

## 8. Open questions / user decisions 必要

1. **v1.0 App Store public release のタイミング**: 既に公開済? 公開待ち?
2. **CURRENT_PROJECT_VERSION の bump 値**: 1 → 2 で OK か? 他ポリシーあるか?
3. **Release notes 文面**: 上記ドラフトで OK か、user が書き直すか?
4. **Screenshots**: (1) 流用 / (2) 全 11 枚再撮影 / (3) export panel のみ差し替え — どれか?
5. **Git tag 命名**: `ios-v1.1.0` / `filmtone-ios-v1.1.0` / `v1.1.0-ios` — どれか? v1.0 を同 prefix で遡って tag するか?
6. **ASC submit / auto-release**: `SUBMIT_FOR_REVIEW=1 AUTOMATIC_RELEASE=1` で自動運用、それとも手動提出?
7. **TestFlight 経由するか**: `release:beta` を先に通すか、直接 `release:appstore` へ行くか?
8. **Capacitor/WebView share path sidecar 対応**: v1.1 に入れる? follow-up v1.1.1 / v1.2 へ?
9. **5 feature branches (`filmtone-ios-v11-*`) の削除タイミング**: release 後すぐ? 一定期間保持?

---

## 9. Handoff prompt (次チャット頭に貼る想定)

---

### ≫ 次のチャット冒頭に貼るプロンプト ≪

以下を次チャットにそのままコピペしてください。

```
Filmtone iOS v1.1 を App Store に release する作業を進めます。

**必ず最初に読むドキュメント** (絶対パス、この順番で読む):

1. `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone-ios-v1.1-release-handoff-2026-04-25-jst.md`
   ← このハンドオフの正本。実装履歴・検証済み gate・release 手順・落とし穴・未決事項すべて記載
2. `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/RELEASE.md`
   ← fastlane lanes と env vars 運用
3. `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md`
   ← v1.0 release rail の歴史的記録 (同じ archive / submit パスを v1.1 で再利用)

**前提条件 (読む前に頭に入れる)**:

- リポ root: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- main tip は `035486fb merge: Filmtone iOS v1.1 T1-T6 parity bundle` (local-only、未 push)
- main clone の working tree に Desktop WIP (11 files) が uncommitted で残っている。**これは別 stream の進行中作業で触らない**。§3 の警告を必ず読む
- v1.0 は App Store Connect "Waiting for Review" 状態で submit 済 (2026-04-20 時点)。v1.0 が public release されるまで v1.1 の ASC submit / tag は待つ方針
- 実装・検証はすべて green 済。release 作業のみが残っている

**やることの優先順位**:

1. ハンドオフドキュメント §5 Pre-flight を確認:
   - `git log -1 --oneline main` で tip が `035486fb` であること
   - main の uncommitted WIP が保持されていること
   - v1.0 App Store 公開済か user に確認
2. ハンドオフドキュメント §8 の Open questions を user に聞く (version bump 値 / release notes 文面 / screenshots 戦略 / tag 命名 / submit オプション)
3. user 回答を受けて §5.1〜5.5 を順に実行
4. 全検証 (§4 のコマンド 4 本) を release 直前に再走らせて green 確認
5. ASC upload / submit / tag / push

**指示の哲学** (このユーザーの持論):

- 保守的な意見は優先しない、プロダクト品質を最優先
- 思考すべきところは sequential-thinking で考える
- わからないことがあれば gemini-search か web search で調査してから答える、記憶ベースの断言は禁止
- 独立して並列実行できるものは並列化する
- Agent Teams merge 後は必ず独立 deep pass を走らせる (shader math の dry run + pbxproj 4 section check + フル xcodebuild)。詳細は life memory `feedback_review_release_blockers_deep_pass.md`
- 日本語で最終出力、内部処理・agent prompt は英語でトークン節約
- Git 操作は user 承認のもとで実行、破壊的操作 (`push --force` / `reset --hard`) は絶対に許可なしで打たない

**やってはいけないこと**:

- Desktop WIP (`apps/desktop-film-lab-batch/` の uncommitted 11 file) に `git stash` や `git checkout --` を掛けない
- v1.0 が公開されていないまま v1.1 を ASC に submit しない (user に確認してから)
- Release notes / version / tag を user 承認なしに勝手に決めない
- 5 feature branches (`filmtone-ios-v11-*`) を release 完了前に削除しない

**最初の一手**:

ハンドオフドキュメント §0〜§9 を全文読んでから、§5 Pre-flight のチェック 3 項目を走らせ、結果を user に報告してください。それから §8 Open questions を user に 1 つずつ聞いてください。
```

---

## 10. この chat の締め

本 chat での成果物:
- v1.1 T1–T6 実装 (Wave 1 foundation → Wave 2 4-parallel Agent Teams → Wave 3 integration)
- 2 release blocker fix (vignette math / pbxproj target wiring)
- main への `--no-ff` merge commit `035486fb`
- 5 worktree 削除、5 feature branches 残置
- 本 handoff 文書 + life memory 2 entries (`filmtone_ios_v1_1_T1_T6_landed.md` / `feedback_review_release_blockers_deep_pass.md`)

次 chat はここから release に振り切って良い。
