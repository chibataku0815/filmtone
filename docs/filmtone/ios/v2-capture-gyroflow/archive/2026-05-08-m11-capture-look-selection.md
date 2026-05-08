# Active — M11 Capture-Time Look Selection

Status: **S11-A〜F PASS — M11 closeout 完了**
(2026-05-08 JST)

S11-A 設計確定 → S11-B UI shell → S11-C live preview rebuild → S11-D
capture-package schema 拡張 → S11-E adoptCaptureResult applySavedLook
xcodebuild PASS → S11-F 実機検証 PASS。M11 closeout 実施。

## S11-F Outcome(2026-05-08)

実機 iPhone 17 Pro #7(`3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`) /
iOS 26.4.2 で owner verify PASS。

実機検証結果:

- **chip 切替で live preview 反映**: cold launch + capture surface →
  Stone / Urban chip タップで live preview の色が切替(初回 cold-start
  でも反映、ただし若干の遅延あり)
- **record success → editor 反映**: chip × record → editor 自動入場時に
  選択 Look が掛かった状態で proxy preview が表示される
- **cancel で editor 不変**: capture をキャンセルしても editor の
  既存 Look / 調整は破壊されない
- **master truth は M10 baseline 維持**: master.mov は ProRes 422 HQ
  `apch` / Apple Log 2 / 4K24 / cinematicExtendedEnhanced のまま、
  Look は焼き込まれない(capture-package.json `selectedLook` field +
  editor 初期状態のみ反映)

S11-F 実装中に発見した bug を 2 件 fix し M11 範囲で closeout:

1. **SSD folder bookmark 復元**: M10 までは capture surface 入場ごとに
   SSD folder を再 pick する必要があり owner UX として劣悪だった。
   `FilmtoneExternalFolderBookmark` 新設(UserDefaults に minimal
   bookmark 永続化、`FilmtoneCaptureView.task` で auto-restore +
   preflight 再実行、stale / disconnected → silent fallback to internal
   mode)。`FilmtoneCapturePreflight` の stale comment も修正
2. **cold-start chip preview structural gap**: editor source 未 load
   状態で capture 入場した場合、`makeLivePreviewGradeProcessor` が
   `guard source != nil else { return nil }` で early return → chip
   切替で grade processor が rebuild されず raw camera のまま、という
   structural gap があった。M10 では editor 経由でしか capture に
   入れなかったため顕在化していなかった bug。
   - **fix**: `FilmtoneEditorStore.makeLivePreviewGradeProcessor`
     内で source nil 時に capture-time synthetic
     `(SourceInfoDTO, SourceProbeDTO)` を構築(M10 capture contract
     と一致 — 4K24 / `apch` / Apple Log 2 / `appleLog2ToRec709` input
     transform)。URI は `file:///filmtone-capture-live-preview.mov`
     (`FilmtoneMediaRuntime.resolveFileURL` が `isFileURL == true`
     で existence check なしに通す経路を狙う;
     `FilmtoneSharedGradeProcessor.applyForLivePreview` は CIImage
     のみ受け取り disk 読み込みなし)
   - 最初の試行では URI を `filmtone://capture-live-preview` にして
     しまい `resolveFileURL` で silent throw → grade processor 構築
     失敗を引いた。`file://` scheme への変更で解消

## 既知の post-M11 polish 候補(M11 blocking ではない)

- **live preview 反映に若干の遅延**: chip タップから VDO の grade
  processor 切替まで 1〜数 frame 遅延が見える。M11 の Done condition
  「即反映」は満たすが、より tight なレスポンスは後続 lane で対象。

## S11-E Outcome(2026-05-08)

- `FilmtoneEditorStore.adoptCaptureResult(_:)` に
  `if let canonicalUUID = package.selectedLook?.canonicalUUID
  { await applySavedLook(id: canonicalUUID) }` を挿入
  (`currentCapturePackageRef` 確定後 / `isBusy = false` 直前)
