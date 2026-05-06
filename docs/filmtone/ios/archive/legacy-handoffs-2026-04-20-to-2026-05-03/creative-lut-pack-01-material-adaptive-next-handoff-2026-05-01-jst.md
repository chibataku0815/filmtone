# Filmtone iOS — Creative LUT Pack 01 素材適応化 next handoff
2026-05-01 JST / next-chat handoff

---

## 0. この doc の目的

Creative LUT Pack 01 は、配管・bundle loading・SHA-256 pin・sidecar provenance まで実装済みで、色と光学値の品質改善も一度入った。CD 実機確認で Golden Halation の暗所破綻は解消したが、その代わり **「固定値を弱めただけ」に見える** という次の本質課題が出た。

次 chat の主題は、Golden Halation 単体ではなく **Pack 01 全 LUT を素材の輝度レンジ / 暗所量 / ハイライト量に応じて適応させること**。固定 `.cube` をさらに弱くするのではなく、素材別に `creativeLut.intensity` と runtime optical `paramOverrides` の初期値を変えて、低レンジ素材では破綻を避け、高レンジ素材では世界観を強く出す。

この doc は、ここまでの経緯・現在の実装状態・不変条件・次 chat の開始手順・最高精度プロンプトをまとめる。

---

## 1. repo / routing / current state

Repo:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Relevant docs and rules:

- `AGENTS.md` — 最初に読む。今回も `git status --short --branch` から入る。
- `apps/capacitor-film-lab-ios/CLAUDE.md` — iOS subtree rules。
- Current prior handoff:
  - `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-quality-iteration-handoff-2026-05-01-jst.md`
- This handoff:
  - `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-material-adaptive-next-handoff-2026-05-01-jst.md`

Current branch status at handoff creation:

```text
## main...origin/main [ahead 2]
```

The worktree is intentionally dirty. Do not revert unrelated work. The Pack 01 lane is mixed with other in-progress user changes, including halo prism / help assets / renderer artifacts. Treat unrelated dirty files as user-owned.

Important Pack 01 files currently touched or created:

