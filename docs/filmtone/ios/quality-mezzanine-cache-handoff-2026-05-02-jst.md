# Filmtone iOS — Quality Mezzanine Cache + Worktree 整理 Handoff (2026-05-02 JST)

> 本文書は単一 chat の引き継ぎを目的とする。新規 chat はこのドキュメントだけ読めば文脈を完全に復元でき、最終 §16 の「引き継ぎプロンプト」をそのまま貼って続行できる。

---

## 1. メタ情報

| 項目 | 値 |
|---|---|
| 作成日 | 2026-05-02 (JST) |
| 直前 chat 終了時 HEAD | `739d94b feat(ios): add Canon Log 3 + Cinema Gamut source profile` (main) |
| origin/main からの ahead | 3 commits (`739d94b` / `fd1f512` / `0fc5141`) |
| working tree | clean (`docs/filmtone/ios/2026-05-02-ios-source-profile-dlog-m-osmo-pocket-3-handoff-jst.md` のみ untracked、本件無関係) |
| 関連 plan file | `~/.claude/plans/ios-ux-enumerated-pebble.md` (本 chat で書いた実装計画、approved 済) |
| Filmtone repo | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` |
| iOS subtree | `apps/capacitor-film-lab-ios/` |
| per-app guide | `apps/capacitor-film-lab-ios/CLAUDE.md` (223 行、必読) |
| repo root guide | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md` |
| user global rules | `/Users/chibatakumi/.claude/CLAUDE.md` (bun 必須 / gemini-search 優先 / 内部英語・最終出力日本語) |

---

## 2. 本 chat の起点 (user 要望)

```
ios 版の改善をしたいです
重い素材のキャッシュ対応について議論しましょう
デスクトップ版は読み込み時に生成したキャッシュを書き出し時にも流用することでUXを高めています
この構造をiosでも実現できるか調査してください

本質の進行を最優先にして、外殻は最小限全てがうまく行った時の品質保証したい時にのみに行う
保守的な意見は優先せずにプロダクトの品質を最優先してください
思考すべきところは必ずsequential-thinkingで考えてください
わからないことがある場合は、検索して調査・質問してください、検索はgeminiかweb searchを使用しましょう
```

加えて user の **不変原則** (life CLAUDE.md / per-app CLAUDE.md より):
- 本質優先 / 外殻最小 — XCTest 6 並列・formal QA 手順書・装飾的 banner は外殻、user 明示要求時のみ
- 保守的ヘッジを優先しない — 「念のため fallback」「v1.x 後回し」のような逃げを避ける
- Silent fallback 禁止 (`feedback_no_fallback_bug_hotbed`) — 色域 / depth / mezzanine いずれも explicit fail
- Handoff 鵜呑み禁止 (`feedback_verify_before_quoting_handoff`) — 現行 surface (grep / Swift / pbxproj) と必ず突き合わせ
- bun 必須、npm 禁止
- Git 操作は user が行う (CLAUDE.md §3 Filmtone repo root)。本 chat では user が明示指示した場合のみ commit / merge を実行

---

## 3. 設計判断 (user 確認済)

本 chat 中の 2 つの AskUserQuestion で確定:

### Q1: 「重い素材のキャッシュ対応」で iOS UX に最も効かせたい対象は?
**選択: 動画 (mezzanine 容量拡張 + quality 流用検討)**

その他選択肢 (deselect 済):
- 静止画 (decoded source cache 新設)
- 両方
- preview→export paint-once 全形式再設計

### Q2: Quality モードの動画 export に高品質 mezzanine 再利用を導入するか?
**選択: 高品質 mezzanine variant を新設して Quality でも流用**

その他選択肢 (deselect 済):
- 現状維持 (Quality は source-direct のまま)
- user 設定で切替可能にする

---

## 4. 調査結果 (デスクトップ vs iOS、最終確定)

### デスクトップ側 cache 構造

| 層 | 種別 | 保存場所 | キー | LRU | export 流用 |
|---|---|---|---|---|---|
| Proxy | 低解像度 H.264 MP4 (1280px 幅) | `app.getPath('sessionData')/film-lab-batch/proxy-cache` (disk 永続) | SHA256 (sourceSig × proxyProfile) | 14 日 / 容量上限 | ✅ |
| Mezzanine | FHD ProRes 422 中間 | renderer state `mezzaninePath` (session) + tmp | 無 (生成時刻) | session 終了で破棄 | ✅ (`precomputedMezzaninePath`) |
| Thumbnail | 1 枚 JPEG | `os.tmpdir()` | 無 (random hex) | session 内 | ❌ |

