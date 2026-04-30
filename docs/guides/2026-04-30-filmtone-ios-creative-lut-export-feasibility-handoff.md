# Filmtone iOS — Creative Look の Cube 化 (Feasibility + 設計案)

- **作成日**: 2026-04-30 JST
- **対象**: 次々チャット以降の実装担当（Filmtone iOS v1.4 候補ライン）
- **入口前提**: v1.3 Camera Profiles + Built-in Look pack (`feat/filmtone-ios-built-in-look-pack` @ `1287c09a`) が main にマージされ archive まで進む段階で着手する設計
- **DaVinci 連携**: 別 worktree `feature/filmtone-davinci-connect-package` の Phase 1 を unblock するための中核アウトプット
- **このチャットでは実装しない** — このドキュメントは設計確定の draft。レビュー後にユーザー承認を得てから commit する

---

## 0. TL;DR

v1.3 で V-Log / S-Log3 の synthesized cube パターン（Python fixture を真値とし、Swift `FilmtoneSourceProfileMath` が hard-gate accuracy で一致することを保証する設計）が確立した。

同じパターンで Filmtone Look の **color-only 部分** を `.cube` に焼く設計を以下に確定する。

- **抽出境界**: `applyGrade` の 9 ステージのうち pixel-local な 3 ステージ（`baseGrade` / `filmCompression` / `printStage`）を baking 対象とし、spatial / temporal / depth-aware ステージは LUT に含まない
- **新 namespace**: `FilmtoneCreativeLutMath`（`FilmtoneSourceProfileMath` とは role を分離）
- **2 モード**: creative-only cube（Rec.709→Rec.709） + combined cube（Log→Rec.709→Look）
- **accuracy budget**: D-CP5 を踏襲しつつ、log decoder が無いぶん **Tier 1 = byte-identical / Tier 2 = trilerp-error 1/255 max** の二段
- **sidecar**: V1 schema のまま additive optional `creativeLut` block（`schemaVersion=1` 維持）
- **v1.4 ship**: 「Look を .cube に書き出す」を **無料機能** として in-app 提供
- **v1.5+ paid SKU**: combined cube + sidecar + reference + DaVinci script を束ねる Filmtone Connect package
- **claim**: 「Look の color tone を焼いた LUT」— "complete recreation" / "DaVinci replacement" は禁止

---

## 1. Color-only ステージの抽出境界（hard fact）

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift:1197-1209` の `applyGrade` を真とする。順序は固定。

| # | ステージ | 関数 | カーネル / 実装 | bakeable? | 理由 |
|---|---------|------|----------------|-----------|------|
| 1 | input LUT | `applyInputLutStage` (1243) | `applyLut` (1563) → `CIColorCubeWithColorSpace` | **bakeable** (既に LUT) | combined cube の前段。`FilmtoneSourceProfileMath.{makeAppleLogToRec709Lut, makeVlogToRec709Cube, makeSlog3ToRec709Cube}` がすでに 33³ cube として存在 |
| 2 | base grade | `applyBaseGradeStage` (1250) | `OpticalKernels.baseGrade` (2873) | **✅ bake** | 完全 pixel-local。exposure (`pow(2.0, e)`) / contrast (around 0.5) / saturation (luma mix) / temperature (R/B shift ×0.1) / tint (R+0.05 / G-0.08 / B+0.05) / fade (lift toward white) |
| 3 | film compression | `applyToneCompressionStage` (1278) | `OpticalKernels.filmCompression` (2890) | **✅ bake** | luma-based smoothstep。`k = mix(5.15, 2.85, range)` の sigmoid を luma で eval し RGB に scale 適用。pixel-local |
| 4 | edge optics | `applyEdgeOpticsStage` (1292) | `radialRGBSplit` (3148) + `edgeSoftnessBlend` (3277) | ❌ spatial | radialRGBSplit は `sample(image, coord ± offset)` で隣接 sample 取得。edgeSoftnessBlend は `sharp` と `CIGaussianBlur` 出力を mix |
| 5 | glow family | `applyGlowFamilyStage` (1314) | `softKneeHighlight` (2969) → CIBoxBlur → `glowComposite` (2981) | ❌ spatial | bloom / halation / diffusion すべて highlight plate を抽出 → blur → composite。**threshold 抽出のみ** local だが visible energy は post-blur |
| 6 | vignette | `applyVignetteStage` (1467) | `OpticalKernels.vignette` (3063) | ❌ spatial | `destCoord()` から UV 取得して radial falloff。ray-angle optics 連携 |
| 7 | grain | `applyGrainStage` (1507) | `OpticalKernels.grain` (3092) | ❌ spatial+temporal | UV + timeSeconds + sourceSeed の hash。clump noise も座標依存 |
| 8 | creative LUT (user) | `applyCreativeLutStage` (1532) | `applyLut` → `CIColorCubeWithColorSpace` | bakeable (既に LUT) | **ユーザーがインポートした 3rd-party .cube** — Look の色味では**ない**ため baking 対象外 |
| 9 | print stage | `applyPrintStage` (1539) | `OpticalKernels.printStage` (2909) | **✅ bake** | CMY 減算 (×0.15) + sigmoid printContrast (`k = mix(1.0, 5.0, amount)`)。pixel-local |
| — | motion blur | `applyVideoMotionStage` (1226) | `motionFeedback` (2930) + `motionBlend` (2938) | ❌ temporal | cross-frame accumulator。inherently temporal |
| — | depth prefilter | `FilmtoneDepthPrefilter` | depth × ray-angle field PSF | ❌ depth-aware | 深度マップが必要 |

### Bake 対象の正味数式

入力 RGB ∈ [0, 1]³ が Rec.709 SDR encoded として与えられる。出力は同じ Rec.709 SDR encoded。ステージ 2 → 3 → 9 の合成を Python に独立 transcribe する。

```text
function bake(rgb, params):
    # Stage 2: baseGrade
    rgb = rgb * pow(2, params.exposure)
    rgb = (rgb - 0.5) * params.contrast + 0.5
    luma = dot(rgb, [0.2126, 0.7152, 0.0722])
    rgb = mix(luma, rgb, params.saturation)
    rgb.r += params.temperature * 0.1
    rgb.b -= params.temperature * 0.1
    rgb.r += params.tint * 0.05
    rgb.g -= params.tint * 0.08
    rgb.b += params.tint * 0.05
    rgb = rgb + params.fade * (1 - rgb)

    # Stage 3: filmCompression (skipped if compressionAmount < 0.001)
    if params.compressionAmount >= 0.001:
        r = clamp(params.compressionRange, 0, 1)
        k = mix(5.15, 2.85, r)
        rangeSoft = smoothstep(0.82, 1, r)
        amt = params.compressionAmount * (1 - 0.18 * rangeSoft)
        luma = dot(rgb, [0.2126, 0.7152, 0.0722])
        x = clamp(k * (luma - 0.5), -5.5, 5.5)
        s = 1 / (1 + exp(-x))
        scale = 1 if luma <= 0.001 else mix(luma, s, amt) / luma
        rgb = clamp(rgb * scale, 0, 1)

    # Stage 9: printStage
    rgb.r -= params.cyan    * 0.15
    rgb.g -= params.magenta * 0.15
    rgb.b -= params.yellow  * 0.15
    if params.printContrast >= 0.001:
        k = mix(1, 5, params.printContrast)
        s = 1 / (1 + exp(-k * (rgb - 0.5)))
        rgb = clamp(mix(rgb, s, params.printContrast), 0, 1)
    return clamp(rgb, 0, 1)
