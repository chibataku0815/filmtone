# Filmtone Effect Terminology Alignment Handoff

- Date: 2026-04-26 JST
- Writer: doc-prep chat (this chat does not implement)
- Target chat: implementation chat that propagates the SSoT to both apps
- Repo: `chibatakumi-portfolio` (`/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`)
- Branch at handoff: `feat/renewal-2026-phase2-motion-dot @ 42a15541`
- **SSoT (must read first)**: `packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md`

This handoff exists because Desktop and iOS evolved independent UI labels for the same effects. The SSoT now defines canonical names. This doc is the procedural runbook to apply them.

---

## 0. Verbatim cold-start prompt (paste into next chat)

```
Filmtone の effect 用語を Desktop / iOS 間でアライメントしてください。SSoT は確定済 (`packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md`)。

このチャットは SSoT を「実装」する担当です。新規用語の提案・議論はしないでください。SSoT が canonical です。

進め方:

1. 必ず最初に `packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md` を end-to-end で読む。
2. `docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-effect-terminology-alignment-handoff-2026-04-26-jst.md` (このチャットを起こした handoff) の §2 pre-flight、§3 file-by-file checklist、§4 verification に沿って実装。
3. SSoT §4 の DECIDE-1〜6 が user により未確定なら、Default 列をそのまま採用し、PR description / commit message に「DECIDE-N: applied Default = X」と明記する。Default は SSoT §4 の表を参照。
4. user に判断を求めるのは、SSoT に書かれていない新規 divergence を発見した場合のみ。SSoT を改訂する権限はある (PR でレビュー)。

絶対にやらないこと:
- SSoT の用語を勝手に変える (PR で SSoT を更新するなら可)
- iOS UI 構造を flat → sectioned に変える (DECIDE-6 が v1.1.x patch を選択しているため、v1.2 別チャットの担当)
- iOS に Cross Filter / Light Shafts / Artifacts native 実装を足す (v1.2 別チャットの担当)
- HDR notice 文言に `ffmpeg`, `zscale`, `libplacebo`, `tone-map`, `PQ`, `HLG` などの技術用語を残す (SSoT §5.4 で禁止)

成果物:
- iOS xcstrings + Desktop messages.json + (任意) HDR notice TSX/Swift 修正
- 1 PR (or 2 PR — iOS / Desktop separable)
- verification 出力を PR description に貼る
```

---

## 1. Why this is doc-then-implement-split

The user's instruction (2026-04-26 JST) was:
> 全ての実装は行う前提でこのチャットでは doc 整理をしてください。実装は別チャットに担当してもらいましょう。

Doc chat must (a) capture every observed divergence, (b) commit to canonical names where Desktop-as-canonical resolves it automatically, (c) flag genuinely two-way decisions as DECIDE-N, (d) leave a verbatim runbook so the implementation chat does not re-investigate. This handoff plus the SSoT must be enough on their own.

---

## 2. Pre-flight (implementation chat does this first)

```bash
# 1. Verify Filmtone state hasn't drifted since this handoff was written.
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh

# Expected at handoff time:
#   iOS  public_version  = 1.1
#   iOS  xcode marketing = 1.1, build = 2
#   Desktop public latest = 1.0.3
#   Branch = feat/renewal-2026-phase2-motion-dot
# If anything has moved meaningfully (e.g. iOS public != 1.1, Desktop != 1.0.3),
# re-read this handoff and confirm the file paths in §3 still exist before editing.

# 2. Confirm SSoT readable.
ls -la /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md

# 3. Confirm working tree is the right branch.
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
git status --short
git rev-parse --abbrev-ref HEAD
```

If `git status --short` shows `M apps/capacitor-film-lab-ios/ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` (logo refresh in progress), leave it untouched — it is unrelated to terminology.

---

## 3. File-by-file checklist

Apply changes in this order. Each file has a "what to change" section and a "what NOT to change" guardrail.

### 3.1 iOS — `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings`

**What to change** (per SSoT §3 JP-flat / EN-flat columns + DECIDE-1..3 per §4 Default):