主要ファイル:
- `apps/desktop-film-lab-batch/electron/proxy-cache.ts:201-216` — `buildProxyCacheKey`
- `apps/desktop-film-lab-batch/electron/proxy-cache.ts:257-319` — `pruneProxyCache`
- `apps/desktop-film-lab-batch/electron/main.ts:2165-2175` — import 時 cache key 判定
- `apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts:196-722` — mezzanine state
- `apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts:563-600` — export 時 `precomputedMezzaninePath` 再利用

### iOS 側 cache 現状 (本実装前)

| 層 | 種別 | 保存場所 | キー | cap | export 流用 |
|---|---|---|---|---|---|
| sources | source asset の copy | `Library/Caches/FilmtonePhase0/sources/` | UUID | LRU (keepOnlyProtected) | source-of-truth |
| mezzanine | SDR/HDR FHD H.264 / HEVC10 | 同 `mezzanine/` | SHA256 (path/size/mtime/duration/profile/depthEnabled) | 1GB / 4 entries | ✅ Speed のみ |
| previews | renderPreviewFrame 出力 JPG | 同 `previews/` | 任意 | 64MB / 24h | - |
| luts | .cube import copy | 同 `luts/` | filename | 20MB / 30d | - |
| exports | 完成出力 (before save) | 同 `exports/` | UUID | 完了で削除 | - |
| 静止画 decoded source | **無** | - | - | - | ❌ (毎回 `CIImage(contentsOf:)` で fresh decode) |
| Tone descriptor | 統計 | `SourceProbeDTO` (JS state) | source URI | session | ✅ |
| Synthesized LUT | 3D LUT | NSCache (`FilmtoneExportSession.swift:2533`) | hash | NSCache 自動 | ✅ |

**ギャップ判定**:
1. 動画 mezzanine: **構造は揃っている**。Speed モードは流用済、Quality は意図的に source-direct (`FilmtoneExportSession.swift:2741-2789` の load-bearing comment「Quality/Master is the product-truth export path and must match the live preview source」)
2. 動画 mezzanine cap: **小さい** (1GB/4) → batch import で hit しにくい
3. 静止画 decoded cache: **構造ごと欠損**。preview slider 操作と final export で同じ HEIC を毎回フル decode (`FilmtoneExportSession.swift:2398-2400`、call sites L884/L1000)
4. `ciContext.clearCaches()` が preview/export 完了で毎回走る (`FilmtoneExportSession.swift:169, 184`) → CI 内部 LRU は session 跨ぎで温まらない設計

本 chat ではユーザー判断により **動画側 (gap 1+2)** を優先実装した。**静止画 decoded cache (gap 3) は別 lane に持ち越し**。

---

## 5. 実装内容 (commit `739d94b` に bundle 済)

### 5.1 コミット情報

```
SHA: 739d94b8c6e71a5c3d7294131485ad61e1130b2f
Author: chibataku0815 <chiba@fores-tone.co.jp>
Date: Sat May 2 15:35:21 2026 +0900
Subject: feat(ios): add Canon Log 3 + Cinema Gamut source profile
```

**重要**: commit subject は Canon Log 3 だが、user の判断で本 chat の mezzanine cache work も同 commit に bundle されている (Canon Log 3 と並行で user が編集していたため)。bundle 内容:

| 編集領域 | 由来 | 中身 |
|---|---|---|
| Canon Log 3 + Cinema Gamut source profile | user の並行 work | `FilmtoneSourceProfileMath.makeCanonLog3CineGamutToRec709Cube` 等、新規 fixture / 新規 docs / 新規 .swift test fixture / TS shell |
| Quality Mezzanine Cache (本 chat) | この chat の私の実装 | 下記 §5.2 の 6 ファイル変更 |

### 5.2 本 chat 由来の変更 (6 ファイル)

#### (A) `apps/capacitor-film-lab-ios/ios/App/App/MezzanineService.swift`

- `ProfileVariant` enum に `qualitySDR` / `qualityHDR` 追加
- `Profile.version` を `4` → `5` に bump (既存 cache を一斉 invalidate)
- `Limits.maxBytes` を `1_073_741_824` (1GB) → `4_294_967_296` (4GB) に拡張
- `Limits.maxEntries` を `4` → `16` に拡張
- `Profile` に helper 追加:
  - `var isHDR: Bool` (10-bit BT.2020/HLG 出力か)
  - `var preservesSourceResolution: Bool` (quality variants は true)
  - `func outputSize(forTrack:)` (quality は source-res、preview-grade は longEdge scale)
  - `func effectiveBitrate(forOutputSize:)` (quality は base bitrate × min(1.0, area/4K_area)、floor 2 Mbps)
