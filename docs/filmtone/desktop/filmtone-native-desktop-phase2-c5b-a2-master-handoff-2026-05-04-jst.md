# Filmtone Native Desktop v2 — Phase 2 C5b A.2 Master Handoff
**Date**: 2026-05-04 JST
**Status**: Phase 2 C5b A.1 (bloom) COMPLETE (uncommitted) → next: C5b A.2 (halation + diffusion)
**Worktree**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
**Branch**: `feature/native-desktop-plan`
**HEAD**: `cda0f9f` feat(macos): Phase 2 C5c RayAngleOptics port + master handoff
**Uncommitted**: `FilmtoneGradeKernels.swift` + `FilmtoneGradePipeline.swift` + `04-phase-plan.md` + `06-quality-gates-risks.md` (C5b A.1 changes)

---

## §1 プロジェクト全体文脈

**Filmtone**: 映像グレーディング iOS/macOS アプリ。フィルムルック (Kodak/Fuji 風) を CIColorKernel チェーンで実現。公開済 iOS 1.2、開発中 iOS 1.3、Electron Desktop (WebGL/ffmpeg)。

**Native Desktop v2**: Electron を SwiftUI + AVFoundation + CoreImage に置き換えるレーン。既存 Electron Desktop 1.x の release rail に影響を与えずに並行開発。目標: iOS canonical CIColorKernel pipeline をそのまま macOS で動かし PSNR 同等出力を得る。

**モノレポ構成**:
```
filmtone/
├── apps/
│   ├── filmtone-desktop-macos/          ← macOS Native v2 (このチャットで触る)
│   │   └── FilmtoneDesktop/
│   │       ├── Color/
│   │       │   ├── FilmtoneGradeKernels.swift   ← CIKernel strings
│   │       │   ├── FilmtoneGradePipeline.swift  ← grade stage orchestrator
│   │       │   ├── FilmtoneColorPipeline.swift  ← source color contract
│   │       │   ├── SourceColorMetadataNormalizer.swift
│   │       │   ├── SourceColorClassifier.swift
│   │       │   ├── FilmtoneRayAngleOptics.swift ← C5c: ray-angle vignette
│   │       │   └── CameraOpticsDTO.swift
│   │       ├── Domain/
│   │       │   ├── FilmtonePhase0Generated.swift  ← bun generate:ios-swift 出力 (手編集禁止)
│   │       │   ├── FilmtonePhase0Params.swift
│   │       │   └── SourceColorTypes.swift
│   │       ├── Export/
│   │       │   ├── FilmtoneStillExporter.swift
│   │       │   ├── FilmtoneVideoExporter.swift
│   │       │   ├── FilmtoneSidecarWriter.swift
│   │       │   └── FilmtoneSidecarTypes.swift
│   │       └── Media/
│   │           ├── FilmtoneVideoReader.swift
│   │           ├── FilmtoneVideoWriter.swift
│   │           ├── FilmtoneVideoFramePreview.swift
│   │           ├── FilmtoneSourceProber.swift
│   │           └── FormatExtensionReader.swift
│   ├── capacitor-film-lab-ios/  ← iOS 正本 (絶対に変更しない)
│   │   └── ios/App/App/FilmtoneExportSession.swift  ← iOS pipeline (4554 行)
│   └── desktop-film-lab-batch/  ← Electron Desktop (影響させない)
└── packages/film-lab-core/       ← TS shared (影響させない)
```

**Worktree パス**: Native Desktop v2 は main branch の外側、専用 worktree で開発。
```bash
# worktree の場所
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/
# このパスで git コマンドを実行 (main repo とは別の branch)
```

---

## §2 達成済み実装サマリー (Phase 0 → C5b A.1)

### Phase 0 + 1a (commit `398743c`)
- Xcode project 作成、SwiftUI main window、buildable 空 app
- `FilmtonePhase0Generated.swift` wiring (bun generate:ios-swift 出力)
- CLI mode (コマンドライン引数で grade → export 実行)

