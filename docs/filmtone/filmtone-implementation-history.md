# Filmtone Implementation History

This file is the compact source of truth for explaining why Filmtone's
implementation moved through WebGPU / WebGL, React + Capacitor, and native
SwiftUI / AVFoundation. Use it before writing articles, release notes, LP copy,
App Store copy, or support text that mentions implementation history.

## Current Architecture In One Paragraph

Filmtone keeps color, preset, LUT, schema, and Swift payload logic in the
shared TypeScript packages, especially `packages/film-lab-core/`. The Web
renderer lives in `packages/film-lab-renderer/` with WebGPU shaders and WebGL
fallbacks. iOS and Native Desktop now use native Swift / SwiftUI / AppKit
surfaces for product-critical runtime behavior, while preserving shared color
intent through generated Swift payloads and verification. The product direction
is not "Web vs native"; it is "shared color truth, native runtime where product
quality needs it."

## Why React + Capacitor Existed

React + Capacitor was not accidental legacy.

The initial Filmtone renderer path was built around WebGPU, with WebGL fallback
support. That made a React + Capacitor iOS shell a reasonable early choice:
the same web-side renderer and TypeScript product logic could be carried onto
iPhone, while keeping Desktop / Web / iOS color behavior close to the same
pipeline.

The correct historical framing is:

```text
Filmtone first had a WebGPU / WebGL renderer and shared TypeScript color logic.
React + Capacitor was chosen so iOS could reuse that renderer path and stay
close to the Desktop / Web implementation.
```

Do not describe React + Capacitor as if it was a random wrapper, a mistake from
day one, or a generic cross-platform shortcut. It was the first bridge for
reusing the web renderer and shared color model.

## Why iOS Moved Native

The product pressure changed when iOS capture became core work.

Once Filmtone needed a real capture surface, Live Look monitoring, Apple Log 2 /
ProRes capture truth, take handling, and editor handoff, the Capacitor-over-web
renderer path hit a product-quality ceiling. The main reason to move native was
runtime quality and performance for capture and monitoring, not a preference for
native code in the abstract.

The correct framing is:

```text
The web renderer path remained valuable, but the capture surface needed native
AVFoundation and SwiftUI control. Filmtone moved the iOS runtime surface native
because Live Look / capture monitoring quality could not depend on the
Capacitor WebGPU route.
```

Use the broad phrase `Capacitor 越しの WebGPU 経路の performance ceiling` when
writing in Japanese. Do not invent unsupported symptoms such as specific shutter
speed failures, stabilization bugs, or device-wide thermal conclusions unless a
current lane explicitly proves them.

## What Stayed Shared

Native iOS did not mean throwing away shared color logic.

Keep these distinctions clear:

- `packages/film-lab-core/`: color math, schema, presets, LUT/source-profile
  contracts, iOS Swift payload generation.
- `packages/film-lab-renderer/`: WebGPU / WebGL renderer and shader path for
  Web/Desktop-era rendering surfaces.
- iOS native app: SwiftUI / AVFoundation runtime surface, native capture,
  export, sidecar, library, and generated Swift color contract use.
- Native Desktop: native macOS app that follows the iOS Filmtone product model
  while keeping shared contract/parity where practical.

When writing public copy, prefer:

```text
レンダリング層が native に降りても、色の考え方は shared core から保つ。
```

Avoid:

```text
WebGPU を捨てた。
React + Capacitor が失敗だった。
iOS は Desktop と別物になった。
```

Those lines erase the reason the earlier architecture existed and overstate the
native pivot.

## Timeline

| Period | State | What to say |
|---|---|---|
| Early Filmtone | WebGPU renderer with WebGL fallback, shared TypeScript color/product logic. | Filmtone started from a web-renderer-centered architecture to keep color behavior portable. |
| Early iOS | React + Capacitor shell reused the web renderer / TypeScript path on iPhone. | React + Capacitor existed to preserve that WebGPU/WebGL route on iOS. |
| Native iOS shift | Runtime discovery showed the live UI is SwiftUI and capture needed native product behavior. | Product capture moved to AVFoundation + SwiftUI for runtime quality. |
| React / Capacitor purge | Dead React/Capacitor runtime surface was removed after SwiftUI became the live path. | Purge removed unreachable build/runtime artifacts; it did not change the shared color source of truth. |
| Current | Shared packages remain canonical; iOS and macOS use native surfaces where product quality needs native control. | Shared color truth plus native product surfaces is the current model. |

## Evidence Pointers

- `README.md`: workspace map for `film-lab-core` and `film-lab-renderer`.
- `packages/film-lab-renderer/src/webgpu/`: WebGPU backend and WGSL shaders.
- `packages/film-lab-renderer/src/webgl/`: WebGL backend and shader fallback.
- `packages/film-lab-core/src/ios-swift-payload.ts`: Swift payload generation
  source.
- `apps/capacitor-film-lab-ios/CLAUDE.md`: current iOS invariant that the live
  UI stack is Native SwiftUI and React/Capacitor was purged on 2026-05-09.
- `docs/filmtone/ios/react-capacitor-purge/strategy.md`: staged purge record
  and merge completion.
- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md`: M7 discovery that the
  React/Capacitor MobilePhase0Editor was not the live UI and that SwiftUI was
  the product surface.

## Copy Rules For This History

- Always explain the initial React + Capacitor choice from renderer reuse:
  WebGPU / WebGL renderer first, then iOS reuse through Capacitor.
- Explain the native move from product quality: capture, Live Look monitoring,
  AVFoundation truth, and performance ceiling.
- Keep shared color truth visible: native runtime did not fork Filmtone's color
  model away from the TypeScript/shared packages.
- Separate implementation history from public release state. Run the truth
  scripts before claiming current App Store, Desktop, or version status.
- If a detail is not in current source, this file, or a cited strategy/archive,
  do not add it for narrative smoothness.
