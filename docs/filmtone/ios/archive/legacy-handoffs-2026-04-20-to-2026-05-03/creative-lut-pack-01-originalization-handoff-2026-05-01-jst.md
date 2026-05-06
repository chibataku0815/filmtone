# Filmtone iOS - Creative LUT Pack 01 originalization handoff
2026-05-01 JST / next-chat handoff

## 0. Purpose

This document hands off the current Creative LUT Pack 01 state so the next chat
can turn the current Palermo-derived reference LUTs into proper original
Filmtone LUTs.

Current state is intentionally a development reference:

- The app now has a working bundled creative-LUT pipeline.
- Pack 01 is reduced to two strong Palermo-derived baselines:
  - `Palermo Reference`
  - `Palermo Green Density`
- The current cubes are not the final product direction.
- The next task is not to add more weak variants. It is to design one or two
  original Filmtone looks that inherit the useful tonal lessons from Palermo
  while becoming Filmtone's own expression.

Product-quality priority:

- Do not preserve a look just because it already exists.
- Do not keep Golden Halation; the user explicitly said it is no longer needed.
- Do not make grain the main signature. The user's view is that Filmtone's
  signature is optical behavior: bloom, halation when tasteful, diffusion, lens
  softness, glow, and density.
- Do not make small variants that are barely different.
- First build one base Creative LUT properly, then decide whether the second
  cold/green companion deserves to remain.

## 1. Repo, branch, and current truth

Repo:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Current branch/worktree at this handoff:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone  6309674 [main]
```

Latest relevant commit:

```text
6309674 Add Palermo-based creative LUTs
2026-05-01 16:30:02 +0900
```

`main` is ahead of `origin/main` by 4 commits at handoff time. There is no
separate worktree branch to merge; this worktree is already on `main`.

The working tree still has unrelated dirty files. Do not revert them and do not
stage them unless the user explicitly asks. Examples of unrelated dirty areas at
handoff time:

- help comparison assets and generator work under
  `apps/capacitor-film-lab-ios/ios/App/App/Assets.xcassets/HelpCompare*`
- renderer/WebGPU halo-prism work
- `messages/en.json`, `messages/ja.json`
- optical recommendation and preset/schema files
- older handoff docs

The newly committed LUT work in `6309674` touched exactly these files:

```text
apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-palermo-green-density.cube
apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-palermo-reference.cube
apps/capacitor-film-lab-ios/ios/App/App/SourceProbeService.swift
packages/film-lab-core/dist/index.d.ts
packages/film-lab-core/dist/index.js
packages/film-lab-core/src/bake-color-only.test.ts
packages/film-lab-core/src/bake-color-only.ts
packages/film-lab-core/src/creative-cube-serialize.ts
packages/film-lab-core/src/creative-cube.test.ts
packages/film-lab-core/src/creative-cube.ts
packages/film-lab-core/src/creative-pack-01.test.ts
packages/film-lab-core/src/creative-pack-01.ts
packages/film-lab-core/src/index.ts
packages/film-lab-core/src/native-bridge.ts
scripts/build-creative-luts.ts
```

## 2. Mandatory start rules for the next chat

Follow `AGENTS.md` first:

1. Read `AGENTS.md`.
2. Run `git status --short --branch`.
3. Route directly to the current LUT surface:
   - `packages/film-lab-core/src/creative-pack-01.ts`
   - `scripts/build-creative-luts.ts`
   - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift`
   - `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json`
4. Do not start with broad file discovery.
5. Use `sequential-thinking` for the design choice of how to originalize the
   LUTs.
6. Use `bun`, not npm/yarn/pnpm.
7. Do not silently lower quality for speed.

Old handoff docs exist, but they are now partly stale because Pack 01 was
reduced from earlier multi-look experiments to two Palermo-derived references:

```text
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-material-adaptive-next-handoff-2026-05-01-jst.md
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-quality-iteration-handoff-2026-05-01-jst.md
```

Use this document as the current source for LUT state.

## 3. User feedback chronology

The important product feedback came in this order:

1. Initial generated Creative LUTs were judged low quality.
   - They looked like "それっぽいLUT" rather than a polished product.
   - The user wanted clear world-building and no breakage.

2. Xcode/iPhone validation was requested.
   - Build/install/launch eventually succeeded on a physical iPhone.
   - Xcode had warnings such as deprecated APIs and Sendable warnings, but the
     immediate product focus stayed on the LUT result.

3. Golden Halation failed.
   - User feedback: "ゴールデンハレーションは破綻しています"
   - Then: "ゴールデンハレーションはもう必要ないので削除してください"
   - Conclusion: do not preserve Golden Halation in the next design.