- `Profile.qualitySDR`: HEVC Main, longEdge=0 (sentinel for source-res), bitrate=80_000_000 (4K base)
- `Profile.qualityHDR`: HEVC Main10, longEdge=0, bitrate=120_000_000 (4K base)
- `generateSync` を helper を使う形に refactor、`profileLevel` を codec/isHDR で computed

#### (B) `apps/capacitor-film-lab-ios/ios/App/App/SourceColorClassifier.swift`

`FilmtoneMezzanineRoutePolicy` を以下に拡張:
- `Variant` enum に `qualitySDR` / `qualityHDR` 追加
- `static let qualityBitrateThreshold: Double = 100_000_000` (100 Mbps、quality variant 生成の閾値)
- `static func qualityPrewarmVariant(for: codecFamily: estimatedDataRate:) -> Variant?` 新設
  - 強条件: ProRes 系 (`prores422`, `prores4444`, `proresRaw`) → 必ず生成
  - 中条件: estimatedDataRate ≥ 100 Mbps → 生成
  - 上記以外 (典型的 iPhone HEVC ~50 Mbps): nil 返す → Quality export は source-direct 維持
- `selectedVariant(...)` に optional 引数 `hasQualityHDRMezzanine` / `hasQualitySDRMezzanine` (default false で既存 caller と互換)
- Quality 分岐追加: 重い source で quality mezzanine 完成済なら使う、無ければ nil → caller が source-direct fallback
- `qualityVariantPreference(for:)` private helper 新設
- `isHeavyCodec(_:)` private helper 新設 (prores422/prores4444/proresRaw を true)

#### (C) `apps/capacitor-film-lab-ios/ios/App/App/MezzanineColorProbe.swift`

- `static func qualityPrewarmVariant(track: AVAssetTrack) -> ProfileVariant?` 新設
- `static func qualityPrewarmVariant(sourceURL: URL) -> ProfileVariant?` 新設 (URL → AVURLAsset → track)
- `private static func codecFamily(for track: AVAssetTrack) -> SourceCodecFamilyDTO?` 新設
- `private static func fourCCString(_ value: FourCharCode) -> String` 新設 (SourceProbeService と同じロジック、DRY 違反だが scope 最小)
- `profileVariant(for:)` に `case .qualitySDR` / `.qualityHDR` 追加

#### (D) `apps/capacitor-film-lab-ios/ios/App/App/AssetPickerService.swift`

`kickOffMezzanine(for sourceURL:)` を拡張:
- preview-grade prewarm (既存) と quality-grade prewarm (新規) を **別 Task** で双方 kick
- quality 側は `MezzanineColorProbe.qualityPrewarmVariant(sourceURL:)` が nil 返す source (典型 iPhone HEVC) では生成 task を立てない

#### (E) `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`

- `resolvedVideoSourceURL()` (`:2741-2789` 旧 → 新 routing):
  - 旧: `guard request.renderMode == .speed else { return sourceURL }` で Quality を即 source-direct
  - 新: 4 variant (sdr/hdr/qualitySDR/qualityHDR) すべて `existingMezzanineURL` で確認、policy `selectedVariant` に委譲
  - Speed → preview-grade variant、Quality → quality-grade variant、policy nil → source-direct fallback (transparent)
  - debug log 文言を `Speed gate:` から `Mezzanine routing:` に統一
- `exportVideo` の `didUseMezzanineVariant` 検出 (`:472-491` 旧 → 新):
  - 旧: 4 つの if-else で sdr/hdr のみ判定
  - 新: `[.qualityHDR, .qualitySDR, .hdr, .sdr]` の preference loop で全 variant 対応
- `renderVideoPreview()` (`:1020-` 旧 → 新):
  - 旧: `let asset = AVURLAsset(url: sourceURL)` で source 直読み
  - 新: `let effectiveSourceURL = resolvedVideoSourceURL()` で export と同じ routing 経由
  - 目的: preview ↔ export bytes 対称性を維持 (mezzanine 完成時は両方 mezzanine 経由、未完成時は両方 source)

#### (F) `apps/capacitor-film-lab-ios/CLAUDE.md` §5