```

### 重要な不変条件

- ステージ 4-7 が cube に**入らない**ことを sidecar / claim / UI 文言で明示すること（§4 / §6）
- `applyCreativeLutStage` (slot 8) はユーザーの import LUT スロットであり Look の baking 対象ではない。Look を cube に焼く設計と user-imported LUT は直交する
- `applyPrintStage` は creative LUT (slot 8) の **後** に走る pipeline 順序。LUT 化した Look を再注入するときの applicaton order が問題になるが、**v1.4 export は単一 cube として一括 bake**（slot 8 を介さない外部利用が前提）

---

## 2. Cube 生成 API 設計（function signatures）

### 2.1 新 namespace `FilmtoneCreativeLutMath`

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCreativeLutMath.swift` （新規）。

```swift
import Foundation

enum FilmtoneCreativeLutMath {

    // MARK: - Per-pixel transcription

    /// 1 pixel に対する color-only stage の合成 (baseGrade → filmCompression → printStage).
    /// `FilmtoneSourceProfileMath.{filmtoneSdrShoulder, rec709Encode}` は呼ばない —
    /// 入力は Rec.709 SDR encoded、出力も同じ空間。
    @inline(__always)
    static func bakeColorOnlyParams(
        red: Double,
        green: Double,
        blue: Double,
        params: FilmtonePhase0Params
    ) -> (red: Double, green: Double, blue: Double)

    // MARK: - Cube generation

    /// Look (preset + strength + quickState + paramOverrides) から 33³ cube を生成。
    /// 戻り値は CIColorCubeWithColorSpace 互換の RGB packed Float32 (R fastest, then G, then B)。
    static func makeCreativeCube(
        presetName: String,
        strength: Double,
        quickState: FilmtoneQuickState,
        paramOverrides: FilmtonePhase0ParamsPatch,
        size: Int = 33
    ) -> [Float]

    /// Source profile + Look を合成した combined cube。
    /// `curve == nil` のときは Rec.709 passthrough = creative-only と同じ cube。
    /// それ以外は FilmtoneSourceProfileMath の対応 pixel pipeline を走らせた後に
    /// bakeColorOnlyParams を適用する。
    static func makeCombinedCube(
        sourceCurve: SourceProfileCurve?,
        sourceImpl: SourceProfileImpl,
        presetName: String,
        strength: Double,
        quickState: FilmtoneQuickState,
        paramOverrides: FilmtonePhase0ParamsPatch,
        size: Int = 33
    ) -> [Float]
}
```

### 2.2 NSCache 統合

新 cache `FilmtoneCreativeLutCache`（または既存の input LUT NSCache を流用するなら key prefix で分離）。

```swift
// Cache key 生成
private static func cacheKey(
    presetName: String,
    strength: Double,
    quickState: FilmtoneQuickState,
    paramOverrides: FilmtonePhase0ParamsPatch,
    size: Int
) -> NSString {
    let presetSafe = FilmtonePhase0Math.safePresetName(presetName)
    let strengthInt = Int((strength * 1_000_000).rounded())
    let quickHash = quickState.canonicalHashHex()         // 8 hex
    let patchHash = paramOverrides.canonicalHashHex()     // 8 hex
    return "creative.\(presetSafe).\(strengthInt).\(quickHash).\(patchHash).\(size)" as NSString
}
```

`canonicalHashHex()` は `quickState` / `paramOverrides` を sorted-keys JSON にして SHA-256 prefix。実装は既存 `FilmtoneLutBlobCodec.sourceHash` と同パターン。

メモリ予算:
- 33³ × 3 channels × Float32 = **419 KB / cube**
- 65³ → 3.3 MB / cube（fallback として用意するが v1.4 では未使用）
- Combined cache は creative + source の合成なので別 namespace
- LRU cap: **8 entries** で約 3.4 MB（既存 source-profile cache 〜575 KB × 5 の 2.9 MB と同等）

### 2.3 SourceProfileImpl ディスパッチ

```swift
case .nilProfile:
    // Rec.709 passthrough — creative-only と同じ
    return makeCreativeCube(...)
case .nativePolicy(.appleLogToRec709), .nativePolicy(.appleLog2ToRec709):
    sourceFn = { rgb in
        // Apple Log decode → rec2020→Rec.709 → shoulder → Rec.709 OETF
        FilmtoneSourceProfileMath.applyAppleLogPipeline(rgb)
    }
case .synthesized(.panasonicVLog):
    sourceFn = FilmtoneSourceProfileMath.vlogPixelToRec709
case .synthesized(.sonySLog3):
    sourceFn = FilmtoneSourceProfileMath.slog3PixelToRec709
case .bundledCube(_):
    // v1.3 では使用されないが将来。bundle resource からロード → trilinear interp
    return nil  // explicit fail（CLAUDE.md feedback_no_fallback_bug_hotbed）
case .userImport:
    return nil  // user-imported LUT は別パス。combined 経路では unsupported を明示 fail
```

