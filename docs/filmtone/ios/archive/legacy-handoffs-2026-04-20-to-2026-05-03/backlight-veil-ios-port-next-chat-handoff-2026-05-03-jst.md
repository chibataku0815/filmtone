# Backlight Veil iOS Port — Next Chat Handoff (2026-05-03 JST)

## 0. 結論サマリ (TL;DR)

- Filmtone Desktop に **Backlight Veil** という新しい optical filter family (`backlightVeil-1-8` / `-1-4` / `-1-2`) を Phase 1 で実装し main にマージ済み。
- 視覚 A/B で **新 1/2 = 視覚的に破綻しない上限** が確定。1/4 は mid、1/8 は subtle。値カーブは §5 にロック。
- iOS 側は **未実装**。次 chat の使命は **同じ family / 同じ 3 density / 同じ視覚的振る舞い** を Filmtone iOS (Swift native pipeline) に port すること。
- Desktop が依存している WebGPU composite の `direct + scatter` math (`opticalDirectTransmission` ほか 6 keys) が iOS native 側に **同一 math として存在するか** をまず探索 → 無ければ Phase 0 / Phase 1 を分けて実装。
- Phase 2 (専用 veiling glare shader pass / directional anisotropic plate / wide pyramid) は Desktop でも未着手。iOS はまず Phase 1 parity を取る。

---

## 1. このドキュメントの読み方

- 読み順: §0 → §2 (Desktop で何が landed したか) → §4 (固有値カーブ) → §6 (iOS 側の前提と open questions) → §11 (引き継ぎプロンプト)。
- 数値は §5 が canonical。再 tune したら §5 を更新する。
- iOS 側にすでに同名 family が profile JSON で存在するように見える場合は **まず Swift surface (`FilmtoneBuiltInCatalog.swift` / `FilmtoneColorPipeline.swift` 等) と突き合わせて live/frozen を確認** する (handoff 鵜呑み禁止 / `feedback_verify_before_quoting_handoff`)。
- 用語ロック: 「動画」(× 短尺動画) / 「video」(× short-form video)。canonical は life `docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`、commit `5ce6d55` (2026-05-01)。

---

## 2. このセッションで Desktop に landed したもの

### 2.1 ブランチ / commit

- worktree: `feature/optical-veiling-glare-research` (`.claude/worktrees/optical-veiling-glare-research/`)。
- commit (順):
  1. `eb9eb04 chore(desktop): freeze AI pick UI surface` — `AiDevToggle` / `AiScenePickCard` を `AI_SCENE_PICK_UI_VISIBLE = false` で凍結 (LLM 課金 dev card と常時 toggle bar が UI noise だったため)。`HALO_PRISM_CONTROLS_VISIBLE` と同パターン。
  2. `2c8e15d feat(filmtone): add Backlight Veil optical filter family (Phase 1 desktop)` — 本 lane の本体。
  3. `(merge to main)` — 本 doc commit 後に main へ非 FF merge。
- すべて main へ merge 済み (本 doc 作成完了後に merge 実行)。

### 2.2 修正したファイル (additive only)