- `packages/film-lab-core/src/creative-pack-01.ts`
- `packages/film-lab-core/src/creative-pack-01.test.ts`
- `packages/film-lab-core/src/bake-color-only.ts`
- `packages/film-lab-core/src/creative-cube.ts`
- `packages/film-lab-core/src/creative-cube-serialize.ts`
- `scripts/build-creative-luts.ts`
- `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json`
- `apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/*.cube`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`

Verification already passed after the latest changes:

```sh
bun run scripts/build-creative-luts.ts --verify
bun test packages/film-lab-core/src/bake-color-only.test.ts packages/film-lab-core/src/creative-cube.test.ts packages/film-lab-core/src/creative-pack-01.test.ts
bun run build:core
bun run verify:ios
cd apps/capacitor-film-lab-ios && xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
git diff --check -- packages/film-lab-core/src/creative-pack-01.ts packages/film-lab-core/src/creative-pack-01.test.ts apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift
```

All passed.

---

## 2. 経緯

### 2.1 Initial Pack 01 state

直前 chat で Creative LUT Pack 01 の実装配管が作られた。

Completed structure:

- 4 bundled `.cube` Looks:
  - Tungsten Bloom
  - Window Diffusion
  - Vintage Haze
  - Golden Halation
- `Resources/CreativeLuts/` folder reference in Xcode project.
- `CreativeLutBinding.bundled(slug, filename, sha256, intensity)` in Swift schema.
- Bundle resource loading with SHA-256 fail-closed behavior.
- Sidecar provenance:
  - `bundledSlug`
  - `bundledPackId`
- `scripts/build-creative-luts.ts` with:
  - `--regenerate`
  - `--regenerate-identity`
  - `--verify`
- TS baker:
  - `bake-color-only.ts`
  - `creative-cube.ts`
  - `creative-cube-serialize.ts`
  - `creative-pack-01.ts`

CD feedback after first real bake:

> 現在はそれっぽいLUTというだけで低品質です  
> しっかり世界観を表現し、破綻のないものにする

Attached images were later clarified as **target samples**, not broken samples.

Target image interpretation:

- Image #1: Golden Halation target direction. Warm stone / skin but blue sky preserved, no yellow film over the whole frame.
- Image #2: Window Diffusion target direction. Family / skin / red / green remain natural, shadows do not crush.
- Image #3: Vintage Haze target direction. Pale pink flowers and dark background remain intact; vintage quality comes from soft density, not dead saturation.
- Tungsten Bloom has no direct attached target; use warm candle/tungsten role while preserving skin and whites.

### 2.2 First quality pass: stable fixed defaults

The first fix did three important things:

1. Rebuilt all 4 Look color values from exaggerated first-pass values to controlled defaults.
2. Reduced optical overrides so the lens character no longer explodes.
3. Fixed a real non-double-apply bug: Pack 01 neutralized the 12 baked color ops, but iOS v2 `baseGradeV2` also applies `shadowTone` / `highlightTone` before the creative LUT. Those were left active from the base preset and contaminated the cube. Pack 01 now neutralizes:
   - all `BAKE_COLOR_PARAM_KEYS`
   - `shadowTone`
   - `highlightTone`

Focused test added:

```text
packages/film-lab-core/src/creative-pack-01.test.ts
```

It asserts every Pack 01 Look neutralizes baked color ops and v2 split-tone strengths.

### 2.3 Second quality pass: Golden Halation dark break + controls

CD feedback:

> ゴールデンハレーション暗所で破綻あり、詳細調整の明るさ調整が効いてない？、クリエティブLUTの効き具合スライダーがない

Fixes applied:

- Golden Halation was made safer in dark footage:
  - lower `temperature`, `fade`, CMY shifts, print contrast, compression.
  - lower `halationIntensity`, `bloomStrength`, `diffusion`.
  - raise `halationThreshold` and `bloomThreshold`.
  - default bundled `creativeLut.intensity` changed from `1.0` to `0.85`.
- Detailed sheet now shows a Look LUT amount slider when `project.creativeLut != nil`.
  - `FilmtoneStrengthSheet.lookLutAmountControl`
  - accessibility id: `filmtone.sheet.slider.creativeLutIntensity`
- Advanced Params now has a `Basic` group:
  - `exposure`
  - `contrast`
  - `saturation`
  - `temperature`
  - `tint`
  - `fade`
- Quick adjustment mapping in the sheet was corrected:
  - UI label `Exposure` now controls `quickState.dynamics`, because that is the quick axis that actually changes `exposure`.
  - UI label `Contrast` maps to `-quickState.era`, because positive era lowers contrast in generated quick weights.
  - UI label `Saturation` maps to `quickState.filmCharacter`, because that is the quick axis that actually raises saturation.
  - Summary text in `FilmtoneEditorStore.quickSummaryText` mirrors those UI mappings.

CD result after this:

> 破綻はなくなりましたが、単純に効果が控えめになっただけとも取れます  
> レンジが広い素材と狭い素材で適応度を変えた方が良いのではないでしょうか？  
> 単体ではありません、全LUTに言えることです

This is the next main task.

---

## 3. Current Pack 01 values

Source of truth:

```text
packages/film-lab-core/src/creative-pack-01.ts
apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift
```

Current manifest summary:

| Look | basePreset | cube sha256 | diagonalMaxDelta | default intensity |
|---|---|---|---:|---:|
| Tungsten Bloom | `iphone` | `d14a82602f22a9099e6dd15fdff596911c941ac0d61b0291c05827729485785d` | `0.08638869971036911` | `1.0` |
| Window Diffusion | `softBlue` | `1ae470bb4779f5c9875d1547c1eb541008e14afa6b700b73e537d26444df9418` | `0.1130395382642746` | `1.0` |
| Vintage Haze | `iphone` | `48b32e343c1821af86687438e2a6b686f05f385d51f2ef0c4a38fc4fd8599862` | `0.10405664891004562` | `1.0` |
| Golden Halation | `amberGlow` | `5aea665f6baeea0d563d3c683dc7c0c153ec8375d351b40cdd9b18aeaecc4794` | `0.07087850570678711` | `0.85` |

### 3.1 Color params

Tungsten Bloom:

```ts
{
  exposure: 0,
  contrast: 1.06,
  saturation: 0.96,
  temperature: 0.11,
  tint: 0.01,
  fade: 0.025,
  compressionAmount: 0.32,
  compressionRange: 0.56,
  printContrast: 0.10,
  cyan: -0.025,
  magenta: 0.015,
  yellow: 0.045,
}
```

Window Diffusion:

```ts
{
  exposure: 0.01,
  contrast: 1.06,
  saturation: 0.90,
  temperature: -0.07,
  tint: -0.015,
  fade: 0.035,
  compressionAmount: 0.30,
  compressionRange: 0.54,
  printContrast: 0.08,
  cyan: 0.035,
  magenta: -0.015,
  yellow: -0.015,
}
```

Vintage Haze:

```ts
{
  exposure: 0,
  contrast: 0.95,
  saturation: 0.88,
  temperature: 0.03,
  tint: 0.01,
  fade: 0.05,
  compressionAmount: 0.16,
  compressionRange: 0.52,
  printContrast: 0.04,
  cyan: -0.01,
  magenta: 0.008,
  yellow: 0.03,
}
```

Golden Halation:

```ts
{
  exposure: -0.03,
  contrast: 1.05,
  saturation: 1.03,
  temperature: 0.08,
  tint: 0.01,
  fade: 0.012,
  compressionAmount: 0.26,
  compressionRange: 0.56,
  printContrast: 0.09,
  cyan: -0.026,
  magenta: 0.028,
  yellow: 0.04,
}
```

### 3.2 Runtime optical overrides

All 4 Looks neutralize:

```ts
exposure: 0
contrast: 1
saturation: 1
temperature: 0
tint: 0
fade: 0
compressionAmount: 0
compressionRange: 0.5
printContrast: 0
cyan: 0
magenta: 0
yellow: 0
shadowTone: 0
highlightTone: 0
```

Look-specific runtime optical values:

```ts
Tungsten Bloom:
{
  bloomThreshold: 0.64,
  bloomStrength: 0.24,
  bloomRadius: 0.56,
  halationIntensity: 0.12,
  halationHue: 28,
  diffusion: 0.06,
}

