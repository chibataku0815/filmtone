# Phase 2 — Color pipeline + 大物 FX (Day 2)

**Budget**: 12h(Day 2 は長日、分割 OK)
**目的**: filmlab.wgsl を Linear Rec.709 + rgba16float + clamp なしで本実装し、v1.0 の core promise「LUT 前に広いレンジで grade」を**技術的に成立**させる。composite + motion blur も同日で通す。

---

## Entry criteria(Phase 1 完了で達成済み — verified 2026-04-18)

- [x] `feature/webgpu-migration-v1` branch(5 commit, push 済み)
- [x] WebGL backend 退避済み(`src/webgl/{WebGLBackend.ts, shaders/, textures/}`)— **class 名は `Viewport` 維持**、Phase 2 で consumer 移行と同時に改名予定(STATUS.md Decisions log 参照)
- [x] `RenderBackend` interface skeleton(`src/webgpu/Backend.ts`)+ memoized `isWebGPUSupported()` (`src/support.ts`)
- [x] 6 primitive: `GpuContext` / `OffscreenTargetPool` / `Lut3DTexture`(identity helper 含む) / `MediaTexture` / `RingBuffer`(depthOrArrayLayers=8) / `BlueNoiseTile` (256×256 R8, void-and-cluster pre-baked)
- [x] 9 WGSL shader: `fullscreen.vert` (procedural 3-vertex) / `bloom-prefilter` / `halation-prefilter` / `downsample` / `upsample` / `lightshafts` / `lightshafts-blend` / `dust` / `filmlab` (identity placeholder)
- [x] `WebGPUBackend` scaffold: `create(canvas)` で全 9 shader を compile-validate、`setMediaFromBitmap` + identity filmlab 経路で `render()` が動く。**bloom/halation pyramid 結線は未了** — Phase 2 T2-1 で filmlab.wgsl 本実装と同時に行う(T1-3 Decisions log 参照)
- [x] `test/golden/baseline-B/` 80 PNG(105 MB、DIRECTION §10 size gate 帯 hit)+ `compareAgainstBaselineB(output, preset, image)` in `test/golden-psnr.ts`
- [x] `jpeg-js` devDependency 追加(pure JS、baseline-B 生成専用)
- [x] Build flag 基盤: `desktop vite.config` `import.meta.env.FILMTONE_BACKEND = "webgpu"`、`apps/web next.config` `env.FILMTONE_BACKEND = "webgl"`(Phase 2 T2-3 までに `src/index.ts` を backend 毎 sub-path export に整理して tree-shake 検証)
- [ ] `bun run typecheck` — desktop app は pre-existing 10 errors が残る。本 phase 起因の差分ゼロ(main でも同数、Regressions log 参照)
- [ ] DIRECTION §9-11 読了

---

## Tasks

### T2-0. Phase 1 繰越 scope の消化(2-3h)[commit 0 または T2-1 に同梱]

Phase 1 Exit 原文で未達、または意図的に punt された 3 項目を Phase 2 の最初に処理する。Day 2 budget 12h に対し +2-3h → Day 4 予備 4h から充当想定。

1. **`RenderBackend` interface 拡張(1h)**
   - 現状: `src/webgpu/Backend.ts` の `RenderBackend` は `render / setResolution / destroy` のみ。
   - 追加: WebGL `Viewport` 側の setter 群を `setParams(record: Record<string, number | boolean>)` 1 本に集約する形で interface 追加、または必要最小限の setter (setExposure / setContrast / … など主要 5-10 本) を個別に足す。v1.0 は `setParams` 1 本推奨(既存 WebGL API の `viewport.setParams(buildViewportParams(grade))` と揃う)。
2. **Bloom / halation pyramid 結線(1-1.5h)**
   - Phase 1 Exit 原文「9 Simple shaders WGSL 移植、end-to-end で bloom/halation 描画確認(目視)」は shader 存在 + compile validate のみで止まっている。
   - T2-1 filmlab.wgsl 本実装の直後に bloom prefilter → downsample 5-level pyramid → upsample 5-level accumulate → composite additive の ping-pong を wire。`OffscreenTargetPool.pyramid()` helper が Phase 1 で入っているので level 分のラベル付き RT は直ぐ取れる。
3. **Viewport → WebGLBackend class 改名 + consumer 更新(1h)**
   - Phase 1 T1-1 で先送りした 4 consumer (`apps/desktop-film-lab-batch/src/renderer/{batch-pipeline.ts, video-export-pipeline.ts}` / `packages/film-lab-ui/src/FilmLabCanvas.tsx` / `apps/web/src/features/interactive/film-lab/film-lab-web-video-export.ts`) を `await Viewport.create(canvas, { prefer })` に移行、同時に `Viewport` class 名を `WebGLBackend` に改名。
   - 併せて `apps/web/src/features/interactive/film-lab/core/Viewport.ts`(film-lab-renderer を re-export) の型更新。
   - `src/index.ts` から `WebGPUBackend` を直 export している部分を、web バンドルで tree-shake できるよう sub-path export に整理(`film-lab-renderer/webgl` / `film-lab-renderer/webgpu` の 2 entry に分割 or Vite/Next で dynamic import がかかる形)。

