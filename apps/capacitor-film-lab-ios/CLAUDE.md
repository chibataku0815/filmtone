# Filmtone iOS — Claude Code 協業ガイド

このファイルは `apps/capacitor-film-lab-ios/` 専用。リポ全体ルール(`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md`) と life 側方針 (`/Volumes/SamsungPortableSSDX5001/documents/life/CLAUDE.md`) はそのまま適用。ここはサブツリー固有の事項のみ。

陳腐化しやすい内容(現行 lane / 件数 / 進捗) は **書かない**。CLAUDE.md は invariant + pointer に絞る。

---

## 1. 運用原則(最優先)

| 原則 | 意味 |
|------|------|
| **本質優先 / 外殻最小** | 製品挙動を直接動かす変更(Swift native / UI wiring / sidecar / Profile / fastlane / shader) = 本質。XCTest 6 並列・formal QA 手順書・過剰 i18n 化・装飾 banner = 外殻。**user が「QA 希望」と明示した時のみ**着手 |
| **保守的ヘッジを優先しない** | 「念のため fallback」「安全側でスキップ」「v1.x 後回し」のような逃げを取らない |
| **思考は sequential-thinking** | 設計判断・lane 衝突・不変条件 gate 評価は `mcp__sequential-thinking`。記憶ベースで断言しない |
| **不確かなら検索** | API / ASC / Capacitor / iOS SDK が曖昧な場合は `gemini-search` → `WebSearch`。記憶ベース推測は `feedback_no_guessing_davinci_plugins` / `feedback_verify_before_documenting` 違反 |
| **handoff は鵜呑みにしない** | 旧 chat の handoff doc 引用前に現行 surface (`grep` / Swift / pbxproj) と突き合わせて live/frozen を確認 (`feedback_verify_before_quoting_handoff`) |
| **並列 stream の silent 縮退禁止** | 複数 chat / Agent Teams で stream を割った時、残タスク silent 省略 / lane の chat 独断 redefine は禁止。完了時 handoff §8.5 4 セクション(Plan Compliance / Cross-Stream Visibility / Scope Diff / 残タスク enumeration) を機構化 (`feedback_no_silent_stream_redefine`) |

---

## 2. アプリ identity

| 項目 | 値 |
|------|-----|
| Bundle ID | `com.chibatakumi.film.lab.ios` |
| TeamID | `C3G77H8NM6` |
| Workspace | `ios/App/App.xcworkspace`、Scheme `App` |
| Signing | Xcode automatic(`match` 不使用) |
| UI stack | **Native SwiftUI** (`FilmtoneRootView`)。React/Capacitor stack は 2026-05-09 に purge 済み(残骸なし) |

バージョンは Xcode build settings の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` から `Info.plist` に注入。**plist 直接編集禁止**。

---

## 3. Commit gate(全部 green になってから commit)

1. `xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO` が `** BUILD SUCCEEDED **`
2. Swift contract を触ったなら `bun run verify:swift-contract`(scripts/verify-phase0-contract.sh)が通る
3. 新規 `.swift` を追加したら `project.pbxproj` の **4 セクション** すべてに登録(`PBXBuildFile` / `PBXFileReference` / `PBXSourcesBuildPhase` / `PBXGroup`)。`grep '<新ファイル名>' ios/App/App.xcodeproj/project.pbxproj | wc -l` が 4 以上で OK
4. Agent Teams で複数 stream を merge した直後は **必ず独立 deep pass**(kernel math dry run + pbxproj 4-section grep + フル xcodebuild) — `feedback_review_release_blockers_deep_pass`

ユーザー承認なしの自動 commit / push 禁止(life CLAUDE.md §11)。

---

## 4. 不変条件(明示 gate なしに触らない)

| 項目 | 現行値 | 触る条件 |
|------|--------|----------|
| `Profile.version` | `5` | スキーマ追加 = bump、フィールド rename も bump。bump は CD と sidecar reader 両側を同一 commit で更新 |
| Sidecar | `V1` schema | フィールド追加は OK(reader が ignore する形に) / 型変更は V2 化が必要 |
| `hiddenDefaults`(例: `depthRayAngleGamma=1.4` / `innerThreshold=0.1`) | 既存値固定 | CD 承認 gate 通過時のみ。toggle ON でも視覚上 inert は許容 |
| `Info.plist` の `NSPhotoLibrary*UsageDescription` / `NSSupportsLiveActivities=true` / `ITSAppUsesNonExemptEncryption=false` | 現行通り | App Store 審査リジェクト直結。変更時は `RELEASE.md` と一緒に PR 説明に明記 |
| ASC API key 環境変数(`ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_CONTENT` or `ASC_KEY_PATH`) | ローカル shell 経由 | コミット禁止 |
| Snapshot 端末 | iPhone 17 Pro Max iOS 26.2 (UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`) | fastlane `screenshots` lane が決め打ち。**fallback / runtime discovery を足さない** |