### Phase 1b (commit `398743c` — 同 commit に含む)
- `FilmtoneGradeKernels.swift`: baseGradeV2 + filmCompressionV2 + printStage CIColorKernel (iOS OpticalKernels verbatim lift)
- `FilmtoneGradePipeline.apply()`: baseGradeV2 → filmCompressionV2 → printStage
- Still export (PNG/JPEG) + sidecar (Case B: lookId/lookVersion only、Look Unification 未 landed)
- PSNR: reset ∞ dB (source byte-identical)、iphone 39.62 dB vs source

### Phase 1c (commit `398743c` — 同 commit に含む)
- `FilmtoneVideoReader/Writer/FramePreview.swift`: AVAssetReader/Writer H.264 MP4 + Rec.709
- `FilmtoneVideoExporter.swift`: per-frame CIImage → grade → render → append
- UI: `.mov/.mp4` open、Export ProgressView + Cancel

### Phase 2 C1 + C2 (commit `aeb0c7c`)
- `SourceColorTypes.swift`: SourceColorClassDTO (8 cases) + SourceColorMetadataDTO
- `SourceColorMetadataNormalizer.swift`: CMFormatDescription → ffprobe vocab
- `SourceColorClassifier.swift`: classify() → SourceColorClassDTO
- `FilmtoneColorPipeline.swift`: defaultOutputContract factory
- `FilmtoneSourceProber.swift`: probeVideo() async (modern AVFoundation API)
- AVFoundation modern async API migration: `loadTracks` / `load(.duration)` / `generator.image(at:)` に 6 箇所 migrate

### Phase 2 C3 (commit `aeb0c7c` — 同 commit に含む)
- baseline-C scaffold: `apps/desktop-film-lab-batch/test/golden/baseline-C/` 4 preset subdir
- `scripts/golden-parity-ios-vs-macos.ts` PENDING-aware harness
- **baseline-C コンテンツ自体は PENDING** (iOS Simulator workflow で populate 待ち、外殻扱いで defer)

### Phase 2 C5a (commit `cd170a6`)
- `FilmtoneGradeKernels.swift`: vignette + grain CIColorKernel 追加 (iOS OpticalKernels verbatim)
- `FilmtoneGradePipeline.apply()`: vignette + grain を iOS canonical 順で挿入
  → `baseGradeV2 → filmCompressionV2 → vignette → grain → printStage`

### Phase 2 C5c (commit `cda0f9f`)
- `CameraOpticsDTO.swift`: iOS L1-46 verbatim (source / horizontalFovDegrees / etc.)
- `FilmtoneRayAngleOptics.swift`: resolve() + kernelArgs() (iOS verbatim)
- `FilmtoneSourceProber.swift`: video camera optics 抽出 (CMFormatDescription HorizontalFieldOfView)
- vignette call site: `applyMask = (cameraOptics?.source == "metadata") ? 1.0 : 0.0`
  → source=="metadata" 時のみ ray-angle mask ON、otherwise pre-C5c byte-identical
- AVMetadataItem deprecated API (`commonMetadata` / `metadata` / `stringValue`) を modern async API へ移行

### Phase 2 C5b A.1 (uncommitted — 現在の作業 HEAD)
- **`FilmtoneGradeKernels.swift`**: 4 kernel 追加
  - `softKneeHighlight` (CIColorKernel): highlight plate extraction
  - `glowComposite` (CIColorKernel): bloom + halation + diffusion energy compositing
  - `tentDownsample` (CIKernel): mirror-padded 13-tap mip downsample
  - `tentUpsample` (CIKernel): mirror-padded 9-tap mip upsample