`applyAppleLogPipeline` は既存 `FilmtoneExportSession.appleLogPixelToRec709`（2492）を `FilmtoneSourceProfileMath` に SSOT 移行する小 refactor が必要（Phase B-1 同形）。

---

## 3. Accuracy fixture 設計

V-Log / S-Log3 と同形で Python (`colour-science` BSD-3-Clause) で fixture を生成する。今回 colour-science は **直接呼ばない**（V-Log と同じ独立 transcribe principle）— colour-science は dev dependency としては useful だが pipeline 計算は自前で書く。

### 3.1 Fixture 生成スクリプト

`apps/capacitor-film-lab-ios/Tests/Fixtures/creative-lut/<look-slug>/encode-ramp.py`

5 built-in Look × 1 file = 5 fixture フォルダ:

```text
Tests/Fixtures/creative-lut/
├── filmtone-signature/    # iphone preset, strength=1, quick=zero, patch=empty
│   ├── encode-ramp.py
│   ├── grayscale-ramp.json     # 4096 (in, out) pairs
│   ├── grid-samples.json       # 17×17×17 grid sampling
│   ├── macbeth-patches.json    # 24 X-Rite patches post-pipeline
│   ├── source-encoded.png      # visual: Rec.709 input ramp
│   ├── expected-rec709.png     # visual: post-bake expected
│   └── provenance.md
├── clean-base/            # reset preset
├── amber-glow/            # amberGlow preset
├── soft-blue/             # softBlue preset
├── night-soft/            # softBlue preset + paramOverrides {exposure: 0.05, saturation: 0.93, halationIntensity: 0.04, bloomStrength: 0.24}
└── ...
```

各 `encode-ramp.py` は:
1. `bake_color_only(rgb, params)` を transcribe（§1 の擬似コードを numpy で実装）
2. `paramsByName[<preset>]` の値を Swift `FilmtonePhase0Generated` から **目視 transcribe**（自動同期しない — drift 検出は accuracy gate の役目）
3. `night-soft` は paramOverrides `{exposure: 0.05, saturation: 0.93}` の **color-only 部分のみ**を適用（halation/bloom は cube に入らないので無視）
4. 出力は `expected = bake(rgb, params)` を grid + ramp + Macbeth に対して生成

### 3.2 Hard accuracy gate 二段

V-Log/S-Log3 は `max = 0.000` を達成しているが、creative LUT は `pow(2, exposure)` / `exp(-x)` で float64 の超微小 drift が出る可能性がある。**二段** で gate する。

#### Tier 1 — Cube grid integrity (Python と Swift の transcribe 一致)

Swift の `bakeColorOnlyParams` を grid 17×17×17 = 4913 点で eval、Python pipeline と直接比較。

- max |Δ| in 8-bit code values ≤ **0.5 / 255** (`max ≤ 0.002` in [0,1])
- 4096-point grayscale ramp R=G=B: max |Δ| ≤ **0.5 / 255**

期待値: 実測 max = 0.000 〜 0.000004（V-Log/S-Log3 と同等の byte-identical）。drift が出たらすぐ調査。

#### Tier 2 — Trilinear interpolation fidelity (33³ で十分か)

Cube を 33³ で生成 → trilinear interp で再 sample → continuous Python eval と比較。

- 4096 random RGB triples（Halton-sequence で生成、ramp/Macbeth/random mix）
- 8-bit code values で max ≤ **1 / 255**, mean ≤ **0.2 / 255**
- ΔE2000 max ≤ **1.0**, mean ≤ **0.5**

Tier 2 が fail した Look がある場合、**その Look だけ 65³** で出力する（fallback にしない、明示分岐）。

### 3.3 Macbeth ΔE2000 gate

V-Log/S-Log3 と同形。X-Rite 24 patch を Rec.709 linear で与え、`rec709_encode` で Rec.709 SDR encoded に持ち上げてから `bake` を通す。

- max ≤ **1.5**, mean ≤ **0.5**（D-CP5 max=2.0/mean=1.0 より tight。log decoder が無いため）

### 3.4 Test harness 拡張

`apps/capacitor-film-lab-ios/scripts/swift/test-source-profile-math.swift` を `test-color-math.swift` に rename するか、別ファイル `test-creative-lut-math.swift` を追加。

`verify-phase0-contract.sh` の compile list に追加:
- `ios/App/App/FilmtoneCreativeLutMath.swift`
- `scripts/swift/test-creative-lut-math.swift`

`package.json` に script:
```json
"gen:fixtures:creative-lut:filmtone-signature": "uv run --with numpy --with pillow --with colour-science python Tests/Fixtures/creative-lut/filmtone-signature/encode-ramp.py",
"gen:fixtures:creative-lut:clean-base": "...",
"gen:fixtures:creative-lut:amber-glow": "...",
"gen:fixtures:creative-lut:soft-blue": "...",
"gen:fixtures:creative-lut:night-soft": "...",
"gen:fixtures:creative-lut": "bun run gen:fixtures:creative-lut:filmtone-signature && bun run gen:fixtures:creative-lut:clean-base && bun run gen:fixtures:creative-lut:amber-glow && bun run gen:fixtures:creative-lut:soft-blue && bun run gen:fixtures:creative-lut:night-soft"
```

### 3.5 v1.3 built-in Look bakeability マトリクス

実際の `FilmtonePhase0Generated.paramsByName` 値（`FilmtonePhase0Generated.swift:64-197`）と `FilmtoneBuiltInCatalog.allLooks`（`FilmtoneBuiltInCatalog.swift:42`）から導出。**color-only param は cube に入る、spatial param は cube に入らない**。

