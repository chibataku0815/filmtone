# Optical Filter Families — iOS

iOS 側の optical filter family 配線についての product invariants。
件数や spec の現行スナップショットは陳腐化が速いので、ここでは **触ったら壊れること** だけ書く。
canonical 値は `packages/film-lab-core/src/optical-filter-profiles.ts` を一次ソースとして読む。

---

## Backlight Veil (v1.x Phase 1b — 配線済 / dormant)

### 何が landed しているか

- **canonical 値 SSOT**: `packages/film-lab-core/src/optical-filter-profiles.ts` の `family === "backlightVeil"` 3 entry (`backlightVeil-1-8 / -1-4 / -1-2`)。Desktop と 1:1。
- **iOS payload**: `packages/film-lab-core/src/ios-optical-filter-payload.ts` が 12 spatial + 6 optical keys × 3 density を抽出。`packages/film-lab-core/src/ios-optical-filter-payload.test.ts` が値ドリフトを CI で fail させる。
- **codegen 出力**: `bun run generate:ios-swift` が `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneOpticalFiltersGenerated.swift` を生成。`enum FilmtoneOpticalFiltersGenerated.backlightVeilProfiles: [Profile]` として 3 entry。**手動編集禁止**。
- **CI fallback kernel**: `FilmtoneExportSession.swift:OpticalKernels.glowCompositeBacklightVeil` ─ WGSL §4.4 (`composite.frag.wgsl.ts:288-316`) の verbatim CIKernel port。`__sample base/bloom/halation/diffusionImage` + 3 spatial floats + 6 optical floats。
- **Metal kernel**: `FilmtoneMetalOpticsRenderer.swift:filmtoneGlowCompositeBacklightVeil` ─ 同 math の MSL port。`fmtGlowShoulder` / `kFilmtoneLumaWeights` を既存 helper として reuse。
- **renderer dispatch**: `FilmtoneMetalOpticsRenderer.GlowFrameParams` に `opticalScatter: OpticalScatterParams?` を追加。**nil = 既存 path** (legacy `filmtoneGlowComposite` kernel)、**non-nil = 新 path** (Backlight Veil kernel)。`renderOpticsChain` 側で nil 切替。
- **Swift goldens**: `apps/capacitor-film-lab-ios/scripts/swift/test-backlight-veil-composite.swift` が CPU port を 4 sample × 3 density = 12 goldens で 1e-9 tolerance lock。`DUMP_GOLDENS=1` で再キャプチャ可能 (drift 検知後の再生成 workflow)。

### 何が dormant か (Phase 1b スコープ外、Phase 1c で接続)

- **caller 側で `opticalScatter` を非 nil に渡す経路**: `FilmtoneExportSession.applyGlowFamilyStage` → `renderOpticsChain` の組み立て時、Backlight Veil family が選択された時に payload を読み出して `OpticalScatterParams` を組む UI / state path は **未配線**。Phase 1b コミット時点で全 export は legacy kernel を呼び続け、output は byte-equivalent。
- **Editor UI surface**: SwiftUI 側で family を選ぶ chip / section は無い。
- **Sidecar emission**: `FilmtoneExportSidecarBuilder` への `opticalFilterFamily: String?` 追加は未実施 (V1 schema additive 拡張で OK)。

### 不変条件 / 触ったら壊れること

1. **canonical 値の変更は Desktop 側でのみ行う**。`ios-optical-filter-payload.ts` 側で再 tune したら CI test (drift gate) で fail する。再 tune が必要なら `optical-filter-profiles.ts` を変更し、Desktop の視覚 ship gate を再確認した上で iOS payload を再生成。
2. **legacy `filmtoneGlowComposite` / `OpticalKernels.glowComposite` を変更しない**。`opticalScatter == nil` の caller (Stone / Urban / preset 等) は完全 byte-equivalent でなければならない (`feedback_no_silent_fallback`)。
3. **新 kernel の出力は unclamped**。WGSL に倣って `direct + scatter` をそのまま書き、後段 vignette / 8-bit conversion で clamp。clamp を加えると HDR scatter が消える。
4. **codegen 出力 `FilmtoneOpticalFiltersGenerated.swift` を手で書き換えない**。drift は `bun run generate:ios-swift -- --check` で検知。
5. **pbxproj 4-section invariant**: 新 `.swift` 追加時 `PBXBuildFile` / `PBXFileReference` / `PBXSourcesBuildPhase` / `PBXGroup` 4 セクション全登録。`grep <name> ios/App/App.xcodeproj/project.pbxproj | wc -l` ≥ 4 で確認 (`apps/capacitor-film-lab-ios/CLAUDE.md` §3-#4)。

### iOS Phase 1 known limitation (Desktop と完全画素一致しない理由)

Backlight Veil profile は Desktop で **30 keys** を駆動するが、iOS の Phase 1b 実装は **18 keys** (12 spatial + 6 optical) のみを使う。以下 11 keys は **iOS で意図的に inert**:

```
depthMistGain                  depthGlowGain
depthMistRayAngleGain          depthBloomRayAngleGain
depthHalationRayAngleGain      depthMistFieldPsfGain
depthBloomFieldPsfGain         depthHalationFieldPsfGain
depthMistFieldPsfRadiusPx      depthBloomFieldPsfRadiusPx
depthHalationFieldPsfRadiusPx
```

- これらは Desktop WGSL の depth-driven field-PSF / ray-angle gain infrastructure 専用 (`packages/film-lab-renderer/src/webgpu/`)。iOS Metal pipeline には対応する pipeline がない。
- 視覚的影響: bloom / halation / diffusion mip の **field-of-view 依存 PSF radius が iOS では一定**になる。中心と周縁の PSF 差が出ない。
- これは **再 tune では解消できない**。Phase 2 (Desktop でも未着手の専用 veiling-glare shader pass / wide pyramid / anisotropic plate) で iOS / Desktop 両方が解消する前提。

視覚 A/B (Phase 1c で実機 TestFlight or Simulator) で **Desktop の 1/2 と iOS の 1/2 が "破綻しない上限" で一致する** ことを確認するのが Phase 1 の ship gate。微小な FoV-dependent PSF 差は Phase 1 の許容範囲。

### 検証コマンド (changes 後に走らせる)

```bash
# 共有
bun test packages/film-lab-core/src/optical-filter-profiles.test.ts
bun test packages/film-lab-core/src/ios-optical-filter-payload.test.ts
bun run typecheck:shared
bun run build:core

# codegen idempotency
bun run generate:ios-swift -- --check

# Swift goldens
swift apps/capacitor-film-lab-ios/scripts/swift/test-backlight-veil-composite.swift

# iOS build
cd apps/capacitor-film-lab-ios
bun run build
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO

# Phase 0 contract
bun run verify:swift-contract
bun test src/lib/phase0-state.test.ts

# pbxproj 4-section
grep 'FilmtoneOpticalFiltersGenerated' ios/App/App.xcodeproj/project.pbxproj | wc -l   # ≥ 4
```

### Phase 1c / 1d 残タスク (本 lane では触らない)

- **1c**: `FilmtoneEditorStore` / `FilmtoneAdvancedParamsModel` に optical filter family 選択 state を追加、SwiftUI chip strip、`FilmtoneOpticalFiltersGenerated.backlightVeilProfiles` を読み出して `GlowFrameParams.opticalScatter` を非 nil で構築するパスを `FilmtoneExportSession` に接続。
- **1d**: `FilmtoneExportSidecarBuilder` の `Sidecar` struct に `opticalFilterFamily: String?` (additive、V1 schema 維持) を追加し export 時 stamp。