Window Diffusion:
{
  diffusion: 0.13,
  bloomThreshold: 0.62,
  bloomStrength: 0.22,
  bloomRadius: 0.68,
  lensSoftness: 0.20,
  halationIntensity: 0.045,
  halationHue: 14,
}

Vintage Haze:
{
  diffusion: 0.10,
  lensSoftness: 0.20,
  grainSize: 0.36,
  grainIntensity: 0.018,
  halationIntensity: 0.02,
  bloomStrength: 0.06,
  vignette: 0.20,
}

Golden Halation:
{
  halationIntensity: 0.12,
  halationRadius: 0.42,
  halationHue: 34,
  halationThreshold: 0.68,
  bloomThreshold: 0.72,
  bloomStrength: 0.12,
  diffusion: 0.04,
}
```

---

## 4. Current UI / behavior fixes

Current detail sheet behavior after latest change:

- `Strength` slider still controls preset strength (`project.strength`).
- If a creative LUT exists, the same sheet now shows `ルックLUTの量` / `Look LUT Amount`.
  - It calls `store.setCreativeLutIntensity`.
  - This is the immediate user-facing answer to "クリエティブLUTの効き具合スライダーがない".
- Advanced Params includes `Basic`.
  - Direct exposure control exists now.
  - This is the immediate answer to "詳細調整の明るさ調整が効いてない?".
- Quick controls were remapped in `FilmtoneStrengthSheet` only, not in generated quick weights:
  - `Exposure` UI -> `quickState.dynamics`
  - `Contrast` UI -> `-quickState.era`
  - `Saturation` UI -> `quickState.filmCharacter`
  - `FilmtoneEditorStore.quickSummaryText` mirrors this.

Do not regenerate `FilmtonePhase0Generated.swift` for this. The current fix intentionally avoids changing generated contract keys and only aligns UI labels to existing quick weights.

---

## 5. Problem to solve next: all LUT material adaptation

CD direction:

> 単体ではありません、全LUTに言えることです

This means the next fix is not "make Golden stronger again" and not "tune one more fixed default". The real product goal is:

- narrow-range / dark / low-highlight material should receive safer, restrained Look defaults.
- wide-range / bright / highlight-rich material should receive stronger Look defaults so the world view is actually expressed.
- this applies to **all Pack 01 Looks**:
  - Tungsten Bloom
  - Window Diffusion
  - Vintage Haze
  - Golden Halation

The correct direction is **adaptive defaulting**, not adaptive `.cube` mutation.

Recommended principle:

- Keep the bundled `.cube` assets byte-pinned and stable.
- Keep `bake-color-only.ts` unchanged.
- At runtime, when a built-in Pack 01 Look is applied, calculate a lightweight source material descriptor and adjust:
  - `creativeLut.intensity`
  - runtime optical `paramOverrides`
  - possibly a small direct `exposure` / `contrast` override only if it is part of the intended Look adaptation and does not break the cube-only color contract.

Because `paramOverrides` currently neutralize baked color ops, adding non-neutral color overrides at runtime would reintroduce double-color behavior. Be careful. Prefer `creativeLut.intensity` plus spatial/optical values first. If color overrides are needed, define them intentionally as **material adaptation overrides**, not accidental base preset leakage.

---

## 6. Suggested adaptive design

### 6.1 Descriptor

Current `SourceProbeDTO` is mostly metadata. It does not currently include luminance percentiles or histogram stats. Next chat should confirm live source/probe state before implementing.

Suggested new descriptor:

```swift
struct FilmtoneSourceToneDescriptor: Codable, Equatable {
    let lumaP05: Double
    let lumaP50: Double
    let lumaP95: Double
    let lumaRangeP05P95: Double
    let shadowCoverage: Double       // e.g. Y < 0.12
    let highlightCoverage: Double    // e.g. Y > 0.78
    let lowMidCoverage: Double       // optional, useful for dark interiors
    let saturationMean: Double       // optional
}
```

Classification:

```text
narrowDark:
  lumaRangeP05P95 < ~0.42
  OR shadowCoverage > ~0.55 and highlightCoverage < ~0.025