- 経路: `applySavedLook(id:)` → `libraryStore.loadLook(id:)` →
  `FilmtoneBuiltInCatalog.look(matching:)` で built-in 解決 →
  `FilmtoneBuiltInCatalog.materializeAsSavedLookEntry(...)` →
  `.bundled` cube + `FilmtoneCreativePack01Adaptation` 適用 →
  `applyLutMutation` + `recomputeProjectParamsPreservingOpticsGlow` →
  preview render scheduled。chip strip / library sheet と完全に同じ
  単一経路(layer fit を裏切らない)
- `await` で apply 完了を待ってから `persist()` →
  `schedulePreviewRender()` 順なので、editor 復帰時の最初の preview
  render が Look 適用後の状態を出す
- `selectedLook == nil`(Filmtone chip / pre-M11 package): branch を
  完全に通過 — editor の現状 Look / 調整は不変、cancel と同等の効果
- error: `applySavedLook` 内の `lutMissingForApply` →
  `self.error = strings.libraryLutMissingOnApply`(既存 error surface)
  に乗る。S11-E は二重 error path を作らない
- master / proxy / `capture-package.json` は S11-D の値を引き続き
  source of truth(applySavedLook は editor state のみを mutate)
- xcodebuild iOS Simulator generic Debug = `BUILD SUCCEEDED`
- 実機色確認(Stone/Urban/Filmtone × record × editor 反映 × master
  truth gate)は S11-F でまとめる

## S11-D Outcome(2026-05-08)

- `FilmtoneCapturePackage.swift`: `FilmtoneSelectedLookRecord` 追加
  (`canonicalUUID: UUID` / `slug: String?` / `englishName: String` /
  `intensity: Double`)、`FilmtoneCapturePackage` に
  `selectedLook: FilmtoneSelectedLookRecord?` 追加。Filmtone chip / 旧
  M10 package = `nil`、Stone / Urban = record。master 焼き込みは無し
- `FilmtoneCapturePackagePersistence.swift`: snapshot に optional flat
  fields(`selectedLookCanonicalUUID` / `selectedLookSlug` /
  `selectedLookEnglishName` / `selectedLookIntensity`)を追加、
  `currentSchemaVersion = 2` に bump。pre-M11 snapshot は全 field 欠落
  → `selectedLook = nil` で decode(forward-compat 維持)。partially-
  written record(UUID 単独存在等)は lens record と同じ policy で
  「look unknown」扱い、fabricate しない
- `FilmtoneCaptureSession.swift`: `private var pendingSelectedLook` +
  `func setSelectedLook(_:)` 追加(`useExternalFolder` と同じ public
  setter pattern)。record-stop 時 package builder で
  `pendingSelectedLook` を `selectedLook:` に渡す。capture session
  自体は chip UI を知らない
- `FilmtoneCaptureView.swift`: `FilmtoneCaptureLook` に `slug: String?`
  追加(stone / urban 定義 + filmtone は nil)、
  `toSelectedLookRecord() -> FilmtoneSelectedLookRecord?` helper 追加。
  `.task` 初回 + `.onChange(of: captureLookSelection)` 両方で
  `session.setSelectedLook(...)` 呼び、record-stop 時に latest pick が
  package へ載る
- editor adoption(`adoptCaptureResult`)は触らない — package
  persistence までで止め、editor 側読み出しは S11-E
- xcodebuild iOS Simulator generic Debug = `BUILD SUCCEEDED`

## S11-C Outcome(2026-05-08)

- `FilmtoneEditorStore.makeLivePreviewGradeProcessor(overridingBuiltInLook:)`
  追加(`FilmtoneEditorStore.swift`)。`builtIn == nil` は既存 argument-less
  版へ委譲(Filmtone chip = editor 状態そのまま、custom adjust 保持)。
  非 nil は transient `FilmtoneProjectState` に catalog の preset /
  strength / quickState / paramOverrides / creativeLut を載せ、
  `loadBundledCreativeLut` で cube 解決 + `FilmtoneCreativePack01Adaptation`
  patch を重ねて `facade.makeLivePreviewGradeProcessor(...)` に
  materialize した `SavedLookEntry` と一緒に渡す(3-layer wiring 維持)
- `FilmtoneCaptureView.swift`: `makeGradeProcessor:` closure prop 追加
  + `activeGradeProcessor` / `activeLiveDiagnostics` を `@State` 化、
  `init(...)` で props から seed。`previewLayer` / `diagnosticOverlay`
  / "Live ungraded" disclaimer / `.task` 初回 log を全部 active 側に切替