不変条件表の `Profile.version` を `4` → `5` に更新、注記追加:
> v=5 (v1.4) は qualitySDR/qualityHDR variants を追加（Quality export での重い source 流用、ProRes / DNxHD / >=100 Mbps gate）

---

## 6. 設計の load-bearing 判断 (将来変更時の根拠)

### 6.1 Quality 流用 invariant の再定義
- 旧: 「Quality/Master export は preview と byte-identical な source bytes を読む」(`FilmtoneExportSession.swift:2742-2748` 旧コメント)
- 新: 「Quality export は **policy が選んだ variant** を読む。preview も同じ routing で同 variant を読む」
- 結果: preview ↔ export 対称性は維持されるが、source-of-truth が「source asset」から「現在 routing が選ぶ最適 variant」に拡張された

### 6.2 Quality variant 生成の eligibility gate
- iPhone 内蔵 HEVC (~50 Mbps) では gate skip → quality variant 生成しない
- 理由: 既に efficient な encode 済 → 再 encode は disk 浪費、UX 寄与薄
- ProRes / DNxHD / >=100 Mbps のみ生成
- 数値根拠: 100 Mbps は iPhone HEVC を除外し、外部 camera HEVC + ProRes/DNxHD を捕捉する分岐点

### 6.3 4GB cap の根拠
- 旧 1GB / 4 entries は preview-grade 2 variant 用に設計、quality 2 variant 追加で不足
- 4GB / 16 entries は SDR + HDR + qualitySDR + qualityHDR を最大 4 source 分保持できる
- `Library/Caches/FilmtonePhase0/mezzanine/` は OS purge 対象、user data 影響なし
- memory warning 時は `handleMemoryWarning` → `reclaimCacheForBackground` → `pruneStandard(protecting:)` で reclaim

### 6.4 Profile.version=5 bump の影響
- 既存 v=4 cache が次回 launch 時に signature mismatch → 自然 invalidate → 再生成
- user 体感: 初回 launch で再 prune + 再生成のコスト発生 (一度きり)
- リリースノート (en/ja) で言及するべき (本 chat では未対応、release_notes.txt は別変更で M 状態)

### 6.5 silent fallback ban との整合
- `feedback_no_fallback_bug_hotbed` ルール: 色域/depth/mezzanine の自動切替は silent degradation の温床
- 本実装の "policy が nil → source-direct" は **silent fallback ではない**
  - quality mezzanine が gate を通過して生成された場合: 必ず使う (確定 routing)
  - gate skip された source: そもそも quality mezzanine が存在しない → source 直読みは「policy が明示的に declined した結果」
  - sidecar `usedMezzanineVariant` で routing 結果を可観測化 (telemetry/debug 可能)

---

## 7. 不変条件 / 触れた gate (CLAUDE.md §5)

| 項目 | 旧値 | 新値 | gate 通過理由 |
|---|---|---|---|
| `MezzanineService.Profile.version` | 4 | **5** | Variant 追加 = bump 必須 (CLAUDE.md §5)、CD と sidecar reader 両側を同一 commit で更新する規則 → CLAUDE.md §5 表自体を同 commit で更新済 |
| `Limits.maxBytes` | 1GB | **4GB** | 不変条件外 (運用 tunable)、Caches dir は OS purge 対象で user data 影響なし |
| `Limits.maxEntries` | 4 | **16** | 不変条件外 |
| `Profile` struct schema | { variant, codec, longEdge, bitrate } | **同上 + isHDR / preservesSourceResolution / outputSize / effectiveBitrate methods** | コンピュテッド prop / method 追加は schema bump 不要 |

`Sidecar V1` schema は触れていない。`usedMezzanineVariant` の値域に `qualitySDR/qualityHDR` を additive で追加するのは reader が ignore すれば OK (本 chat で sidecar reader 側の確認はしていない、§9.2 参照)。

---

## 8. Verification 状況

### ✅ 完了 (本 chat 中に実施)

| Gate | 結果 |
|---|---|
| `xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` |
| `bun run build` (tsc --noEmit + vite build) | success、4786 modules、bundle warning 既存範囲 |
| `bun test src/lib/phase0-state.test.ts` | 14 pass / 0 fail |
| `bun run verify:swift-contract` (`./scripts/verify-phase0-contract.sh`) | 全 fixture pass: motion blur / cube parser / cache store / source-color-classifier / ray-angle optics / D-Log / C-Log / C-Log 3 / V-Log / S-Log3 accuracy / sidecar builder |