narrowFlat:
  lumaRangeP05P95 < ~0.42
  but not deeply dark

normal:
  middle state

wideHighlight:
  lumaRangeP05P95 > ~0.58
  and highlightCoverage > ~0.035

veryBright:
  highlightCoverage high enough that glow/halation can be expressive
  but should avoid clipping.
```

Do not hard-code these thresholds without testing on real frames. Start with them as initial gates, then verify on the three target images and at least one dark Golden Halation failure clip/frame.

### 6.2 Where to compute descriptor

Candidates to inspect:

- `SourceProbeService.swift`
- `FilmtoneEditorStore.applyProbe`
- preview render / compare frame pipeline
- `FilmtoneExportSession.applyGrade`

Avoid expensive full-video scanning. Product-quality first, but do not make Look tapping slow.

Pragmatic recommendation:

- For stills: sample a downscaled `CIImage` once after source pick or immediately before first Look apply.
- For videos: sample one representative frame from current preview / midpoint if already available; otherwise first stable decoded frame.
- Downscale to a small grid, e.g. 64px or 96px long edge, compute luma percentiles.
- Cache descriptor in `FilmtoneEditorStore` for the current source URI.
- Invalidate when source changes.

### 6.3 Where to apply adaptation

Best insertion point:

```text
FilmtoneEditorStore.applySavedLook(id:)
```

Current flow:

1. Load `SavedLookEntry`.
2. Resolve `.bundled` creative LUT via `loadBundledCreativeLut`.
3. Set:
   - `state.presetName`
   - `state.strength`
   - `state.quickState`
   - `state.paramOverrides`
   - `state.creativeLut`
4. `recomputeProjectParams()`

Add a focused helper around step 3:

```swift
let adaptation = FilmtoneCreativePack01Adaptation.resolve(
    slug: slug,
    descriptor: sourceToneDescriptor
)

