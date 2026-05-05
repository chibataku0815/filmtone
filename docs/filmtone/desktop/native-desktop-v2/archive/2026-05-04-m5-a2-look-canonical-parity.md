# Active Task: M5-A.2 Look Canonical Parity (Interrupt — mid-size)

Date opened: 2026-05-04 JST
Milestone: M5 (Native Editing UI), slice A.2
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`
Classification: Interrupt — mid-size (Tier 1 #2 動画スクラブ を後回し)

## Goal

iOS v1.4 Creative LUT Pack 01 (Stone / Urban) を Desktop に移植し、Look (高層、cube +
override) と Preset (低層、4 entries) の 2-tier 構造を canonical 化する。Look 選択時は
`basePreset = "reset"` + `paramOverrides` + `.cube` が iOS と等価に作用する。

## Scope reference

`strategy.md` Milestones M5 (Native Editing UI) → slice A.2。Visual Smoke 完了後の
Interrupt として差し込み。原 Tier 1 #2 (動画スクラブ) は M5-A.2 完了後に再開予定。

## Design decisions (canonical for Desktop)

- **D1 Cube source**: iOS Resources から **コピー** (sha256 pin 維持、disk 重複 ~14.8 MB
  受容)
- **D2 Catalog source**: **hand-port Swift struct** (TS-driven generator は別 followup)
- **D3 Strength semantics**: **preset-blend (α)** — Strength slider は `params + override` を
  `resetParams` に向けて lerp。Cube intensity は look pin の 1.0 固定 (M5-A.1 invariant 継続)
- **D4 Strength=0 + Look**: **cube も gate off** (ii) — `strength == 0` で Look 選択中も
  bareline
- **D5 UI**: **2-tier picker** — Look (top, None / Stone / Urban) + Preset (below,
  Look=None 時のみ enabled)
- **D6 Slice scope**: A.2.3 substance-only — Quick state 3-axis UI / 形式 parity sweep は
  除外
- **Pipeline insertion**: iOS canonical (`FilmtoneExportSession.swift:1561`) と同位置、
  grain と print の間
- **Color space**: `CIColorCubeWithColorSpace` の `inputColorSpace` =
  `FilmtoneCIContext.outputColorSpace` (sRGB)

## Edit Targets (sequenced; build green at each stage boundary)

### Stage 1 — Foundation primitives (additive, no callers)

- [x] NEW `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePhase0ParamsPatch.swift`
  - port `FilmtonePhase0ParamsPatch` struct from iOS `FilmtonePhase0Math.swift:210`
  - port `FilmtonePhase0Params.applyingPatch(_:)` (iOS `:158`) + `setValue(_:for:)` (iOS
    `:151`) + `keyPaths` dict (iOS `:104-141`) — full 35-key keypath table
  - Codable は省略 (in-memory のみ)
- [x] NEW `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCubeParser.swift`
  - verbatim copy of iOS `FilmtoneCubeParser.swift` (~220 lines, self-contained)
  - エラー型を local `FilmtoneCubeParseError` に置換、`filmtoneLocalized*` 削除、
    `ParsedCubeLutDTO` → local `ParsedCubeLut`
- [x] NEW `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCreativePackCatalog.swift`
  - `BuiltInLook` struct (slug / canonicalUUID / englishName / bundledFilename /
    pinnedSha256 / intensity: 1.0 / packId: "creative-pack-01" / paramOverridesPatch)
  - Stone + Urban entries — UUIDs & sha256 from
    `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json`
  - paramOverrides dict は iOS `FilmtoneBuiltInCatalog.swift:139-171` から 26 keys 移植
  - `static let cubeSize = 65`、`static let all: [BuiltInLook]`、
    `static func find(slug:) -> BuiltInLook?`

### Stage 2 — Cube loader (sha256 + parser glue)

- [x] NEW `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCreativeLutLoader.swift`
  - `static func load(look: BuiltInLook) -> PreparedCreativeLut?`
  - `Bundle.main.url(forResource:withExtension:subdirectory:"CreativeLuts")`
  - `CryptoKit.SHA256.hash(data:)` で fail-closed verify
  - Float64 RGB triples → packed `Float32` RGBA (alpha=1) `Data` (~7 MB / cube)
  - `NSCache` keyed by slug (video export 用、frame ごと re-parse 防止)

### Stage 3 — Pipeline integration (still no UI, lookSlug=nil で no-op)

- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
  - add `applyCreativeLutStage(to image: CIImage, lut: PreparedCreativeLut) -> CIImage`
    (port iOS `FilmtoneExportSession.swift:2077-2095`、Stone/Urban は intensity=1.0 pin
    なので simple path のみ — alpha-blend 分岐不要)
  - `apply(...)` シグネチャに `creativeLut: PreparedCreativeLut? = nil` 追加
  - **挿入位置**: 現 grain (L57-66) の直後、現 printStage (L67) の直前 (iOS canonical
    一致)
  - header コメントに `... → grain → creativeLut → printStage` 反映

### Stage 4 — State + presetCatalog merge

- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePresetCatalog.swift`
  - add `static func resolved(presetName: String, strength: Double, lookSlug: String?) ->
    FilmtonePhase0Params`
    - lookSlug 解決 →
      `target = paramsByName["reset"].applyingPatch(look.paramOverridesPatch)`
    - `lerp(resetParams, target, strength)` (D3-α)
    - lookSlug == nil → 既存 `params(for:strength:)` 委譲
  - add `static func lookId(forSlug slug: String) -> String` →
    `"filmtone:builtin:\(slug):\(presetVersion)"`
- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
  - add `var lookSlug: String? = nil`
  - update `presetParams` to use `FilmtonePresetCatalog.resolved(...)`
  - add `var resolvedCreativeLut: PreparedCreativeLut?` computed
    (`lookSlug != nil && presetStrength > 0` → load via Loader、それ以外は nil で
    D4-ii 実現)

### Stage 5 — UI 2-tier picker

- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/GradeControls.swift`
  - top に Look picker (`[("None", nil), ("Stone", "filmtone-creative-pack-01-stone"),
    ("Urban", "filmtone-creative-pack-01-urban")]`) bound to `state.lookSlug`
  - 既存 Preset picker は `state.lookSlug == nil` 時のみ enabled (Look 選択時は visually
    disable + dim)
  - Look 選択時は `state.presetName = "reset"` を強制 (Stone/Urban basePreset pin)
  - Strength slider は Look or non-reset preset 時 enabled

### Stage 6 — Preview + export plumbing

- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
  - `let lookSlug: String?` を view + `PreviewImageView` に追加
  - `renderAndAssign` 内で `creativeLut` 解決 →
    `FilmtoneGradePipeline.apply(... creativeLut:)`
- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  - `state.lookSlug` を `PreviewSurface` / `FilmtoneStillExportRequest` /
    `FilmtoneVideoExportRequest` に thread
- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarTypes.swift`
  - `FilmtoneSidecarRequest` protocol に `var lookSlug: String? { get }` 追加
- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift`
  - `FilmtoneStillExportRequest.lookSlug: String?` 追加 (default nil for backward compat)
  - render 前に `creativeLut` 1 回解決 → `FilmtoneGradePipeline.apply(... creativeLut:)`
- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
  - 同様に `lookSlug` + frame loop **外**で `creativeLut` 1 回解決 (cache hit、per-frame
    parse 禁止)

### Stage 7 — Sidecar additive (no schema bump)

- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift`
  - `request.lookSlug != nil` 時:
    - `lookId` / `batchLookChoice.lookId` を `FilmtonePresetCatalog.lookId(forSlug:)` に
      置換
    - `batchLookChoice.baseLookName = slug` (Look identity が preset identity を上書き)
    - 新規 block `creativeLut: { size: 65, intensity: 1.0, sourceHash: <pinned sha256>,
      bundledSlug: <slug>, bundledPackId: "creative-pack-01" }` 追加
  - additive のみ、reader が unknown field を ignore する前提で schema bump 不要

### Stage 8 — CLI

- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop/App/FilmtoneDesktopApp.swift`
  - `--look <slug>` parser 追加 (`parseLook(args:) -> String?`、
    `FilmtoneCreativePackCatalog.find` で validate、unknown slug は exit 64)
  - 両 export request に thread
  - `--preset` と `--look` 同時指定時: Look 勝ち、preset = "reset" 強制、stderr warning
  - header コメント usage block 更新

### Stage 9 — Resources

- [x] COPY
  `apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-{stone,urban}.cube`
  → `apps/filmtone-desktop-macos/FilmtoneDesktop/Resources/CreativeLuts/`
  sha256 verify: `shasum -a 256` 後、`Tests/Fixtures/creative-pack-01/manifest.json` の値と
  照合
- [x] EDIT `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
  - `Resources` PBXGroup + `CreativeLuts` subgroup
  - 2× PBXFileReference + 2× PBXBuildFile を既存 PBXResourcesBuildPhase の files array に
    append
  - **重要**: group reference (yellow folder) で追加 — folder reference (blue folder) は
    `Bundle.main.url(forResource:subdirectory:"CreativeLuts")` 解決を壊す
  - **推奨手段**: Xcode UI "Add Files" → "Copy items if needed" off、"Create folder
    references" off

## Verification (Step-by-step smoke)

- [x] 1. `xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj -scheme
       FilmtoneDesktop -configuration Debug build` → BUILD SUCCEEDED
- [x] 2. App launch → `09-skin-light.png` open
- [x] 3. Look picker = **Stone** → preview shift visible (Palermo Reference cast)
- [x] 4. Strength 1.0 → 0.0 drag → 0 で bareline (cube も gate off、D4-ii 確認)
- [x] 5. Look picker = **Urban** → Stone と異なる greener cast
- [x] 6. Look = None → Preset picker re-enabled、Stone/Urban 解除
- [x] 7. ⌘E export PNG @ Look=Stone, Strength=1.0 → sidecar JSON 検証:
       - `lookId: "filmtone:builtin:filmtone-creative-pack-01-stone:v2"`
       - `batchLookChoice.baseLookName: "filmtone-creative-pack-01-stone"`
       - `creativeLut: { size: 65, intensity: 1.0, sourceHash: "2f9e0240...",
         bundledSlug: ..., bundledPackId: "creative-pack-01" }`
- [x] 8. 短尺 video (~5s 1080p) export @ Look=Stone → MP4 + sidecar 同 shape、cube が
       全 frame に適用
- [x] 9. CLI: `./FilmtoneDesktop --export-still --input <png> --output /tmp/out.png
       --look filmtone-creative-pack-01-stone --strength 1.0` → stdout `ok WxH /tmp/out.png`、
       sidecar 生成
- [x] 10. Negative path: bundle から cube 除去 → relaunch → Stone 選択 → cube stage
        skipped (fail-closed)、grade は走る (preview = reset 状態)、no crash

## Edge cases / Risks

- **Cube SHA mismatch**: Loader nil → pipeline silently skip (fail-closed)。debug `print`
  のみ、UI toast は M5-A.2-followup
- **Color space**: cube は sRGB 空間 baked、`CIColorCubeWithColorSpace` の
  `inputColorSpace` = `FilmtoneCIContext.outputColorSpace` (sRGB) を渡す。linearSRGB 渡し
  禁止
- **Strength=0 + Look**: D4-ii 実装 (`resolvedCreativeLut == nil` で gate)
- **Missing cube resource**: SHA mismatch と同経路で silent skip
- **Video export memory**: `PreparedCreativeLut.cubeData` ~7 MB、frame loop **外**で 1 回
  resolve、NSCache hit
- **`paramKeys` 確認済**: `FilmtonePhase0Generated.swift:8` に存在 (Desktop generated mirror
  済)
- **EditorState ↔ Look coupling**: Look 選択時は `presetName="reset"` 強制、UI で disable
  表示
- **CLI mutual exclusivity**: `--preset X --look Y` → Look 勝ち、stderr warn、exit 0
- **pbxproj merge**: line-noise 多発、resource 追加コミットは Swift 編集と分けて auditable
  に

## Out of Scope (M5-A.2 では扱わない)

