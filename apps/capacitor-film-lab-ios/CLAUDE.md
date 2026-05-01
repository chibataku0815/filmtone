# Filmtone iOS — Claude Code 協業ガイド

このファイルは `apps/capacitor-film-lab-ios/` 専用。リポジトリ全体ルール（standalone リポ root の `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md`）と life 側の方針 (`/Volumes/SamsungPortableSSDX5001/documents/life/CLAUDE.md`) はそのまま適用される。ここでは **このサブツリーでしか必要にならないこと** だけを書く。

---

## 1. 運用原則（最優先）

| 原則 | 意味 |
|------|------|
| **本質優先 / 外殻最小** | 製品挙動を直接動かす変更（Swift native / UI wiring / sidecar / Profile / fastlane 本体）= 本質で着手。XCTest 6 並列・formal QA 手順書・過剰 i18n 化・装飾的 pre-banner = 外殻で **ユーザーが「QA 希望」と明示したときのみ**着手 |
| **保守的ヘッジを優先しない** | 「念のため fallback」「安全側でスキップ」「保守的に v1.2 後回し」みたいな逃げを優先しない。プロダクト品質に効く判断を取る |
| **思考は sequential-thinking** | 設計判断・lane 衝突・不変条件 gate 評価は `mcp__sequential-thinking` を使う。記憶ベースで断言しない |
| **不確かなら検索** | API / ASC / Capacitor / iOS SDK の挙動が曖昧な場合は `gemini-search` → `WebSearch` の順で確認してから書く。記憶ベースの推測は `feedback_no_guessing_davinci_plugins` / `feedback_verify_before_documenting` 違反 |
| **handoff は鵜呑みにしない** | 旧 chat の handoff doc を引用する前に、現行 surface (`grep` / Swift / pbxproj) と突き合わせて live/frozen を確認する (`feedback_verify_before_quoting_handoff`) |
| **並列 stream の silently 縮退禁止** | Agent Teams や複数 chat で stream を分割した場合、§3 残タスクの silent 省略・lane の chat 独断 redefine は禁止。完了時は handoff §8.5 4 セクション (Plan Compliance / Cross-Stream Visibility / Scope Diff / 残タスク enumeration) で機構化 (`feedback_no_silent_stream_redefine`) |

---

## 2. アプリ identity

| 項目 | 値 |
|------|-----|
| Bundle ID | `com.chibatakumi.film.lab.ios` |
| TeamID | `C3G77H8NM6` |
| Display Name | `Filmtone` |
| Workspace | `ios/App/App.xcworkspace` |
| Scheme | `App` |
| Signing | Xcode automatic（`match` 不使用） |
| Live Activities | 有効 (`NSSupportsLiveActivities=true`) |
| 暗号化申告 | 不要 (`ITSAppUsesNonExemptEncryption=false`) |
| Capacitor | `7.4.3` (`@capacitor/core` / `@capacitor/ios` / `@capacitor/cli`) |

バージョン番号は Xcode build settings の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` から `Info.plist` に注入される。直接 plist を書き換えない。

---

## 3. ビルド連鎖（canonical）

```sh
# 1. 依存
./scripts/bundle.sh install        # Homebrew Ruby + fastlane（初回 / Gemfile 変更時のみ）

# 2. Web shell（TS / React 変更時 OR Capacitor bridge 変更時）
bun run build                      # tsc --noEmit && vite build
bun run cap:sync:ios               # web 変更を ios/App/App/public へ反映 — Swift だけの変更ならスキップ可

# 3. ローカル検証（commit 前）
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO

bun test src/lib/phase0-state.test.ts   # Phase 0 の web 側 contract test
bun run verify:swift-contract           # ./scripts/verify-phase0-contract.sh

