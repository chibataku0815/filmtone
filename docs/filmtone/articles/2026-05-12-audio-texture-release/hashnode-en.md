# Preserving Audio and Softening Fine Detail in Filmtone's Native Export Pipeline

Status: candidate technical draft. Do not publish until Desktop public `1.7`
and iOS public `1.9` are both confirmed by the truth scripts.

Publication switch:

- Before public truth: keep `upcoming`, `release candidate`, `at the time this
  draft was prepared` framing.
- After public truth: change the opening sentence to
  `Filmtone Desktop 1.7 and Filmtone iOS 1.9 are now public.` and update the
  Release Guard section to reflect the post-release truth-script output.

TOC policy: Hashnode auto-generates a sticky right-sidebar TOC from h1 / h2 /
h3 when the article's "Enable Table of Contents" setting is on. Turn this
setting on at publish time. Do not write a manual TOC in the body — it would
duplicate the sidebar.

## About Filmtone

Filmtone is a small app for color-grading video on iPhone and macOS. You
load a clip and it writes out an MP4 with clean fine texture.

Under the surface, the shipping iOS and macOS apps are both native Swift:
`AVFoundation` for decode/encode, `CoreImage` (CIKernel) for the
GPU-side grading work, SwiftUI / AppKit for UI. The color *logic* — Look
composition, kernel constants, curve / compression / shadow /
detail-softness / optics resolution — lives in a single TypeScript core
(`packages/film-lab-core`) and is regenerated into a Swift package
(`packages/film-lab-swift-core`, `FilmLabSwiftCore`) that both native
apps import. So the platforms share the color source of truth, but the
runtime path itself is native Swift on both sides.

The WebGPU / WebGL renderer (`packages/film-lab-renderer`) is also part
of the monorepo, but it is consumed by the web landing site (via a
submodule) — not by the iOS or macOS app runtime.

## Context

This is an implementation note. The headline change in the upcoming Desktop
and iOS update is Texture Softness, an edge-aware control for reducing
over-sharpened fine detail and local contrast. Alongside it, the same
release fixes a bug where normal video exports could leave the original
audio out of the completed MP4 — interesting here because of how the
success check is wired, not because it is a feature.

This note covers both, but the framing is different: Texture Softness as a
new implementation area, and the audio fix as a small lesson in validating
the finished output instead of trusting writer state.

## Audio Fix: Validate the Finished File

The export rule is intentionally narrow:

If the source for a normal video export has audio, the exported MP4 should also have audio.

The implementation path is familiar:

1. Inspect the source asset for audio.
2. Create the appropriate audio reader path.
3. Write AAC audio into the MP4 output.
4. Complete the export.
5. Reopen the completed output and validate the audio track before reporting success.

The last step is the important one.

It is tempting to treat writer configuration as proof. It is not. The user only receives the completed file, so the export pipeline should validate the completed file.

Filmtone applies this framing on the normal video export path. Highlight-reel export remains source-audio disabled in this release because that path rebuilds selected timeline segments and should not inherit the same claim by accident.

On iOS, app-captured clips also include microphone audio in the release candidate. Desktop and iOS differ at the runtime level, but the product rule is the same: success should be based on the output artifact, not on the pipeline's good intentions.

## Texture Softness: Reduce Detail, Not Readability

Texture Softness exists because the sharpening that phone and action-cam
sensors / ISPs / encoders apply in-camera is *already baked into the
source file*. The grading stages downstream do not add to it (and cannot
remove it), but once contrast and print processing settle the picture,
that pre-existing fine acutance often becomes the loudest part of the
frame.

The wrong solution is a plain blur. A blur reduces detail, but it also damages the parts of the frame that should stay legible: text, hair, fabric, leaves, architecture, and generated grain.

Filmtone instead treats Texture Softness as an edge-aware detail operation:

```text
source frame
  -> edge-preserving local reference
  -> detail layer
  -> amplitude-gated detail reduction
  -> downstream optics / glow / grain / LUT / print stages
```

The control is separate from Lens Softness. Lens Softness is closer to lens/periphery character. Texture Softness targets fine local acutance across the frame.

The placement also matters. The detail reduction happens before later optics, glow, grain, creative LUT, and print stages. That avoids feeding exaggerated micro-edges into glow, while also avoiding a late blur that would flatten generated grain.

## Source Detail Bias Should Not Pollute Looks

Filmtone also applies a conservative source detail bias when available metadata suggests the source has heavy in-camera sharpening (e.g. recent iPhone and action-cam profiles).

This bias is runtime-only.

That boundary is deliberate. A saved Look should represent the user's reusable grade intent. It should not silently carry source-specific correction from one device or profile into unrelated footage.

The practical model is:

- shared Look data: reusable creative intent (curve / grade foundations also appear as bundled Look entries);
- source metadata / profile: how this specific source should be interpreted;
- source detail bias: a conservative runtime assist, never stored as part of the Look.

This keeps the feature safer to explain and safer to evolve. It avoids manufacturer-specific claims and preserves portability across source material.

## Native Runtime Without Forking Color Truth

Filmtone's native direction has a specific shape worth describing precisely.

Historically, the iOS app used React + Capacitor as a shell to reuse the
WebGPU / WebGL renderer on the phone. As capture, Live Look monitoring,
and export quality became product-critical, the iOS runtime moved to
native SwiftUI + AVFoundation (1.8 cutover), and the Desktop runtime
moved to a native macOS app. The WebGPU renderer is still maintained,
but only for the web landing site — not for the iOS or macOS app
runtime.

That migration did *not* fork the color model per platform. The color
truth still lives in one TypeScript core and is generated into a Swift
Package consumed by both native apps:

```text
TypeScript color core  (packages/film-lab-core)
  → generated Swift constants / DTOs  (packages/film-lab-swift-core, FilmLabSwiftCore)
  → imported by iOS + macOS native apps
  → executed via CoreImage CIKernels on Apple GPUs
```

This is the architectural lesson from the release: "native runtime" and
"shared color contracts" are not opposites. By moving the runtime native
while keeping the color spec in one regenerated source of truth, the iOS
and macOS apps can respect platform realities (capture, codec, export)
without each platform drifting into its own color product.

## Release Guard

At the time this draft was prepared:

- Desktop public latest is still `1.6`;
- Desktop local candidate is `1.7` build `4`;
- iOS public App Store version is still `1.8`;
- iOS local candidate is `1.9` build `8`.

This article should not use public release language until the truth scripts report Desktop public `1.7` and iOS public `1.9`.

## Takeaway

The implementation lesson is small but useful:

- validate media export claims on the completed output file;
- do not solve hard detail with a generic blur;
- keep source-specific compensation out of reusable creative state;
- move runtime native where quality requires it, but keep shared color truth explicit.

That is the shape Filmtone is moving toward.

Filmtone iOS is available on the App Store: https://apps.apple.com/jp/app/filmtone-%E3%83%95%E3%82%A3%E3%83%AB%E3%83%A0%E8%AA%BF%E3%82%AB%E3%83%A9%E3%82%B0%E3%83%AClut/id6762564806