state.paramOverrides = entry.paramOverrides.merging(adaptation.paramOverrides)
state.creativeLut = resolvedCreativeLut.withIntensity(adaptation.intensity)
```

Do not mutate the static catalog entry. The adaptation belongs to the current project state and current source.

Important UX rule:

- Apply adaptation when the user taps a built-in Pack 01 Look.
- Do not keep re-adapting after the user manually moves sliders.
- If source changes while `appliedSavedLookId` is still active and no manual adjustments happened, it is acceptable to recalculate once. If that is risky, defer source-change re-adaptation and only adapt on Look tap for v1.

### 6.4 Adaptive behavior target by Look

These are initial target behaviors, not final exact constants.

Tungsten Bloom:

- narrowDark:
  - keep warmth but reduce bloom trigger.
  - lower `creativeLut.intensity` to about `0.75-0.85`.
  - reduce `bloomStrength`, `halationIntensity`, `diffusion`.
- wideHighlight:
  - restore stronger tungsten glow.
  - allow `creativeLut.intensity` around `1.0`.
  - allow `bloomStrength` around `0.26`, `halationIntensity` around `0.14`, threshold lower than safe default if highlights are present.

Window Diffusion:

- narrowFlat:
  - avoid milky gray haze.
  - lower diffusion and bloom.
  - keep skin/red/green natural.
- wideHighlight:
  - stronger window atmosphere.
  - raise diffusion and bloom moderately.
  - preserve faces; do not haze the whole frame.

Vintage Haze:

- narrowDark:
  - avoid lifting blacks into muddy matte.
  - lower fade-ish perception via LUT intensity if needed.
  - grain/softness can stay, but not so much that detail dies.
- wideHighlight:
  - vintage softness can be more visible.
  - slightly stronger LUT intensity / lens softness / grain.
  - still keep pink flowers and skin from going dead.

Golden Halation:

- narrowDark:
  - current safe profile is the baseline:
    - default intensity `0.85`
    - `halationIntensity 0.12`
    - `bloomStrength 0.12`
    - high thresholds.
  - this eliminated the observed dark break.
- wideHighlight:
  - bring back stronger world view:
    - intensity toward `1.0`
    - halation/bloom closer to the earlier expressive values, but only when actual highlights exist.
  - keep blue sky and neutral stone.

---

## 7. Non-negotiables

- Do not hand-edit `FilmtonePhase0Generated.swift`.
- Do not change `bake-color-only.ts` unless there is a proven Swift parity reason. It is the SSOT port.
- Do not break Pack 01 byte-pin discipline.
  - If `.cube` values change, run `--regenerate`, update manifest and Swift SHA values.
  - If only runtime adaptation changes, `.cube` files should not change.
- Do not reintroduce base preset color leakage.
  - Pack 01 must keep `shadowTone: 0` and `highlightTone: 0`.
  - Keep `creative-pack-01.test.ts` green.
- Do not treat this as a portfolio / release metadata task.
- Do not edit portfolio implementation. Portfolio consumes this repo as submodule.
- Do not stage/commit/push unless explicitly asked.
- Use `bun`, not npm/yarn/pnpm.

---

## 8. Verification for next chat

Minimum after adaptation implementation:

```sh
bun run scripts/build-creative-luts.ts --verify
bun test packages/film-lab-core/src/bake-color-only.test.ts packages/film-lab-core/src/creative-cube.test.ts packages/film-lab-core/src/creative-pack-01.test.ts
bun run build:core
bun run verify:ios
cd apps/capacitor-film-lab-ios && xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
git diff --check
```

If a new Swift descriptor/adaptation helper is added, add focused tests if there is an existing lightweight Swift test route. If not, keep implementation small and rely on `xcodebuild` plus manual real-device visual checks.

Manual CD checks after build:

- Apply each Pack 01 Look to:
  - dark / narrow-range footage
  - normal footage
  - bright / high-range footage
- Confirm:
  - narrow-range material does not break.
  - high-range material does not become boring.
  - Look LUT Amount slider is visible in detail sheet.
  - Basic Exposure direct slider is visible and actually changes brightness.
  - user manual adjustment is not overwritten by automatic adaptation.

---

## 9. Known current limitation

Current state after latest implementation is stable but conservative:

- Golden Halation dark break is gone.
- Golden Halation now has a safe default, diagonal drift `0.07087850570678711`, intensity `0.85`.
- But this can read as "just weaker".

That is why next step must be material adaptation across all Looks.

Do not try to solve this by globally increasing the fixed defaults. That will reintroduce dark/low-range failures.

---

## 10. Highest-precision next-chat prompt

Copy the prompt below into the next chat.

```text
Filmtone iOS Creative LUT Pack 01 の素材適応化を引き継ぎます。

必ず最初に以下を読んでください:

1. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/AGENTS.md
2. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/CLAUDE.md
3. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-material-adaptive-next-handoff-2026-05-01-jst.md
4. 必要に応じて前段 handoff:
   /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-quality-iteration-handoff-2026-05-01-jst.md

まず `git status --short --branch` を実行し、dirty worktree を確認してください。既存の unrelated user changes は絶対に revert しないでください。

今回の目的:

Creative LUT Pack 01 は破綻しない固定値まで来たが、固定で弱くしただけでは高レンジ素材で世界観が出ない。Golden Halation 単体ではなく、Tungsten Bloom / Window Diffusion / Vintage Haze / Golden Halation の全 LUT を、素材の輝度レンジ・暗所量・ハイライト量に応じて適応させる。