---

## 5. コードマップ(grep で済む詳細は書かない)

- Swift 本体: `ios/App/App/*.swift`(export pipeline / depth / color-profile / Live Activity / optics / state / SwiftUI が同居)
- 自動生成: `FilmtonePhase0Generated.swift` は手動編集禁止
- 新ファイル追加時の pbxproj 4-section 登録は §3 Commit gate に従う

Built-in Look / Source Profile catalog の不変条件は `docs/builtin-catalog.md`。

---

## 6. Release rail

詳細は `RELEASE.md`(同ディレクトリ)。lane (`archive` / `screenshots` / `metadata` / `beta` / `release` / `submit_review`) は **fail-fast** に保つ:IPA を勝手に作らない、screenshots 数のミスマッチで通さない。CI 化しても同じ振る舞い。

---

## 7. 状況把握(陳腐化が速いので CLAUDE.md には書かない)

| 何を知りたい? | どこを見る |
|---------------|-----------|
| 公開バージョン / 進行中 lane / ASC submit 状況 | `/Volumes/SamsungPortableSSDX5001/documents/life/.claude/projects/.../memory/MEMORY.md` の "Active work" |
| 進行中ブランチ | `git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone branch -a \| grep filmtone-ios` |
| 直近 iOS タッチ commit | `git log --oneline -20 -- apps/capacitor-film-lab-ios/` |
| この PR の意図 | PR description + life `docs/guides/<date>-filmtone-ios-<topic>-handoff.md` |
| release/ios truth | life `scripts/check-filmtone-release-truth.sh` / `check-filmtone-ios-truth.sh` |

---

## 8. Handoff doc & 主要 pointer

| 用途 | パス |
|------|------|
| 直近 chat 引き継ぎ(feature 単位) | `docs/filmtone/ios/<topic>-handoff-<date>-jst.md`(filmtone repo) |
| 大きい lane 単位(PR 跨ぎ) | `docs/guides/<date>-filmtone-ios-<topic>-handoff.md`(filmtone repo) |
| 5 ロール俯瞰 / cross-repo | `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/<date>-filmtone-ios-<topic>-handoff.md` |
| 再利用パターン正本 | `/Volumes/SamsungPortableSSDX5001/documents/life/.claude/knowledge/patterns/` |
| リリース手順詳細 | `RELEASE.md`(同ディレクトリ) |
| v1.0 デバイスチェック | `IOS-DEVICE-CHECKLIST.md` |
| 5 ロールパネル / Agent Teams 起動 | `/Volumes/SamsungPortableSSDX5001/documents/life/.cursor/rules/life-planning-invocation.mdc` |

ファイル名は `YYYY-MM-DD-filmtone-ios-<topic>-handoff.md`(kebab-case、JST date)。chat 終了時 §8.5 4 セクションを必ず書く(`feedback_no_silent_stream_redefine`)。

---

## 9. このアプリ固有のアンチパターン

- **silent fallback パイプラインを足さない**(`feedback_no_fallback_bug_hotbed`) — primary→secondary 自動切替は silent degradation の温床。色域 / depth / mezzanine いずれも、外す条件は明示 fail で出す
- **handoff の機能言及を引用する前に live/frozen を確認**(`feedback_verify_before_quoting_handoff`) — 過去 chat の「実装済」が現行 surface で復活していることがある
- **JSX コメントを `return (` の直下に書かない**(`feedback_no_jsx_comment_outside_root_return`) — `Expected ',', got '<elementName>'`。コメントは関数 JSDoc か JSX 要素内に
- **Agent Teams 並列 merge 後は独立 deep pass**(`feedback_review_release_blockers_deep_pass`) — 並列 agent は shader math の dry run と pbxproj 登録は視野外
- **判断コストを細切れに押し付けない**(`feedback_minimize_decision_cost`) — ユーザー承認受領後は「commit + push + 次手」をまとめて出す
- **新 Settings ページや装飾 banner を本質より優先しない** — 既存 sheet / 既存 toast / 既存 i18n 文字列に乗せる方を先に検討