# 4. 出荷
bun run release:archive            # fastlane archive → build/fastlane/Filmtone.ipa
IPA_PATH=build/fastlane/Filmtone.ipa bun run release:beta       # TestFlight
IPA_PATH=build/fastlane/Filmtone.ipa REVIEW_PHONE='+81-...' bun run release:appstore  # ASC
```

**よくある事故**:
- Swift だけ書き換えて web 側を sync しないまま archive → Capacitor bridge 経由のメソッド名がずれてランタイムで崩れる。bridge を触ったら必ず `cap:sync:ios`。
- `cap sync` が `ios/App/App/public` を上書きするので、public 配下を手で編集しても次の sync で消える。

---

## 4. Commit gate（これら全部 green になってから commit）

1. `bun run build`（tsc --noEmit + vite build）が通る
2. `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` が `** BUILD SUCCEEDED **`
3. 該当する web 側テスト（Phase 0 を触ったなら `bun test src/lib/phase0-state.test.ts`）が通る
4. 新規 `.swift` を追加したら `project.pbxproj` の **4 セクション** すべてに登録されていること（`PBXBuildFile` / `PBXFileReference` / `PBXSourcesBuildPhase` / `PBXGroup`）。`grep '<新ファイル名>' ios/App/App.xcodeproj/project.pbxproj | wc -l` が 4 以上なら OK
5. Agent Teams で複数 stream をマージした直後は **必ず独立 deep pass**（kernel math の dry run + pbxproj 4-section grep + フル xcodebuild）— `feedback_review_release_blockers_deep_pass`

ユーザー承認なしに自動 commit / push しない（life CLAUDE.md §11）。

---

## 5. 不変条件（明示 gate なしに触らない）

| 項目 | 現行値 | 触る条件 |
|------|--------|----------|
| `Profile.version` | `4` | スキーマ追加 = bump、フィールド名 rename も bump。bump は CD と sidecar reader 両側を同一 commit で更新 |
| Sidecar | `V1` schema | フィールド追加は OK（reader が ignore する形に）／ 型変更は V2 化が必要 |
| `hiddenDefaults` (例: `depthRayAngleGamma=1.4` / `innerThreshold=0.1`) | 既存値固定 | CD（クリエイティブディレクター = ユーザー）承認 gate を通過した時だけ。toggle ON でも視覚上 inert は許容 |
| `Info.plist` の `NSPhotoLibrary*UsageDescription` / `NSSupportsLiveActivities` / `ITSAppUsesNonExemptEncryption` | 現行通り | App Store 審査リジェクト直結。変更時は `RELEASE.md` と一緒に PR 説明に明記 |
| ASC API key 環境変数 (`ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_CONTENT` or `ASC_KEY_PATH`) | ローカル shell 経由 | コミット禁止。`.gitignore` 化済を前提に動く |
| Snapshot 端末 | iPhone 17 Pro Max iOS 26.2 (UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`) | fastlane `screenshots` lane が決め打ち。fallback / runtime discovery を **足さない** |

---

## 6. Swift モジュール領域マップ（`ios/App/App/`）

| 領域 | 主要ファイル |
|------|--------------|
| Export pipeline | `FilmtoneExportSession.swift` / `FilmtoneExportSession+Cancelable.swift` / `FilmtoneExportSidecarBuilder.swift` / `FilmtoneExportNotification.swift` / `FilmtoneExportAttributes.swift` / `MezzanineService.swift` |
| Depth (still + video) | `DepthSourceService.swift` / `VideoDepthSourceService.swift` / `FilmtoneDepthMap.swift` / `FilmtoneDepthPrefilter.swift` |
| Color / Profile | `FilmtoneColorPipeline.swift` / `FilmtoneCubeParser.swift` / `SourceColorMetadataNormalizer.swift` / `SourceProbeService.swift` / `MezzanineColorProbe.swift` |
| Live Activity / Widget | `FilmtoneExportLiveActivity.swift` / `LockScreenView.swift` / `DynamicIslandViews.swift` / `CancelExportIntent.swift` |
| Optics math | `FilmtoneRayAngleOptics.swift` / `FilmtoneMotionBlurMath.swift` / `FilmtonePhase0Math.swift` |
| State / Storage | `FilmtoneEditorStore.swift` / `FilmtoneEditorFacade.swift` / `FilmtonePersistence.swift` / `CacheStore.swift` / `FilmtoneSnapshotSupport.swift` |
| Capacitor bridge | `FilmtoneBridgeViewController.swift` / `FilmtoneMediaPlugin.swift` / `FilmtoneMediaTypes.swift` / `FilmtoneMediaRuntime.swift` |
| UI (SwiftUI) | `FilmtoneRootView.swift` / `FilmtonePreviewView.swift` / `FilmtonePreviewPlayerView.swift` / `FilmtonePresetRow.swift` / `FilmtoneStrengthSheet.swift` / `FilmtoneHdrPolicyNotice.swift` / `FilmtoneExportPanel.swift` |
| Generated | `FilmtonePhase0Generated.swift` ← 手動編集禁止 |