- `.onChange(of: captureLookSelection)` で closure 呼び出し → bundle
  swap → `[F3R] live preview rebuild for chip=…` を log
- `FilmtoneRootView.swift`: closure 内で
  `chip.canonicalUUID.flatMap { FilmtoneBuiltInCatalog.look(matching: $0) }`
  → `store.makeLivePreviewGradeProcessor(overridingBuiltInLook: builtIn)`
  に橋渡し。Filmtone chip(canonicalUUID = nil)= no override
- editor store の persisted state は触っていない(cancel-preservation 維持)
- xcodebuild iOS Simulator generic Debug = `BUILD SUCCEEDED`

## S11-B Outcome(2026-05-08)

- `FilmtoneCaptureLook` 型 + Filmtone / Stone / Urban の 3 chip 定数を
  `FilmtoneCaptureView.swift` に追加(`FilmtoneBuiltInCatalog.allLooks`
  から slug 経由で `canonicalUUID` を解決 — UUID hardcode 回避)
- `FilmtoneCaptureLook.resolve(from: UUID?)` で editor の
  `appliedSavedLookId` を chip にマッピング(該当 chip なし →
  `.filmtone`)
- `FilmtoneCaptureView.init(...)` に `initialCaptureLook` prop 追加、
  default `.filmtone` で M10 caller 互換維持
- `@State private var captureLookSelection`(ephemeral)
- `captureLookStrip` を `bottomDeck` の `contractBanner` 直上に挿入。
  pill row、selected = white border 28%、recording 中は disabled
- `FilmtoneRootView` で `FilmtoneCaptureLook.resolve(from:
  store.appliedSavedLookId)` を渡して initial chip 選択
- xcodebuild iOS Simulator generic Debug = `BUILD SUCCEEDED`
- S11-B 範囲: chip tap は `captureLookSelection` 更新のみ(live
  preview rebuild は S11-C)

## Design Locks(S11-A user 承認 2026-05-08)

- **配置**: bottom strip(record button 直上)
- **chip set**: Filmtone(default) / Stone / Urban の固定 3 chip
- **default chip 名**: "Filmtone"(canonical 用語ロック踏襲)
- **Look overwrite policy**: capture-Look が editor を上書き
  (`adoptCaptureResult` 内で `applySavedLook` を呼ぶ)
- **state model**: `FilmtoneCaptureView` 内 `@State` ephemeral、cancel
  時に editor 触らない、record success 時のみ commit
- **live preview rebuild 経路**: closure prop —
  `EditorStore.makeLivePreviewGradeProcessor(overridingLook:)` 新設
- **capture-package schema**: `selectedLook: FilmtoneSelectedLookRecord?`
  field 追加 + `schemaVersion: Int` 初導入(forward-compat decode)

---

## Why this active exists