SourceKit のクロスターゲット false positive (`Cannot find FilmtoneExportSession in scope`、`No such module 'UIKit'` 等) は既存パターンと同じく出ているが、xcodebuild iOS target ではビルド成功 → 無視可。

### ⏳ 未実施 (本 chat 以後の TODO、§9.1 参照)

1. **実機検証** (重い ProRes vs iPhone HEVC 双方):
   - import → AssetPickerService kickoff で SDR + qualitySDR (or HDR + qualityHDR) の双方が生成されることを `Library/Caches/FilmtonePhase0/mezzanine/` 観察
   - Quality export → output sidecar の `usedMezzanineVariant` が `qualitySDR` or `qualityHDR` を記録
   - **iPhone 内蔵 HEVC 4K** (~50 Mbps) → quality variant が **生成されない** (policy gate skip)、Quality export は source-direct (sidecar の `usedMezzanineVariant` が nil)
2. **Cap 拡張動作確認**:
   - 5 件の 4K ProRes (各 ~5-10GB) を順次 import → `du -sh Library/Caches/FilmtonePhase0/mezzanine/` で 4GB 以下、`ls | wc -l` で 16 以下
3. **Preview ↔ Export bytes 対称性**:
   - 重い ProRes import → quality mezzanine 生成中 → preview render → 完成通知後 preview 再描画 → 同 frame で preview と final export を pixel diff (perceptual identical 確認)
4. **Memory warning 経路**:
   - simulator で memory warning 強制発火 → `reclaimCacheForBackground` 経路で `pruneStandard(protecting:)` が走ることを log で確認、編集中 source は protected で残る
5. **Profile.version=5 bump cold-start prune**:
   - simulator で v=4 cache を残した状態から起動 → 起動 prune で旧 cache が evict されること、新規 import で v=5 signature が hit miss → 生成 → hit に遷移

### 📋 別途確認が必要 (sidecar reader 側)

`usedMezzanineVariant` フィールドに `qualitySDR/qualityHDR` 値域追加について:
- iOS 側 `FilmtoneExportSidecarBuilder.swift` は raw value 文字列で書き出し済 (本 chat で touch せず、現状のまま機能)
- DaVinci Connect / TS reader 側で strict enum decode していないか要確認
- もし strict なら `case unknown` fallback を追加する PR が必要

---

## 9. 次 chat で対応すべき項目

### 9.1 First-priority: 実機検証 (Iteration A)
- 本実装の動作を実機で確認 (§8 ⏳ 未実施 1-5)
- 必要なら user に「Mac 上の iOS Simulator で simulator-stagger テストを走らせてよいか」確認後、UI test (XCUITest) で自動化検討。ただし XCTest 6 並列 / formal QA 手順書 は外殻 → user 明示要求あるまで自動化しない

### 9.2 sidecar reader 互換性確認 (Iteration B)
- DaVinci Connect / TS reader 側で `usedMezzanineVariant` の strict 性確認
- `grep -rn "usedMezzanineVariant" packages/ apps/desktop-film-lab-batch/ ../chibatakumi-portfolio/` で reader 側の実装を探索
- `qualitySDR` / `qualityHDR` 値が unknown として扱われた時の挙動を確認

### 9.3 静止画 decoded source cache (Iteration C、別 lane 候補)
- 本 chat の AskUserQuestion で **deferred** とした課題
- gap: `FilmtoneExportSession.swift:2398` の `loadedSourceImage(at:)` が毎回 `CIImage(contentsOf:)` で fresh decode、preview と export で 2 回呼ばれる (L884, L1000)
- 提案構造: NSCache<URL+mtime, CGImage> in-memory cache、preview の slider 操作で hit、export 時も hit
- 着手前に user に「動画側の効果が見えてから着手するか、即時並行か」確認推奨

### 9.4 wt branch 復活が必要になった場合 (低優先)
- 本 chat で削除した `wt/filmtone-107-heavy-source-proxy` の commits は object store に残存 (~90 日)
  - `d195854` (toast UX): proxy 生成中の UI 通知 (`VideoExportProxyNotice` type)
  - `e4d8777` (perf: temporary proxy): 旧設計の `createVideoExportSourceProxy` (main の `proxy-cache.ts` で superseded)
- **toast UX (d195854)** は再実装価値あり: main の `proxy-cache.ts` plumbing に合わせて UI 通知を新規 commit で追加 (rebase ではなく cherry-pick + adapt)

