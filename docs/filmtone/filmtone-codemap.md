# Filmtone Codemap — コード構造の正本

Last updated: 2026-07-19 JST（codemap-feature-audit lane / Wave 0 skeleton）

## これは何か

全 app / package の**構造・責務・入口・生成境界・build/verify 手段**を 1 枚に
集約した canonical code-structure map。`README.md` / `AGENTS.md` の routing 表・
`docs/filmtone/README.md` 索引・`documentation-governance/inventory.md` は、この
codemap の分散した断片であり、本書がその SSOT。「どこを触るか」を決めるときは
まず本書を見る。

読み方:

- **正本は source**。本書は地図であって仕様ではない。挙動・数値の現行仕様は各
  source / package doc を優先する。
- **生成領域は手編集禁止**（下表）。codemap 上も `⚙︎ generated` で明示し、
  リファクタリング・cleanup の対象にしない。再生成は指定コマンドで行う。
- **live lane を尊重**。`davinci-plugin/` / `davinci-bridge/` / `native-desktop-v2`
  の active lane 本文は本書からリンクするだけで改稿しない。

## サーフェス一覧

| サーフェス | 種別 | 主言語 | 役割（要約） | build / verify |
|---|---|---|---|---|
| `packages/film-lab-core` | package | TS | 色計算・schema・preset・LUT・Swift payload の canonical kernel | `bun run build:core` |
| `packages/film-lab-renderer` | package | TS | WebGL / WebGPU renderer | `bun run build:renderer` |
| `packages/film-lab-smart-look` | package | TS | smart look 推論 | `bun run build:smart-look` |
| `packages/film-lab-ui` | package | TS | Desktop / iOS 共通 UI controls | consuming app の verify（専用 script なし） |
| `packages/film-lab-swift-core` | package | Swift | 共有 Swift runtime core | Swift Package build（`generate:ios-swift` で Generated 再生成） |
| `packages/film-lab-codex-mcp` | package | TS | Filmtone automation の MCP server | `bun run verify:filmtone-mcp` / `filmtone:mcp` |
| `apps/filmtone-desktop-macos` | app | Swift | 正式 native macOS Desktop app | `bun run verify:desktop` / `verify:macos` |
| `apps/capacitor-film-lab-ios` | app | Swift | iOS app（native SwiftUI + AVFoundation） | `bun run verify:ios` |
| `apps/filmtone-resolve-ofx` | app | C++/Metal | DaVinci Resolve OFX plugin（2026-07 新規） | app 直下 `Makefile`（**root verify script なし**） |
| `apps/desktop-film-lab-batch` | app | TS | legacy Electron Desktop（**frozen / rollback 専用**） | `bun run verify:legacy-desktop` |

## 生成領域（手編集禁止 ⚙︎）

| パス | 生成元 | 備考 |
|---|---|---|
| `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift` | `bun run generate:ios-swift` | Swift payload 生成物 |
| `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneOpticalFiltersGenerated.swift` | `bun run generate:ios-swift` | optical filter 生成物 |
| `apps/filmtone-resolve-ofx/Sources/Generated/**` | `Scripts/GenerateContracts` | OFX contract 生成物 |
| `packages/film-lab-renderer/dist/**` | `bun run build:renderer` | submodule 消費用に**意図的に track** |
| `packages/film-lab-smart-look/dist/**` | `bun run build:smart-look` | submodule 消費用に**意図的に track** |

## 各サーフェス詳細

各節は Wave 1〜10 の監査で充填する。フォーマット: 役割 / 構造（dir→責務）/
入口・facade / 生成領域 / 責務・feature-arch 所見 / build・verify。

### packages/film-lab-core
- 役割: 色計算・param schema・preset/Look・LUT・native payload 生成の canonical
  kernel（SSOT）。Desktop / iOS / renderer / Resolve が消費。