Exit: typecheck clean、既存 desktop WebGL 経路で regression なし、web build で WebGPU コードが含まれない(`bun run --cwd apps/web build` → `grep -l WebGPUBackend dist/ -r` で 0 match 確認)。

Commit 案: T2-0 は T2-1 と統合して commit(filmlab.wgsl 本実装と同 commit)で OK、独立したければ `Extend RenderBackend interface; rename Viewport → WebGLBackend; wire bloom/halation pyramid` で 1 commit。

---

### T2-1. filmlab.wgsl primary grade 段 (4h) [commit 1]

**実装順**(DIRECTION §3 のパイプライン順序に従う):
1. media sample(linear RGB、hw sRGB decode 前提)
2. optional radial RGB shift
3. LUT1 sampling(Log→Linear Rec.709、入力は Log encoded のため soft-shaper **不要**)
4. Exposure → `color.rgb *= exp2(uExposure)`
5. Contrast → `(x - 0.5) * uContrast + 0.5`
6. Saturation → `mix(vec3(luma), x, uSaturation)` (luma = dot(x, Rec.709 coeffs))
7. Temperature → R += T*0.1, B -= T*0.1
8. Tint → R += t*0.05, G -= t*0.08, B += t*0.05
9. Split toning → `x += shadowTint * (1-luma) * 0.18 + highlightTint * luma * 0.18`
10. Fade (Lift) → `x + fade * (1 - x)`
11. Highlights / Shadows → `x += shadows*(1-luma)*0.5 + highlights*luma*0.5`
12. Film Compression → sigmoid by luma、**clamp 除去**、`lumaScale = (luma > 0.001) ? mix(luma, sigmoid(luma), amt) / luma : 1`

**全ステップに共通で**:
- `max(x, 0.0)` ガードを pow/log/sqrt 直前に挿入(DIRECTION §10 Phase 2)
- `clamp(0,1)` は**一切入れない**(最終 swap blit で hw OETF が受ける)

**31 uniforms struct**(DIRECTION §4 + §10 Phase 2):
```wgsl
struct GradeUniforms {
  // vec4 でパック(全 fields は .x / .xy / .xyz で access)
  exposure_contrast_saturation_padding: vec4f,      // x=exp, y=con, z=sat, w=_
  temperature_tint_fade_rgbShift: vec4f,
  highlights_shadows_compAmount_compRange: vec4f,
  shadowTint: vec4f,      // .xyz = RGB tint、.w = _
  highlightTint: vec4f,
  splitPosition_lut1Intensity_lut1Enabled_lut2Intensity: vec4f,
  lut2Enabled_cyan_magenta_yellow: vec4f,
  printContrast_fitMode_imgResX_imgResY: vec4f,
  resolution_time_padding: vec4f,
}
```
TS 側に対応 type と `packGradeUniforms(params: Params): Float32Array` ヘルパー(32 floats = 128 bytes = 8 vec4)。

**LUT sampler** (DIRECTION §10 Phase 2):
```ts
const lutSampler = device.createSampler({
  addressMode: 'clamp-to-edge',
  magFilter: 'linear', minFilter: 'linear', mipmapFilter: 'nearest',
});
```

**Golden gate**: 代表 preset 3 種 × 5 画像 = 15 ケースで Baseline B 比 PSNR を測定。40dB 超えが 12/15 以上。
- PSNR 38-40dB near-miss → DIRECTION §10 Phase 2 Default に従い investigate
- 2 件以上不一致 → direction chat

**Commit 案**: `Implement filmlab.wgsl primary grade (exposure..compression) in linear rgba16float`

---

### T2-2. soft-shaper + LUT2 + print stage (2h) [commit 2]

**soft-shaper**:
```wgsl
// Reinhard before LUT2 only (LUT1 は不要、DIRECTION §2)
fn soft_shape(x: vec3f) -> vec3f {
  let k = 0.5;  // DIRECTION §10 Phase 2、v1.0 では固定
  return x / (x + vec3f(k)) * (1.0 + k);  // 1.0 で等倍、>1 で gentle roll-off
}
```

**LUT2 sampling**: soft-shaped 入力を 3D texture サンプリング、`mix(pre, post, lut2Intensity)` で強度適用。

**Print CMY**: `color.r -= cyan*0.15; color.g -= magenta*0.15; color.b -= yellow*0.15;`
**Print Contrast**: sigmoid `k = mix(1.0, 5.0, amt); s = 1/(1+exp(-k*(x-0.5))); mix(x, s, amt)`