### 9.5 リリースノート反映 (Iteration D)
- `apps/capacitor-film-lab-ios/fastlane/metadata/{en-US,ja}/release_notes.txt` に v1.4 の Quality mezzanine cache を反映
- 注意: release_notes.txt は本 chat 開始時点で既に M 状態 (user の並行 work)、現在も working tree にあるかは要確認
- 文言案 (en): "Heavy ProRes / DNxHD sources now reuse a master-grade mezzanine on Quality export, cutting decode-time wait without giving up source resolution."
- 文言案 (ja): 「重い ProRes / DNxHD ソースは Quality 書き出し時に master-grade mezzanine を流用、ソース解像度を保ったまま decode 待ち時間を短縮」

---

## 10. 削除した branch (履歴保全)

`wt/filmtone-107-heavy-source-proxy` (was `d195854`) を削除済 (`git branch -D`)。理由:
- e4d8777 (perf: temporary proxy) は main の `apps/desktop-film-lab-batch/electron/proxy-cache.ts` (`b4eecd7 Implement Filmtone UX fixes and proxy cache`) で superseded
- main は wt branch から 1 ヶ月先行、conflict 5 ファイル (electron/main.ts は 565 行 hunk 含む)
- rebase で「より advanced な main impl を旧設計で上書き」する形になり、UX 寄与が逆効果

復旧 anchor (~90 日内):
```bash
git cat-file -t d195854   # commit (still object store)
git cat-file -t e4d8777   # commit (still object store)
# 復活したい場合: git branch wt-recovered d195854
```

---

## 11. ファイル / 行番号 cheat sheet

### iOS Swift (本 chat 編集対象)
| ファイル | 編集ポイント |
|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/MezzanineService.swift` | `:9-12` (ProfileVariant)、`:15-` (Profile + helpers)、`:49-52` (Limits)、`:297-327` (generateSync header) |
| `apps/capacitor-film-lab-ios/ios/App/App/SourceColorClassifier.swift` | `:58-` (FilmtoneMezzanineRoutePolicy 全面拡張) |
| `apps/capacitor-film-lab-ios/ios/App/App/MezzanineColorProbe.swift` | `:33-` (qualityPrewarmVariant + helpers) |
| `apps/capacitor-film-lab-ios/ios/App/App/AssetPickerService.swift` | `:63-` (kickOffMezzanine 拡張) |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift` | `:1020-` (renderVideoPreview)、`:465-491` (didUseMezzanineVariant)、`:2741-` (resolvedVideoSourceURL) |
| `apps/capacitor-film-lab-ios/CLAUDE.md` | §5 不変条件表の `Profile.version` 行 |

