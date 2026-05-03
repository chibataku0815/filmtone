# 05 Future Lanes

Parent index:
[filmtone-native-desktop-transition-plan-2026-05-03-jst.md](../filmtone-native-desktop-transition-plan-2026-05-03-jst.md)

These lanes are strategic direction, not Phase 1/2 blockers.

## Continuity Export On Mac

Goal: iOS decides the look, Mac performs the heavy export.

Product assumption:

- Do not transfer source video over the network.
- The user mounts or copies the same material via external SSD / shared local
  storage.
- iOS sends only a small recipe payload: look/params, source profile, trim
  range, input file identity, output intent, and optional verification hash.

Candidate Apple-native transports:

- CloudKit private database or iCloud KVS for recipe state and export request.
- `NSUserActivity` / Handoff for "continue this edit on Mac".
- Multipeer Connectivity only if direct local pairing becomes a better product
  experience than iCloud state sync.

Do not start this lane until Native Desktop export is reliable enough that the
Mac side can honor the recipe without changing output quality.

## Resolve / Pro NLE Integration

Progression:

1. `.cube` LUT export for broad NLE portability.
2. DaVinci Resolve Scripting API or DCTL export if Filmtone recipe fidelity
   justifies Resolve-specific work.
3. OFX only after the native render core boundary is stable enough to wrap.

Adobe integration stays out of the initial Native v2 roadmap. The distribution
and SDK surface is too heavy for the first buy-once Desktop lane.

Architecture implication:

- Keep SwiftUI responsible for primary UI.
- Use AppKit for macOS-specific file access, windowing, menus, Finder
  integration, and Apple ecosystem hooks that SwiftUI cannot express cleanly.
- Use UIKit only on the iOS side when SwiftUI needs platform-specific support.
- Keep render stages separable enough that an Objective-C++ / C++ / Metal core
  can be introduced later without rewriting product UI.