4. The balance was wrong.
   - User feedback: "光学系がfilmtoneの特徴なのにそれは弱くて、無駄にフィルムグレインが強すぎます"
   - Meaning: grain should be restrained. Optical behavior must be the Filmtone
     signature.

5. Night Soft regressed.
   - User feedback: "修正前ナイトソフトいい感じだったのに大幅劣化している"
   - Current catalog no longer contains active Night Soft. UUID `...000005` is
     reserved by a retired low-light built-in while the base Creative LUT is
     being rebuilt.
   - If Night Soft returns later, use the earlier pleasing direction as a
     separate decision, not as part of the current Palermo originalization task.

6. Too many weak variants were not useful.
   - User feedback: "ナイトソフト以外変化が小さすぎて作る必要を感じません"
   - User direction: first make one base Creative LUT properly.

7. Palermo reference should be analyzed directly.
   - User asked whether `.cube` can be parsed directly.
   - Answer: yes. The implementation now parses and bundles 65^3 `.cube` source
     data.
   - User accepted proceeding with direct cube analysis.

8. Palermo direct reference improved the result.
   - User feedback after switching to Palermo-derived source cubes:
     "そこそこよくなりました"

9. A stronger cold/green companion was requested.
   - User supplied:
     `/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs/LUT + Extras/Palermo + Colour Density + Green Density.cube`
   - User said: "これが良いと思います"

10. The first cold/green result was still too similar.
    - User supplied two phone screenshots and said: "ほぼ差分がないです"
    - Result: generation-time transform `cold-green-density-v1` was added so
      neutral grays, asphalt, buildings, and signage visibly shift cold/cyan
      green, not only chromatic colors.

## 4. Reference images and local assets mentioned

Target reference stills from the user:

```text
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_Mk3y3DZthw/CleanShot 2026-05-01 at 13.54.37@2x.png
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_RbBYttuTYL/CleanShot 2026-05-01 at 13.55.03@2x.png
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_1ge21M2vMQ/CleanShot 2026-05-01 at 13.55.13@2x.png
```

These were not "broken output" images. They were aesthetic references:

- warm urban sunlight with blue sky preserved
- polished daylight family/skin/red/green rendering
- soft floral/pink highlight handling with deep but not crushed background

Phone screenshots showing "almost no difference" between the two current LUTs:

```text
/Users/chibatakumi/Downloads/スクリーンショット 0008-05-01 16.13.58.png
/Users/chibatakumi/Downloads/スクリーンショット 0008-05-01 16.14.14.png
```

Reference LUT source folder:

```text
/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs
```

Current source cubes:

```text
/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs/DJI_DLOG-M-Palermo.cube
/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs/LUT + Extras/Palermo + Colour Density + Green Density.cube
```

Important legal/product posture:

- The user said the work is for development reference and not external product
  shipment in its current form.
- The next step is explicitly to move from reference-derived LUTs to original
  Filmtone LUTs.
- Treat Palermo as an analytical reference, not the final product identity.

## 5. Current Pack 01 catalog state

Active catalog entries in
`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift`:

| Look | Slug | UUID | Base preset | Strength | Creative LUT |
|---|---|---|---|---:|---|
| Palermo Reference | `filmtone-creative-pack-01-palermo-reference` | `FB1A0001-0000-4000-8000-000000000006` | `reset` | `1.0` | bundled 65^3 cube |
| Palermo Green Density | `filmtone-creative-pack-01-palermo-green-density` | `FB1A0001-0000-4000-8000-000000000007` | `reset` | `1.0` | bundled 65^3 cube plus cold transform |

Deprecated or intentionally unused UUID notes:

- `...000001` to `...000004`: removed old degenerate preset-wrapper looks.
- `...000005`: reserved by retired low-light built-in while base Creative LUT is
  rebuilt.
- `...000008` and `...000009`: intentionally not reused after removal of weak
  sampler entries.

Current cube hashes and sizes:

| Look | File | SHA-256 | Bytes | diagonalMaxDelta |
|---|---|---|---:|---:|
| Palermo Reference | `filmtone-creative-pack-01-palermo-reference.cube` | `3a6ba8427daac679990112d1fa244c0c1397d8f47125d0837e35f9fa1ab2fc4c` | `7113286` | `0.16783398389816284` |
| Palermo Green Density | `filmtone-creative-pack-01-palermo-green-density.cube` | `ffb9b1600108ebafcd0d60519d4fccd01262916c9519894b805d5264bb45d3c6` | `7415302` | `0.15953081846237183` |

Manifest:

```text
apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json
```

