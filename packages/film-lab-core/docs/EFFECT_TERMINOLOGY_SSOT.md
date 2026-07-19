# Filmtone Effect Terminology SSoT

- Last reviewed: 2026-07-13 JST
- Owner: `packages/film-lab-core` (this is the canonical place because the contract keys live in `src/presets.ts` and iOS Swift types are already generated from this package via `ios-swift-payload.ts`).
- Consumers: `apps/desktop-film-lab-batch/messages/{en,ja}.json`, `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings`, future surfaces.
- Replaces: ad-hoc JP/EN labels scattered between Desktop messages and iOS xcstrings.

This document is the single source of truth for **every user-visible name** of an effect, parameter, section, or notice across all Filmtone surfaces. Implementation chats apply these labels verbatim. New effects are added here first, then propagated.

---

## 0. Why this exists

Three real-world divergences forced this SSoT:

1. **JP UI labels diverged** — Desktop uses poetic JP (`光のにじみ`, `ハイライトの柔らかさ`, `周辺の色ずれ`); iOS uses literal transliteration (`ブルーム量`, `圧縮量`, `RGB シフト`). Both are valid; pick one and propagate.
2. **EN UI labels also diverged** — e.g. `rgbShift` is `Color fringing` on Desktop but `RGB Shift` on iOS. `printContrast` is `Print snap` on Desktop but `Print Contrast` on iOS. `grainRadialMix` is `Grain edge emphasis` on Desktop but `Grain Radial Mix` on iOS.
3. **Desktop's own UI keys drift from contract keys** — Desktop has `controls.filmGrain` (UI key) but the contract key is `grainIntensity`; Desktop has `controls.compression` but the contract key is `compressionAmount`. This is internal-only drift but it confuses cross-surface alignment work.

Aligning iOS to "current Desktop" without a SSoT would bake in Desktop's existing inconsistencies. This doc reconciles them once.

---

## 1. Naming layers

| Layer | What | Where | Already canonical? |
|---|---|---|---|
| L1 | Contract key (camelCase) | `packages/film-lab-core/src/presets.ts` | ✅ yes — both apps already use these |
| L2 | EN UI label, **section-aware** (used inside a Desktop section header) | this doc | ❌ defined here |
| L3 | EN UI label, **flat** (used in iOS flat list) | this doc | ❌ defined here |
| L4 | JP UI label, **section-aware** | this doc | ❌ defined here |
| L5 | JP UI label, **flat** | this doc | ❌ defined here |
| L6 | Section / family | this doc | ❌ defined here |

L1 must never change without contract version bump. L2-L5 may evolve; this doc records the active version.

**Section-aware vs flat**: Inside a Desktop "Halation" section, sub-sliders read short labels like `Intensity / Spread / Hue` because the section header carries context. In iOS's current flat list, the same sliders need `Halation Intensity / Halation Spread / Halation Hue`. Both forms are needed until iOS adopts sections.

---

## 2. Style policy

### JP
- **Prefer concrete user-friendly JP** for end-user labels. The user is non-developer photographers/videographers.
- **カタカナ allowed** when (a) the term is industry-standard (`ハレーション`, `ビネット`, `ティント`), or (b) the JP equivalent is awkward / not understood by the target user.
- **Don't mix styles within a family**: if "Bloom" family uses `光のにじみ`, then sub-params follow that frame; don't mix `光のにじみ強さ` with `ブルームしきい値`.
- **Avoid English transliteration with `量` / `レンジ` suffix** when a real JP word exists (`ブルーム量` → `強さ`, `圧縮レンジ` → `階調の広がり`).