M10 closeout で live preview の VDO grade chain は Stone / Urban も含めて
編集中の Look に追従するようになった(F3-Fix #1)。一方で **Look を切り
替える UI は editor 側にしか無い** — owner は「色を選ぶために素材を一度
読み込む」遠回りを強いられている。これは撮影プロダクトとして弱い。

M11 はこの遠回りを撤廃する。strategy.md M11 の Done conditions を満たす
ためのサブステージ分解を S11-A で確定し、user 承認後に S11-B〜F の実装
に入る。

---

## Out of scope (M11 全体・S11-A も同じ)

- master file への Look 焼き込み(M10 truth gate を絶対に動かさない)
- Library full picker / saved Look 作成・削除・rename(library sheet は
  editor 側のまま)
- intensity slider(まずは固定 intensity)
- camera profile selector(capture 中固定、editor で変更)
- chip strip の sort / favorite / search
- M11 後の master/proxy export truth(M12 lane)

---

## S11-A 範囲(この active で確定すること)

### A1. UI 配置案

候補(user 選択待ち):

| 案 | 配置 | 利点 | 欠点 |
|---|---|---|---|
| Bottom strip | record button 直上に horizontal scroll chip strip | record と Look 選択を片手で完結、record 動線を遮らない | bottomDeck の縦寸が増える |
| Right column | look reference panel の下に縦 chip stack | 既存 right column の流儀を踏襲、bottom 圧迫しない | reach が悪い、横スクロールに馴染まない |
| Top sheet | record button 横の "Look" pill → bottom sheet | scale する(将来 saved Look 追加時) | tap 数増、live preview 即反映と相性悪い |

**Recommendation: Bottom strip**(録画体験の中心は record button、Look
選択も録画判断の一部 → 同じ操作ゾーンに置く)。chip 要素は square thumbnail
+ 下に Look 名 1 行、selected state は white border + slight scale。

### A2. 表示する Look セット

M11 v1 は **fixed 3-chip strip** を提案:

1. **Filmtone**(default — `creativeLut == nil` の素の状態)
2. **Stone**(`FilmtoneBuiltInCatalog.creativePack01Stone`)
3. **Urban**(`FilmtoneBuiltInCatalog.creativePack01Urban`)

理由:
- bundled Look は現状この 2 個のみ(v1.4 で他 4 個削除済 — 既存ナレッジ
  通り)
- saved Look を chip strip に出すと sort / favorite / overflow 問題が発生
  → 別 lane に隔離
- Filmtone(素) を入れることで「Look を外して撮る」選択も同じ強度で残す

将来拡張(M11 範囲外): saved Look 表示は library sheet 経由、または
"more" chip → sheet で別途。

### A3. データ流れ

**ephemeral capture-Look state を `FilmtoneCaptureView` 内 `@State` で
保持**(editor store を mid-capture で mutate しない):

```
@State private var captureLookSelection: CaptureLookSelection
```

- 初期値: presented 時の `lookReference.lookLabel` から逆解決
  (Stone / Urban → 該当 chip、それ以外 → Filmtone)
- chip タップ → `captureLookSelection` を更新 → live preview 用の
  grade processor を rebuild → bottomDeck に反映
- record success(`.completed(package)`)時に
  `package.selectedLook` field に書き込む
- record cancel(`.cancelled`)時は何もしない — editor store は
  pre-capture state のまま

**editor store を触るのは `adoptCaptureResult(_:)` 内のみ**:
- `package.selectedLook` を読み、対応する `BuiltInLook.canonicalUUID` を
  `applySavedLook(id:)` に渡す → 既存経路で `creativeLut` /
  `paramOverrides` / `quickState` / `presetName` が反映される
- これによって editor 入った瞬間に Look が掛かった状態で proxy preview が
  出る(F3-Fix #1 で確認済の 3-layer wiring が動く)

### A4. live preview rebuild 経路

現状 `FilmtoneRootView` で `store.makeLivePreviewGradeProcessor()` を
fullScreenCover 表示時に **1 回だけ** snapshot している。M11 では Look
切替時に再 build が必要。

提案アプローチ:
- `FilmtoneCaptureView` に new closure prop を追加:
  `makeGradeProcessor: (CaptureLookSelection) -> FilmtoneLivePreviewBundle?`
- `FilmtoneRootView` 側で store 経由で build できるよう
  `EditorStore.makeLivePreviewGradeProcessor(overridingLook:)` を新設
  (既存の引数なし版は default で使い続ける、二重実装回避)
- chip タップ → state 更新 → SwiftUI .onChange で closure 再呼び出し →
  bundle 差し替え → VDO sample tick から自動的に新 processor が掛かる

代替案: capture surface 自前で `BuiltInLook` → `Phase0ExportRequestDTO`
patch を組み立てる経路。**却下** — `applySavedLook` の `presetName` /
`paramOverrides` / `creativeLut` / `quickState` 解決ロジックを二重実装
することになり `feedback_audit_layer_fit_before_placing_new_files` 違反。

### A5. capture-package.json schema 拡張

現行 `FilmtoneCapturePackage` は M10 baseline まで。M11 で field 追加:

```swift
struct FilmtoneSelectedLookRecord: Codable, Equatable {
    let canonicalUUID: UUID         // Stone/Urban の canonicalUUID、Filmtone は nil/sentinel
    let slug: String?               // bundled-only — built-in catalog slug
    let englishName: String         // owner readable("Filmtone" / "Stone" / "Urban")
    let intensity: Double           // M11 固定 1.0、将来 slider 用
}

// FilmtoneCapturePackage に追加
let selectedLook: FilmtoneSelectedLookRecord?  // nil = pre-M11 capture
```

`FilmtoneCapturePackagePersistenceSnapshot` schemaVersion bump:
- 現行が無い場合は `schemaVersion: Int = 2` を追加(`= 1` は M10 baseline 想定)
- decode 側で `schemaVersion` 欠如 = 1 として `selectedLook = nil` 解釈

注意点: schemaVersion を初導入する場合、既存 M10 capture-package を
破壊しないよう **decode は forward-compatible に**(absent field は nil)。

### A6. cancel 時の不変条件

`onCancelled` では editor store に何も伝えない(M10 と同じ)。capture
state は SwiftUI の lifecycle で破棄される。

### A7. master file への影響(必須 verify)

S11-F device gate で確認:
- Look 切替を 5 回行ってから record
- ffprobe / mp4dump で master.mov の `apch` / colr / fps / 10-bit 422 が
  M10 baseline と同一であること
- M10 capture-package.json `parameters*` が Apple Log 2 /
  cinematicExtendedEnhanced / 24 / 3840×2160 を保持

---

## サブステージ提案(S11-B〜F)

| Stage | 範囲 | 期待粒度 |
|---|---|---|
| **S11-B** | UI shell — chip strip 追加(初期は no-op、`captureLookSelection` state だけ) | 30〜45 min |
| **S11-C** | live preview rebuild — `EditorStore.makeLivePreviewGradeProcessor(overridingLook:)` + closure 配線 + chip tap で processor 差し替え | 60〜90 min |
| **S11-D** | capture-package schema 拡張 — `FilmtoneSelectedLookRecord` 追加・persistence snapshot bump・decode forward-compat | 45〜60 min |
| **S11-E** | adoptCaptureResult applySavedLook 経路接続 — record success → editor 入場時に Look が掛かった状態で proxy 表示 | 30〜45 min |
| **S11-F** | device verification — Stone / Urban / Filmtone 切替 → record → editor 反映 → master truth gate(M10 と同等)| 60 min |

各 stage 終了時に active.md を Update + 必要なら paused/ 退避。S11-F PASS で
M11 closeout(active archive + strategy.md Completion Log 1〜3 行)。

---

## Verify(S11-A 完了条件)

- [ ] strategy.md に M11 milestone が追記されている(M10 直後、## Known Constraints 直前)
- [ ] active.md(本書)に S11-A 〜 S11-F の範囲・分解が書面化されている
- [ ] **user が A1 配置案を選定**(bottom strip / right column / top sheet / その他)
- [ ] **user が A2 Look セットを承認**(Filmtone / Stone / Urban の 3-chip / 別構成)
- [ ] **user が A4 live preview rebuild の実装経路を承認**(closure 案 vs 別案)
- [ ] **user が A5 capture-package schema 拡張を承認**(field 名・schemaVersion 戦略)

ここまで確定したら S11-B 着手 OK。

---

## Open Questions(user review で解消したい)

1. **chip strip の縦圧迫許容度**: bottom strip にすると bottomDeck 縦寸が
   90px 程度増える。owner の片手操作で問題ないか?
2. **Filmtone(素)chip の名称**: "Filmtone" / "Original" / "None" のどれが
   owner にとって意図明確か(canonical 用語ロックは "Filmtone" 寄り)
3. **編集途中の Look 切替挙動**: editor で Stone を当てた状態で capture
   に入り、capture surface で Urban に切替 → record → editor 戻り。この時
   editor の Look は Urban で上書きで OK か?それとも capture-Look は
   capture surface 専用で editor 側は Stone を保つべきか?
   (現状提案は前者 — adoptCaptureResult が capture-Look を applySavedLook
   する。後者にする場合は data flow 全体を再設計)
4. **saved Look chip 表示の M11 inclusion 可否**: out-of-scope と書いたが、
   "more" chip → sheet 経由で saved Look も M11 に含める案もある。M11
   範囲を狭く保つか、sheet も含めるか。

---

## Unexpected / Follow-up

(ここに S11-A 中に出た差し込み・後で見る項目を追記)