Note: `generatedFromCommit` in the manifest currently points to a pre-final
commit (`9d735ff...`) because the cubes were regenerated before commit
`6309674`. `--verify` does not compare `generatedFromCommit`; it compares the
manifest hash, shipped cube hash, and fresh re-bake hash. If the next chat
regenerates intentionally, this field will update.

## 6. Current TypeScript implementation

Primary source:

```text
packages/film-lab-core/src/creative-pack-01.ts
```

Pack constants:

```ts
export const CREATIVE_PACK_01_ID = "creative-pack-01" as const;
export const CREATIVE_PACK_01_BAKER_VERSION = "1.1.0-palermo-reference" as const;
export const CREATIVE_PACK_01_CUBE_SIZE = 65 as const;
```

Current looks use identity `colorParams` because color is carried by source
cubes, not by the 12-op Filmtone baker:

```ts
{
  exposure: 0,
  contrast: 1,
  saturation: 1,
  temperature: 0,
  tint: 0,
  fade: 0,
  compressionAmount: 0,
  compressionRange: 0.5,
  printContrast: 0,
  cyan: 0,
  magenta: 0,
  yellow: 0,
}
```

Runtime `paramOverrides` neutralize all color-only runtime operations:

- `exposure`
- `contrast`
- `saturation`
- `temperature`
- `tint`
- `fade`
- `compressionAmount`
- `compressionRange`
- `printContrast`
- `cyan`
- `magenta`
- `yellow`
- `shadowTone`
- `highlightTone`

This avoids double-applying color after the cube.

### 6.1 Palermo Reference optical baseline

`packages/film-lab-core/src/creative-pack-01.ts`:

```ts
bloomThreshold: 0.62
bloomStrength: 0.22
bloomRadius: 0.58
halationIntensity: 0.08
halationHue: 24
diffusion: 0.045
lensSoftness: 0.08
grainIntensity: 0.006
grainSize: 0.16
vignette: 0.06
strength: 1.0
```

Swift mirror:

```text
FilmtoneBuiltInCatalog.creativePack01PalermoReferencePatch
```

### 6.2 Palermo Green Density optical baseline

`packages/film-lab-core/src/creative-pack-01.ts`:

```ts
bloomThreshold: 0.66
bloomStrength: 0.18
bloomRadius: 0.54
halationIntensity: 0.045
halationHue: 18
diffusion: 0.07
lensSoftness: 0.10
grainIntensity: 0.005
grainSize: 0.14
vignette: 0.07
strength: 1.0
sourceCubeTransform: "cold-green-density-v1"
```

Swift mirror:

```text
FilmtoneBuiltInCatalog.creativePack01PalermoGreenDensityPatch
```

### 6.3 Builder script

Primary script:

```text
scripts/build-creative-luts.ts
```

Modes:

```sh
bun run scripts/build-creative-luts.ts --verify
bun run scripts/build-creative-luts.ts --regenerate
bun run scripts/build-creative-luts.ts --regenerate-identity
```

For source-cube looks, `--regenerate` parses the external `.cube` source,
optionally applies a transform, writes the bundled cube, and writes the manifest.

`Palermo Reference` currently copies the source cube text bytes directly.

`Palermo Green Density` parses the source cube and applies
`cold-green-density-v1`, then serializes a transformed cube with Filmtone
comments.

### 6.4 cold-green-density-v1

This transform was added because the raw Green Density cube was too similar to
Palermo Reference on neutral urban footage.

Design:

- Compute Rec.709 luma.
- Compute chroma.
- Weight neutral grays more strongly than saturated colors.
- Protect high highlights.
- Add a cold/cyan-green cast primarily to grays, asphalt, concrete, and signage.
- Avoid making saturated reds muddy.

Measured sample deltas after the transform:

```text
gray50: reference 0.435,0.452,0.415 -> green 0.374,0.465,0.506
gray75: reference 0.731,0.734,0.681 -> green 0.634,0.750,0.818
road:   reference 0.312,0.331,0.289 -> green 0.254,0.336,0.356
```

Next chat should decide whether this transform becomes a stepping stone for an
original Filmtone cold-density look or is replaced entirely.

## 7. Current Swift/iOS integration

Bundled LUT loading:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
```

Important behavior:

- `.bundled(slug, filename, sha256, intensity)` resolves from
  `Bundle.main` under `Resources/CreativeLuts`.
- The raw `.cube` file bytes are SHA-256 checked against the catalog.
- If missing or mismatched, it fails closed and surfaces the same missing-LUT
  path as deleted library LUTs.
- Parsed LUTs carry:
  - `bundledSlug`
  - `bundledPackId`

DTO provenance:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
packages/film-lab-core/src/native-bridge.ts
```