現状:

- Pack 01 の配管、bundle loading、SHA-256 pin、sidecar provenance は完成済み。
- `.cube` は `Resources/CreativeLuts/` にあり、manifest は `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json`。
- Current Look values are in `packages/film-lab-core/src/creative-pack-01.ts`.
- Swift catalog mirror is in `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift`.
- Pack 01 neutralizes all baked color ops plus `shadowTone` / `highlightTone`. Do not break this.
- `creative-pack-01.test.ts` protects this contract.
- Detail sheet now has:
  - Look LUT Amount slider when `project.creativeLut != nil`
  - Basic advanced controls including direct Exposure
  - corrected Quick axis mapping for Exposure / Contrast / Saturation
- Golden Halation dark break was fixed by making its fixed default safer:
  - LUT intensity `0.85`
  - diagonal drift `0.07087850570678711`
  - darker/low-range safe optical values
- CD feedback after that:
  「破綻はなくなりましたが、単純に効果が控えめになっただけとも取れます。レンジが広い素材と狭い素材で適応度を変えた方が良いのではないでしょうか？ 単体ではありません、全LUTに言えることです」

次 chat の実装方針:

1. sequential-thinking を使って、全 LUT の素材適応設計を詰める。
2. 現在の `SourceProbeDTO` / preview pipeline / render pipeline を live code で確認する。記憶で断言しない。
3. 軽量な source tone descriptor を設計・実装する:
   - lumaP05 / lumaP50 / lumaP95
   - lumaRangeP05P95
   - shadowCoverage
   - highlightCoverage
   - optional saturationMean
4. Descriptor は full video scan ではなく、downscaled still or representative preview frame から計算する。Look tap が重くならないようにする。
5. Runtime adaptation は `.cube` を変えるのではなく、built-in Pack 01 Look 適用時に:
   - `creativeLut.intensity`
   - runtime optical `paramOverrides`
   を素材に応じて調整する。
6. 最有力 insertion point:
   `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift` の `applySavedLook(id:)`
   where it resolves `.bundled` creative LUT and assigns project state.
7. Static catalog itselfは mutateしない。current source/project state に adaptation を反映する。
8. User manual adjustments must not be overwritten. Apply adaptation on built-in Look tap; source-change re-adaptation is optional only if `appliedSavedLookId` is still active and no manual edit happened.
9. Keep `bake-color-only.ts` unchanged. Do not hand-edit `FilmtonePhase0Generated.swift`.
10. Keep the existing Pack 01 `.cube` byte-pin unless you intentionally retune cubes. The likely v1 adaptation should not require cube regeneration.

Quality target:

- narrow-range / dark material: safe, no black lift, no red/yellow cast, no glow explosion.
- wide-range / highlight-rich material: stronger Look identity, not boring, visible lens character.
- normal material: current safe values are acceptable baseline.
- Applies to all 4 Looks, not Golden only.

Suggested initial adaptive behavior:

- Tungsten Bloom:
  - dark/narrow: lower LUT intensity and bloom/halation.
  - wide/highlight: allow stronger bloom/halation and intensity near 1.0.
- Window Diffusion:
  - narrow/flat: reduce haze so faces and reds/greens stay clear.
  - wide/window highlight: stronger diffusion and bloom.
- Vintage Haze:
  - dark/narrow: avoid muddy matte and excessive black lift.
  - wide: allow more softness/grain/LUT presence.
- Golden Halation:
  - dark/narrow: keep current safe profile.
  - wide/highlight: reintroduce stronger halation/bloom/intensity, while preserving blue sky and neutral stone.

Verification required:

```sh
bun run scripts/build-creative-luts.ts --verify
bun test packages/film-lab-core/src/bake-color-only.test.ts packages/film-lab-core/src/creative-cube.test.ts packages/film-lab-core/src/creative-pack-01.test.ts
bun run build:core
bun run verify:ios
cd apps/capacitor-film-lab-ios && xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
git diff --check
```

重要:

- 保守的に弱くするだけで終わらせない。
- 破綻回避と世界観表現の両立がゴール。
- 本質優先。portfolio / release metadata / UI decoration は今回やらない。
- 不確かな実装事実は grep / sed / tests で確認してから進める。
- Git操作はしない。stage / commit / pushは禁止。
```