### iOS Swift (関連、本 chat では touch せず)
| ファイル | 役割 |
|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/CacheStore.swift` | bucket 管理、`.mezzanine` bucket は signature ベースで動作、本実装で構造変更不要 |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift` | sidecar 書き出し、`usedMezzanineVariant.rawValue` で値を出力 (本 chat で touch せず動作) |
| `apps/capacitor-film-lab-ios/ios/App/App/BenchmarkCollector.swift` | `recordMezzanineUsage(used: variant:)` で variant 追跡、本実装で構造変更不要 |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift:535-538` | benchmark への variant 渡し |
| `apps/capacitor-film-lab-ios/ios/App/App/SourceProbeService.swift:659-682` | codec 抽出ロジック (MezzanineColorProbe で重複実装、DRY 候補) |

### デスクトップ (参考)
| ファイル | 役割 |
|---|---|
| `apps/desktop-film-lab-batch/electron/proxy-cache.ts` | デスクトップ proxy cache (SHA256 + LRU 14d)、iOS mezzanine の参考設計 |
| `apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts` | デスクトップ session-scoped mezzanine state |
| `apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts:563-600` | デスクトップ export での mezzanine 流用 |

---

## 12. CLAUDE.md / グローバル ルール抜粋 (新 chat で再読推奨)

### `~/.claude/CLAUDE.md` (user global)
- **言語ルール**: 内部処理 (sequential-thinking thought / Agent prompt / 中間分析) は英語、最終 user 出力は日本語
- **bun 必須**: `bun install` / `bun run` / `bun add`、npm 禁止、`bun.lock` が正本
- **検索**: gemini-search → WebSearch の順
- **memory ベース断言禁止**: `feedback_no_guessing_davinci_plugins` / `feedback_verify_before_documenting`

### `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md` (repo root)
- 本リポは Filmtone Desktop + iOS + 共有 packages の **実装の正本**
- Truth gate scripts: life の `scripts/check-filmtone-{release,ios}-truth.sh` を信頼
- アンチパターン: `npm publish` 禁止、`packages/film-lab-{renderer,smart-look}/dist/` を消さない、portfolio を実装正本扱いしない、用語ロック (`動画` not `短尺動画`)

### `apps/capacitor-film-lab-ios/CLAUDE.md` (per-app、必読 223 行)
- §5 不変条件 (Profile.version=5、sidecar V1、hiddenDefaults、Info.plist の Photo/Live Activity/暗号化、ASC API key 環境変数、snapshot 端末)
- §4 Commit gate: bun build / xcodebuild SUCCEEDED / Phase0 test / pbxproj 4-section
- §11 アンチパターン (silent fallback / handoff 鵜呑み / JSX comment / Agent Teams 並列 merge 後の deep pass / 判断コスト細切れ禁止 / Settings 装飾優先禁止)

---

## 13. 本 chat の memory 更新 (今後の chat に効く feedback)

本 chat 中に user が追加した auto memory:
- `feedback_dont_overengineer_dirty_state_split.md`: 「bundle in-flight work into one commit; don't unstage / patch-split unless explicitly asked」 — dirty state を hunk 単位で split しない、明示要求あるまで bundle 推奨

既存 memory:
- `feedback_auto_mode_no_decision_handoff.md`: auto mode + plan approved → run the next command, don't punt to user
- `userEmail`: chiba@fores-tone.co.jp
- `currentDate`: 2026-05-02

---

## 14. 注意点 / 罠

1. **Edit tool 使用時の SourceKit false positive**: `Cannot find FilmtoneExportSession in scope` 等は IDE/SourceKit クロスターゲットの誤検知、xcodebuild iOS target では通る。新 chat も同様の警告に惑わされないこと
2. **`UIKit` import warning**: SourceKit が macOS 想定でチェックしている場合 fail するが iOS app target では問題なし、無視可
3. **deprecation warnings** (`naturalSize` / `preferredTransform` / `tracks(withMediaType:)` / `duration`): macOS 13+ で deprecated、`load(.naturalSize)` async 移行が推奨。本実装ではファイル全体の既存パターンに合わせて旧 API のままにした。async 移行は別 lane で
4. **MezzanineColorProbe 内の codec 抽出 DRY 違反**: SourceProbeService.swift:659-682 と同じロジックを duplicating。scope 最小化のため共通化せず。共通化するなら `SourceTrackInspector.swift` 新設が筋
5. **sidecar reader 互換性未確認**: `usedMezzanineVariant` の値域に `qualitySDR/qualityHDR` 追加について TS / DaVinci 側 strict decode を確認していない (§9.2)
6. **commit 779d94b は Canon Log 3 commit subject**: 本 chat の mezzanine work が混入しているが、subject には現れない。`git show 739d94b -- apps/capacitor-film-lab-ios/ios/App/App/MezzanineService.swift` で確認できる
7. **release_notes.txt は本 chat で未更新**: §9.5 で対応推奨

---

## 15. Verification one-liner (新 chat で再走させる場合)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios && \
  xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
    -destination 'generic/platform=iOS Simulator' -configuration Debug \
    build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3 && \
  bun run build 2>&1 | tail -5 && \
  bun test src/lib/phase0-state.test.ts 2>&1 | tail -5 && \
  bun run verify:swift-contract 2>&1 | tail -10
```

期待: `** BUILD SUCCEEDED **`、`✓ built in ...`、`14 pass 0 fail`、Source profile math tests passed / Sidecar builder tests passed

---

## 16. 引き継ぎプロンプト (新 chat 冒頭で貼る)

> 以下を新しい Claude Code chat の冒頭にそのまま貼ってください。`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` で起動してください。