Sidecar provenance is threaded so exported sidecars can identify bundled looks.

Source-tone descriptor:

```text
apps/capacitor-film-lab-ios/ios/App/App/SourceProbeService.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
packages/film-lab-core/src/native-bridge.ts
```

Probe now computes lightweight source tone stats:

- `lumaP05`
- `lumaP50`
- `lumaP95`
- `lumaRangeP05P95`
- `shadowCoverage`
- `highlightCoverage`
- `lowMidCoverage`
- `saturationMean`

However, material adaptation is currently disabled:

```swift
enum FilmtoneCreativePack01Adaptation {
    static func resolve(
        slug: String,
        descriptor: FilmtoneSourceToneDescriptor?
    ) -> Resolved? {
        // The Palermo reference should remain a stable measured baseline.
        // Material-adaptive adjustments resume only after the base LUT is
        // visually signed off on device.
        return nil
    }
}
```

This is intentional. The next chat should first create a good original base LUT,
then re-enable material adaptation only if it improves product quality.

## 8. Verification already run after final cold transform

These passed before commit `6309674`:

```sh
bun run scripts/build-creative-luts.ts --verify
bun test packages/film-lab-core/src/bake-color-only.test.ts packages/film-lab-core/src/creative-cube.test.ts packages/film-lab-core/src/creative-pack-01.test.ts
git diff --check
bun run build:core
bun run verify:ios
```

Physical iPhone build/install/launch also succeeded:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios
xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'id=00008150-001674883C84401C' -configuration Debug -derivedDataPath build/xcode-device -allowProvisioningUpdates build
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 build/xcode-device/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 com.chibatakumi.film.lab.ios
```

Nonfatal warnings existed in Xcode/devicectl logs, but build/install/launch
succeeded.

## 9. What should change next

Goal:

Make the current Palermo-derived development references into original Filmtone
Creative LUTs.

Do not just do one of these:

- rename Palermo to a Filmtone name
- reduce intensity
- add grain
- make a third or fourth weak variant
- copy the reference cube and call it done

Do this instead:

1. Analyze current cubes numerically.
   - Compare identity -> Palermo Reference.
   - Compare Palermo Reference -> Palermo Green Density.
   - Inspect neutral axis, skin-ish hues, red, foliage green, sky/cyan, yellow
     stone, highlight shoulder, and shadow density.

2. Identify what is worth keeping.
   - Polished highlight density.
   - Deep but readable shadows.
   - Warm urban sunlight without yellowing the whole image.
   - Preserved blue/cyan separation.
   - Controlled red/skin handling.
   - Clean grain restraint.

3. Design an original Filmtone transform.
   - Prefer a parametric transform inside `scripts/build-creative-luts.ts` or a
     new small module if that keeps the logic testable.
   - Use luma masks and hue/chroma masks rather than blunt channel offsets.
   - Preserve color stability on neutral grays unless the look intentionally
     shifts them.
   - Avoid global yellow wash.
   - Avoid crushed shadows.
   - Avoid high-chroma clipping.

4. Keep optical behavior as Filmtone's signature.
   - Bloom/diffusion/lens softness should be visible but not smeared.
   - Halation should be tasteful or absent; do not revive Golden Halation as a
     dedicated look unless the user explicitly reverses the decision.
   - Grain should stay low and supportive.

5. Iterate with real images/video.
   - Use the user's reference stills and phone screenshots.
   - If possible, build a small local comparison script that applies the cubes
     to stills and emits side-by-side PNGs before reinstalling to iPhone.
   - Then regenerate cubes, run verification, install to device, and ask for
     visual feedback.

6. Rename only after visual direction is good.
   - Current `Palermo Reference` and `Palermo Green Density` are internal names.
   - Once originalized, rename slugs, Swift names, string keys, UUID comments,
     manifest entries, and cube filenames together.
   - Keep UUIDs only if the semantic identity is "same look evolved"; create
     new UUID reservations if the look becomes a new identity.

## 10. Likely implementation path

Recommended first pass:

1. Add cube-analysis helpers, probably in `scripts/build-creative-luts.ts` or a
   temporary script under `scripts/`.
2. Print measured deltas for selected RGB samples:
   - neutral ramp
   - skin approximation
   - red jacket/signage
   - foliage green
   - sky blue
   - asphalt/concrete
   - high highlight
   - deep shadow
3. Use those measurements to define an original transform.
4. Regenerate `filmtone-creative-pack-01-*.cube`.
5. Update manifest and Swift SHA-256 pins.
6. Run verification.
7. Install on iPhone only after local still comparisons show meaningful product
   quality.

Commands:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
bun run scripts/build-creative-luts.ts --regenerate
bun run scripts/build-creative-luts.ts --verify
bun test packages/film-lab-core/src/bake-color-only.test.ts packages/film-lab-core/src/creative-cube.test.ts packages/film-lab-core/src/creative-pack-01.test.ts
bun run build:core
bun run verify:ios
git diff --check
```