- 構造（flat `src/`, barrel export, concern 別モジュール）:
  - `params.ts` grade param-key SSOT / `presets.ts` grade catalog + defaults /
    `schema.ts`・`phase0-schema.ts` zod 検証
  - `look-ids.ts` PRESET_VERSION + Look-ID / `ios-*.ts` iOS Swift payload 生成・preset 互換
  - `native-bridge.ts` probe/optics/export bridge + LUT serialize /
    `cube-parser.ts`・`lut-pack-2d.ts` .cube parse + 2D pack
  - `creative-*.ts` Stone/Urban Look 生成 / `optical-filter-profiles.ts`・
    `optical-recommendation.ts` optical profile + scene 推薦
  - `source-profile-conversion.ts` Log→Rec.709 / `film-compression-v3.ts`・
    `shadow-latitude.ts`・`film-breath.ts`・`detail-softness.ts` per-effect 色 math
  - `resolve-spatial-contract.ts` Resolve spatial-optics contract /
    `imported-grade-look.ts` .drx import
- 入口: `src/index.ts`（~30 module barrel）→ `dist/`
- 生成領域: ⚙︎ `dist/`（tsup 出力・track）。`ios-swift-payload.ts` /
  `resolve-spatial-contract.ts` は Swift/C++ 文字列を emit するが hand-written source。
- 所見: **clean**。god object なし（最大 `presets.ts` 864、大半は RAW_PRESETS data
  catalog）。flat namespace だが厳格 single-responsibility のため subdir 化は全
  consumer import を churn させる cosmetic reorg（scope 外）。
- docs: package `docs/`（EFFECT_TERMINOLOGY_SSOT / LUT_2D_PACKING /
  PRESET_VERSIONING）。README なし。
- build/verify: `bun run build:core`

### packages/film-lab-renderer
- 役割: cross-backend（WebGL2 legacy + WebGPU v1.0）fullscreen-quad grade + post-FX
  renderer（Three.js 基盤、browser/desktop）。**消費は web rail**（portfolio
  `apps/web` の WebGPU sub-entry + legacy Electron）。native Metal は非依存。
- 構造: root `Viewport.ts`（backend 切替 wrapper）, `RendererRuntime.ts`
  （capability/context-loss contract）, `MediaLoader.ts`, `support.ts`。
  `webgl/` WebGLBackend + GLSL-as-TS。`webgpu/` WebGPUBackend + 抽出済み helper
  （gradeUniforms/compositeUniforms/crossFilterState/rayAngleOptics/Lut3DTexture 等）+ WGSL-as-TS。
- 入口: default `Viewport`/`WebGLBackend`/`MediaLoader`。`/webgpu` sub-entry
  `GpuContext`/`WebGPUBackend`/GPU primitives。
- 生成領域: ⚙︎ `dist/`（track）, `src/webgpu/assets/blue-noise-256.ts`
  （`scripts/generate-blue-noise.mjs`）
- 所見（2026-07-19 landed）: per-effect GPU pass を feature-vertical module へ分割。
  - `webgpu/WebGPUBackend.ts` **4384 → 2870**: `webgpu/passes/`（bloom / crossFilter /
    diffusion / halation / haloPrism / lightShafts / motionBlur / pyramid / types）へ抽出。
    `bun run build:renderer`（tsup）green。
  - `webgl/WebGLBackend.ts` **2621 → 2257**: `webgl/passes/`（bloom / halation /
    diffusion / lightShafts / motionBlur / crossFilter）へ分割。haloPrism は WebGPU
    専用、dust / detailSoftness は WebGL 固有のため inline 維持。`build:renderer` + tsc green。
  - 呼び出し順は不変に保持。最終の WebGL↔WebGPU 視覚 parity（A/B render）は owner gate。
- docs: README なし。root README:16,25 / AGENTS:45 から routed。
- build/verify: `bun run build:renderer`

### packages/film-lab-smart-look
- 役割: cloud "Smart Look" AI grade-delta の共有 validation/parse/merge library
  （API contract + client 適用のみ、OpenAI/Next 非依存）。