```
Filmtone iOS の Quality Mezzanine Cache 実装の続きを担当してほしい。

前提コンテキスト (この doc に全部書いてある、最初に読んで):
docs/filmtone/ios/quality-mezzanine-cache-handoff-2026-05-02-jst.md

要約 (上記 doc から抜粋):
- 直前 chat で「重い素材のキャッシュ対応」(動画) を iOS に実装、commit 739d94b に bundle 済 (Canon Log 3 と同 commit)
- ProfileVariant に qualitySDR/qualityHDR 追加、source-resolution + master-grade bitrate (4K 80/120Mbps)、policy gate (ProRes/DNxHD/>=100Mbps) で iPhone HEVC は skip
- Profile.version 4→5 bump、Limits cap 1GB/4 → 4GB/16
- resolvedVideoSourceURL を Speed/Quality 統一 routing に再構築、renderVideoPreview も同 routing で preview↔export bytes symmetry 維持
- 関連 6 ファイル: MezzanineService.swift / SourceColorClassifier.swift / MezzanineColorProbe.swift / AssetPickerService.swift / FilmtoneExportSession.swift / CLAUDE.md
- xcodebuild + bun build + phase0 test + verify:swift-contract 全 pass、ただし実機検証は未実施

不変原則 (CLAUDE.md / user 既出 feedback と整合):
1. 本質優先 / 外殻最小 — XCTest 6 並列・formal QA 手順書・装飾 banner は user 明示要求時のみ
2. 保守的ヘッジ優先しない — 「念のため fallback」「v1.x 後回し」のような逃げを取らない
3. silent fallback 禁止 (feedback_no_fallback_bug_hotbed) — 色域 / depth / mezzanine いずれも explicit fail
4. handoff 鵜呑み禁止 (feedback_verify_before_quoting_handoff) — 現行 surface (grep / Swift / pbxproj) と必ず突き合わせて live/frozen 確認
5. dirty state を hunk split しない (feedback_dont_overengineer_dirty_state_split) — bundle in-flight work into one commit、明示要求あるまで patch-split しない
6. bun 必須、npm 禁止
7. Git 操作は user が行う (CLAUDE.md §3) — commit / push / merge は user 明示指示時のみ
8. 内部処理 (sequential-thinking / agent prompt) は英語、最終出力は日本語
9. 不確かなら gemini-search → WebSearch の順で確認、memory ベースで断言しない
10. 思考は mcp__sequential-thinking で

最初にやってほしいこと (順番に):
1. handoff doc (上記パス) を Read で全部読む
2. 上記 doc §1 のメタ情報を git で verify (git log -1、git status --short)
3. 上記 doc §11 cheat sheet の主要ファイルを Read で目を通す (MezzanineService / SourceColorClassifier / MezzanineColorProbe / AssetPickerService / FilmtoneExportSession の該当行)
4. 上記 doc §15 の verification one-liner を走らせて緑であることを確認
5. その上で「次に何をするか」の選択肢を提示してほしい (doc §9 の Iteration A-D + 別案も含めて)

選択肢 §9 の要約:
- A: 実機検証 (重い ProRes vs iPhone HEVC で sidecar variant 確認、cap 4GB LRU 動作確認、preview↔export visual diff、memory warning 経路、Profile.version=5 cold-start prune)
- B: sidecar reader 互換性確認 (TS / DaVinci 側で usedMezzanineVariant の strict decode 有無、qualitySDR/qualityHDR を unknown 扱いするか)
- C: 静止画 decoded source cache (FilmtoneExportSession.swift:2398 の毎回 CIImage decode を NSCache<URL+mtime, CGImage> で hit、preview slider と export で共有)
- D: リリースノート反映 (en/ja の release_notes.txt に v1.4 Quality mezzanine cache を反映)

まずは A の "iPhone HEVC は quality variant が生成されない" を simulator で確認するのが最短で本質的だが、user の優先順位を仰いでから着手してほしい。

時間がかかってもいいので、計算資源を最大限利用して正確に推論すること。
```

---

## 17. 補足 — chat 中で参照した外部 file

| パス | 用途 |
|---|---|
| `~/.claude/plans/ios-ux-enumerated-pebble.md` | 本 chat で書いた plan (approved 済) |
| `~/.claude/projects/.../memory/MEMORY.md` | auto memory 索引 |
| `~/.claude/projects/.../memory/feedback_auto_mode_no_decision_handoff.md` | auto mode + plan approved 時のルール |
| `~/.claude/projects/.../memory/feedback_dont_overengineer_dirty_state_split.md` | 本 chat 中に user が追加した新 feedback |
| `/Volumes/SamsungPortableSSDX5001/documents/life/CLAUDE.md` | 5 ロール憲法、knowledge hub 入口 |

---

> 本 doc の保存場所: `apps/capacitor-film-lab-ios/CLAUDE.md` §10 の規則に従い `docs/filmtone/ios/<topic>-handoff-<date>-jst.md` 形式で repo に commit 推奨 (`git add docs/filmtone/ios/quality-mezzanine-cache-handoff-2026-05-02-jst.md && git commit -m "docs(filmtone-ios): handoff for quality mezzanine cache work"`)。commit は user 判断。
