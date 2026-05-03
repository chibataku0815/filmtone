# 06 Quality Gates Risks

Parent index:
[filmtone-native-desktop-transition-plan-2026-05-03-jst.md](../filmtone-native-desktop-transition-plan-2026-05-03-jst.md)

## Native UI Gate

Pass when:

- standard controls pick up platform behavior on the latest macOS target
- custom controls use `glassEffect` only where it improves hierarchy
- control layers float above content without blocking color judgment
- Reduce Transparency / accessibility settings remain legible
- pointer and keyboard interaction feel native

Fail when:

- Liquid Glass becomes decoration that makes controls harder to read
- preview content is tinted or blurred in a way that affects grading decisions
- the app looks like the Electron UI with different material values

## Color / Render Gate

Pass when:

- source profile math matches existing fixtures
- built-in params match shared core defaults
- preview/export use the same stage order or a proven equivalent
- still and video outputs pass golden comparison within defined tolerance
- sidecar metadata explains the exact applied pipeline

Fail when:

- native preview looks better but export differs
- native export silently disables a stage
- color profile handling is implicit
- HDR/SDR policy is guessed instead of encoded

## Product Gate

Pass when:

- a real Filmtone user can import, grade, export, and verify output
- native app is faster, clearer, or more trustworthy than Electron in the core
  workflow
- release rail can move without blocking urgent Electron fixes

Fail when:

- development spends time on release copy, docs, screenshots, or cosmetic
  polish before the vertical slice is correct
- Native v2 cannot beat Electron on core output quality

## Open Questions

These require direct implementation proof, not discussion:

- Whether the best preview path is CoreImage-only, Metal-only, or a hybrid.
  *(Phase 1b 取り敢えず CoreImage CIColorKernel chain で landing。Phase 2 で
  Metal CIKernel/MTKView 検証。)*
- Whether iOS `FilmtoneExportSession` should be shared as-is, split into a
  platform-neutral Swift module, or ported selectively.
  *(Phase 1b は CIColorKernel kernel sources のみ verbatim lift。Phase 1c で
  video core flow (`makeWriter` / `makeVideoInput` / `makeVideoReaderOutput`
  / per-frame loop) の structure のみ port、telemetry (UIKit/UIDevice 依存
  2 行) は **削減**。本体 4554 行のうち macOS-relevant は限定的 →
  **selectively ported** が答え。Phase 2 で SPM `film-lab-swift-core` への
  集約と一緒に shared 化。)*
- Whether Native Desktop v2 should keep ffmpeg for edge video formats or move
  fully to AVFoundation. Product quality decides this; silent fallback is not
  acceptable.
- Whether macOS support floor should be latest-only for Liquid Glass or latest
  first with a reduced-material fallback. The prototype should optimize for
  latest macOS quality first, then decide support floor from product evidence.
- Whether IOSurface-backed Metal render/export materially improves 4K/6K
  throughput over the current Electron/ffmpeg path on representative clips.
- Whether the first Continuity recipe transport should be CloudKit private DB,
  iCloud KVS, Handoff, or Multipeer Connectivity. Decide only after native
  export is trustworthy.
- Whether Resolve integration needs DCTL / scripting fidelity, or whether
  `.cube` export is enough for the first NLE-facing release.

## Risks And Responses