- **`FilmtoneGradePipeline.swift`**: 全面更新
  - glow pyramid 定数 (iOS verbatim): `glowBaseScale=0.5`, `bloomSpreadBoost=1.25`, `halationSpreadDivisor=12.0`, `diffusionCompositeBase=0.87`, `bloomMipLevels=6`, `halationMipLevels=6`, `diffusionMipLevels=4`, `glowUpsampleBlurRadius=1.0`
  - `applyGlowFamilyStage()` 追加 (bloom active、halation/diffusion plates = black)
  - 全 helper: `extractHighlightPlate`, `buildMipBlurComposite`, `buildMipPyramid`, `tentDownsampledImage`, `tentUpsampledImage`, `downsampledImage`, `upsampledImage`, `scaledImage`, `weightedImage`, `addImages`, `blackImage`, `extentOriginVector`, `extentSizeVector`, `computeMipWeights`, `clampValue`
  - pipeline 更新: `baseGradeV2 → filmCompressionV2 → **glowFamily** → vignette → grain → printStage`
- **PSNR 変化 (EXPECTED)**:
  - `paramsByName["reset"]` は `bloomStrength=0.22` を持つ named preset → bloom active → reset ≠ ∞ dB は正常
  - reset preset: `macOS↔source ≒ 40.05 dB` (bloom active による変化)
  - iphone preset: `macOS↔source ≒ 35.59 dB`
  - `resetParams` (identity params、bloomStrength=0.0) は今後も ∞ dB を維持

---

## §3 現在のコードベース状態

### `FilmtoneGradeKernels.swift` (C5b A.1 後、327 行)

```
CIColorKernel 一覧:
  baseGradeV2          (Phase 1b)
  filmCompressionV2    (Phase 1b)
  printStage           (Phase 1b)
  vignette             (C5a)
  grain                (C5a)
  softKneeHighlight    (C5b A.1) ← highlight plate extraction
  glowComposite        (C5b A.1) ← bloom + halation + diffusion composite

CIKernel 一覧:
  tentDownsample       (C5b A.1) ← mirror-padded 13-tap
  tentUpsample         (C5b A.1) ← mirror-padded 9-tap
```

`CIColorKernel(source:)` deprecation: 9 箇所 (Phase 1b 3 + C5a 2 + C5b A.1 4)
Metal CIKernel 移行は別 lane (C7 または後続 chunk)。

### `FilmtoneGradePipeline.swift` (C5b A.1 後、437 行)

現在の pipeline (iOS canonical 準拠):
```
baseGradeV2 → filmCompressionV2 → applyGlowFamilyStage → vignette → grain → printStage
```

iOS 正本 pipeline:
```
baseGradeV2 → filmCompressionV2 → edgeOptics → glowFamily → vignette → grain → printStage
```

edgeOptics (radialRGBSplit + edgeSoftnessBlend) は C5b A.3 で追加予定。

### applyGlowFamilyStage の現在実装

```swift
private static func applyGlowFamilyStage(to image: CIImage, params: FilmtonePhase0Params) -> CIImage {
    guard
        params.bloomStrength > 0.0001 ||
        params.halationIntensity > 0.0001 ||
        params.diffusion > 0.0001
    else { return image }

    let extent = image.extent
    let black = blackImage(for: extent)

    let bloomImage: CIImage
    if params.bloomStrength > 0.0001 {
        let bloomPlate = extractHighlightPlate(
            from: image,
            threshold: params.bloomThreshold,
            knee: params.bloomSoftKnee,
            tintColor: CIColor(red: 1, green: 1, blue: 1, alpha: 1)
        )
        bloomImage = buildMipBlurComposite(
            from: bloomPlate,
            radius: params.bloomRadius,
            levelCount: bloomMipLevels,
            spreadMultiplier: bloomSpreadBoost,
            useTentResampling: true
        )
    } else {
        bloomImage = black
    }

    // C5b A.2: halation + diffusion plates (currently black)
    let halationImage: CIImage = black
    let diffusionImage: CIImage = black

    guard let kernel = FilmtoneGradeKernels.glowComposite else { return image }
    return kernel.apply(extent: extent, arguments: [
        image, bloomImage, halationImage, diffusionImage,
        params.bloomStrength, params.halationIntensity, params.diffusion, diffusionCompositeBase,
    ]) ?? image
}
```

