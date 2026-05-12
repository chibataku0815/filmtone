# Preserving Audio and Softening Fine Detail in Filmtone's Native Export Pipeline

Status: candidate technical draft. Do not publish until Desktop public `1.7`
and iOS public `1.9` are both confirmed by the truth scripts.

Publication switch:

- Before public truth: keep `upcoming`, `release candidate`, `at the time this
  draft was prepared` framing.
- After public truth: change the opening sentence to
  `Filmtone Desktop 1.7 and Filmtone iOS 1.9 are now public.` and update the
  Release Guard section to reflect the post-release truth-script output.

## Context

Filmtone's upcoming Desktop and iOS updates focus on two implementation areas:

- preserving audio in normal video export;
- adding Texture Softness, an edge-aware control for reducing over-sharpened
  fine detail and local contrast.

This is not a broad launch post. It is an implementation note about output validation and source-aware image processing in a native creator tool.

## Audio Preservation: Validate the Finished File

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

Texture Softness exists because very sharp footage can keep too much local contrast after grading.

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

Filmtone also applies a conservative source detail bias when available metadata suggests heavily sharpened consumer footage.

This bias is runtime-only.

That boundary is deliberate. A saved Look should represent the user's reusable grade intent. It should not silently carry source-specific correction from one device or profile into unrelated footage.

The practical model is:

- shared Look / Preset data: reusable creative intent;
- source metadata / profile: how this specific source should be interpreted;
- source detail bias: a conservative runtime assist, never stored as part of the Look.

This keeps the feature safer to explain and safer to evolve. It avoids manufacturer-specific claims and preserves portability across source material.

## Native Runtime Without Forking Color Truth

Filmtone's current native direction is easy to misdescribe, so the distinction matters.

The project started from a WebGPU / WebGL renderer and shared TypeScript color logic. React + Capacitor was used on iOS because it let the iPhone app reuse that renderer path.

As capture, Live Look monitoring, and export quality became product-critical, Filmtone moved runtime surfaces into native SwiftUI / AVFoundation on iOS and native macOS surfaces on Desktop.

That does not mean the color model was forked per platform.

The intended architecture is:

```text
shared color truth
  + generated Swift payloads / verification
  + native runtime where capture/export quality needs native control
```

This is the main lesson from the release: native runtime and shared color contracts are not opposites. For a media app, they can be a practical way to keep product behavior close while still respecting platform realities.

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