| Key | Current EN | Current JP | New EN | New JP |
|---|---|---|---|---|
| `filmtone.param.bloom_strength` | Bloom Strength | ブルーム量 | Bloom Strength | 光のにじみ・強さ |
| `filmtone.param.bloom_threshold` | Bloom Threshold | ブルームしきい値 | Bloom Threshold | 光のにじみ・しきい値 |
| `filmtone.param.bloom_radius` | Bloom Radius | ブルーム半径 | Bloom Radius | 光のにじみ・半径 |
| `filmtone.param.bloom_soft_knee` | Bloom Soft Knee | ブルームソフトニー | Bloom Soft Knee | 光のにじみ・ソフトニー |
| `filmtone.param.halation_intensity` | Halation Intensity | ハレーション量 | Halation Intensity | ハレーション強度 |
| `filmtone.param.halation_spread` | Halation Spread | ハレーション広がり | (no change) | (no change) |
| `filmtone.param.halation_hue` | Halation Hue | ハレーション色相 | (no change) | (no change) |
| `filmtone.param.halation_threshold` | Halation Threshold | ハレーションしきい値 | (no change) | (no change) |
| `filmtone.param.halation_radius` | Halation Radius | ハレーション半径 | (no change) | (no change) |
| `filmtone.param.halation_soft_knee` | Halation Soft Knee | ハレーションソフトニー | (no change) | (no change) |
| `filmtone.param.vignette` | Vignette | 周辺減光 | Vignette | ビネット |
| `filmtone.param.diffusion` | Diffusion | ディフュージョン | Diffusion | 光の拡散 |
| `filmtone.param.lens_softness` | Lens Softness | レンズソフト | Lens softness | レンズの柔らかさ |
| `filmtone.param.rgb_shift` | RGB Shift | RGB シフト | Color fringing | 周辺の色ずれ |
| `filmtone.param.compression_amount` | Compression Amount | 圧縮量 | Highlight softness | ハイライトの柔らかさ |
| `filmtone.param.compression_range` | Compression Range | 圧縮レンジ | Tone span | 階調の広がり |
| `filmtone.param.print_contrast` | Print Contrast | (none) | Print Contrast | 仕上げのコントラスト |
| `filmtone.param.grain_intensity` | Grain Intensity | グレイン量 | Grain Strength | フィルムグレイン・強さ |
| `filmtone.param.grain_size` | Grain Size | グレイン粒径 | Grain Size | 粒子の粗さ |
| `filmtone.param.grain_radial_mix` | Grain Radial Mix | グレイン周辺ミックス | Grain edge emphasis | グレインの周辺の強さ |

DECIDE defaults applied above:
- DECIDE-1 Default: keep "Print Contrast" (no Desktop "Print snap")
- DECIDE-2 Default: "Color fringing"
- DECIDE-3 Default: "Grain edge emphasis"

If user has overridden any DECIDE, replace the corresponding row.

**What NOT to change**: keys with `extractionState: stale` should retain that state — Apple's xcstrings tooling refreshes it on next build. Do not manually flip to `extractionState: translated` unless re-extracting.

**HDR notice rewrites in this file** (per SSoT §5):

| Key | New EN | New JP |
|---|---|---|
| `filmtone.hdr.notice.title` | HDR video loaded | HDR動画を読み込みました |
| `filmtone.hdr.notice.body.pq` | (see SSoT §5.2 generic body) | (see SSoT §5.2 generic body) |
| `filmtone.hdr.notice.body.hlg` | (see SSoT §5.2 generic body) | (see SSoT §5.2 generic body) |
| `filmtone.hdr.notice.body.wideGamutUnknown` | (see SSoT §5.2 generic body) | (see SSoT §5.2 generic body) |

If implementation chat agrees with SSoT §5.3 recommendation to **collapse three body keys into one**, add a follow-up task to refactor `FilmtoneHdrPolicyNotice.swift` and remove the unused two body keys. Otherwise replace each variant body with the same generic text and document in PR description.

### 3.2 iOS — `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`

**What to change**: the `defaultValue:` strings inside `init(locale:)` for the keys above. These act as fallback when xcstrings has no localization. They must mirror the new xcstrings values.