| Look | 元 preset | param overrides | Cube に焼く (color-only) | Cube に焼かない (spatial) | 視覚的差分の見込み |
|------|----------|----------------|------------------------|------------------------|--------------------|
| Filmtone Signature | iphone | empty | exposure 0.02, contrast 1.03, saturation 0.98, temperature 0.02, fade 0.02 | rgbShift 0.0012, lensSoftness 0.14, bloomStrength 0.16, halationIntensity 0.018, diffusion 0.05, vignette 0.18, grainIntensity 0.012 | 中（vignette + 微小 glow が消える） |
| Clean Base | reset | empty | （reset は color-only ほぼ identity） | bloomStrength 0.22 (preset 値!), diffusion 0.08, halationSpread 22, halationHue 20 | 大（reset 自体が bloom を含む） |
| Amber Glow | amberGlow | empty | exposure 0.01, contrast 1.03, saturation 1.03, temperature 0.10, tint 0.02, cyan -0.025, magenta 0.03, yellow 0.045 | rgbShift 0.0015, lensSoftness 0.16, bloomStrength 0.20, halationIntensity 0.04 (visible!), diffusion 0.10, vignette 0.22, grainIntensity 0.016 | 中〜大（halation+diffusion が消える） |
| Soft Blue | softBlue | empty | exposure 0.04, contrast 0.99, saturation 1.02, temperature -0.08, tint -0.04, fade 0.10, cyan 0.015, magenta -0.03, yellow -0.025 | softBlue spatial set | **小** — 色彩 dominant な Look なので cube reproduction は良い |
| Night Soft | softBlue + patch | (color-only) exposure 0.05, saturation 0.93 / (spatial) halationIntensity 0.04, bloomStrength 0.24 | softBlue color-only + (exposure 0.05, saturation 0.93) override | softBlue spatial + halation+bloom 強化分 | 大（halation+bloom 強化分が消える、街灯の滲みが失われる） |

→ **Soft Blue + Filmtone Signature が cube reproduction 品質が最も高い。Night Soft は LUT 化での色味再現は可能だが視覚的 identity の半分（halation glow）が失われる**ことを UI / claim で明示する必要がある。

---

## 4. Sidecar 拡張案（V1 schema 維持）

`FilmtoneExportSidecarBuilder.swift` の既存 7 block (`look` / `lutRefs` / `output` / `mezzanine` / `depth` / `savedLook` / `cameraProfile`) と整合させる additive optional `creativeLut` block を追加。**`schemaVersion = 1` 維持**（CLAUDE.md §5 不変条件）。

### 4.1 ブロック shape

`FilmtoneExportSidecarBuilder.swift` に builder-local struct を追加:

```swift
/// v1.4 Creative LUT export Phase D: 焼き出した Look LUT の provenance。
/// ファイル本体（Filmtone-<slug>.cube または combined-color.cube）は
/// sidecar の sibling として書かれる。`data` array は載せない（既存
/// SidecarLutRef と同方針）。
///
/// `mode` は LUT が何を含むかを区別する:
///   - "creative-only": Rec.709 → Rec.709 (Look の color-only stage のみ)
///   - "combined":      Source curve → Rec.709 → Look の color-only stage
struct SidecarCreativeLut: Encodable {
    let mode: String                  // "creative-only" | "combined"
    let filename: String               // "Filmtone-FilmtoneSignature.cube" 等
    let lutSize: Int                   // 33 or 65
    let bakedFromLookId: String        // SavedLookEntry.id (UUID string lowercase)
    let bakedFromLookName: String      // English name
    let bakedFromLookSlug: String?     // built-in 時のみ (FB1A...)
    let presetName: String             // safePresetName 後
    let presetVersion: String          // FilmtonePhase0Generated.presetVersion
    let strength: Double
    let quickStateHash: String         // 16 hex (canonical SHA-256 prefix)
    let paramOverridesHash: String     // 16 hex
    let bakedColorParams: [String]     // ["exposure","contrast","saturation","temperature","tint","fade","compressionAmount","compressionRange","printContrast","cyan","magenta","yellow"]
    let excludedSpatialParams: [String] // ["rgbShift","lensSoftness","bloomStrength","bloomThreshold","bloomRadius","diffusion","halationIntensity","halationSpread","halationHue","halationThreshold","halationRadius","bloomSoftKnee","halationSoftKnee","vignette","grainIntensity","grainRadialMix","grainSize","shutterAngle","trailIntensity"]
    let combinedSourceProfile: SidecarCameraProfile?  // mode=="combined" のみ
    let sha256: String                 // SHA-256 of the .cube file bytes
}
```

### 4.2 `FilmtoneExportSidecarV1` への追加

```swift
struct FilmtoneExportSidecarV1: Encodable {
    // ... 既存 7 block ...
    let savedLook: SidecarSavedLookRef?
    let cameraProfile: SidecarCameraProfile?
    /// v1.4 Creative LUT export: 同一 export で .cube を書き出した時のみ populate。
    /// nil なら従来通り（v1.3 byte-identical）。Additive optional V1 field。
    let creativeLut: SidecarCreativeLut?
}
```

### 4.3 SidecarBuildInputs への追加

```swift
struct SidecarBuildInputs {
    // ... 既存 field ...
    let cameraProfile: SidecarCameraProfile?
    /// v1.4: 同一 export で creative LUT を焼き出した場合に渡す。
    /// nil なら従来通り。facade chain 経由で運ばれる
    /// (`2026-04-30-ios-state-vs-wire-dto.md` § 「DTO に乗せる場合」と同形でも可、
    /// ただし JS bridge が知る必要は無いため facade chain 推奨)。
    let creativeLut: SidecarCreativeLut?
}
```

### 4.4 cap 確認

既存 sidecar 〜3 KB（v1.3 後）。`creativeLut` block は 〜400 bytes（excludedSpatialParams 配列が最大）。8 KB cap に対して余裕あり。contract test でアサート継続。

### 4.5 V1 schema 維持の根拠

- 既存 reader は unknown key を ignore（CLAUDE.md §5）
- `creativeLut` は v1.3 reader にとって「無いのが既定」と区別不能 — 後方互換問題なし
- DaVinci Connect Workspace Script は `creativeLut.filename` を読んで package 内 .cube path を解決する想定 — schema bump 不要