**最終**: 出力は linear RGB、swap blit で hw sRGB OETF が担当(shader 内 gamma 変換**不要**)。

**Golden gate**: 代表 preset 5 種 × 10 image = 50 ケースで Baseline B 比 PSNR ≥ 40dB が 45/50 以上。

**Commit 案**: `Add soft-shaper + LUT2 + print stage to filmlab.wgsl`

---

### T2-3. composite.wgsl (3h) [commit 3]

**入力**: rt.colorGraded(Pass 0 出力)+ rt.bloom(5-mip 合成後)+ rt.halation(6-mip 合成後)+ rt.diffusion(3-mip lazy)+ dust/scratch overlay texture(既存 canvas 由来、MediaTexture から流入)+ grain(blue-noise tile)

**bind group**(DIRECTION §10 Phase 2):
- group 0: per-frame uniforms(21 fields packed into vec4 struct)
- group 1: textures ×4 (colorGraded, bloom, halation, diffusion)+ dust/grain textures + sampler

**grain 実装**:
- blue-noise tile を uv coordinate でタイリングサンプル: `uv_tile = fract(uv * resolution / 256.0)`
- `grain = textureSampleLevel(blueNoise, sampler, uv_tile, 0.0).r - 0.5`
- `grain *= uGrainIntensity * mix(1.0, edgeWeight, uGrainRadialMix)`
- `edgeWeight = pow(length(uv - 0.5) * 2.0, uGrainSize * 2.0)`

**vignette, splits, diffusion**: 既存 GLSL の composite.frag.ts 移植(Naga ベースで変換 → hand-fix)。splits は per-pixel grade split の視覚化、既存 UI が使っていれば保持。

**Golden gate**: 代表 preset 5 × image 10 = 50 ケース、Baseline B 比 PSNR ≥ 40dB が 45/50 以上。

**Commit 案**: `Migrate composite.wgsl with 2 bind groups and blue-noise grain`

---

### T2-4. motion blur + ring buffer (3h) [commit 4]

**Ring buffer**(Phase 1 で `RingBuffer.ts` 実装済み、ここで接続):
- `validSlots: 0` から始まり、frame 毎に `validSlots = min(validSlots + 1, 8)`
- resize 時は texture 再生成 + `validSlots = 0`

**Shader 1: motionblur-feedback**:
- 現 frame の input + 前 slot を `mix(input, prev, uTrail)`(trail 0..0.95)
- 書き込み先 = ring の `nextSlot` layer

**Shader 2: motionblur-blend**:
- 過去 N=`min(validSlots, frames)` slots を triangle/box/exponential 重みで平均
- `activeFrames = min(8, shutterAngle / 360 * 8)` で参加 slot 数を決定
- weights は pre-normalized(sum = 1)

**WGSL**(shader 2 抜粋):
```wgsl
@fragment
fn fs(@location(0) uv: vec2f) -> @location(0) vec4f {
  var sum = vec3f(0.0);
  for (var i: u32 = 0u; i < uActiveFrames; i = i + 1u) {
    let layer = (uCurrentSlot - i + 8u) % 8u;  // ring wrap
    let sample = textureSampleLevel(ringTex, ringSamp, uv, f32(layer), 0.0);
    sum = sum + sample.rgb * uWeights[i];
  }
  return vec4f(sum, 1.0);
}
```

**Golden gate**: motion blur OFF + ON で 10 image × 2 preset = 20 ケース、Baseline B 比 PSNR ≥ 40dB が 18/20 以上。motion blur ON の方は比較が難しい(temporal)ので 38dB まで緩めて良い。

**Commit 案**: `Add motion blur 2-pass with depthOrArrayLayers=8 ring buffer`

---

## Exit criteria(10 項目、全達必須)

### Phase 1 繰越 scope(T2-0 必達)

- [ ] `RenderBackend` interface が WebGL / WebGPU 双方を満たす形に拡張済み
- [ ] bloom / halation pyramid が WebGPUBackend 側で ping-pong 結線、目視で WebGL 版と近似
- [ ] `Viewport` → `WebGLBackend` 改名 + 4 consumer 更新、web build で WebGPUBackend が tree-shake される

### Phase 2 本体