For device install:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios
xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'id=00008150-001674883C84401C' -configuration Debug -derivedDataPath build/xcode-device -allowProvisioningUpdates build
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 build/xcode-device/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 com.chibatakumi.film.lab.ios
```

## 11. Known risks and cleanup targets

1. Stale comments.
   - `packages/film-lab-core/src/native-bridge.ts` comments still mention old
     example slugs such as `warm-print`. Update comments when renaming final
     original looks.

2. TS and Swift params are manually mirrored.
   - `creative-pack-01.ts` optical overrides must match
     `FilmtoneBuiltInCatalog.swift`.
   - A future sync guard would reduce drift, but do not spend time there before
     the look is visually good.

3. External source paths are hardcoded.
   - Current reference source cube paths live outside the repo.
   - This is acceptable for current development but should not become the final
     original-product dependency.

4. Manifest `generatedFromCommit`.
   - It is pre-final as noted above. Regeneration updates it.

5. Working tree remains dirty.
   - Keep unrelated user changes intact.
   - Stage only the originalization work when committing.

6. Licensing/product identity.
   - Current Palermo-derived cubes are development references.
   - Originalization must remove the product identity dependency on Palermo.

## 12. Highest-precision next-chat prompt

Use this prompt in the next chat:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

まず AGENTS.md を読んで、git status --short --branch を確認してください。
今回の目的は Creative LUT Pack 01 の現在の Palermo 由来 LUT を、Filmtone のオリジナル LUT に適切に変更することです。

最初に必ずこの handoff を読んでください:
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-originalization-handoff-2026-05-01-jst.md

重要な前提:
- 現在 main の最新関連 commit は 6309674 "Add Palermo-based creative LUTs" です。
- 現在の active Look は Palermo Reference と Palermo Green Density の 2 つだけです。
- Golden Halation は破綻していて不要なので復活させないでください。
- Night Soft は以前良かったが今は別問題です。まず Pack 01 のベース LUT を作り込んでください。
- フィルムグレインを強くしないでください。Filmtone の特徴は光学系、つまり bloom / diffusion / lens softness / tasteful glow / 必要な場合のみ控えめな halation です。
- Palermo は開発参考です。最終的には Palermo をコピーしたものではなく、Filmtone 独自の LUT にしてください。
- 商品として外には出さない開発参考として Palermo を限りなく解析してよいが、今回のゴールはそれを元にオリジナルへ転換することです。
- 変化が小さいバリエーションを増やさないでください。まず一つのベース Creative LUT を完成度高く作り込んでください。

対象ファイル:
- packages/film-lab-core/src/creative-pack-01.ts
- scripts/build-creative-luts.ts
- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift
- apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json
- apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/*.cube
- 必要なら packages/film-lab-core/src/creative-cube*.ts と bake-color-only.ts

進め方:
1. sequential-thinking を使って、Palermo 解析からオリジナル Filmtone LUT へ転換する設計を考えてください。
2. current cubes を数値解析してください。identity -> Palermo Reference、Palermo Reference -> Palermo Green Density の差分を、neutral ramp / skin-ish hue / red / foliage green / sky blue / asphalt / highlight / shadow で見てください。
3. Palermo の良い点だけを抽出し、luma mask と hue/chroma mask に基づく Filmtone オリジナル transform を作ってください。単なる channel offset や intensity 変更で済ませないでください。
4. 光学系は runtime paramOverrides で控えめに強くしてください。grain は低く、halation は破綻しない範囲、diffusion/bloom/lens softness を中心にしてください。
5. `bun run scripts/build-creative-luts.ts --regenerate` で cube と manifest を更新し、Swift の SHA-256 pin と optical patch を同期してください。
6. `bun run scripts/build-creative-luts.ts --verify`、関連 bun tests、`bun run build:core`、`bun run verify:ios`、`git diff --check` を通してください。
7. できれば実機インストールまで行って、iPhone 上で確認できる状態にしてください。

保守的な意見よりプロダクト品質を優先してください。わからないことがあればローカルファイルを調べ、必要なら web search で調査してください。既存の無関係な dirty worktree 変更は絶対に revert しないでください。
```