- 構造: 単一 `src/index.ts`（360）— error-code 定数、zod schema（delta / request
  superRefine）、`parseAndClampSmartLookDelta`（step + absolute clamp）、LLM text
  からの balanced-brace JSON 抽出、`computeSmartLookPresetBaseline` /
  `interpolateFilmLabPresetForSmartLook`、`applySmartLookDelta`、consent versioning。
- 入口: schema / parse・clamp・apply・baseline fn / consent helper
- 生成領域: ⚙︎ `dist/`（track）
- 所見: **clean**。single-responsibility 360 行、god object なし。
- docs: README なし（in-file JSDoc 充実）。root README:18 / AGENTS:47 から routed。
- build/verify: `bun run build:smart-look`

### packages/film-lab-ui
- 役割: React UI surface（canvas + control panel + primitives）。**このリポでの
  実消費は legacy Electron `desktop-film-lab-batch`（5 files）+ renderer dev-script
  のみ**。native macOS Desktop（Swift）/ iOS（Swift）は非消費。portfolio web
  preview の消費は repo 外。
- 構造: `src/` flat + `src/ui/` primitives。`FilmLabCanvas.tsx` viewport/render/media,
  `FilmLabControlPanelCore.tsx` grade controls, `film-lab-reducer.ts`
  state/undo/compare, `LUTPanel.tsx`, `VideoTransportControls`/filmstrip,
  contract files, `filmLabPanelTokens.ts`。
- 入口: `src/index.ts`（barrel）, `FilmLabCanvasPackageEntry.tsx`
- 生成領域: なし
- 所見（2026-07-19 landed・package typecheck green）:
  - `FilmLabControlPanelCore.tsx` **2070 → 1204**: 最重量の control family を
    `FinishToolsSection.tsx` + `ui/CollapsibleHeader.tsx` + `ui/PanelControlSlider.tsx`
    へ分割。
  - `FilmLabCanvas.tsx` **2460 → 2381**: 純粋 helper 11 個（closeImageBitmaps /
    getActiveExportParityGeometry / buildViewportParams 等）と dev-probe hook
    （`useDevDepthProbeBitmaps`）は既に module-level 抽出済み。残る forwardRef
    本体（37 useRef / 18 useEffect）は不可分な stateful wiring で、hook 分割は
    forward-reference / stale-closure runtime bug（build 検出不可・web smoke 不可）を
    生むため**強行しない**（product-quality 判断）。
  - 最終の web runtime smoke（canvas 描画 + control 操作）は owner gate。
- docs: README なし。root README:17 / AGENTS:46 から routed。
- build/verify: 専用 script なし（consuming app verify）

### packages/film-lab-swift-core
- 役割: pure-Foundation Phase 0 data layer（CoreImage/SwiftUI/Metal 非依存）。
  iOS / macOS 双方が消費する共有 Swift runtime。
- 構造（`Sources/FilmLabSwiftCore/` flat, one-type-per-file, feature-vertical 命名）:
  - `Editor*` editor contract/command（Panel/Toolbar/Preview/CompareSplit/
    ExportState/LookOperations/SourceProfile/AdvancedAdjust）
  - `Filmtone*` grade param model + effect data（Phase0Params/Patch, QuickState,
    HighlightMarkers, FilmBreath, FilmCompressionV3, VideoTiming, ShadowLatitude,
    DetailSoftness, OpticalFilterEditorCatalog 等）
  - `Phase0OutputProfileDTO` export DTO
- 入口: `FilmLabSwiftCore` library product（`Package.swift`）
- 生成領域: ⚙︎ `Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift`
  （`bun run generate:ios-swift`）
- 所見: **clean**。最大 386 行、one-type-per-file、god object なし。
- docs: README なし（`Package.swift` に Foundation-only scope doc comment）。
- build/verify: Swift Package build（`verify:ios` / `verify:macos` で transitive compile）

### packages/film-lab-codex-mcp
- 役割: Filmtone batch-export + source-inspection を MCP（stdio）として Codex に
  公開する automation server。