---

## §4 git 状態

```
HEAD:   cda0f9f  feat(macos): Phase 2 C5c RayAngleOptics port + master handoff
Branch: feature/native-desktop-plan
Worktree: /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/

Uncommitted changes (C5b A.1):
  M apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift
  M apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift
  M docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md
  M docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/06-quality-gates-risks.md
```

**C5b A.1 commit コマンド** (C5b A.2 着地後にまとめてもよい):
```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
git add apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift
git add apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift
git add docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md
git add docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/06-quality-gates-risks.md
git commit -m "feat(macos): Phase 2 C5b A.1 bloom mip pyramid (softKneeHighlight + tentDownsample/Up + glowComposite)"
```

---

## §5 不変条件 (違反禁止)

| 番号 | ルール |
|------|--------|
| INV-1 | `apps/capacitor-film-lab-ios/` を一切編集しない。iOS Xcode project は触れない |
| INV-2 | `packages/film-lab-core/src/` を編集しない (sidecar schema 変更禁止、additive-only) |
| INV-3 | `FilmtonePhase0Generated.swift` を手編集しない (`bun run generate:ios-swift` 出力を使う) |
| INV-4 | iOS kernel sources を verbatim lift する (macOS で最適化・改変しない) |
| INV-5 | Look Unification 未 landed → sidecar は Case B (lookId/lookVersion only) を継続 |
| INV-6 | bun 必須 (`npm` 禁止) |
| INV-7 | git commit は user が実行 (Claude は commit しない) |
| INV-8 | CIKernel-based stages (radialRGBSplit / edgeSoftnessBlend) は C5b A.3 まで defer |
| INV-9 | `Swift.min` / `Swift.max` を使う (`min` / `max` は GLSL と曖昧になる可能性あり) |
| INV-10 | `clamp` 関数名は Swift で `clampValue` に rename (iOS iOS pipeline では `clamp` が static func として定義されているが、macOS では Swift 標準の `min/max` 混在で曖昧) |

---

## §6 C5b A.2 実装計画 — halation + diffusion plates

### iOS 正本コード (FilmtoneExportSession.swift)

**halation plate** (L1839-1874):
```swift
let halationImage: CIImage
if params.halationIntensity > 0.0001 {
    // depthCI prefilter は macOS では skip (depth map なし)
    let halationPlate = extractHighlightPlate(
        from: image,   // ← depthCI なしなので image をそのまま
        threshold: params.halationThreshold,
        knee: params.halationSoftKnee,
        tintColor: Self.halationColor(for: params.halationHue)  // ← 赤〜オレンジ色
    )
    halationImage = buildMipBlurComposite(
        from: halationPlate,
        radius: params.halationRadius,
        levelCount: Self.halationMipLevels,       // = 6
        spreadMultiplier: 1.0 + max(params.halationSpread, 0) / Self.halationSpreadDivisor,
        // = 1.0 + halationSpread / 12.0
        useTentResampling: true
    )
} else {
    halationImage = black
}
```

**diffusion plate** (L1876-1905):
```swift
let diffusionImage: CIImage
if params.diffusion > 0.0001 {
    // depthCI prefilter は macOS では skip
    diffusionImage = buildMipBlurComposite(
        from: image,   // ← highlight plate extraction なし、image 全体をぼかす
        radius: 0.9,   // ← 固定値 (params.diffusion ではない)
        levelCount: Self.diffusionMipLevels,      // = 4
        spreadMultiplier: 1.15,                    // ← 固定値
        useTentResampling: true
    )
} else {
    diffusionImage = black
}
```