- [ ] filmlab.wgsl 完全実装(primary grade + soft-shaper + LUT2 + print)
- [ ] composite.wgsl 完全実装(21 uniforms, 4 intermediate inputs, grain, vignette)
- [ ] motion blur 2 shader + RingBuffer 接続
- [ ] **Golden PSNR gate**: 代表 5 preset × 10 image = 50 ケースで Baseline B 比 ≥ 40dB が 45/50 以上
- [ ] `bun run typecheck` clean(可能なら pre-existing errors も整理、無理なら据え置き OK)
- [ ] **視覚証明**: 高 DR サンプル画像(夕日 / 白ドレス)で、WebGPU 版が WebGL 版より LUT2 出力の highlight グラデーションが豊かであることを目視確認、screenshot を `docs/webgpu-migration/assets/highlight-proof/` に保存
- [ ] STATUS.md Day 2 → done、Regression / Notes 更新
- [ ] `phase-3-handoff.md` の Entry 欄と Known gotchas 反映

---

## Phase 2 固有の Decision Defaults(DIRECTION §10 再掲)

- 31 uniforms all vec4 packed
- LUT sampler: clamp-to-edge, linear
- Soft-shaper k=0.5 固定
- Composite bind groups 2-group
- Motion blur `validSlots` から開始
- PSNR 38-40dB near-miss → investigate
- `max(x, 0.0)` ガード必須

---

## Known gotchas(Phase 1 引継ぎ + Phase 2 で追記)

**Phase 1 → Phase 2 引継ぎ(STATUS.md Phase 1 Known gotchas を抜粋)**

- **Viewport class 名は暫定的に旧仕様**: `src/webgl/WebGLBackend.ts` の class はまだ `Viewport`(`src/index.ts` で `Viewport` として再 export)。Phase 2 で WebGPUBackend が consumer 向け asyc factory として成立する時、FilmLabCanvas / batch-pipeline / video-export-pipeline / film-lab-web-video-export の 4 consumer を `new Viewport({vert, frag, w, h})` から `await Viewport.create(canvas, {prefer})` へ移行。同時に `Viewport` → `WebGLBackend` 改名を実施。この **consumer 移行は Phase 2 T2-1 着手前の準備タスク**として組み込むか、T2-1 commit 1 の直前に挟むと clean
- **Uniform struct pattern**: 9 Simple shader と同じ vec4 packed パターンで 31 uniform を組む(DIRECTION §10 Phase 2)。ts 側の `packGradeUniforms()` は 8 vec4 = 32 floats = 128 bytes
- **Sampler 再利用可**: `WebGPUBackend` が持つ `linear / linear / clamp-to-edge / mipmap: nearest` sampler は LUT3D / media / bloom すべて兼用 OK
- **`BufferSource` 型ナロー**: `device.queue.writeTexture()` / `writeBuffer()` に TypedArray を渡す時、TS 5.9 で `ArrayBufferLike` vs `ArrayBuffer` 不一致。`as unknown as BufferSource` で narrow(Phase 1 で `Lut3DTexture.ts` / `BlueNoiseTile.ts` に適用済み)
- **WGSL `mod()` 不在**: GLSL `mod(x, 2.0)` は WGSL に無い。`x - floor(x * 0.5) * 2.0` で書き直し(downsample/upsample で適用済み)。Naga 変換後も同じ hand-fix が必要
- **procedural fullscreen triangle**: vertex buffer を使わず `@builtin(vertex_index)` で 3-vertex triangle を生成する pattern を T1-3 で採用。全 fragment pipeline が同 vertex shader(`fullscreenVertexWgsl`)を再利用できるので、Phase 2 filmlab.wgsl も vertex module は既存 9 shader と同じで良い
- **Backend interface はまだ minimal**: `src/webgpu/Backend.ts` の `RenderBackend` は `render / setResolution / destroy` のみ。Phase 2 で setter(setExposure, setContrast, …)群を追加する時、WebGL 側 `Viewport` の 60 setter をそのまま interface に移しても良いが、v1.0 は `setParams(record)` 1 本にまとめると WebGL の既存 API と揃う — direction default がまだ無いので最初の T2-1 commit で判断

**Phase 2 で判明したらここに追記**:

---

## Fail-stop / Escalate 条件

- Golden gate で 50 ケース中 5 件以上 PSNR < 40dB → direction chat
- filmlab.wgsl 単体で 6h 以上かかった → direction chat(scope 調整判断)
- Motion blur ring buffer で GPU validation error 多発 → direction chat
- composite shader が perf 50% 超劣化 → direction chat

---

## 完了報告 template

```
Phase 2 完了。filmlab.wgsl(primary + soft-shaper + LUT2 + print)/ composite / motion blur 実装。
Golden PSNR ≥ 40dB = {n}/50。視覚証明: highlight グラデーション改善確認済み(スクショ保存)。
Regression {あり / なし}。
commit 案: 4 commit(primary / shaper+LUT2 / composite / motion blur)
OK なら Phase 3 に移ります。
```

---

## First command in Phase 3 chat

```
作業ディレクトリ: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

@apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-handoff.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md を読んで Phase 3 を実行してください。
Master plan ~/.claude/plans/sequential-thinking-gemini-web-swirling-prism.md の Day 3 節も確認。
```