- 構造: `src/index.ts` MCP server（tool schema + routing + stdio）/
  `src/automation-client.ts` request 検証 + subprocess client + BatchJobManager +
  HMAC plan 署名 / `src/security.ts` MCP_LIMITS + path policy（allowlist / sensitive
  拒否 / home redaction）
- 入口: `src/index.ts` `createFilmtoneMcpServer()`
- MCP tools（7）: `inspect_sources` / `prepare_filmtone_answer_context` /
  `preview_batch_job`（dry-run, HMAC）/ `start_batch_job` / `get_batch_job_status` /
  `cancel_batch_job` / `summarize_batch_job`。export profile v1 = social1080 / archiveH264。
- 生成領域: なし
- 所見: **clean**。god object なし（`automation-client.ts` 636 は borderline だが
  batch orchestration に cohesive）。
- docs: README なし。索引未登録（root script のみ）。
- build/verify: `bun run verify:filmtone-mcp` / start `bun run filmtone:mcp`

### apps/filmtone-resolve-ofx
- 役割: DaVinci Resolve OFX plugin（`FilmtoneFinish`, C++17/Metal arm64）。Filmtone
  の optics/finish を 1 つの OFX image effect として Resolve 内で適用（2026-07 新規）。
- 構造:
  - `Sources/Host` OFX foundation + 共有 Metal substrate（`FilmtoneFinishPlugin.cpp`
    entry, `ModuleProcessor.h` base, `MetalPipelineCache`, `Spatial/SpatialMetalHost`
    共有 compute host + `SpatialModuleProcessor` base）
  - `Sources/Effects` 8 feature-vertical folder: LensSoftness / DeepGlow / Vignette /
    PeripheralChromaticShift / TextureSoftness / FilmBreath / GateWeave / FilmDamage
  - `Sources/Integration` OFX param describe + render 統括（`FilmtoneFinishParameters`,
    `FilmtoneFinishRenderGraph`, `FilmtoneResolveFactoryDefaults`）
  - `Scripts/GenerateContracts/generate.ts` core contract + SHA256-pinned artifact
    → `Sources/Generated`
- 入口: `Sources/Host/FilmtoneFinishPlugin.cpp`（`getPluginIDs` → `FilmtoneFinishFactory`）
- 生成領域: ⚙︎ `Sources/Generated/Contracts/*.{hpp,json,provenance.json}`
  （`Scripts/GenerateContracts`）
- 所見: **clean — feature-vertical 済み**。god object なし（最大
  `FilmDamageMetalSource.h` 1398 は埋め込み Metal shader raw-string,
  `SpatialMetalHost.mm` 1111 は共有 substrate）。
- 設計 lane（read-only）: `docs/filmtone/davinci-plugin/{strategy,progress,delegation}.md`
  + `workstreams/`, `davinci-bridge/active.md`
- ドリフト所見: (1) root `verify:resolve` script なし（`Makefile` のみ、CI/verify
  統括から不可視）(2) 全索引 routing 未登録 (3) app-dir README なし
- build/verify: app 直下 `make`（`OFX_SDK_ROOT` 依存）→ `build/FilmtoneFinish.ofx.bundle`

### apps/filmtone-desktop-macos
- 役割: 正式 native SwiftUI/AppKit macOS Desktop。still/video open → Look/grade/optics
  preview → still/video export。共有ロジックは `import FilmLabSwiftCore`。
- 構造: `App/` @main + Help menu / `Color/`（24 files: grade/preset pipeline, CIKL
  kernel, source-profile math, LUT parse, imported-grade/saved-look store,
  creative-pack）/ `Domain/` pure value type/catalog / `Export/` still/video exporter
  + sidecar / `Media/` AVFoundation probe/read/write/composition/thumbnail /
  `State/` EditorState store + Export/DRX/capture/imported-grade coordinator +
  view model / `UI/`（13: root window, preview, inspector/export panel,
  Look/adjust/glass control）/ `Verify/` hand-rolled test-runner（非 XCTest）/
  `AutomationCLI/` MCP/STDIO batch CLI
