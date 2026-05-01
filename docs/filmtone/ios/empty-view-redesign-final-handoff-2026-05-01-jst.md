# Filmtone iOS — Empty View 暫定 land 完了 + motion-dot 検討記録 (Chat 引き継ぎ)

- **作成**: 2026-05-01 JST
- **HEAD (land 完了時、未 commit)**: working tree dirty、CD 駆動 commit 待ち
- **目的**: 元 `FilmtoneEmptyView` (wordmark + tagline + amber/teal radial gradient) を CD 「チープ」却下 → 0 ベース再設計を motion-dot 統合で詰めるも architectural scope 過大 → CD 提供 symbol 画像 1 枚 + tagline 完全撤去という妥協案で land 完了。motion-dot 統合議論は本 chat 後の別 chat へ deferred

---

## 0. TL;DR (30 秒)

- Empty view の wordmark `Text("Filmtone")` + tagline `Text("カメラの色を、映画の色に")` を CD 提供 `filmtone-symbol01.png` (1024×1024 RGBA) 1 枚に置換
- `tagline` プロパティ + `filmtone.tagline` 初期化を `FilmtoneStrings.swift` から完全撤去 (`Localizable.xcstrings` に該当 key は元々未登録、再 introduce 防止)
- 既存の amber/teal 多重 radial gradient + scrim 背景を撤去 → near-black + 微弱 center vignette のみに縮約
- saved Looks teaser (≥1 件) / CTA 2 button (Photo Library `.glassProminent` / Files `.glass`) は touch なし、既存配線維持
- simulator BUILD SUCCEEDED 確認、CD 視覚 gate (実機) は CD 駆動
- motion-dot (portfolio の WebGPU metaball SDF + film post-pass) 統合は **次 chat 議論**

---

## 1. land した変更 (atomic、本 chat 1 commit 想定)

| ファイル | 編集内容 |
|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/Assets.xcassets/FilmtoneSymbol01.imageset/` | 新規 dir、`/Users/chibatakumi/Downloads/filmtone-symbol01.png` を `filmtone-symbol01.png` として配置 + universal idiom の `Contents.json` 作成。pbxproj 4-section 登録 **不要** (Assets.xcassets folder reference で自動 discovery) |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptyView.swift` | 全面書き直し: `backgroundLayer` を Color.black + 単一 RadialGradient (white 0.04 → black 0.45) に縮約 / `scrimLayer` 削除 / `wordmarkBlock` 削除 / `symbolHero` (`Image("FilmtoneSymbol01")`, 220pt sq, contentMode .fit) 新規 / accessibility ID `filmtone.empty.title` `filmtone.empty.hint` 削除、`filmtone.empty.symbol` 新規 |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift` | line 49 `let tagline: String` 削除 / line 634-640 の `tagline = filmtoneLocalized("filmtone.tagline", ...)` 初期化 block 削除 |
| `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings` | touch なし (元々 `filmtone.tagline` key は未登録、`filmtoneLocalized` の defaultValue fallback で動いていただけ) |

`FilmtoneRootView.swift` は touch なし — `FilmtoneEmptyView(... onPickWithLook: ...)` callback signature 不変、`pendingLookOnPickComplete` (line 21 + line 96-106 auto-apply) も維持。

---

## 2. CD 却下 → motion-dot 検討 → 妥協案 land の経緯

### 2.1 元実装 (前 chat land、CD 却下)

```
hero gradient (amber/teal/black 3-layer radial)
  + scrim (black 0.18 → 0.62 linear)
  + wordmark Text("Filmtone") .system(size:44, weight:.semibold) tracking 2
  + tagline Text("カメラの色を、映画の色に。")
  + (≥1 件で) Saved Looks teaser
  + CTA 2 button