### EN
- **Short noun phrases**. Title Case for top-level controls; sentence case for hints.
- **Section-aware form drops parent prefix** (`Strength` not `Bloom Strength` when nested in a Bloom section).
- **Flat form keeps prefix** (`Bloom Strength`, `Halation Hue`).
- **No vendor / branded names** (e.g. don't say "Print snap" if generic "Print Contrast" reads truer).

### Cross-cutting
- Effect family names are **proper nouns**: "Bloom", "Halation", "Cross Filter", "Light Shafts" — never lowercase, never translated to ad-hoc Japanese.
- Section/group names use **plain plurals** in EN (`Effects`, `Optics`, not `Effect`).

---

## 3. Canonical terminology table

Notation:
- **AUTO**: Desktop is canonical → iOS adopts Desktop's value as-is.
- **DECIDE-N**: Desktop and iOS both have plausible values; user picks → see §4.
- **NEW**: SSoT introduces this label (neither Desktop nor iOS currently has it; needed for consistency).
- iOS impl?: ✅ live in v1.1 / 🟡 partial / 🔴 not yet (v1.2 candidate)
- Family is the parent grouping in section-aware UI. `—` means "top-level / no parent".

### 3.1 Tone / Color / Source adjustments

| Contract key | EN section-aware | EN flat | JP section-aware | JP flat | Family | iOS impl? | Resolution |
|---|---|---|---|---|---|---|---|
| `exposure` | Exposure | Exposure | 露出 | 露出 | Source | ✅ | AUTO |
| `contrast` | Contrast | Contrast | コントラスト | コントラスト | Source | ✅ | AUTO |
| `saturation` | Saturation | Saturation | 彩度 | 彩度 | Source | ✅ | AUTO |
| `temperature` | Temperature | Temperature | 色温度 | 色温度 | Source | ✅ | AUTO |
| `tint` | Tint | Tint | ティント | ティント | Source | ✅ | AUTO |
| `fade` | Fade | Fade | フェード | フェード | Source | ✅ | AUTO |
| `highlights` | Highlights | Highlights | ハイライト | ハイライト | Source | 🟡 | AUTO |
| `shadows` | Shadows | Shadows | シャドウ | シャドウ | Source | 🟡 | AUTO |
| `highlightsTrim` | Highlights (source) | Source highlights | ハイライト (素材) | 素材ハイライト | Source | 🔴 | AUTO (Desktop wins) |
| `shadowsTrim` | Shadows (source) | Source shadows | シャドウ (素材) | 素材シャドウ | Source | 🔴 | AUTO |
| `sourceTemp` | Source temperature | Source temperature | 素材の色温度 | 素材の色温度 | Source | 🔴 | AUTO |
| `sourceTint` | Tint (green / magenta) | Source tint | ティント（緑〜マゼンタ） | 素材ティント | Source | 🔴 | AUTO |
| `compressionAmount` | Highlight softness | Highlight softness | ハイライトの柔らかさ | ハイライトの柔らかさ | Process | 🟡 | **AUTO (Desktop wins; iOS replaces "Compression Amount" / "圧縮量")** |
| `compressionRange` | Tone span | Tone span | 階調の広がり | 階調の広がり | Process | 🟡 | **AUTO (Desktop wins; iOS replaces "Compression Range" / "圧縮レンジ")** |
| `printContrast` | Print snap | Print snap | 仕上げのコントラスト | 仕上げのコントラスト | Process | 🟡 | **DECIDE-1**: keep Desktop "Print snap" or change to "Print Contrast"? |

### 3.2 Hue/Tone color (split toning)

| Contract key | EN | JP | Family | iOS impl? | Resolution |
|---|---|---|---|---|---|
| `shadowHue` | Shadow hue | シャドウの色相 | Color | 🔴 | AUTO |
| `shadowTone` | Shadow tone | シャドウトーン | Color | 🔴 | AUTO |
| `highlightHue` | Highlight hue | ハイライトの色相 | Color | 🔴 | AUTO |
| `highlightTone` | Highlight tone | ハイライトトーン | Color | 🔴 | AUTO |

### 3.3 Bloom family

| Contract key | EN section-aware | EN flat | JP section-aware | JP flat | Family | iOS impl? | Resolution |
|---|---|---|---|---|---|---|---|
| (family header) | Bloom | Bloom | 光のにじみ | 光のにじみ | — | ✅ | AUTO (family name) |
| `bloomStrength` | Strength | Bloom Strength | 強さ | 光のにじみ・強さ | Bloom | ✅ | **AUTO (Desktop wins; iOS replaces "ブルーム量")** |
| `bloomThreshold` | Threshold | Bloom Threshold | しきい値 | 光のにじみ・しきい値 | Bloom | ✅ | **AUTO (iOS replaces "ブルームしきい値")** |
| `bloomRadius` | Radius | Bloom Radius | 半径 | 光のにじみ・半径 | Bloom | ✅ | **AUTO (iOS replaces "ブルーム半径")** |
| `bloomSoftKnee` | Soft knee | Bloom Soft Knee | ソフトニー | 光のにじみ・ソフトニー | Bloom | ✅ | AUTO |

#### Deep Glow profile family

`Deep Glow` is the canonical Filmtone feature name for the three optical
profiles whose compatibility ids remain `backlightVeil-1-8`,
`backlightVeil-1-4`, and `backlightVeil-1-2`. It is not a claim of parity with
an AE or third-party plug-in.

| Surface | EN | JP |
|---|---|---|
| Feature/group | Deep Glow | Deep Glow |
| Grouped variant 1 | Subtle | 控えめ |
| Grouped variant 2 | Balanced | 標準 |
| Grouped variant 3 | Strong | 強め |
| Standalone variant 1 | Deep Glow - Subtle | Deep Glow - 控えめ |
| Standalone variant 2 | Deep Glow - Balanced | Deep Glow - 標準 |
| Standalone variant 3 | Deep Glow - Strong | Deep Glow - 強め |

The low-level Bloom parameter family remains an advanced adjustment contract.
Do not expose `Backlight Veil`, density-only labels, `Light Bloom`, or
`光のにじみ` as alternate names for the Deep Glow profile family.

### 3.4 Halation family

| Contract key | EN section-aware | EN flat | JP section-aware | JP flat | Family | iOS impl? | Resolution |
|---|---|---|---|---|---|---|---|
| (family header) | Halation | Halation | ハレーション | ハレーション | — | ✅ | AUTO (industry-standard term) |
| `halationIntensity` | Intensity | Halation Intensity | 強度 | ハレーション強度 | Halation | ✅ | AUTO (iOS replaces "ハレーション量" → "ハレーション強度") |
| `halationSpread` | Spread | Halation Spread | 広がり | ハレーション広がり | Halation | ✅ | AUTO |
| `halationHue` | Hue | Halation Hue | 色相 | ハレーション色相 | Halation | ✅ | AUTO |
| `halationThreshold` | Threshold | Halation Threshold | しきい値 | ハレーションしきい値 | Halation | ✅ | AUTO |
| `halationRadius` | Radius | Halation Radius | 半径 | ハレーション半径 | Halation | ✅ | AUTO |
| `halationSoftKnee` | Soft knee | Halation Soft Knee | ソフトニー | ハレーションソフトニー | Halation | ✅ | AUTO |

### 3.5 Optical effects (single-slider)

| Contract key | EN | JP | Family | iOS impl? | Resolution |
|---|---|---|---|---|---|
| `vignette` | Vignette | ビネット | Optics | ✅ | **AUTO (Desktop wins; iOS replaces "周辺減光" → "ビネット")** |
| `diffusion` | Diffusion | 光の拡散 | Optics | ✅ | **AUTO (Desktop wins; iOS replaces "ディフュージョン" → "光の拡散")** |
| `lensSoftness` | Lens softness | レンズの柔らかさ | Optics | ✅ | **AUTO (Desktop wins; iOS replaces "Lens Softness" / "レンズソフト" → "Lens softness" / "レンズの柔らかさ")** |
| `rgbShift` | Color fringing | 周辺の色ずれ | Optics | ✅ | **DECIDE-2**: Desktop EN "Color fringing" or iOS EN "RGB Shift"? JP confirmed as "周辺の色ずれ" (Desktop wins). |

### 3.6 Grain family

| Contract key | EN section-aware | EN flat | JP section-aware | JP flat | Family | iOS impl? | Resolution |
|---|---|---|---|---|---|---|---|
| (family header) | Grain | Film Grain | フィルムグレイン | フィルムグレイン | — | ✅ | AUTO (Desktop wins; family is "Film Grain" / "フィルムグレイン") |
| `grainIntensity` | Strength | Grain Strength | 強さ | フィルムグレイン・強さ | Grain | ✅ | AUTO (Desktop has no slider for this directly; flat form derives from family) |
| `grainSize` | Size | Grain Size | 粒子の粗さ | 粒子の粗さ | Grain | ✅ | **AUTO (Desktop wins; iOS replaces "グレイン粒径" → "粒子の粗さ")** |
| `grainRadialMix` | Edge emphasis | Grain edge emphasis | 周辺の強さ | グレインの周辺の強さ | Grain | ✅ | **DECIDE-3**: Desktop EN "Grain edge emphasis" or iOS EN "Grain Radial Mix"? JP confirmed as "グレインの周辺の強さ" (Desktop wins). |

### 3.7 Cross Filter (Desktop only — v1.2 candidate on iOS)

iOS does not yet implement Cross Filter. JP names below are reserved for future iOS use; do not change Desktop side.

| Contract key | EN | JP | Family | iOS impl? |
|---|---|---|---|---|
| (family header) | Cross Filter | クロスフィルター | — | 🔴 |
| `crossFilterStrength` | Strength | 強度 | Cross Filter | 🔴 |
| `crossFilterSpikes` | Points | ポイント数 | Cross Filter | 🔴 |
| `crossFilterAngle` | Angle | 回転角度 | Cross Filter | 🔴 |
| `crossFilterLength` | Length | 光条の長さ | Cross Filter | 🔴 |
| `crossFilterThreshold` | Threshold | 輝度しきい値 | Cross Filter | 🔴 |
| `crossFilterChromatic` | Chromatic | 色分散 | Cross Filter | 🔴 |
| `crossFilterSizeLimit` | Source size | 光源サイズ | Cross Filter | 🔴 |
| `crossFilterRandomness` | Randomness | ランダム性 | Cross Filter | 🔴 |
| `crossFilterMinSpacing` | Streak spacing | 光芒の間隔 | Cross Filter | 🔴 |

### 3.8 Light Shafts (Desktop only — v1.2 candidate on iOS)

| Contract key | EN | JP | Family | iOS impl? |
|---|---|---|---|---|
| (family header) | Light Shafts | ライトシャフト | — | 🔴 |
| `shaftIntensity` | Light intensity | 光の強さ | Light Shafts | 🔴 |
| `shaftDecay` | Beam softness | 光の広がり | Light Shafts | 🔴 |
| `shaftOriginX` | Source X | 光源 X | Light Shafts | 🔴 |
| `shaftOriginY` | Source Y | 光源 Y | Light Shafts | 🔴 |

### 3.9 Film artifacts (Desktop only — v1.2 candidate on iOS)

| Contract key | EN | JP | Family | iOS impl? |
|---|---|---|---|---|
| `dustAmount` | Dust | ホコリ | Artifacts | 🔴 |
| `scratchAmount` | Film scratches | スクラッチ | Artifacts | 🔴 |
| `shutterAngle` | Shutter angle | シャッターアングル | Artifacts | 🔴 |
| `trailIntensity` | Trail length | 残像の長さ | Artifacts | 🔴 |

### 3.10 Color cast (CMY)

| Contract key | EN | JP | Family | iOS impl? | Resolution |
|---|---|---|---|---|---|
| `cyan` | Cyan | シアン | Color cast | ✅ | AUTO |
| `magenta` | Magenta | マゼンタ | Color cast | ✅ | AUTO |
| `yellow` | Yellow | イエロー | Color cast | ✅ | AUTO |

---

## 4. Decisions required

The following rows in §3 are flagged DECIDE-N. Resolve before propagating.

| ID | Question | Default if no answer | Implementation impact |
|---|---|---|---|
| **DECIDE-1** | `printContrast` EN: "Print snap" (Desktop) or "Print Contrast" (iOS)? | Use **"Print Contrast"** — clearer for non-photographers and matches the contrast family conceptually. | iOS keeps current EN; Desktop EN updates `controls.printContrast`. |
| **DECIDE-2** | `rgbShift` EN: "Color fringing" (Desktop) or "RGB Shift" (iOS)? | Use **"Color fringing"** — describes the *effect* the user sees, not the implementation mechanism. JP "周辺の色ずれ" already aligns with this framing. | iOS xcstrings updates EN value; Desktop unchanged. |
| **DECIDE-3** | `grainRadialMix` EN: "Grain edge emphasis" (Desktop) or "Grain Radial Mix" (iOS)? | Use **"Grain edge emphasis"** — same reason as DECIDE-2. Hint copy already explains the radial mechanism. | iOS xcstrings updates EN value; Desktop unchanged. |
| **DECIDE-4** | Optics source tag — bilingual JP (`メタデータ` / `推定`) (iOS-style) or EN-only (`metadata` / `assumed`) (Desktop-style) when JP locale? | Use **bilingual** (iOS-style). Optics source provenance is meta-info shown to end users; JP locale should read JP. | Desktop messages/ja.json adds JP values; Desktop video-probe-label.ts reads localized values. |
| **DECIDE-5** | Should Desktop UI keys be renamed to match contract? `controls.filmGrain` → `controls.grainIntensity`, `controls.compression` → `controls.compressionAmount`. Breaking change for any external i18n fork; internal-only otherwise. | **Yes, rename.** Drift between UI key and contract key has no upside and creates this exact category of confusion. | Desktop messages/{en,ja}.json key rename + UI code that reads them. |
| **DECIDE-6** | iOS UI structure direction — adopt Desktop-style sections in v1.2 (so labels can use **section-aware** form), or keep flat in v1.1.x and apply **flat** form? | **v1.1.x patch uses flat form** (lower risk). v1.2 plan includes section adoption and a label switch to section-aware form. | iOS implementation chat applies §3 JP-flat / EN-flat columns now; section-aware columns reserved for v1.2 chat. |

**Default policy**: if user does not respond before the implementation chat starts, the Default column is applied and noted in the implementation handoff PR description.

---

## 5. HDR notice canonical text

Desktop's text is end-user oriented ("brightness or color may look different"). iOS currently uses developer-flavored language ("PQ source detected", "tone-map"). Adopt Desktop's tone everywhere.

### 5.1 Title

| Locale | Canonical |
|---|---|
| EN | **HDR video loaded** |
| JP | **HDR動画を読み込みました** |

### 5.2 Body — generic (recommended single body across PQ / HLG / wideGamutUnknown variants)

| Locale | Canonical |
|---|---|
| EN | This environment may not be able to convert HDR video into a standard SDR video accurately. You can continue exporting, but brightness or color may look different in other apps. For color-critical exports, convert the clip to SDR in your camera app or editor before importing it. |
| JP | この環境では、HDR動画を標準のSDR動画として正確に変換できない場合があります。書き出しは続行できますが、他のアプリで見ると明るさや色が元動画と違って見えることがあります。正確な色で書き出したい場合は、カメラアプリや編集アプリでSDR動画に変換してから読み込んでください。 |

### 5.3 Body — variant-specific (only if user research shows generic is insufficient)

iOS currently splits PQ vs HLG vs wideGamutUnknown bodies. SSoT recommends **collapsing into one generic body** because:
- The user-visible *effect* is the same regardless of transfer function.
- PQ vs HLG is implementation detail; user only cares "color may look different".
- Maintenance cost of 3 variants × 2 locales = 6 strings is unjustified.

If iOS implementation chat finds a concrete UX reason to keep variants, document it inline in the xcstrings comment field; otherwise collapse to one.

### 5.4 Removed forbidden phrases

These phrases are **banned** in user-visible HDR notice text on any surface:

- `ffmpeg`, `zscale`, `libplacebo`, `tone-map`, `linearize`, `transfer function`, `PQ`, `HLG` (technical jargon)
- Homebrew install commands or any shell command
- "internal filter" / "fixture doc" links

Implementation chat must grep both apps for these strings post-change to ensure none leaked.

---

## 6. Section / family canonical names

Top-level section names that group multiple effects.

| EN | JP | Includes |
|---|---|---|
| Source adjustments | 素材の調整 | exposure, contrast, saturation, temperature, tint, fade, highlights, shadows, sourceTemp, sourceTint, highlightsTrim, shadowsTrim |
| Process | 階調 | compressionAmount, compressionRange, printContrast |
| Color | カラー | shadowHue, shadowTone, highlightHue, highlightTone |
| Color cast | 色被り | cyan, magenta, yellow |
| Bloom | 光のにじみ | bloomStrength, bloomThreshold, bloomRadius, bloomSoftKnee |
| Halation | ハレーション | halationIntensity, halationSpread, halationHue, halationThreshold, halationRadius, halationSoftKnee |
| Optics | 光学 | vignette, diffusion, lensSoftness, rgbShift |
| Grain | フィルムグレイン | grainIntensity, grainSize, grainRadialMix |
| Cross Filter | クロスフィルター | crossFilter* (Desktop now, iOS v1.2) |
| Light Shafts | ライトシャフト | shaft* (Desktop now, iOS v1.2) |
| Artifacts | フィルムの質感 | dustAmount, scratchAmount, shutterAngle, trailIntensity (Desktop now, iOS v1.2) |
| Effects | エフェクト | finishTools family selector (Mist / Glow / Cross / Texture / Lens / Motion) |

**Note**: "Effects" is the Desktop's `finishTools` umbrella. iOS adopts this name as-is in v1.2 if/when it ships finishTools.

---

## 7. Out of scope (handled elsewhere)

- **Optical recommendation labels** (`opticalRecipe*`, `opticalRecommendation*`) — these are end-user "recipes" that are intentionally JP-flavored on Desktop (`室内のあたたかい光`, `夜景の街明かり`). Not part of effect terminology. iOS does not implement recommendation system in v1.1.
- **Toast / status copy** (`toast.save.success`, etc.) — UX-flavored, not effect names. iOS v1.1 already has these and they are fine as-is.
- **Preset names** (`Cinematic`, `Neutral`, `Clean Base`, etc.) — separate canonical list; not in this SSoT.
- **Onboarding / tooltip prose** — translation-as-needed, not term-level alignment.

---

## 8. Future: generate-from-SSoT

L2-L5 columns of §3 are currently maintained by hand in two places (Desktop messages.json + iOS xcstrings). The natural evolution is:

1. Add `packages/film-lab-core/src/terminology.ts` exporting a typed table mirroring §3.
2. Extend the existing `ios-swift-payload.ts`-style codegen to emit:
   - `apps/desktop-film-lab-batch/messages/{en,ja}.json` `controls.*` block
   - `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings` `filmtone.param.*` entries
3. Make the codegen idempotent and gate it behind `bun run generate:terminology --check` similar to existing `bun run generate:filmtone-ios-swift --check`.

This is a v1.2 task; not part of the v1.1.x alignment chat.

---

## 9. Change log

| Date | Change | By |
|---|---|---|
| 2026-04-26 | Initial draft. Captures divergences observed in Desktop messages.json (en+ja) and iOS xcstrings as of `feat/renewal-2026-phase2-motion-dot @ 42a15541`. | doc-prep chat |