---

## 5. UX / Surface 案

### 5.1 v1.4 — 「Look を .cube に書き出す」（FREE）

**置き場所案 A**: Library row long-press menu に "Export as .cube"。built-in / user 両方で表示。
**置き場所案 B**: 既存 Save Current Look sheet に「.cube として書き出す」セクション追加。新規 Save と同時 export。

両方を実装するのが理想だが v1.4 では **A だけで先に出す**（既存 long-press menu の拡張で済むため UI churn 最小）。

ファイル出力経路:
1. `FilmtoneCreativeLutMath.makeCreativeCube(...)` で 33³ cube 生成
2. `FilmtoneCubeWriter.serialize(...)` で Adobe .cube text に変換
3. `UIDocumentPickerViewController(forExporting: [tempURL])` で Files に保存（Photos には保存しない — CLAUDE.md `feedback_no_fallback_bug_hotbed` 派生：媒体が違う）
4. ファイル名: `Filmtone-<englishName-kebab>.cube`（例: `Filmtone-FilmtoneSignature.cube`, `Filmtone-AmberGlow.cube`, `Filmtone-NightSoft.cube`, ユーザー Look は `Filmtone-MyLook.cube`）

エラーハンドリング:
- 不明 preset → `FilmtonePhase0Math.safePresetName` でデフォルトに fall through（既存挙動と同じ）— silent fallback ではない（contract に明記）
- writer 失敗 → user-visible error sheet「.cube の書き出しに失敗しました」

### 5.2 v1.5+ — Filmtone Connect package（PAID SKU）

別 worktree (`feature/filmtone-davinci-connect-package`) の DaVinci Connect Phase 1 が land した後、creative LUT export と統合:

- Package layout (overall plan §4.2):
  ```
  FilmtoneExport/
    media.mov
    media.mov.filmtone-ios-export-session-v1.json    # sidecar（creativeLut + cameraProfile + savedLook 全含む）
    combined-color.cube                              # makeCombinedCube 出力
    reference-after.jpg                              # graded poster frame
  ```
- ファイル名は **package 内固定**（`combined-color.cube`） — DaVinci script の参照パスと整合
- 単独 export (§5.1) と package export (§5.2) で **生成パスが分岐**：
  - 単独: `Filmtone-<slug>.cube` (creative-only)
  - Package: `combined-color.cube` (combined source+creative)

### 5.3 文言（JP / EN, vocabulary gate 遵守）

CLAUDE.md / Phase H から JP `短尺動画` 禁止 / EN `short-form video` 禁止。Look/cube 文言は以下を採用:

#### JP（リリース notes / sheet copy）

```
Look を .cube に書き出して、DaVinci Resolve / Premiere Pro / Final Cut Pro などで再利用できるようになりました。

書き出した .cube は Look の色味（exposure / contrast / saturation / temperature / tint / fade / 印刷フィルタ）を内包します。Filmtone 上で適用される spatial な効果（halation / bloom / diffusion / vignette / grain）は LUT には含まれません — それらは Filmtone 上での仕上げ要素として残ります。
```

#### EN

```
Export your Look as a .cube file for DaVinci Resolve, Premiere Pro, Final Cut Pro, and other NLEs.

The exported .cube captures the color tone of your Look — exposure, contrast, saturation, temperature, tint, fade, and print filter. Spatial effects (halation, bloom, diffusion, vignette, grain) remain Filmtone-only and are not encoded in the LUT.
```

UI sheet (export 確認) には「色味のみが書き出されます」一行注釈を必ず置く（claim 境界の一次防御）。

---

## 6. Product claim 境界

DaVinci Connect overall plan §1 の non-claim と整合させる。

### ✅ 言える

- "Export your Look as a .cube file."
- "Color tone of the Look is preserved (exposure, contrast, saturation, temperature, tint, fade, print filter)."
- "Pre-grade on iPhone. Finish in DaVinci."（DaVinci Connect SKU の上位 claim）
- "iPhone で下地を、DaVinci で仕上げを。"
- "色のみを LUT に焼きます。"

### ❌ 言わない

- ❌ "Recreate Filmtone Looks in DaVinci"
- ❌ "Complete Filmtone reproduction"
- ❌ "Filmtone Looks are editable in Resolve"
- ❌ "All Filmtone effects in a single LUT"
- ❌ "Filmtone がモバイル DaVinci になる"
- ❌ "Filmtone の見た目を完全に再現"

### 文言 audit 経路

リリース直前に Phase H docs cleanup と同形で fastlane release_notes.txt + App Store description.txt を grep:
- `grep -E "(complete|完全|再現|recreate|all effects)" fastlane/metadata/`
- 該当行があれば手動レビュー

---

## 7. SKU / 課金位置

### 結論

| 機能 | SKU | リリース |
|------|-----|---------|
| **Look を .cube に書き出す（creative-only, 単一ファイル）** | **無料** | v1.4 |
| **Filmtone Connect for DaVinci package（combined cube + sidecar + reference + script）** | **有料（Filmtone Connect SKU）** | v1.5+ |
| 将来の DCTL / OFX 近似 | 同有料 SKU 内 | v1.6+ |

### 根拠

PeekLut（競合）は Premium LUT export を有料化しているが、Filmtone がそれを真似ると差別化が崩れる:

- Filmtone は dual-lane color thinking（Source Profile + Film Look）+ baked physical look（halation / glow / depth-aware optics）が **本質的差別化**
- Look LUT export は dual-lane の **片側だけ**を切り出した派生物。これを paywall で囲うと「物理シミュレーションがないと差別化できない」signal になる
- 単独 .cube export を free にすることで Filmtone の brand: "honest, physical-look-driven, iPhone-native" が立つ

一方 **Filmtone Connect for DaVinci package は paid SKU として強い**:
- Package という単位（複数ファイル + sidecar + reference + script）= bridge product
- DaVinci 上での finishing workflow を Filmtone から立ち上げる **end-to-end value**
- combined-color.cube だけでは無く、reference-after.jpg + marker note の "provenance carrier" としての価値（overall plan §4.3）