| path | 変更 |
|---|---|
| `packages/film-lab-core/src/optical-filter-profiles.ts` | `OpticalFilterFamily` union に `"backlightVeil"` 追加。`OPTICAL_FILTER_PROFILES` array に 3 entry (`backlightVeil-1-8` / `-1-4` / `-1-2`) 追記 |
| `packages/film-lab-core/src/optical-filter-profiles.test.ts` | 期待 ID list 拡張 |
| `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx` | `OPTICAL_FILTER_FAMILY_ORDER` / `OPTICAL_FILTER_FAMILY_LABELS` に warmMist→backlightVeil→pearlGlow の順で挿入 |
| `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts` | `opticalFilterFamilySchema` z.enum 拡張 |
| `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts` | `backlightVeil-1-4` JSON round-trip test 追加 |
| `packages/film-lab-core/dist/index.{js,d.ts}` | tsup rebuild (CLAUDE.md §6 #2 で track 対象) |
| `packages/film-lab-smart-look/dist/index.d.ts` | bun install postinstall artefact (track 対象) |
| `apps/desktop-film-lab-batch/src/renderer/OpticalFinishRecommendationPanel.tsx` | AI pick freeze (`eb9eb04`) |
| `docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/backlight-veiling-glare-implementation-plan-2026-05-03-jst.md` | Phase 1 / 2 / 3 / 4 / 5 全体計画 (origin handoff doc) |

### 2.3 verify 通過状況

```
bun test packages/film-lab-core/src/optical-filter-profiles.test.ts             5 pass
bun test packages/film-lab-core/src/optical-recommendation.test.ts              5 pass
bun run build:core                                                              ESM + DTS pass
bun run build:renderer                                                          ESM + DTS pass
bun test apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts (incl. backlightVeil round-trip)  25 pass
bun run verify:desktop  (typecheck:desktop / typecheck:shared / smart-look smoke) all pass
git diff --check                                                                clean
```

視覚 A/B (user-driven, ship gate): outdoor backlight portrait + indoor window backlight でユーザーが目視確認、新 1/2 を「破綻しない上限」と確定。新 1/4 / 1/8 は線形補間 (§5)。

---

## 3. Backlight Veil とは何か (look の定義)

### 3.1 一行 mission

「強い光源 (太陽 / 大面積の白い窓) が レンズ内で散乱し、画面全体の黒を持ち上げ、低周波な乳白色の veil を乗せる」 ─ 既存 Bloom (highlight 局所 glow) / Halation (colored edge glow) / Mist (whole-image diffusion) では再現できない、lens 自体が光に飲まれる感覚。

### 3.2 reference 3 系統 (canonical visual targets)

| 種別 | 特徴 |
|---|---|
| **outdoor sun silhouette** (e.g. ビーチ silhouette) | 太陽が画面外/枠ぎりぎりから入射。シルエットの黒が grey-flat にならず光源側から veil。haze は uniform に近い |
| **outdoor cliff / wedding portrait backlit** | 強い directional plate が upper-left 等から大きく。haze gradient 顕著 (光源側濃く反対側薄く) |
| **indoor window backlight** | 大面積の白い窓 (specular point ではない平面光) が source。境界硬すぎず、室内に creamy haze が広がる。被写体の顔は読めるが warm wash が乗る |

### 3.3 視覚的 character (NG / OK)

| 観点 | OK (target) | NG (避ける) |
|---|---|---|
| 黒の挙動 | scatter による光持ち上げ | global flat fade |
| highlight | clip しても creamy soft saturate | hard digital plate |
| 色味 | cream / peach / golden | yellow-green global cast |
| bloom | wide soft falloff | localized sharp glow |
| 全体感 | "lens が光に飲まれる" | "global hazy filter" |

---

## 4. なぜ既存 Bloom / Halation / Mist では足りないか

### 4.1 Bloom = highlight-thresholded local glow

luminance threshold を超えた pixel から pyramid blur で広げる。**threshold で gate するので光源近傍に局所化** する。広域 haze にはならない。

### 4.2 Halation = colored edge glow

bloom-like だが warm tint で edge を狙う。**「窓の中に creamy haze が満ちる」のような plate 効果は出ない**。

### 4.3 Mist = uniform whole-image diffusion

画面全体を一様にぼかす。**source 方向性 (光源側濃く反対側薄く) は持たない**。

### 4.4 Backlight Veil = direct + scatter math (Desktop WebGPU が既に実装)

Desktop の `composite.frag.wgsl.ts` に **既存の direct+scatter blend math** がある:

```
// from packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts:288-336
let baseLuma = dot(baseRgb, LUMA_R709);
let shadowHold = 1.0 - smoothstep(0.02, 0.34, baseLuma);
let directLoss =
  (1.0 - opticalDirectTransmission) * opticalScatterStrength
  * (1.0 - shadowHold * opticalBlackRetention * 0.75);
let direct = color.rgb * (1.0 - directLoss);

let highlightMask = smoothstep(0.42, 1.28, dot(max(baseRgb, vec3f(0.0)), LUMA_R709));
let highlightDrive = mix(1.0, 1.0 + highlightMask * 1.65, opticalHighlightReactivity);
let blackProtect = mix(1.0, smoothstep(0.04, 0.48, baseLuma), opticalBlackRetention);
let warmBias = vec3f(
  1.0 + opticalWarmScatter * 0.18 + opticalSpectralTail * 0.12,
  1.0 + opticalWarmScatter * 0.05,
  1.0 - opticalWarmScatter * 0.10 - opticalSpectralTail * 0.08,
);
let scatterEnergy = bloom * 0.82 + halation * 1.08 + diffused * diffusion * 0.24;
let scatter = glowShoulder(
  scatterEnergy * warmBias * opticalScatterStrength * highlightDrive * blackProtect
);
color = vec4f(direct + scatter, color.a);
```

これが Backlight Veil の本質。bloom / halation / diffused buffer を **scatter source として再利用** し、highlight に応じて scatter を増幅、shadow lift を制御し、warm/spectral bias を加える。

**Phase 1 = 既存 math を新 profile params でドライブする probe**。Phase 2 (未着手) = 専用 source mask + wide pyramid + anisotropic plate 用 dedicated render pass。

---

## 5. 確定値カーブ (canonical, locked)

すべての数値は `packages/film-lab-core/src/optical-filter-profiles.ts` (commit `2c8e15d`) を canonical とする。iOS port では **同一値を 1:1** で保つこと。

### 5.1 共通 metadata

```ts
family: "backlightVeil"
density: "1/8" | "1/4" | "1/2"
displayName: "Backlight Veil 1/8" | "Backlight Veil 1/4" | "Backlight Veil 1/2"
shortLabel: "1/8" | "1/4" | "1/2"
```

### 5.2 param 値 table

| param | 1/8 (subtle) | 1/4 (mid) | 1/2 (max stable) |
|---|---:|---:|---:|
| `bloomThreshold` | 0.66 | 0.56 | 0.50 |
| `bloomStrength` | 0.20 | 0.38 | 0.60 |
| `bloomRadius` | 0.70 | 0.80 | 0.88 |
| `bloomSoftKnee` | 0.70 | 0.76 | 0.82 |
| `diffusion` | 0.12 | 0.24 | 0.38 |
| `depthMistGain` | 0.20 | 0.34 | 0.50 |
| `depthGlowGain` | 0.16 | 0.27 | 0.40 |
| `depthMistRayAngleGain` | 0.34 | 0.50 | 0.66 |
| `depthBloomRayAngleGain` | 0.24 | 0.38 | 0.52 |
| `depthHalationRayAngleGain` | 0.20 | 0.30 | 0.40 |
| `depthMistFieldPsfGain` | 1.00 | 1.06 | 1.12 |
| `depthBloomFieldPsfGain` | 1.00 | 1.04 | 1.08 |
| `depthHalationFieldPsfGain` | 1.00 | 1.03 | 1.06 |
| `depthMistFieldPsfRadiusPx` | 18 | 25 | 32 |
| `depthBloomFieldPsfRadiusPx` | 10 | 14 | 18 |
| `depthHalationFieldPsfRadiusPx` | 14 | 18 | 22 |
| `halationIntensity` | 0.07 | 0.14 | 0.22 |
| `halationThreshold` | 0.58 | 0.52 | 0.46 |
| `halationRadius` | 0.52 | 0.62 | 0.74 |
| `halationHue` | 22 | 22 | 22 |
| `halationSoftKnee` | 0.48 | 0.56 | 0.64 |
| `lensSoftness` | 0.06 | 0.08 | 0.10 |
| `rgbShift` | 0.0005 | 0.0007 | 0.0009 |
| `opticalDirectTransmission` | 0.92 | 0.81 | 0.70 |
| `opticalBlackRetention` | 0.78 | 0.56 | 0.36 |
| `opticalScatterStrength` | 0.42 | 0.66 | 0.90 |
| `opticalHighlightReactivity` | 0.62 | 0.78 | 0.95 |
| `opticalWarmScatter` | 0.10 | 0.17 | 0.24 |
| `opticalSpectralTail` | 0.04 | 0.07 | 0.10 |

### 5.3 behavior 値 table

`OpticalFilterBehavior` は recommendation system 用 metadata (rendering には影響しない)。iOS にも同等構造があれば同期、無ければ無視可。

| behavior | 1/8 | 1/4 | 1/2 |
|---|---:|---:|---:|
| `blackRetention` | 0.78 | 0.56 | 0.36 |
| `directTransmission` | 0.92 | 0.81 | 0.70 |
| `scatterStrength` | 0.42 | 0.66 | 0.90 |
| `scatterCore` | 0.42 | 0.56 | 0.70 |
| `scatterTail` | 0.50 | 0.68 | 0.86 |
| `highlightReactivity` | 0.62 | 0.78 | 0.95 |
| `warmth` | 0.10 | 0.17 | 0.24 |
| `spectralTail` | 0.04 | 0.07 | 0.10 |
| `depthResponse` | 0.32 | 0.50 | 0.66 |
| `rayAngleResponse` | 0.32 | 0.50 | 0.66 |
| `fieldPsfScale` | 1.00 | 1.05 | 1.10 |

### 5.4 値カーブ設計の意図

- 強度系 (`bloomStrength` / `halationIntensity` / `diffusion` / `opticalScatterStrength`) は **新 1/2 を 100% として** 1/4 ≒ 60-65%、1/8 ≒ 30-35% の linear 補間。
- 逆相系 (`opticalDirectTransmission` / `opticalBlackRetention`) は 1.0 方向に緩める ─ 1/8 で shadow をほぼ保持、1/2 で shadow を veil に流す。
- hue 系 (`halationHue` / `opticalWarmScatter` / `opticalSpectralTail`) は 質を保つため線形より緩めに減衰。`halationHue: 22` は全 density で固定 (warm-amber)。

### 5.5 プリセットとの関係

- profile を選択すると `buildOpticalFilterParamPatch(id)` が `OPTICAL_FILTER_BASE_PATCH` (PRESETS.reset の 56 optical keys) ∪ `profile.params` を返し、現在 params を上書きする。
- `crossFilterStrength` / `haloPrismStrength` は `params` で明示しないため reset 値 (= 0) にリセットされる ─ Backlight Veil 適用時に streak / prism halo が同時発火しない設計。

---

## 6. iOS port — 前提と open questions

### 6.1 確認済 iOS surface (このセッションで grep)

- Swift native: `apps/capacitor-film-lab-ios/ios/App/App/`
  - `FilmtoneColorPipeline.swift` — Phase 0 grade pipeline 本体と推測
  - `FilmtonePhase0Math.swift` — math 本体
  - `FilmtoneBuiltInCatalog.swift` — built-in profile / preset catalog
  - `FilmtonePhase0Generated.swift` — generated (おそらく codegen 由来)
  - `FilmtoneExportSession.swift` — export sidecar / metadata
  - `FilmtoneExportSidecarBuilder.swift` — JSON sidecar builder (Desktop の export-metadata-session 相当)
- script tests: `apps/capacitor-film-lab-ios/scripts/swift/test-*.swift`、`verify-phase0-contract.swift`
- iOS CLAUDE.md (`apps/capacitor-film-lab-ios/CLAUDE.md`): Phase 0 contract / pbxproj 4-section 不変条件 / fastlane release 手順あり (詳細はそちら)。
- builtin catalog ドキュメント: `apps/capacitor-film-lab-ios/docs/builtin-catalog.md` (このセッションでは未読、要参照)。

### 6.2 未確認 (次 chat の探索 task)

1. **iOS 側に optical-filter-profile JSON / Swift catalog があるか?** ある場合、Desktop の `OPTICAL_FILTER_PROFILES` と同期する codegen ルートがあるか? (`bun run generate:ios-swift` が root package.json scripts に存在 ─ Phase 0 codegen の延長で profile も同期されている可能性)
2. **iOS 側に `direct + scatter` math が存在するか?**
   - 存在する → 同 6 keys (`opticalDirectTransmission` 等) を Swift 側でも認識する必要。Phase 0 contract に既に含まれている可能性。
   - 存在しない → §4.4 の WGSL math を Swift 側に新規実装。Metal compute / Core Image kernel / CPU SIMD のどれを使うかは現行 pipeline に依存。
3. **iOS 側の bloom / halation / diffusion pyramid は何 mip 持っているか?** Desktop は bloom 5 mips / halation 6 mips / diffusion 3-level。同等のスペクトル広さがあるか確認 ─ 無いと geometric reach 不足で render が違う。
4. **iOS 側の Lens Filter family UI** ─ Desktop は `OPTICAL_FILTER_FAMILY_ORDER` を tsx の inline 定数で管理 (i18n JSON ではない)。iOS は SwiftUI / Capacitor bridge どちら経由で family chip を出しているか?
5. **export sidecar metadata** ─ Desktop は `opticalFilterFamilySchema` z.enum を拡張した。iOS の `FilmtoneExportSidecarBuilder.swift` も同 family を enum として持っているか? もし persist 互換が必要なら "backlightVeil" の追加が必要。
6. **WebGL fallback の iOS 影響** ─ Desktop には WebGL composite path があり direct+scatter 未実装 = silent degrade。iOS は完全 native pipeline (Capacitor preview のみ web) なので、preview / export ともに native で同 math 実装が必須。

### 6.3 Phase 区分け (iOS 側)

| Phase | 内容 | gating |
|---|---|---|
| **iOS-Phase 0**  | (前提確認) 上記 §6.2 questions の探索のみ。コード変更なし。`FilmtoneColorPipeline.swift` / `FilmtonePhase0Math.swift` / Phase 0 contract codegen 経路を読む | sequential-thinking + grep |
| **iOS-Phase 1a** | `direct + scatter` math が iOS native に **既に存在する** 場合: profile catalog に backlightVeil 3 entry を追加するだけ。Desktop の値カーブ §5.2 を 1:1 で写す | unit test (Swift script test) + xcodebuild |
| **iOS-Phase 1b** | math が **存在しない** 場合: §4.4 の WGSL を Swift / Metal に port。`composite.frag.wgsl.ts:288-336` をまず逐語的 (rgb 空間、係数すべて) に Swift 実装し、Phase 0 math contract に組み込む。codegen ルートがあれば codegen 出力を更新 | Swift unit test (`scripts/swift/test-*.swift` パターン) で WGSL と同じ結果が出ることを照合 |
| **iOS-Phase 1c** | UI surface (Lens Filter chip / family label) を iOS 側にも追加 | snapshot test (もしあれば) + xcodebuild |
| **iOS-Phase 1d** | export sidecar の family enum 拡張 | round-trip test |
| **iOS-Phase 2**  | 専用 veiling-glare shader pass (directional anisotropic plate / wide pyramid) ─ **Desktop でもまだ未着手**。iOS 単独で先行 port しない | (separate lane) |

### 6.4 visual gate (iOS)

iOS でも Desktop と同じ reference 3 系統 (§3.2) で視覚 A/B を行う。1/2 が Desktop と同じ "破綻しない上限" になっていることが必須。**iOS の方が強く / 弱く出る場合は WGSL math と Swift port の係数誤差を疑う** (gamma / color space / shadowHold 閾値の数値ずれが典型)。

---

## 7. WebGL silent degrade と WebGPU 専用性 (Desktop 既知の限界)

Desktop は WebGPU composite (`packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`) でのみ direct+scatter 実装。WebGL composite (`packages/film-lab-renderer/src/webgl/shaders/composite.frag.ts`) は screen-blend のみで `optical*` keys を query / upload しない ─ WebGPU 不在環境では Backlight Veil profile が **静かに退化** (bloom/halation/diffusion params のみ適用)。

iOS Capacitor preview が WebGPU を使えるか / native 経由か で扱い分けが必要。一般に iOS 17+ Safari は WebGPU 限定的 (Behind feature flag)。**iOS の preview は native pipeline を信じるのが安全**。

---

## 8. 既知の隣接 bug (Backlight Veil とは独立 / 別 lane)

### 8.1 Desktop mezzanine URL swap failure

ProRes / LOG 4K mov を読み込むと `[mezzanine] 完了` で transcode mp4 はできるが、**MediaLoader が原本 .mov を decode しに行って失敗** する。`progressiveLoad.startProgressiveLoad` の URL swap が適用されていない。

- 影響: 動画素材で Backlight Veil の visual A/B が即時にできない (静止画 / 手動 ffmpeg transcode で workaround)
- 別 lane で起票推奨。iOS 側にも類似の mezzanine cache failure が存在 (life `quality-mezzanine-cache-failure-2026-05-02` ─ iOS 系)
- このセッションでは触らない (本質 = Backlight Veil 視覚)

### 8.2 `*FieldPsfRadiusPx` 絶対 px (preview/export mismatch)

`depthMistFieldPsfRadiusPx: 32` 等は **絶対 pixel** 値。1080p preview と 4K export で kernel 幅が変わる可能性。Desktop §Risks/Resolution-dependent radius と整合 ─ Phase 1 では reference plan の値をそのまま使い視覚で確認、差が顕在化したら normalized radius 化を別 lane で。**iOS port でも同じ規約を踏襲**。

### 8.3 `opticalBlackRetention: 0.36` (新 1/2)

global fade に近づく下限。indoor window で顔が潰れる場合は値を引き上げる (energy/threshold axis tune)。iOS 視覚 gate で監視。

---

## 9. 運用原則 / 不変条件 (commit 前 reminder)

- **本質優先 / 外殻最小** (life CLAUDE.md と整合): 製品挙動を直接動かす変更 = 本質。XCTest 6 並列 / formal QA 手順書 / 過剰 i18n / 装飾 banner = 外殻 (user 明示時のみ)。
- **保守的ヘッジを優先しない**: 「念のため fallback」「v1.x 後回し」は取らない。プロダクト品質に効く判断を取る。
- **思考は sequential-thinking 必須**: 設計判断 / lane 衝突 / 不変条件 gate は `mcp__sequential-thinking`。記憶ベース断言禁止。
- **不確かなら検索**: API / Capacitor / iOS SDK / Metal / Core Image 仕様は `gemini-search` → `WebSearch` の順。記憶ベース推測は `feedback_no_guessing_davinci_plugins` / `feedback_verify_before_documenting` 違反。
- **handoff 鵜呑み禁止**: 旧 chat の handoff doc を引用する前に現行 surface (`grep` / Swift / pbxproj) と突き合わせて live/frozen 確認 (`feedback_verify_before_quoting_handoff`)。
- **bun 必須**: `bun install` / `bun run` / `bun add`。`npm` 禁止、`bun.lock` が正本。
- **Git 操作は user**: 自動 commit / push 禁止。user 明示要求時のみ。
- **iOS pbxproj 4-section 不変**: 新 .swift 追加時は `PBXBuildFile` / `PBXFileReference` / `PBXSourcesBuildPhase` / `PBXGroup` の 4 セクションすべてに登録 ─ `grep '<新ファイル名>' ios/App/App.xcodeproj/project.pbxproj | wc -l` >= 4。
- **JSX comment を return ( の直下に置かない** (Desktop 側、`feedback_no_jsx_comment_outside_root_return` 既発火 2 回)。

---

## 10. 検証コマンド (iOS port 完了時に走らせるべきもの)

```bash
# 共有 (root の filmtone repo で)
bun run typecheck:shared
bun test packages/film-lab-core/src/optical-filter-profiles.test.ts

# iOS specific
cd apps/capacitor-film-lab-ios

bun run build                                  # tsc --noEmit + vite build
bun run cap:sync:ios                           # Swift 単独変更ならスキップ可

xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO

bun test src/lib/phase0-state.test.ts          # Phase 0 contract test
bun run verify:swift-contract                  # ./scripts/verify-phase0-contract.sh

# 必要に応じて Swift unit test
swift apps/capacitor-film-lab-ios/scripts/swift/test-source-profile-math.swift
# (Backlight Veil 用 test を追加する場合は同パターンで)
```

life truth scripts (release / iOS 状態を主張する前に必須):

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

doc とスクリプトが食い違ったら **スクリプトを信頼**。

---

## 11. 引き継ぎプロンプト (次 chat 開始時にそのまま貼る)

> Filmtone iOS に **Backlight Veil** optical filter family を Phase 1 として port してください。
>
> 前提となる canonical doc:
> - 本 handoff: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/backlight-veil-ios-port-next-chat-handoff-2026-05-03-jst.md` (このファイル) ─ §0 / §2 / §5 / §6 を必ず読む。
> - Desktop Phase 1 計画書: `docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/backlight-veiling-glare-implementation-plan-2026-05-03-jst.md`
> - Desktop 実装の canonical 値: `packages/film-lab-core/src/optical-filter-profiles.ts` (commit `2c8e15d`)
> - WGSL scatter math 本体: `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts:288-336`
> - iOS リポルール: `apps/capacitor-film-lab-ios/CLAUDE.md` (pbxproj 4-section 不変条件 / fastlane / Phase 0 contract)
> - root リポルール: `CLAUDE.md` (本質優先 / 保守的ヘッジ禁止 / git は user 操作 / bun 必須)
> - life CLAUDE.md: `/Volumes/SamsungPortableSSDX5001/documents/life/CLAUDE.md`
>
> **第 1 タスク (iOS-Phase 0 = 探索のみ、コード変更なし)**:
> 以下を `mcp__sequential-thinking` で順に確認し、コード surface と突き合わせて report してください。記憶ベース推測禁止、すべて grep / Read で verify。
>
> 1. iOS 側に optical-filter-profile catalog (Swift / JSON / generated) が存在するか? あれば location と shape を report。`FilmtoneBuiltInCatalog.swift` / `FilmtonePhase0Generated.swift` / `apps/capacitor-film-lab-ios/docs/builtin-catalog.md` を起点。
> 2. iOS 側の Phase 0 / color pipeline (`FilmtoneColorPipeline.swift` / `FilmtonePhase0Math.swift`) に `opticalDirectTransmission` / `opticalBlackRetention` / `opticalScatterStrength` / `opticalHighlightReactivity` / `opticalWarmScatter` / `opticalSpectralTail` の 6 keys が **既に存在するか** ─ 関連する direct + scatter blend math が実装されているか?
> 3. iOS 側の bloom / halation / diffusion 実装 (mip 数 / kernel 経路 / Metal vs Core Image)。Desktop の 5 / 6 / 3-level pyramid と比較。
> 4. iOS 側 Lens Filter family UI (SwiftUI / Capacitor bridge) の現状と、新 family 追加の最小 diff surface。
> 5. iOS 側 export sidecar (`FilmtoneExportSidecarBuilder.swift`) に family enum がある場合、Desktop の `opticalFilterFamilySchema` z.enum と同期方法。
> 6. Phase 0 contract codegen (`bun run generate:ios-swift` 等) の経路 ─ Desktop の `optical-filter-profiles.ts` を変更すると iOS の Generated swift が更新される自動経路があるか?
>
> **第 2 タスク (報告 → 実装計画)**:
> 第 1 タスクの結果に応じて以下を ExitPlanMode で plan として提示。
>
> - direct+scatter math が iOS native に **既存** → iOS-Phase 1a (profile catalog 拡張のみ) の最小 diff plan
> - **未実装** → iOS-Phase 1b (Swift / Metal で WGSL math を 1:1 port) の plan。逐語的 port (rgb 空間、係数すべて 1:1)。Swift unit test (`scripts/swift/test-*.swift` パターン) で WGSL 出力と一致することを照合。
>
> **§5 の 3 density 値カーブ (1/8 / 1/4 / 1/2) は全部 1:1 で iOS にも適用**。再 tune は禁止 (Desktop で破綻しない上限を確認済み)。
>
> 視覚 gate: outdoor sun silhouette / outdoor cliff backlight / indoor window backlight の 3 系統で実機 (TestFlight or Simulator) で A/B。1/2 が Desktop と同じ "破綻しない上限" であることが ship gate。
>
> 出力ルール:
> - 日本語、技術用語英語可。ファイル参照は `path/to/file:line` 形式。簡潔・行動志向。
> - **Git 操作は user が行う** (自動 commit / push 禁止、user の明示要求時のみ)。
> - `mcp__sequential-thinking` 必須。`gemini-search` / `WebSearch` を使って iOS / Metal / Core Image / Capacitor 仕様を曖昧なら verify。
> - 並列 stream silently 縮退禁止。完了時 handoff §8.5 4 セクション (Plan Compliance / Cross-Stream Visibility / Scope Diff / 残タスク enumeration)。
>
> Out of scope (このチャットでは触らない):
> - Phase 2 (専用 veiling-glare shader / wide pyramid / anisotropic plate) ─ Desktop でも未着手
> - mezzanine URL swap bug (Desktop / iOS 両方に存在、別 lane)
> - optical-recommendation の scoring 更新 (Phase 4)
> - WebGL fallback (iOS は native pipeline 前提)
>
> まず探索結果と plan を出してください。コード変更は plan 承認後。