```

CD コメント:

> 最初の画面に Filmtone, カメラの色を映画の色に のようなチープな見せ方をするのはやめてください。ちゃんと考えたいです

### 2.2 0 ベース再設計の方向性提示 (CD 「どれもしょぼい」却下)

sequential-thinking + WebSearch (Lightroom mobile / Halide / Darkroom / RNI Films / VSCO / Apple Liquid Glass HIG) で詰めた 3 方向:

1. **Curated Reel (単一 CTA)**: graded photo の Ken Burns crossfade 3-5 枚 substrate + glass CTA 1 個
2. **Studio (graded substrate + Look chips)**: 単一 graded photo 静止 + 横スクロール glass chip strip (typographic) + tap で Look pre-arm + picker
3. **Showcase (per-Look thumbnail tiles)**: 暗 substrate + 2×N grid の Look tile (bundled = pre-rendered ref / saved = generic backdrop+name)

CD 判定:

> どれもしょぼいですね

3 案共通の失敗モード = 「graded substrate + UI を上に置く = wallpaper + button」 のパターンから出ていない、craft の重みが表現されていない。

### 2.3 motion-dot 統合検討 (CD 「B (craft signal) が近い、motion-dot 使えませんか」)

CD 提示の portfolio package (`/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/packages/motion-dot/`):

- WebGPU + WGSL ベース metaball SDF + 16 シーン (Orbit / Grid Fluid / River Flow / Magnet / Mitosis / Pendulum Wave / Ripple / Flock / DNA Helix / Phase Transition / Firefly Sync / Molecular / Chain / Living Typography / Fluid GPU)
- film post-pass 内蔵 (bloom / grain / chromatic aberration / vignette)
- kinetic handoff API (particle 雲分散 → 再形成 transition)
- TypeScript / verbatim transplant 済 (handoff doc: `chibatakumi-portfolio/docs/renewal-2026/motion-dot-transplant-handoff-2026-04-26.md`)

iOS 統合の architectural 選択肢を提示:

| 選択肢 | 内容 | 判定 |
|---|---|---|
| 1. WKWebView 埋め込み | SwiftUI empty view 内に WKWebView host、minimal HTML が motion-dot を mount、bridge で picker 呼出。kinetic handoff 含む | scope 過大 (bridge 配線 + cold launch 500ms+ overhead + SwiftUI Liquid Glass が WebView 内容を refract substrate にできない) |
| 2. Metal native port | WGSL metaball SDF + post-pass を MSL に port、SwiftUI MTKView で host | 数週間規模 rebuild、本質優先/外殻最小に違反 |
| 3. pre-rendered video loop | motion-dot を web で 30s ProRes 録画 → bundle 同梱 → AVPlayer 再生 | kinetic handoff 失われる、bundle 15-30MB |
| 4. film-lab-renderer 拡張 | 既存 LUT renderer に metaball scene 増設 | renderer 責務膨張、film-lab-renderer architecture が motion-dot 16 scene を取り込めるか要調査 |

CD 判定:

> ダメそうですね、では現状でテキストの部分にロゴを一旦の妥協案として入れましょう

→ motion-dot 統合は **本 chat scope 外**、別 chat で再開

### 2.4 妥協案 land (本 chat の最終判断)

CD 確認:
- 使用 asset = CD が `/Users/chibatakumi/Downloads/filmtone-symbol01.png` を提供 (1024×1024 RGBA、Liquid Glass aesthetic そのものの hexagonal translucent glass form)
- tagline = **必要なし** (CD 「そもそもお前が勝手につけただけだし、意味わからんし」 — 前 chat が無断追加した文字列、根絶対象)

land 完了 (本 doc §1 参照)。

---

## 3. 検証結果

### 3.1 simulator build

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
```

→ `** BUILD SUCCEEDED **`

### 3.2 tagline 撤去確認

```bash
grep -rn "tagline" .../FilmtoneStrings.swift .../FilmtoneEmptyView.swift
# → FilmtoneEmptyView.swift line 3-4 の doc comment のみ (削除決定の記録、tagline 文字列の存在ではない)

grep -c "tagline" .../Localizable.xcstrings
# → 0
```

### 3.3 accessibility ID

```
filmtone.empty
filmtone.empty.symbol      ← 新規
filmtone.empty.savedLooks
filmtone.empty.photoLibrary
filmtone.empty.files
```

旧 `filmtone.empty.title` / `filmtone.empty.hint` は撤去済。XCUITest snapshot suite が依存している場合は次サイクルで identifier alias 更新 (本 land では未対応 — CD 「QA 希望」明示時マターと整合、`feedback_review_release_blockers_deep_pass`)。