### Filmtone Connect SKU の price target（参考）

- IAP Lifetime: **¥1,500 〜 ¥2,800**（competitor: PeekLut Premium ¥1,500/年 sub）
- Subscription はやらない — Filmtone brand は subscription fatigue と逆方向
- 1 回の買い切りで package export + DaVinci script + 将来 DCTL/OFX をすべて unlock
- 価格決定は v1.5 ship 直前、競合再調査 + ASC 内部統計で確定

---

## 8. 実装ボリューム見積もり

### 8.1 新規ファイル

| ファイル | LOC 概算 | 備考 |
|---------|---------|------|
| `ios/App/App/FilmtoneCreativeLutMath.swift` | ~300 | bakeColorOnlyParams + makeCreativeCube + makeCombinedCube + cache integration |
| `ios/App/App/FilmtoneCubeWriter.swift` | ~80 | Adobe .cube text serializer (TITLE / LUT_3D_SIZE / DOMAIN_MIN/MAX / triplets) |
| `Tests/Fixtures/creative-lut/<5 looks>/encode-ramp.py` | ~250 × 5 = ~1,250 | テンプレート 1 本作って preset 値だけ差し替える |
| `scripts/swift/test-creative-lut-math.swift` | ~200 | Tier 1 + Tier 2 + Macbeth gate |
| `docs/creative-lut-math/<5 looks>.md` | ~100 × 5 = ~500 | spec citation + 定数表（preset 値の transcribe 元）|

### 8.2 修正ファイル

| ファイル | 修正概算 | 内容 |
|---------|---------|------|
| `ios/App/App/FilmtoneSourceProfileMath.swift` | +~40 | `applyAppleLogPipeline` を SSOT 移行（既存 `appleLogPixelToRec709` の Phase B-1 同形 refactor） |
| `ios/App/App/FilmtoneExportSession.swift` | +~80 | 単独 .cube 書き出しの export action endpoint、sidecar plumbing |
| `ios/App/App/FilmtoneExportSidecarBuilder.swift` | +~60 | SidecarCreativeLut struct + V1 sidecar field |
| `ios/App/App/FilmtoneEditorFacade.swift` | +~20 | `runExport(... creativeLutBake: CreativeLutExportRequest? = nil)` パラメータ |
| `ios/App/App/FilmtoneMediaRuntime.swift` | +~20 | facade chain の next layer |
| `ios/App/App/FilmtoneRootView.swift` | +~80 | Library row long-press の "Export as .cube" action |
| `ios/App/App/FilmtoneStrings.swift` | +~30 | 文言 JP+EN |
| `package.json` | +5 entries | gen:fixtures:creative-lut:* |
| `scripts/verify-phase0-contract.sh` | +2 lines | compile list 拡張 |
| `apps/capacitor-film-lab-ios/CLAUDE.md` | +~10 lines | §6 Swift module map 更新（30 行 cap 注意）|
| pbxproj | 新 .swift 2 ファイル × 4 セクション = 8 entries | PBXBuildFile / PBXFileReference / PBXGroup / PBXSourcesBuildPhase |

### 8.3 期間見積もり

senior dev、v1.3 context fresh、Agent Teams 並列無し前提:

- Phase A (math primitives + Python fixtures + Swift gate): **1.5 day**
- Phase B (cube writer + snapshot test): **0.5 day**
- Phase C (combined cube generator): **0.5 day**
- Phase D (sidecar block): **0.5 day**
- Phase E (UX surface + strings): **0.75 day**
- Phase F (DaVinci package integration, 別 worktree merge): **0.5 day**
- Phase G (release rail): **0.5 day**

**total ~5 days** for v1.4 単独ライン（Phase A-E + G）。Phase F は v1.5 で別 worktree からのマージ後に統合。

並列にしたくなる工程: A の Python fixture 5 本は preset 値だけ変えるテンプレート増殖で Agent Teams 4-5 stream 余地あり。ただし stream 設計のオーバーヘッドより 1 人で書いた方が速い（~3 hours / 5 fixtures）。

### 8.4 Contract gate の影響

- `scripts/verify-phase0-contract.sh` の standalone compile に `FilmtoneCreativeLutMath.swift` を追加（依存は `FilmtonePhase0Generated` / `FilmtoneSourceProfileMath` のみ — 既存 standalone graph に収まる）
- `phase0-contract-support.swift` の stub は **触らない**（DTO に追加しないため — `2026-04-30-ios-state-vs-wire-dto.md` の判断フロー）
- accuracy gate は `bun run verify:swift-contract` 経由で 5 Look × Tier 1 + Tier 2 の **10 件追加**

---

## 9. リスク分析

### 9.1 数値精度（major risk）

**症状候補**: `pow(2.0, exposure)` / `1 / (1 + exp(-x))` の Float64 計算で Python (numpy) と Swift (Foundation) が微小 drift。

**緩和**:
- bakeColorOnlyParams は `Double` 全域。Float32 に落とすのは `.cube` 書き出しの最終 packing のみ
- Tier 1 で max ≤ 0.5/255 を要求 → 0.000 が出るはずだが drift が ~0.001 出ても 8-bit では消える
- numpy `pow` vs Swift `Foundation.pow` は ULP レベルで一致するはず（両者 IEEE 754 binary64）

**Fallback**: Tier 1 が drift で fail したら、その preset の transcribe 値を Swift 側 `paramsByName` から **直接コピー**して Python 側に貼る（手動同期）。drift 原因が constant transcribe error の場合に有効。

### 9.2 33³ 解像度不足（moderate risk）

**症状候補**: `printStage` の `k = mix(1, 5, printContrast)` の sigmoid が printContrast=1.0 で boundary に近づき、33³ trilinear interp で edge で 1/255 を超える drift。

**確認**: v1.3 の 5 built-in は printContrast=0 / cyan=magenta=yellow=0 が大半。Filmtone Signature / Soft Blue で `cyan/magenta/yellow ≠ 0` のみ。CMY scale 0.15 は緩い → 33³ で十分のはず。