Example diff for `vignette`:
```swift
"vignette": filmtoneLocalized(
    "filmtone.param.vignette",
    defaultValue: "Vignette",   // unchanged
    comment: "Advanced parameter label."
),
```
The `defaultValue` for `vignette` is already `"Vignette"` and the JP is in xcstrings, so no Swift change needed for this key. But for keys where `prefersJapanese ? "..." : "..."` appears (HDR notice title/bodies), update both branches.

**What NOT to change**:
- Param key strings (`"bloomStrength"`, `"vignette"`, etc.) — these are L1 contract keys.
- The `paramLabel(for:)` lookup logic.
- Comment strings (`comment: "..."`).

### 3.3 Desktop — `apps/desktop-film-lab-batch/messages/en.json` + `messages/ja.json`

**Apply DECIDE-5** (rename UI keys to match contract):
- Rename `controls.filmGrain` → `controls.grainIntensity`
- Rename `controls.compression` → `controls.compressionAmount`
- Find every reader (`useTranslations("controls").*` or `t("film-lab.controls.filmGrain")` etc.) and update.
  - `cd apps/desktop-film-lab-batch && rg -n 'controls\.(filmGrain|compression)\b' src` to find call sites
  - `rg -n 'film-lab\.controls\.(filmGrain|compression)\b' src` for fully-qualified i18n keys
- Update messages/en.json: also align EN values where SSoT and current diverge:
  - `printContrast`: `"Print snap"` → `"Print Contrast"` (DECIDE-1 default)
  - `lensSoftness`: `"Lens Softness"` → `"Lens softness"` (sentence case for sub-label)
  - `intensity` (top-level standalone, used inside Halation): `"Intensity"` (already correct)
- Update messages/ja.json:
  - `vignette`: `"ビネット"` (already correct)
  - All other rows already match SSoT JP values.

**HDR notice in Desktop**:
- `apps/desktop-film-lab-batch/messages/en.json` `desktop.batch.hdrPolicyNoticeTitle` and `hdrPolicyNoticeBody` — already canonical per SSoT §5. No change needed.
- `apps/desktop-film-lab-batch/messages/ja.json` `desktop.batch.hdrPolicyNoticeTitle` and `hdrPolicyNoticeBody` — already canonical. No change needed.
- Confirm with grep that no other Desktop string mentions `ffmpeg`, `zscale`, `libplacebo`. If any leaked, remove.

**DECIDE-4** (optics source tag bilingual):
- File `apps/desktop-film-lab-batch/src/renderer/video-probe-label.ts:5-30` currently emits English `metadata` / `assumed` / `manual` literals.
- Add a localizer that maps to JP per SSoT §3 / iOS-equivalent (`メタデータ` / `推定` / `手動`).
- New i18n keys (proposed):
  ```json
  "controls.opticsSourceMetadata": "metadata" / "メタデータ"
  "controls.opticsSourceAssumed": "assumed" / "推定"
  "controls.opticsSourceManual": "manual" / "手動"
  ```

### 3.4 film-lab-core — `packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md`

**Do not edit** unless implementing v1.2 codegen (SSoT §8). If anything in §3 was wrong / missing / under-specified, append a row in the §9 change log and edit the table.

---

## 4. Verification

Run all four:

```bash
# iOS contract / Swift
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
bun run generate:filmtone-ios-swift --check
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -sdk iphonesimulator -configuration Debug build

# Desktop typecheck + tests
bun run --cwd apps/desktop-film-lab-batch typecheck
bun run --cwd apps/desktop-film-lab-batch test

# Cross-cutting forbidden-jargon grep — must return ZERO hits
rg -nE '\b(zscale|libplacebo|tone-map|linearize|brew install)\b' \
  apps/desktop-film-lab-batch/messages \
  apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings
```

Manual smoke (5 min):
- Open Desktop dev build, switch JP locale, load HDR fixture, confirm notice text matches SSoT §5.2 verbatim.
- Open iOS sim, JP locale, scroll all advanced params, screenshot, compare visually to Desktop with same values open. Every effect label should match the SSoT JP-flat column.

---