- 入口/facade: `App/FilmtoneDesktopApp.swift` @main → `UI/RootWindowView.swift` →
  `State/EditorState.swift`（@MainActor @Observable 中央 store）。grade facade
  `Color/FilmtoneGradePipeline.apply()`
- 生成領域: app 内なし（codegen は swift-core 対象）
- 所見: **largely clean** — layer 分離実在、coordinator/view-model 抽出済み、真の
  god object なし。watch-item（urgent でない・named product move なし）:
  `UI/RootWindowView.swift` 1366 が SwiftUI view + ~350 行 NSWindow geometry engine
  混在（window UX 反復時に `WindowGeometry` 抽出候補）。`AutomationCLI/
  FilmtoneAutomationCore.swift` 950 は DTO + SecurityPolicy + executor の 3 責務
  （CLI 成長時に SecurityPolicy 抽出候補）。
- docs: app-local README。root README:11 / AGENTS:20,40 / desktop/README /
  native-desktop-v2/strategy から routed。active.md なし（open subtask なし）。
- build/verify: `bun run verify:desktop`（→ `verify:macos` xcodebuild）

### apps/capacitor-film-lab-ios
- 役割: native SwiftUI iOS app（live UI = `FilmtoneRootView`）。capture → adopt →
  grade → export + ExportActivity Live Activity extension。旧 React/Capacitor は purged。
- 構造（feature folder, **flat-root source ゼロ**）: `Root/`(6 app shell) /
  `Capture/`(33, `FilmtoneCaptureSession` facade + **Internal**/4:
  DeviceManager/RecordingStateController/AudioSupport/PackageAssembler) /
  `Editor/`(33, `FilmtoneEditorStore` facade + **Internal**/6:
  PreviewOrchestrator/ProjectMutationCoordinator/ExportCoordinator/CaptureRelay/
  LibraryController/ProjectController) / `Export/`(39, `FilmtoneExportSession`
  orchestrator + SidecarBuilder + **Internal**/28 collaborator) / `Look/`(12,
  LookDirector/CreativePack01/ColorPipeline) / `Optics/`(8, MetalOpticsRenderer) /
  `Source/`(12) / `Services/`(13, Mezzanine/AssetPicker) / `Smoke/`(4, device harness) /
  `Strings/`(1) / `FilmtoneExportActivity/`(3, extension)
- 入口/facade: `Root/FilmtoneRootView`; `FilmtoneEditorStore`; `FilmtoneCaptureSession`;
  `FilmtoneExportSession`
- 生成領域: ⚙︎ `Optics/FilmtoneOpticalFiltersGenerated.swift`（`generate:ios-swift`）。
  `Export/Internal/OpticalKernels.swift` 1263 は hand-written collaborator（非生成）。
- 所見: **feature folder 維持・flat-root ゼロ**。god-object リグロース 2 件は
  **分割済み（2026-07-19 landed・`bun run verify:ios` build + contract gate green）**:
  - `Editor/FilmtoneEditorStore.swift` **2002 → 1517**: live-preview grade-processor
    factory を `Editor/Internal/EditorPreviewGradeFactory.swift`(474) へ、project
    recompute を `Editor/Internal/EditorProjectRecomputeController.swift`(208) へ抽出。
    stale MARK 修正。
  - `Export/FilmtoneExportSession.swift` **1281 → 1097**: per-frame grade STAGE
    pipeline（applyGrade/applyVideoMotionStage/applyGrainStage/applyFilmDamageStage/
    paramsApplyingFilmBreath 等）を既存 `Export/Internal/GradeRenderPipeline.swift` へ集約。
  - schema-owner-ok: Strings 2010, ExportSidecarBuilder 2000。test-harness-ok:
    Smoke 1743/1396/1081。view-body: FullscreenLutEditor 1307, CaptureView 1089。
  - 最終の record→adopt→grade→export の device smoke は owner gate（未実行）。