**Fallback**: Tier 2 が fail した特定 Look は **65³** で出力（メモリは 8 倍だが 1 entry あたり 3.3 MB なので絶対値小）。

### 9.3 急峻 curve 検出方法

事前に各 preset の bake 関数の Lipschitz 定数を Python で測定:

```python
# 33³ grid sample → spatial gradient max
gradients = np.gradient(cube)  # cube shape (33,33,33,3)
max_gradient = max(np.abs(g).max() for g in gradients)
# max_gradient * (1/32) が 33³ 量子化の最大丸め誤差候補
```

`max_gradient * (1/32) * 255 < 0.5` なら 33³ で安全。> 0.5 なら 65³ 必須。

### 9.4 CIColorCubeWithColorSpace のセマンティクス

**懸念**: iOS の `CIColorCubeWithColorSpace` filter が cube を「どの色空間で trilerp する」か。Apple docs では `inputColorSpace` パラメータが指定可能だが、Filmtone は明示指定していない（`applyLut` 1563 行）。

**確認手順**:
1. WebSearch で 2026-04 の最新 Apple docs 確認（"CIColorCubeWithColorSpace inputColorSpace nil semantics"）
2. iPhone 17 Pro Max iOS 26.2 の simulator に同 cube を 2 経路（CI 経由 / DaVinci 経由）で適用して visual diff
3. 必要なら inputColorSpace に Rec.709 SDR を明示 set（既存 `applyLut` の参考）

### 9.5 DaVinci interpretation

**懸念**: DaVinci Resolve は .cube を **Display LUT** / **Output LUT** / **Node LUT** のどれとして扱うかで表現が変わる。Filmtone Connect Phase 0 spike では `Graph:SetLUT(1, ...)` で **Node 1 の Input LUT** として apply している。

**確認**:
- DaVinci Resolve 20.x の `Graph:SetLUT` API doc を WebFetch で確認
- combined-color.cube の semantic は「Source curve → Rec.709 + Look 色味焼き付け」なので **Node 1 Input LUT** が正しい（ただし source の color space management を Bypass にする必要あり）
- 単独 creative-only LUT は **Display LUT** として適用するのが正しい挙動（既に Rec.709 graded image に Look を上塗り）

これは Filmtone Connect Lua script (overall plan §3.1) で apply path を分岐する責任 — 設計は overall plan で確定済み。

### 9.6 sidecar 8 KB cap

`creativeLut` block + 既存 7 block で 〜3.5 KB の見込み。8 KB cap に余裕あり。contract test で継続検証。

### 9.7 v1.3 standalone contract gate 衝突

`Phase0ExportRequestDTO` に **追加しない**（`2026-04-30-ios-state-vs-wire-dto.md` の判断フロー / `feedback_no_fallback_bug_hotbed` の事例）。creative LUT 焼き出しトリガーは facade chain 経由の追加パラメータで通す。

```swift
// FilmtoneEditorFacade.swift
func runExport(
    request: Phase0ExportRequestDTO,
    protectedCacheURIs: [String] = [],
    appliedSavedLook: SavedLookEntry? = nil,
    cameraProfile: CameraProfileSelection? = nil,
    creativeLutBake: CreativeLutExportRequest? = nil,    // 追加
    onProgress: ...
) async throws -> Phase0ExportResultDTO
```

`CreativeLutExportRequest` は iOS-side struct (`FilmtoneCreativeLutMath.ExportRequest` 等):
```swift
struct CreativeLutExportRequest {
    let mode: Mode    // .creativeOnly | .combined(curve, impl)
    let outputURL: URL
    let cubeSize: Int = 33
}
```

JS bridge は知る必要が無い（v1.4 では UI が Library long-press で iOS 内完結）。

### 9.8 user-saved Look の bake 安定性

v1.3 は 5 built-in のみが catalog にある。user Look は任意の `paramOverrides` を持つ。Tier 2 が user Look で fail する可能性がある。

**緩和**: bake 時 Lipschitz check を runtime で実行し、超過した場合 65³ に上げる「runtime adaptive resolution」を v1.5 で導入。v1.4 は **33³ 固定** + 「色味再現精度に限界がある」claim で出す。

---

## 10. v1.3 の教訓を再利用

### 10.1 DTO vs facade chain 判断（`2026-04-30-ios-state-vs-wire-dto.md`）

creative LUT 焼き出しトリガーは **facade chain 経由** で通す。DTO に乗せない。

理由:
- JS bridge (Capacitor TS) は creative LUT のトリガーを生成 / 解釈する必要が無い（UI は SwiftUI 内完結）
- standalone Phase 0 contract gate stub の Codable synthesis 衝突を回避（`CreativeLutExportRequest` は associated value enum 持ち）
- 既存の `appliedSavedLook` / `cameraProfile` が facade chain 経由で実績あり

### 10.2 Source Profile fixture pipeline（`2026-04-30-source-profile-fixture-pipeline.md`）

完全に同形パターンを creative LUT に適用:

| § | source-profile での内容 | creative-lut での対応 |
|---|------------------------|---------------------|
| 1. Spec 確認 | メーカー公式 PDF + Antler Post mirror | `FilmtonePhase0Generated.swift` の preset 定数 + `OpticalKernels` の CIKernel source |
| 2. Python fixture | colour-science で独立 transcribe | numpy で stage 2+3+9 を独立 transcribe |
| 3. uv で生成 | `bun run gen:fixtures:vlog` | `bun run gen:fixtures:creative-lut:*` |
| 4. Swift math | `vlogPixelToRec709` + `makeVlogToRec709Cube` | `bakeColorOnlyParams` + `makeCreativeCube` |
| 5. Catalog 1 行 | `FilmtoneSourceProfileCatalog.allProfiles` | 不要（Look catalog `FilmtoneBuiltInCatalog.allLooks` に既存）|
| 6. Strings 追加 | `FilmtoneStrings.cameraVLog` | export action 用文言追加 |
| 7. pipeline dispatch | `makeSynthesizedInputLut(curve:)` switch | export endpoint 追加 |
| 8. accuracy test | linearization + Macbeth | Tier 1 (grid integrity) + Tier 2 (trilerp fidelity) + Macbeth |
| 9. UI Menu | 自動列挙 | 既存 Library row long-press menu に 1 entry |
| 10. pbxproj | 4-section 登録 | 同左 |
| 11. Gate 順 | 同 canonical 順 | 同左 |