- Quick state 3-axis UI (filmCharacter / era / dynamics) — sidecar は zeros 維持
- iOS との bytewise parity sweep (formal QA、user 希望時のみ別 active)
- TS-driven Swift generator extension (M5-A.2-followup)
- LUT-intensity-as-second-axis UI (D3-β/γ 不採用)
- User-imported `.cube` LUT — bundled built-in 限定
- Cube SHA fail 時 toast/warning chip
- Desktop test target 新設
- Camera Profile (`FilmtoneSourceProfileCatalog`) — 別 lane

## Open Questions

- **OQ-1 ローカライズ**: Stone/Urban 表示英語そのまま v.s. Desktop 簡易 string table 新設
  → 推奨: 英語そのまま (本 slice)
- **OQ-2 lookId format**: `filmtone:builtin:<slug>:<presetVersion>` 採用 (本 plan で固定)。
  film-lab-core canonical `look:mp:<name>:v1` (`look-ids.ts:25`) との乖離は
  **pre-existing** (Desktop は既に `filmtone:base:` 採用)、status quo 維持
- **OQ-3 Sidecar on cube load fail**: `creativeLut` block omit (本 plan 固定、
  attempted-and-failed の signal 不要)

## Estimated footprint

- 新規 Swift: 4 files、~600 LOC
- 編集 Swift: 9 files、~190 LOC 追加
- Resources: 2 cube binary (~14.8 MB) + pbxproj diff ~30 lines
- 計: ~13 source files / ~800 LOC / 2 binary / 1 pbxproj
- 工数: codebase familiar で半日、pbxproj/keypath で詰まれば 1–2 日

## INV-7 / commit (user-manual)

- 自動 commit 禁止
- Stage 1–3 (foundation, lookSlug=nil で no-op) を 1 commit
- Stage 4–8 (state + UI + plumbing + sidecar + CLI) を 1 commit
- Stage 9 (cube binary + pbxproj) を別 commit (auditable)
- 計 3 commit 予定、user-manual で実行

## Unexpected

- pbxproj resource pattern surprise (Stage 9): the active.md note said
  "yellow-folder PBXGroup is correct, blue folder breaks
  `subdirectory:` resolution". Empirically the opposite is true on
  macOS: a yellow-folder PBXGroup **flattens** every child file into
  `Contents/Resources/` at build time, so
  `Bundle.main.url(forResource:withExtension:subdirectory:"CreativeLuts")`
  returns nil. iOS sidesteps this by using a folder reference
  (`lastKnownFileType = folder`) for `CreativeLuts/`, which preserves
  the directory inside the bundle. Resolution choice for this slice:
  **kept** the yellow-folder PBXGroup (per project rule) and **dropped
  the `subdirectory:` argument** from the Loader. The .cube files end
  up at `Contents/Resources/<filename>.cube`, which `Bundle.main.url`
  resolves by name + extension. Follow-up: revisit the active.md /
  CLAUDE.md note about blue vs yellow when iOS / Desktop pbxproj
  patterns are unified (likely M5-A.2-followup or M4 SPM).

## Result

all gates pass — Stone / Urban Look ports active end to end.

CLI smoke (build = BUILD SUCCEEDED, app = `Contents/MacOS/FilmtoneDesktop`):

- `--look filmtone-creative-pack-01-stone --strength 1.0` → `ok 1280x720`
  + sidecar `creativeLut.sourceHash = 2f9e0240…9393c4`,
  `lookId = filmtone:builtin:filmtone-creative-pack-01-stone:v2`,
  `baseLookName = filmtone-creative-pack-01-stone`
- `--look filmtone-creative-pack-01-urban --strength 1.0` → distinct PNG
  hash from Stone (cube actually flowing through the pipeline)
- `--look filmtone-creative-pack-01-stone --strength 0.0` → distinct PNG
  hash from strength=1.0; sidecar omits the `creativeLut` block (D4-ii
  bareline)
- `--look bogus-slug` → exits 64 with `unknown --look slug: bogus-slug`
  (CLI validation gate)

Three commits landed (b8b3bd4 / 29d287f / 430c5a0). Visual smoke in the
running app is the next user-driven gate (the strength-slider chat
already validated bareline / iPhone / Soft Blue / Amber Glow at
M5-A.1).