## 5. Out of scope (do not attempt)

| Topic | Why out | Whose chat |
|---|---|---|
| iOS UI restructure (sections vs flat list) | DECIDE-6 default = stay flat in v1.1.x | v1.2 chat |
| Cross Filter / Light Shafts / Dust / Scratch / Shutter Angle / Trail Intensity native iOS impl | iOS does not have these renderers yet | v1.2 chat |
| `terminology.ts` codegen (SSoT §8) | New TS module + codegen pipeline | v1.2 chat |
| Marketing / preset names alignment | Different SSoT, different table | separate chat |
| Versioning sync between Desktop and iOS | Soft-align at v2.0 (different memory entry) | future v2.0 release chat |
| Logo / AppIcon rollout | In progress in life repo, separate stream | logo chat |

---

## 6. Ship procedure (after merge)

iOS:
- Bump MARKETING_VERSION to `1.1.1`, CURRENT_PROJECT_VERSION to `3`.
- This is a string-only patch with no runtime change → low-risk submission.
- Fastlane → ASC submit (auto release after approval per existing `AUTOMATIC_RELEASE=1` policy).
- After live, update memory entry `filmtone_ios_v1_1_live.md` to record `1.1.1` and what shipped.

Desktop:
- Bump package.json to `1.0.4`.
- DMG build + tag `desktop-v1.0.4`.
- Upload to Vercel Blob (`film-lab/desktop/update-meta.json`), notify users via in-app banner.
- Note: this terminology PR alone may not be worth a 1.0.4 release if HDR + export parity work (memory: `filmtone_desktop_v1_0_4_pending.md`) is bundling. Coordinate with that chat — if v1.0.4 is already in flight, fold this into it; otherwise ship as v1.0.3.x or wait.

---

## 7. PR description template

```markdown
## Summary
- Apply Filmtone effect terminology SSoT (`packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md`).
- iOS xcstrings + iOS Swift defaults + Desktop messages.json{en,ja} aligned.
- HDR notice text rewritten to remove `ffmpeg / zscale / libplacebo` from user-visible strings.

## DECIDE outcomes
- DECIDE-1 `printContrast` EN: applied Default = "Print Contrast"
- DECIDE-2 `rgbShift` EN: applied Default = "Color fringing"
- DECIDE-3 `grainRadialMix` EN: applied Default = "Grain edge emphasis"
- DECIDE-4 optics source tag: applied Default = bilingual (Desktop side updated to localize)
- DECIDE-5 Desktop UI key rename: applied Default = renamed `filmGrain` / `compression` → `grainIntensity` / `compressionAmount`
- DECIDE-6 iOS UI structure: applied Default = stay flat for v1.1.x (deferred to v1.2)

## Verification
- bun verify:swift-contract: ✅ N tests
- xcodebuild iOS Debug: ✅ BUILD SUCCEEDED
- bun typecheck Desktop: ✅
- forbidden-jargon grep: ✅ 0 hits
- Manual smoke (Desktop JP, iOS sim JP): ✅ matches SSoT

## Out of scope (per handoff §5)
- iOS UI restructure / Cross Filter native / terminology codegen
```

---

## 8. After this PR lands

Update memory:
- Add a note in `filmtone_ios_v1_1_live.md` that v1.1.1 string-only patch shipped (or queued).
- Add a note in `filmtone_desktop_v1_0_4_pending.md` that terminology alignment is no longer pending.
- Optionally add a feedback memory: "Filmtone 用語は `packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md` が canonical。両アプリで新しい effect を追加する時は SSoT を先に更新する。"

---

## 9. Cross references

- SSoT: `packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md`
- iOS release runbook: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-v1.1-release-handoff-2026-04-25-jst.md`
- iOS truth gate: `docs/guides/filmtone-ios-release-current-state.md` (life)
- Desktop release truth gate: `docs/guides/film-lab-current-index.md` (life)
- Desktop v1.0.4 pending work (HDR + export parity, separate from this): memory `filmtone_desktop_v1_0_4_pending.md`
- Versioning sync policy: per memory recommendation, sync at v2.0 (do not force-align in v1.x)