### 10.3 namespace 役割分離

`FilmtoneSourceProfileMath` は source profile 専用 namespace のまま保つ。`FilmtoneCreativeLutMath` を新規追加して role を分離する。

理由:
- SSOT として name が role を反映する
- 標準偏差 contract gate stub が両 namespace を独立に compile できる（standalone graph が dependency より小さく保てる）
- 将来 DCTL / OFX 近似コード（v1.5+ paid SKU）も `FilmtoneCreativeLutMath` 名前空間で受け入れられる

### 10.4 アンチパターン回避

`2026-04-30-source-profile-fixture-pipeline.md` § アンチパターンを creative LUT でも踏襲:

- ❌ Macbeth 期待値に X-Rite linear reference をそのまま書く → Filmtone shoulder で必ず drift する
   → **creative LUT では shoulder は無いが、`pow(2, exposure) * contrast` のチェーンで drift する** → Python pipeline 出力を期待値にする
- ❌ メーカー公式 LUT を真値として fixture 比較する → 循環参照
   → creative LUT には「メーカー公式」が存在しないため自動回避だが、**Filmtone Desktop の cube 出力**を真値にしない（Desktop は WebGPU の Float32 / iOS は Core Image の Float / 数値表現が違う）
- ❌ `colour-science` API を直接呼ぶ → 意図的に独立実装
   → 同左
- ❌ DTO に `creativeLutBake` を追加する → standalone contract gate stub 衝突
   → facade chain 経由（§9.7）

---

## 11. 実装着手チェックリスト（次々チャット用）

### 11.1 着手前 verify

```sh
bash /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
git log --oneline -20
git -C apps/capacitor-film-lab-ios status
bun run verify:swift-contract
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

すべて green かつ v1.3 lane が main にマージ済みであることを確認。

### 11.2 Phase 着手順

1. **Phase A**: Python fixture 5 本 + `FilmtoneCreativeLutMath.swift` math primitives + accuracy gate
2. **Phase B**: `FilmtoneCubeWriter.swift` (Adobe .cube serializer)
3. **Phase C**: `makeCombinedCube` + cache + combined accuracy gate (4 source curves × 1 reference Look)
4. **Phase D**: `SidecarCreativeLut` block + builder integration
5. **Phase E**: Library long-press menu "Export as .cube" + SwiftUI + strings
6. **Phase F (別 worktree gating)**: combined-color.cube を Filmtone Connect package builder に注入
7. **Phase G**: v1.4 release rail (MARKETING_VERSION bump, fastlane release notes, App Store description update)

各 Phase 後に commit gate 4 件（`bun run build` / `xcodebuild` / `bun run verify:swift-contract` / pbxproj 4-section grep）green であることを確認。

### 11.3 不変条件 reminder

- `Profile.version` = `4` 触らない
- Sidecar `schemaVersion` = `1` 触らない
- iOS preset names locked (`["reset", "iphone", "softBlue", "amberGlow"]`)
- `FilmtonePhase0Generated.swift` 手動編集禁止（generator のみ）
- 新 Swift ファイル 2 件（`FilmtoneCreativeLutMath.swift`, `FilmtoneCubeWriter.swift`）は pbxproj 4-section 全部に登録（`grep -c <ファイル名> ios/App/App.xcodeproj/project.pbxproj` ≥ 4）
- DTO に追加しない（facade chain 経由）
- Vocabulary gate: JP `短尺動画` 禁止 / EN `short-form video` 禁止
- 既存 untracked 4 docs (`docs/filmtone/ios/filmtone-connect-*` 3 件 + 既存 `docs/guides/2026-04-30-filmtone-ios-v1.3-release-prep-handoff.md`) を触らない
- DaVinci spike worktree (`feature/filmtone-davinci-connect-package`) のコードに依存しない設計（Phase F の merge までは独立 build）

---

## 12. 関連ドキュメント

- `docs/filmtone/ios/filmtone-connect-davinci-overall-plan-2026-04-30-jst.md` — DaVinci Connect 全体計画（Phase 1 で combined-color.cube が必要）
- `docs/filmtone/ios/filmtone-connect-davinci-real-package-export-handoff-2026-04-30-jst.md` — Phase 1 ハンドオフ
- `docs/filmtone/ios/filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md` — PeekLut positioning pivot
- `docs/guides/2026-04-30-filmtone-ios-v1.3-release-prep-handoff.md` — v1.3 release prep（v1.4 はこの後着手）
- `.claude/knowledge/patterns/2026-04-30-source-profile-fixture-pipeline.md` — Source Profile fixture テンプレート（同形で踏襲）
- `.claude/knowledge/patterns/2026-04-30-ios-state-vs-wire-dto.md` — DTO vs facade chain 判断フロー
- `apps/capacitor-film-lab-ios/CLAUDE.md` — Swift module 領域マップ
- `apps/capacitor-film-lab-ios/RELEASE.md` — release rail 詳細

---

## 13. 完了基準（次々チャット）

- ✅ Phase A〜E land、build green、accuracy gate 全 5 Look × Tier 1 + Tier 2 green
- ✅ sidecar contract test green、`creativeLut` block 出力確認
- ✅ iPhone 17 Pro Max iOS 26.2 で 5 built-in Look の `.cube` 書き出し smoke 成功
- ✅ DaVinci Resolve 20.x で書き出した cube を Display LUT / Node LUT 両経路で apply、visual sanity check
- ✅ App Store description / fastlane release notes が claim 境界に収まる（vocabulary gate clean）
- ✅ Phase F は別 worktree merge 待ち（v1.4 ship gate ではない）
- ✅ Phase G land 後 v1.4 archive → TestFlight → ASC submit
