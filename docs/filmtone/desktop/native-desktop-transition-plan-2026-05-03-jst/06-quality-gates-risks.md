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
- Whether iOS `FilmtoneExportSession` should be shared as-is, split into a
  platform-neutral Swift module, or ported selectively.
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

## Definition Of Done For This Plan

This plan is done when it gives the next chat one clear first move:

```text
create apps/filmtone-desktop-macos and make the first native vertical slice
```

It is not done by more documentation. The next useful work is code.