| Risk | Product-first response |
|---|---|
| Native UI succeeds but export drifts | Stop UI expansion and fix render/export parity first. |
| AVFoundation rejects formats Electron/ffmpeg accepted | Make unsupported formats explicit, or keep a declared ffmpeg lane. Do not silently downgrade quality. |
| Generated Swift diverges between iOS and macOS | Move generation to a shared contract and test both outputs. |
| Liquid Glass harms preview judgment | Restrict glass to chrome/control layers. Preview remains visually neutral. |
| Native app grows into a second full product before parity | Keep phase gates vertical and small; no batch UI until one-item export is correct. |
| Release pressure interrupts v2 | Keep Electron release rail alive until Native v2 passes product gates. |
| Look Unification lane が Phase 1 着手時に未着地で sidecar contract が定まらない | macOS sidecar emitter は Look canonical (`lookId` / `lookVersion`) で書く。Electron reader 側の dual-emit catch-up は Look Unification の責務。本 plan は Look Unification handoff doc を参照する形で整合確認のみ |
| Look Unification と Native v2 のどちらが先に release rail を変えるか競合 | Look Unification を先 (vocabulary 不統一のまま public release しない、Phase 5 release gate で確認)。Native v2 は Look Unification 着地後に sidecar dual emit を継承 |
| Native v2 / Look Unification 両方で同時に `film-lab-core` schema を変更 | Native v2 は schema 変更を **持たない方針** (Data Contract additive only)。Look Unification 側が canonical 加算を担当し、Native v2 はそれを消費するだけ |
| Performance architecture discussion delays the vertical slice | Phase 1 accepts a minimal CoreImage/native path if it proves parity. IOSurface / Metal compute optimization belongs to Phase 2. |
| iOS handoff work starts before Mac export is reliable | Continuity Export On Mac starts only after native export can honor a recipe without changing output quality. |
| Resolve / OFX ambitions pull the product toward a pro plugin before Desktop parity | `.cube` export is the first NLE step. DCTL / OFX remain future lanes until the native render core is stable. |
| baseline-B fixtures derive from legacy WebGL render path; Phase 1b iOS-canonical CIColorKernel lift cannot satisfy "PSNR > 35dB vs baseline-B" gate | **Phase 2 C3 で scaffold landed (uncommitted)**: `apps/desktop-film-lab-batch/test/golden/baseline-C/` 4 preset subdir + provenance README + `scripts/golden-parity-ios-vs-macos.ts` PENDING-aware harness。**baseline-C content 自体は PENDING** (user iOS Simulator workflow で 4×10=40 cell populate 待ち)。populate 後、(1) 案 C で macOS↔baseline-C 直接 PSNR 確認 → (2) 失敗セルあれば 案 C step (3) WGSL→Metal port を不足 effect path に対して実施 → (3) 確定 baseline-C で macOS 内 regression 完結。reset preset は ∞ dB (params identity) 期待値、non-reset は >> 35dB 期待 (kernel sources verbatim lift)。 |
| AVFoundation sync API (`asset.tracks(withMediaType:)` / `track.naturalSize` / `track.preferredTransform` / `AVAssetImageGenerator.copyCGImage(at:)` 等) は macOS 13+ で deprecated | **RESOLVED in Phase 2 C2** (uncommitted)。6 sites 全解消: FramePreview の `tracks` / `duration` / `copyCGImage` を `loadTracks` / `load(.duration)` / `generator.image(at:)` async + variadic `track.load(_:_:)` へ migrate。Reader は `FilmtoneVideoTrackProbe` 受領 init に rebuild、deprecated path 撤去。`bun run verify:macos` で AVFoundation deprecation 0 (残 warning は既存 `CIColorKernel(source:)` 3 箇所のみ — Metal CIKernel 移行 lane 別 chunk または C7 と合流)。 |
| Phase 1c per-frame CIImage chain は 1-sec synthetic で 0.366s (proof scale)、4K/6K の実 throughput 未測定 | **RESOLVED in Phase 2 C7** (chat A.4)。4K @ 80fps (realtime 3.4×) / 1080p @ 200fps、CPU 6-9%、kernel chain overhead 0.1-0.2ms/frame。IOSurface refactor 不要判定。6K/8K 未測定は許容 (4K margin で十分)。 |
| vignette canonical 化 (RayAngleOptics + camera-optics metadata 経路) が未 port で macOS↔iOS bit-identity の上限が ~35 dB | **RESOLVED in Phase 2 C5c** (commit `cda0f9f`、chat A.5)。CameraOpticsDTO + FilmtoneRayAngleOptics verbatim lift、FilmtoneSourceProber に video camera optics 抽出 (CMFormatDescription HorizontalFieldOfView) 追加。source=="metadata" 時のみ applyMask=1、otherwise applyMask=0 で pre-C5c byte-identical 保持。AVMetadataItem deprecated API (`commonMetadata`/`metadata`/`stringValue`) も modern async API へ移行。 |
| Phase 1c で `FilmtoneVideoReader` / `FilmtoneVideoWriter` を `@unchecked Sendable` で vouch、Phase 2 C1 で `FilmtoneVideoTrackProbe` を non-Sendable に明示 | exporter の単一 Task 内のみで使用 (concurrent reentry なし)。Phase 2 C1 で `track.load(_:_:_:_:)` variadic version を採用 (`async let` × non-Sendable AVAssetTrack の data race を回避)。actor-isolated queue / IOSurface-backed Metal compute は C7 refactor 時に再評価。 |
| Swift 6 strict concurrency が AVFoundation non-Sendable types (AVAssetTrack / AVURLAsset) を捕捉、`async let` × multi-key load が data race として弾かれる | **RESOLVED in Phase 2 C1+C2** (uncommitted)。variadic `AVAsynchronousKeyValueLoading.load(_:_:_:_:)` を採用 (single underlying request、track ownership split なし)。Probe 構造体 (`FilmtoneVideoTrackProbe`) は Sendable 不要 (single-Task consumer 限定)。 |
| Native Desktop ユーザー配布 (Phase 5 release rail 切替) 前に Look Unification main merge + sidecar dual emit 切替が必須、現在は Case B (Look canonical only) 継続 | release blocker (Phase 5 acceptance gate で確認)。Look Unification chat B 側で main merge 待ち (`feature/desktop-look-unification` branch に Phase A `1f99d68` + Phase B `fd9ddd2` landed、main 未 merge)。Phase 1c 開始時 + Phase 2 C1 開始時の grep で main 状態確認済 (BASE_LOOKS export 不在 = 未着地)。merge 観測時に macOS sidecar emitter を dual emit へ切替 (Case A)。 |
| C5b A.1 bloom 有効化後、`golden-parity-macos.ts --preset reset` の macOS↔source が ∞ dB でなくなる (reset preset に `bloomStrength=0.22` が含まれるため) | **EXPECTED CHANGE in Phase 2 C5b A.1** (uncommitted、chat A.6)。bloom 実装前の ∞ dB は「bloom が未実装で identity 動作」の副作用だった。C5b A.1 以降の regression 基準: reset preset は **~40 dB** (macOS↔source)、iphone preset は **35.59 dB** (macOS↔source)。C5b A.2 (halation + diffusion) 着地後はさらに変化する想定。reset の ∞ dB sanity は `resetParams` (bloomStrength=0.0 の identity params) を使う test に変更するか、sidecar の `lookId` roundtrip を別途確認する形に移行。 |

## Definition Of Done For This Plan

This plan is done when it gives the next chat one clear first move:

```text
create apps/filmtone-desktop-macos and make the first native vertical slice
```

It is not done by more documentation. The next useful work is code.