新ファイル追加時は §4 の pbxproj 4-section 登録を必ず確認。

---

## 7. Capacitor plugin surface（`FilmtoneMediaPlugin`）

| メソッド | 役割 |
|---------|------|
| `pickSource` | フォトライブラリから写真/動画を選択 |
| `pickLutFile` | 3D LUT (.cube) ファイル選択 |
| `probeSource` | コーデック / 色域 / 解像度 / 尺の metadata 抽出 |
| `renderPreviewFrame` | 現在 state で 1 frame プレビュー生成 |
| `runExport` | 本書き出し（mezzanine / depth / sidecar 含む） |
| `saveToPhotos` | 出力をフォトライブラリへ書き戻し |
| `shareOutput` | 共有シート提示 |
| `cancelExport` | 進行中 export を停止 |
| `handleMemoryWarning` | メモリ圧迫時のキャッシュ放出 |

bridge を増やすときは TS 側 `src/native/filmtoneMedia.ts` と同時に PR を切る（片肺が一番事故る）。

---

## 8. Release rail（fastlane）

詳細は `RELEASE.md`。lane だけ列挙：

| lane | 用途 | 必須 env |
|------|------|---------|
| `archive` | App Store IPA を `build/fastlane/Filmtone.ipa` に作る | ASC API key 三点（任意でも自動署名は走るが headless 環境では必須） |
| `screenshots` | iPhone 17 Pro Max（決め打ち UDID）で UI test を走らせ ja / en-US の両ロケールにステージ | — |
| `metadata` | ASC へローカライズ済みメタデータを upload | ASC API key 三点 + `REVIEW_PHONE` |
| `beta` | 既存 IPA を TestFlight に upload | `IPA_PATH` + ASC API key 三点 |
| `release` | IPA + metadata + screenshots を ASC に upload。`SUBMIT_FOR_REVIEW=1` で審査提出、`AUTOMATIC_RELEASE=1` で承認後自動公開 | `IPA_PATH` + ASC API key 三点 + `REVIEW_PHONE` |
| `submit_review` | binary を触らずに審査提出のみ | `APP_VERSION` + `BUILD_NUMBER` |

`beta` / `release` は **fail-fast**: IPA を勝手に作らない、screenshots 数のミスマッチで通さない。CI 化するときも同じ振る舞いを保つ。

---

## 9. lane 状況の真実（current state）

CLAUDE.md には書かない（陳腐化が早すぎる）。以下を見る：

| 何を知りたい？ | どこを見る |
|---------------|-----------|
| 公開バージョン / 進行中 lane / ASC submit 状況 | `/Volumes/SamsungPortableSSDX5001/documents/life/.claude/projects/.../memory/MEMORY.md` の "Active work" セクション |
| 進行中ブランチ | `git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone branch -a \| grep filmtone-ios` |
| 直近 iOS タッチ commit | `git log --oneline -20 -- apps/capacitor-film-lab-ios/` |
| この PR の意図 | 該当 PR description + life `docs/guides/<date>-filmtone-ios-<topic>-handoff.md` |

---

## 10. Handoff doc の置き場

| repo | パス | 用途 |
|------|------|------|
| filmtone (standalone) | `docs/filmtone/ios/<topic>-handoff-<date>-jst.md` | 直近 chat 引き継ぎ（feature 単位） |
| filmtone (standalone) | `docs/guides/<date>-filmtone-ios-<topic>-handoff.md` | 大きい lane 単位（PR 跨ぎ） |
| life | `docs/guides/<date>-filmtone-ios-<topic>-handoff.md` | 5 ロール俯瞰の master plan / cross-repo 引き継ぎ |
| life | `.claude/knowledge/patterns/<date>-<pattern>.md` | 再利用可能な手順（fastlane 初回、ASC 譲渡、Capacitor cap sync 連携 等） |