### 3.4 SourceKit cross-file diagnostics

実装中、`FilmtoneEmptyView.swift` / `FilmtoneStrings.swift` で `Cannot find type 'FilmtoneEditorStore'` 等の SourceKit warning が複数出力。**いずれも cross-file LSP resolution 起因**で xcodebuild は green、無害。次 chat で SourceKit indexing が走り直せば解消する。

### 3.5 CD 視覚 gate (CD 駆動、未実施)

iPhone 17 Pro Max iOS 26.2 (UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192` / 実機 `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`):

- [ ] empty view 中央に symbol 画像 (~220pt) が表示
- [ ] 背景は near-black + 微弱 center vignette、amber/teal 跡無し
- [ ] wordmark / tagline 不在
- [ ] saved Looks teaser (≥1 件) / CTA 2 button が既往動作
- [ ] CTA tap → photo picker / files picker → fullscreen editor transition
- [ ] saved Look chip tap → photo picker → 素材ロード後 auto-apply (`pendingLookOnPickComplete`)

---

## 4. 残タスク (次 chat)

### 4.1 motion-dot 統合 (architectural 選択肢の再評価)

empty view を「生きた craft surface」にする方針は **未着手**。次 chat で以下を改めて評価:

1. **WKWebView 埋め込み再評価** — kinetic handoff (素材ロード時の particle 散逸 → reveal) が成立し、cold launch overhead が許容できるかは prototype で実測する
2. **pre-rendered video loop** — motion-dot を `bun run dev` で起動 → screen recording で 30s ProRes/H.265 化 → AVPlayer + AVPlayerLayer で SwiftUI に host。glass refraction substrate として機能するか、bundle bloat 許容か、loop seam が見えないかを評価
3. **`film-lab-renderer` 拡張** — `packages/film-lab-renderer/` の WGSL pipeline に metaball pass を mountable scene として注入、empty view 時はその scene、source ロード時 LUT scene へ kinetic handoff。film-lab-renderer の責務拡大を許容するかは要 architecture review
4. **Metal native port** — 数週間規模、本 cycle scope 外で確定

判断 input が CD から得られた段階で再開。

### 4.2 XCUITest 復旧 (CD「QA 希望」明示時)

旧 accessibility ID `filmtone.empty.title` / `filmtone.empty.hint` を依存している snapshot suite がある場合、`filmtone.empty.symbol` への alias 移植 + tagline テキスト assertion 削除。本 land では未対応。

### 4.3 `FilmtoneStrings.appName` の用途整理 (低優先)

現 land 後、`appName` は `FilmtoneEmptyView.symbolHero.accessibilityLabel` のみで使用。他 UI 表面で `appName` を出していなければ撤去候補だが、Onboarding / fastlane metadata / Localizable string export 経路で使われている可能性があるため touch しない。

---

## 5. 不変条件 reminder (次 chat でも遵守)

| 項目 | 値 |
|---|---|
| `Profile.version` | 4 固定 |
| `FilmtoneEditorStore` API | 既存のみ (新 method 追加禁止) |
| Capacitor bridge | 触らない |
| `FilmtonePhase0Generated.swift` | 編集禁止 |
| amber chrome | 再導入禁止 (content semantic = Look 識別 / warn 等は維持) |
| `#available(iOS 26.0, *)` | 再導入禁止 |
| pbxproj 4-section 登録 | Assets.xcassets imageset は不要、Swift 新規 file は必要 |
| sheet bg | `.presentationBackground(.thinMaterial)` のみ |
| bun 必須 (`npm` 禁止) | |
| Git 操作 | user 駆動 (auto commit / push 禁止) |

---

## 6. 引き継ぎプロンプト (次 chat 起動時に貼る)

```
あなたは Filmtone iOS (iOS 26.0 deployment / SwiftUI / Capacitor 7.4.3 /
`com.chibatakumi.film.lab.ios`) の Liquid Glass UI 担当です。

直前 chat で empty view の妥協案 (CD 提供 symbol 画像 + tagline 完全撤去) を
land 済 (working tree dirty、CD 駆動 commit 待ち)。次サイクルで motion-dot
(portfolio の WebGPU metaball SDF + film post-pass) を empty view に統合する
architectural 選択肢を再評価する。

# 必読 (順番厳守)

1. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md
2. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/CLAUDE.md
3. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/empty-view-redesign-final-handoff-2026-05-01-jst.md (本ファイル)
4. /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/renewal-2026/motion-dot-transplant-handoff-2026-04-26.md
5. /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/packages/motion-dot/src/main.ts

# あなたが守ること

- 本質優先 / 外殻最小、保守的ヘッジ優先しない
- 設計判断は mcp__sequential-thinking、不確かなら gemini-search → WebSearch
- handoff 機能言及を引用前に grep / Swift / pbxproj で live/frozen 確認
- 自動 commit / push 禁止、bun 必須、出力は日本語

# 残タスク (本 doc §4)

1. motion-dot 統合 architectural 選択肢の再評価 (WKWebView / pre-rendered video / film-lab-renderer 拡張 / Metal port)
2. XCUITest accessibility ID 復旧 (CD 「QA 希望」明示時)

# まず最初にやること

1. git status で working tree 確認 (本 chat の land が commit 済か未 commit か)
2. 本 handoff doc + portfolio motion-dot doc + main.ts (668 行) を Read
3. sequential-thinking で「motion-dot を Filmtone iOS empty view に統合する最小 viable な path」を 6-10 thought で詰める
4. CD に統合方針 (WKWebView prototype / pre-rendered video / 拡張 renderer のいずれか) を提示、選択を仰ぐ
```

---

## 7. 完了サイン

- [x] symbol asset (`FilmtoneSymbol01.imageset/`) Assets.xcassets に取り込み完了
- [x] `FilmtoneEmptyView.swift` 全面書き直し (wordmark + tagline 削除 / symbol hero 追加 / 背景縮約)
- [x] `FilmtoneStrings.swift` から `tagline` プロパティ + 初期化 block 削除
- [x] `Localizable.xcstrings` に `filmtone.tagline` key が無いことを確認
- [x] simulator build green
- [x] tagline grep 0 件 (Swift / Localizable)
- [x] accessibility ID 整合 (`filmtone.empty.symbol` 新規、旧 title/hint 撤去)
- [x] handoff doc 作成 (本ファイル)
- [ ] CD 駆動 commit + push
- [ ] CD 視覚 gate (実機 iPhone 17 Pro Max iOS 26.2)
- [ ] 次 chat 起動 (motion-dot 統合議論)

---

## 8. §8.5 機構化 (`feedback_no_silent_stream_redefine`)

### Plan Compliance

Plan SSoT: `/Users/chibatakumi/.claude/plans/filmtone-ios-ios-frolicking-rabin.md`

| Plan step | Chat 結果 |
|---|---|
| Step 1: Asset import | ✅ `FilmtoneSymbol01.imageset/` 作成、`Contents.json` 配置、`filmtone-symbol01.png` cp |
| Step 2: `FilmtoneEmptyView.swift` 書き直し | ✅ 全面書き直し、`backgroundLayer` 縮約 / `scrimLayer` 削除 / `wordmarkBlock` 削除 / `symbolHero` 新規 |
| Step 3: `FilmtoneStrings.swift` から tagline 撤去 | ✅ プロパティ + 初期化 block 削除 |
| Step 4: `Localizable.xcstrings` から `filmtone.tagline` key 撤去 | ✅ 元々未登録のため no-op (確認のみ) |
| Step 5: `FilmtoneRootView` 配線確認 | ✅ touch なし、callback signature 不変 |
| Step 6: 検証 | ✅ simulator build SUCCEEDED + tagline grep 0 + accessibility ID sanity |

Plan 通り完遂、scope diff なし。

### Cross-Stream Visibility

本 chat は単 chat 直線実装、並列 stream なし。次 chat (motion-dot 統合) も単 chat 直線想定。Agent Teams は使用せず。

### Scope Diff (plan からの差分)

なし。Plan §確定方針 5 項を 1:1 で実装。

### 残タスク enumeration

§4 参照。motion-dot 統合 (next chat) + XCUITest 復旧 (CD 「QA 希望」明示時)。