- docs: app `CLAUDE.md`（**実 139 行。root CLAUDE.md §4/§8 の "223 行" は doc-drift**）。
  root README:14 / AGENTS:26,43 / docs/filmtone/README / ios/README から routed。app
  `docs/`（builtin-catalog / optical-filter-families / source-profile-math）。
- build/verify: `bun run verify:ios`（CLAUDE.md:48 の xcodebuild -workspace）

### apps/desktop-film-lab-batch
- 役割: **frozen legacy Electron Desktop**（rollback / legacy 明示時のみ触る）。
  film-lab-ui / renderer / core / smart-look を消費する web rail 実装。
- 構造: `src/renderer/`（66 files, React UI + video export pipeline）, `electron/`
  （main process / video-src-protocol）, `test/`（Playwright golden / PSNR）
- 生成領域: `dist/`（build 出力）
- 所見（**分類のみ・refactor 禁止**）: god object 複数（`src/renderer/App.tsx`
  **3362**, `video-export-pipeline.ts` 1761, `video-export-webcodecs.ts` 1538,
  `batch-tab/BatchTabPanel.tsx` 1341）。frozen rail のため**本ループの改修対象外**。
  現行製品は native macOS Desktop（`apps/filmtone-desktop-macos`）。
- docs: app-local README（`CLAUDE.md` は未作成 = legacy 不変条件顕在時に user 指示で追加）。
- build/verify: `bun run verify:legacy-desktop`

## Refactor Log（2026-07-19 実行）

監査で検出した god object を分割実行。検証は各サーフェスの build gate（テスト
スイートは §0 により不使用）。抽出は verbatim（logic/呼び出し順不変）。build は
動作保存を完全証明しないため、最終確認は owner gate（下表）で行う。clean 判定の
core / smart-look / swift-core / codex-mcp / resolve-ofx(code) / desktop-macos は対象外。

| # | 対象 | 実行結果 | build 検証 | owner gate（未実行） |
|---|---|---|---|---|
| R3 | iOS ExportSession grade stage → 既存 `Export/Internal/GradeRenderPipeline` | **landed** 1281→1097 | `verify:ios` build + contract gate green | 実機 export |
| R4 | iOS EditorStore preview factory → 新 `Editor/Internal/EditorPreviewGradeFactory`(474) | **landed** EditorStore 2002→1517・pbxproj 登録済 | 同上 | 実機 grade/preview |
| R5 | iOS EditorStore recompute → 新 `Editor/Internal/EditorProjectRecomputeController`(208) | **landed** | 同上 | 実機 |
| R1 | renderer pass module 抽出 | **landed** WebGPU 4384→2870・WebGL 2621→2257（`webgpu/passes/` 9 + `webgl/passes/` 6, 呼び出し順不変） | `build:renderer` + tsc green | WebGL↔WebGPU 視覚 parity A/B |
| R2 | ui god object 分割 | Panel **landed** ControlPanelCore 2070→1204（FinishToolsSection + 2 support）。Canvas は安全 helper 抽出済で残余は不可分 stateful wiring のため非強行 | package typecheck green | web runtime（canvas/control） |

watch-item（named move 発生時）: desktop-macos `UI/RootWindowView.swift` NSWindow
geometry → `WindowGeometry` 抽出 / `AutomationCLI/FilmtoneAutomationCore.swift`
SecurityPolicy 抽出。scope 外（frozen）: legacy Electron `desktop-film-lab-batch`
（App.tsx 3362 等）。

## 索引との整合

本 codemap と以下の routing は同じ現実を指す。ドリフト時は本書を更新し、各索引を
合わせる（Wave Z で reconcile）:

- `README.md` Primary Surfaces
- `AGENTS.md` Routing 表
- `docs/filmtone/README.md` ディレクトリ構成
- `.ai/GLOBAL.md` プロジェクト概要 / `.ai/parallel-work.md` ディレクトリ分離表
- `documentation-governance/inventory.md` Classification