ファイル名は `YYYY-MM-DD-filmtone-ios-<topic>-handoff.md`（kebab-case、JST date）。chat 終了時に handoff doc §8.5（Plan Compliance / Cross-Stream Visibility / Scope Diff / 残タスク enumeration）を必ず書く（`feedback_no_silent_stream_redefine`）。

---

## 11. このアプリ固有のアンチパターン

- **silent fallback パイプラインを足さない**（`feedback_no_fallback_bug_hotbed`）— primary→secondary 自動切替は silent degradation の温床。色域 / depth / mezzanine いずれも、外す条件は明示 fail で出す
- **handoff の機能言及を引用する前に live/frozen を確認**（`feedback_verify_before_quoting_handoff`）— 過去 chat の「実装済」が現行 surface で復活してることがある
- **JSX コメントを `return (` の直下に書かない**（`feedback_no_jsx_comment_outside_root_return`）— `Expected ',', got '<elementName>'`。コメントは関数 JSDoc か JSX 要素内に
- **Agent Teams 並列 merge 後は独立 deep pass**（`feedback_review_release_blockers_deep_pass`）— 並列 agent は shader math の dry run と pbxproj 登録は視野外。merge 後に kernel 境界値計算 + pbxproj 4-section grep + フル xcodebuild
- **判断コストを細切れに押し付けない**（`feedback_minimize_decision_cost`）— ユーザー承認受領後は「commit + push + 次手」をまとめて出す
- **新 Settings ページや装飾 banner を本質より優先しない** — 既存 sheet / 既存 toast / 既存 i18n 文字列に乗せる方を先に検討

---

## 12. 主要ファイル pointer

- リリース手順詳細: `RELEASE.md`（このディレクトリ）
- v1.0 出荷時のデバイスチェック手順: `IOS-DEVICE-CHECKLIST.md`
- リポジトリ全体ルール: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md`（standalone リポ root、2026-05-01 migration 後の正本）
- life 側方針: `/Volumes/SamsungPortableSSDX5001/documents/life/CLAUDE.md`
- 5 ロールパネル / Agent Teams 起動: `/Volumes/SamsungPortableSSDX5001/documents/life/.cursor/rules/life-planning-invocation.mdc`
- 直近 lane handoff の入口: `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/`（`grep -l filmtone-ios` で抽出）
- パターン正本: `/Volumes/SamsungPortableSSDX5001/documents/life/.claude/knowledge/patterns/`（fastlane 初回、ASC 譲渡、Capacitor 周り 等）

---

## 13. Built-in Catalog (v1.3+)

| 領域 | エントリ | 主要ファイル |
|------|---------|--------------|
| Built-in Looks | 5 件（Filmtone Signature / Clean Base / Amber Glow / Soft Blue / Night Soft） | `FilmtoneBuiltInCatalog.swift` |
| Source Profiles | 5 件（Apple Log / Apple Log 2 / V-Log / S-Log3 / Rec.709） | `FilmtoneSourceProfileCatalog.swift` |

### 不変条件

- Built-in Look の canonical UUID = `FB1A...` namespace（dedup key、library merge で参照）
- Built-in Look は `immutable: true`。ユーザー編集は新規 user look として保存され、built-in は不変
- Camera Profile catalog id 形式: `built-in:source-profile.<slug>`（例: `built-in:source-profile.v-log`）— sidecar `cameraProfile.catalogId` で書き出される
- Synthesized math (V-Log / S-Log3) は accuracy fixture (`max = 0.000`) が hard gate。spec 改訂時は fixture 再生成して PR 同梱

### UserDefaults

- お気に入り: key = `filmtone.builtinLookFavorites`（`Set<UUID>` シリアライズ）

### v1.4 候補 curve 追加

`.claude/knowledge/patterns/2026-04-30-source-profile-fixture-pipeline.md` 参照。Nikon N-Log / Canon Log 3 / BMD Film Gen 5 / ARRI LogC4 + bundled `.cube` 経路。

### Apple Log 2 known limitation

Rec.2020-matrix-as-approximation で動く（CD signed off via AskUserQuestion 2026-04-30）。v1.4 で AVFoundation native gamut info に refine 予定。