**`halationColor` helper** (L2392-2398):
```swift
private static func halationColor(for hue: Double) -> CIColor {
    let t = clamp(hue / 100.0)  // hue は 0-100 の range
    let red   = (0xe8 + ((0xc8 - 0xe8) * t)) / 255.0  // = 232 → 200
    let green = (0x10 + ((0x60 - 0x10) * t)) / 255.0  // =  16 →  96
    let blue  = (0x20 + ((0x10 - 0x20) * t)) / 255.0  // =  32 →  16
    return CIColor(red: red, green: green, blue: blue, alpha: 1)
}
```
- hue=0 → 赤 (#E81020)、hue=100 → オレンジ (#C06010)

### macOS 実装コード (変更箇所のみ)

`FilmtoneGradePipeline.swift` の `applyGlowFamilyStage` の `// C5b A.2` コメント部分を以下に置換:

```swift
// C5b A.1 commit 時はこのコードに差し替え:

let halationImage: CIImage
if params.halationIntensity > 0.0001 {
    let halationPlate = extractHighlightPlate(
        from: image,
        threshold: params.halationThreshold,
        knee: params.halationSoftKnee,
        tintColor: halationColor(for: params.halationHue)
    )
    halationImage = buildMipBlurComposite(
        from: halationPlate,
        radius: params.halationRadius,
        levelCount: halationMipLevels,
        spreadMultiplier: 1.0 + Swift.max(params.halationSpread, 0) / halationSpreadDivisor,
        useTentResampling: true
    )
} else {
    halationImage = black
}

let diffusionImage: CIImage
if params.diffusion > 0.0001 {
    diffusionImage = buildMipBlurComposite(
        from: image,
        radius: 0.9,
        levelCount: diffusionMipLevels,
        spreadMultiplier: 1.15,
        useTentResampling: true
    )
} else {
    diffusionImage = black
}
```

### halationColor helper を FilmtoneGradePipeline に追加

`clampValue` の直前 (またはどこか private static func の後) に追加:

```swift
private static func halationColor(for hue: Double) -> CIColor {
    let t = clampValue(hue / 100.0)
    let red   = (0xe8 + ((0xc8 - 0xe8) * t)) / 255.0
    let green = (0x10 + ((0x60 - 0x10) * t)) / 255.0
    let blue  = (0x20 + ((0x10 - 0x20) * t)) / 255.0
    return CIColor(red: red, green: green, blue: blue, alpha: 1)
}
```

### params フィールド確認

`FilmtonePhase0Params` に以下のフィールドが既に存在することを確認してから実装する:
```bash
grep -n "halation\|diffusion" apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtonePhase0Params.swift
```
期待: `halationIntensity`, `halationThreshold`, `halationSoftKnee`, `halationRadius`, `halationHue`, `halationSpread`, `diffusion` がある。

もし存在しない場合は `FilmtonePhase0Generated.swift` から確認:
```bash
grep -n "halation\|diffusion" apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtonePhase0Generated.swift
```

---

## §7 C5b A.2 実装手順

1. **前提確認** (grep でパラメータ存在確認):
   ```bash
   cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
   grep -n "halation\|halationHue\|halationSpread\|diffusion" \
     apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtonePhase0Params.swift
   ```

2. **`FilmtoneGradePipeline.swift` 編集**:
   - `applyGlowFamilyStage` の `let halationImage: CIImage = black` と `let diffusionImage: CIImage = black` を §6 のコードに置換
   - `halationColor(for:)` static func を追加

3. **build 確認**:
   ```bash
   bun run verify:macos 2>&1 | tail -5
   ```
   期待: `BUILD SUCCEEDED`

4. **PSNR 確認**:
   ```bash
   bun run scripts/golden-parity-macos.ts --preset iphone 2>&1 | grep -E "PSNR|dB|avg"
   ```
   - A.2 後の期待値: iphone preset で halation active → PSNR は A.1 の 35.59 dB からさらに変化する可能性あり
   - halation は赤オレンジ tint の highlight blur → iphone preset の `halationIntensity` 値による

5. **plan docs 更新**:
   - `04-phase-plan.md`: C5b A.2 行を COMPLETE に更新、着地状況セクション追加
   - `06-quality-gates-risks.md`: 新 PSNR baseline を記録

---

## §8 C5b A.3 (次次 chunk) 概要

`radialRGBSplit` + `edgeSoftnessBlend` の CIKernel port + `applyEdgeOpticsStage`。

**iOS 正本** (FilmtoneExportSession.swift L1702-1722):
```swift
private func applyEdgeOpticsStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
    var current = image
    if params.rgbShift > 0.0001 {
        current = applyRadialRGBShift(params.rgbShift, to: current)
    }
    let rgbShiftNormalized = Self.clamp(params.rgbShift / max(FilmtonePhase0Generated.rgbShiftMax, 0.0001))
    let aberrationSoften = Self.aberrationEdgeSoften(for: rgbShiftNormalized)
    if aberrationSoften > 0.0001 || params.lensSoftness > 0.0001 {
        current = applyEdgeSoftness(to: current, aberrationSoften: aberrationSoften, lensSoftness: params.lensSoftness)
    }
    return current
}
```

**挿入位置**: `filmCompressionV2` の直後、`glowFamily` の前 (iOS canonical)。

**CIKernel sources**: iOS OpticalKernels から `radialRGBSplit` + `edgeSoftnessBlend` を verbatim lift。

---

## §9 Sanity Check (次チャット冒頭で実行)

```bash
# 1. worktree の場所確認
ls /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/apps/filmtone-desktop-macos/

# 2. git 状態
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
git log --oneline -5
git status --short

# 3. build
bun run verify:macos 2>&1 | tail -5

# 4. 現在の PSNR baseline (C5b A.1 uncommitted 状態)
bun run scripts/golden-parity-macos.ts --preset reset 2>&1 | grep -E "PSNR|avg|dB" | head -5
bun run scripts/golden-parity-macos.ts --preset iphone 2>&1 | grep -E "PSNR|avg|dB" | head -5
```

**期待結果 (C5b A.1 uncommitted 状態)**:
- `git log` → HEAD = `cda0f9f`、uncommitted M × 4
- build: `BUILD SUCCEEDED`
- PSNR reset: `macOS↔source ≒ 40.05 dB` (bloom active、∞ dB でなくなった = 正常)
- PSNR iphone: `macOS↔source ≒ 35.59 dB`

**Look Unification 着地確認** (C5b A.2 開始前):
```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
```
- 何も出力されない = Look Unification 未 landed → Case B sidecar 継続 (正常)
- 何か出力される = Look Unification landed → sidecar を Case A (dual emit) に切替が必要

---

## §10 全体進捗マップ

```
Phase 0+1a  [✅ 398743c]  Xcode project + SwiftUI skeleton + Phase0 contract
Phase 1b    [✅ 398743c]  CIKernel grade (baseGrade+filmComp+print) + still export + sidecar
Phase 1c    [✅ 398743c]  video open/preview/export (AVFoundation)
Phase 2 C1  [✅ aeb0c7c]  SourceColor DTO + classifier + color pipeline factory
Phase 2 C2  [✅ aeb0c7c]  AVFoundation modern async + Swift 6 concurrency (同 commit)
Phase 2 C3  [✅ aeb0c7c]  baseline-C scaffold (content PENDING、外殻 defer)
Phase 2 C5a [✅ cd170a6]  vignette + grain CIKernel
Phase 2 C5c [✅ cda0f9f]  RayAngleOptics + camera optics probe
Phase 2 C5b A.1 [🔶 uncommitted]  bloom mip pyramid ← 今ここ
Phase 2 C5b A.2 [⬜ next]  halation + diffusion plates ← 次チャット推奨
Phase 2 C5b A.3 [⬜ TBD]   edgeOptics (radialRGBSplit + edgeSoftnessBlend)
Phase 2 C6  [⬜ 急がない]  SPM film-lab-swift-core 化
Phase 2 C7  [✅ measurement only]  IOSurface/Metal perf (4K 80fps確認、refactor 不要)
Phase 3+    [⬜ future]   Look Unification dual emit、Continuity、Resolve .cube
```

---

## §11 ios canonical params (iphone preset) — PSNR 参照

`FilmtonePhase0Generated.swift` の `paramsByName["iphone"]` から取得:
- bloomStrength > 0 → bloom active
- halationIntensity の値によって A.2 後の PSNR 変化量が決まる
- 正確な値は実装前に `grep -A 40 '"iphone"' apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtonePhase0Generated.swift` で確認

---

## §12 参照ファイル一覧

| ファイル | 内容 | 行番号参考 |
|---------|------|------------|
| iOS `FilmtoneExportSession.swift` | iOS pipeline 正本 (4554 行) | — |
| iOS L1540-1567 | iOS pipeline stage order (applyGlowFamilyStage 呼び出し位置) | — |
| iOS L1724-1934 | `applyGlowFamilyStage` 全実装 (bloom + halation + diffusion) | — |
| iOS L1839-1874 | halation plate 実装 | — |
| iOS L1876-1905 | diffusion plate 実装 | — |
| iOS L2392-2398 | `halationColor(for:)` helper | — |
| iOS L4227-4263 | `softKneeHighlight` + `glowComposite` kernel GLSL | — |
| iOS L4424-4498 | `tentDownsample` + `tentUpsample` kernel GLSL | — |
| macOS `FilmtoneGradeKernels.swift` | kernel strings (現在 327 行) | — |
| macOS `FilmtoneGradePipeline.swift` | grade orchestrator (現在 437 行) | — |
| `04-phase-plan.md` | Phase 計画 + 各 chunk 着地状況 | — |
| `06-quality-gates-risks.md` | quality gate + risk table (C5b A.1 PSNR 変化記録) | — |

---

## §13 最高精度引き継ぎプロンプト (次チャット冒頭ペースト用)

```
You are continuing Filmtone Native Desktop v2 development from a handoff document.

## Context

- Project: Filmtone — film-look grading iOS/macOS app. Native Desktop v2 replaces the Electron desktop with SwiftUI + AVFoundation + CoreImage.
- Worktree: /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/ (branch: feature/native-desktop-plan)
- iOS canonical reference: apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift (4554 lines) — NEVER modify this file.
- macOS grade pipeline: apps/filmtone-desktop-macos/FilmtoneDesktop/Color/

## Current git state

HEAD: cda0f9f feat(macos): Phase 2 C5c RayAngleOptics port + master handoff

Uncommitted changes (Phase 2 C5b A.1 — bloom mip pyramid — COMPLETE but not committed):
  M apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift
  M apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift
  M docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md
  M docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/06-quality-gates-risks.md

## What was done in C5b A.1 (uncommitted)

Added 4 kernels to FilmtoneGradeKernels.swift (verbatim from iOS OpticalKernels):
- softKneeHighlight (CIColorKernel): highlight plate extraction
- glowComposite (CIColorKernel): bloom + halation + diffusion energy composite
- tentDownsample (CIKernel): mirror-padded 13-tap mip downsample
- tentUpsample (CIKernel): mirror-padded 9-tap mip upsample

Updated FilmtoneGradePipeline.swift (~437 lines):
- Glow pyramid constants: glowBaseScale=0.5, bloomSpreadBoost=1.25, halationSpreadDivisor=12.0, diffusionCompositeBase=0.87, bloomMipLevels=6, halationMipLevels=6, diffusionMipLevels=4, glowUpsampleBlurRadius=1.0
- applyGlowFamilyStage() added: bloom plate ACTIVE, halation + diffusion = black placeholder
- Pipeline: baseGradeV2 → filmCompressionV2 → glowFamily → vignette → grain → printStage
- All pyramid helpers added (verbatim from iOS)

PSNR change (expected):
- reset preset: ~40.05 dB (was ∞ dB; paramsByName["reset"].bloomStrength=0.22 activates bloom)
- iphone preset: ~35.59 dB

## Next task: Phase 2 C5b A.2 — halation + diffusion plates

Implement halation and diffusion plates in applyGlowFamilyStage(), replacing the black placeholders.

### Step 1: Sanity check

Run these first and report results:
```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
git log --oneline -5
git status --short
bun run verify:macos 2>&1 | tail -3
bun run scripts/golden-parity-macos.ts --preset reset 2>&1 | grep -E "PSNR|avg" | head -3
bun run scripts/golden-parity-macos.ts --preset iphone 2>&1 | grep -E "PSNR|avg" | head -3
```

Expected: HEAD=cda0f9f, 4 uncommitted M, BUILD SUCCEEDED, reset≈40dB, iphone≈35.59dB.

### Step 2: Check halation/diffusion params exist

```bash
grep -n "halation\|halationHue\|halationSpread\|diffusion" \
  apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtonePhase0Params.swift
```

### Step 3: Implement halation plate in applyGlowFamilyStage

iOS reference (FilmtoneExportSession.swift L1839-1874):
- halationImage = extractHighlightPlate(from: image, threshold: params.halationThreshold, knee: params.halationSoftKnee, tintColor: halationColor(for: params.halationHue))
- then buildMipBlurComposite(from: halationPlate, radius: params.halationRadius, levelCount: halationMipLevels, spreadMultiplier: 1.0 + Swift.max(params.halationSpread, 0) / halationSpreadDivisor, useTentResampling: true)

### Step 4: Implement diffusion plate in applyGlowFamilyStage

iOS reference (FilmtoneExportSession.swift L1876-1905):
- diffusionImage = buildMipBlurComposite(from: image, radius: 0.9, levelCount: diffusionMipLevels, spreadMultiplier: 1.15, useTentResampling: true)
- NOTE: diffusion uses full image as input (no highlight plate extraction), and uses fixed radius=0.9 and spreadMultiplier=1.15

### Step 5: Add halationColor helper

iOS reference (FilmtoneExportSession.swift L2392-2398):
```swift
private static func halationColor(for hue: Double) -> CIColor {
    let t = clampValue(hue / 100.0)
    let red   = (0xe8 + ((0xc8 - 0xe8) * t)) / 255.0
    let green = (0x10 + ((0x60 - 0x10) * t)) / 255.0
    let blue  = (0x20 + ((0x10 - 0x20) * t)) / 255.0
    return CIColor(red: red, green: green, blue: blue, alpha: 1)
}
```

### Step 6: Build + PSNR

bun run verify:macos 2>&1 | tail -3
bun run scripts/golden-parity-macos.ts --preset iphone 2>&1 | grep -E "PSNR|avg" | head -5

### Step 7: Update plan docs

- 04-phase-plan.md: mark C5b A.2 COMPLETE, add 着地状況 section
- 06-quality-gates-risks.md: record new PSNR baselines (if changed from A.1)

### Step 8: Create next handoff doc

Create docs/filmtone/desktop/filmtone-native-desktop-phase2-c5b-a3-master-handoff-2026-05-04-jst.md
targeting C5b A.3 (edgeOptics: radialRGBSplit + edgeSoftnessBlend CIKernel port).
End with a paste-ready English prompt for the next chat.

## Critical invariants

- NEVER edit apps/capacitor-film-lab-ios/ (iOS Xcode project inviolable)
- NEVER edit packages/film-lab-core/src/ (TS shared, additive-only)
- NEVER hand-edit FilmtonePhase0Generated.swift
- Kernel sources MUST be verbatim lift from iOS OpticalKernels
- Sidecar stays Case B (lookId/lookVersion only) until Look Unification lands on main
- bun mandatory (no npm)
- git commit is performed by the user, NOT by Claude
- Use Swift.min / Swift.max to avoid GLSL name collision
- clamp() is renamed to clampValue() in macOS pipeline (to avoid Swift stdlib ambiguity)
- SourceKit false-positive errors are expected; trust xcodebuild output only
```
