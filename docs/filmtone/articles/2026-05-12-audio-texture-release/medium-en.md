# Filmtone Is Updating Audio Export and Texture Softness

Status: candidate draft. Do not publish until Desktop public `1.7` and iOS
public `1.9` are both confirmed by the truth scripts.

Publication switch:

- Before public truth: keep `upcoming update` and `after release`.
- After public truth: change title to
  `Filmtone Updated Audio Export and Texture Softness`
  and first line to `Filmtone Desktop 1.7 and Filmtone iOS 1.9 are now available.`

---

Filmtone's upcoming Desktop and iOS updates focus on two output details:

- preserving audio in normal video export;
- adding Texture Softness, a control for reducing over-sharpened fine detail without using a simple blur.

This is not a big new-screen release. It is about the file that remains after the edit. If a video has audio, the normal export should keep it. If a grade makes fine edges look too strong, there should be a more specific control than blur.

## Audio Should Be Judged at the Output

For normal video exports, Filmtone now preserves source audio when the source has audio. On iOS, clips recorded inside the app also include microphone audio.

The important part is not only adding an audio input to the writer. The important part is checking the completed file.

That distinction matters. Preview audio, writer configuration, and output audio are related, but they are not the same promise. The user's artifact is the finished file, so Filmtone validates that file before reporting success.

Highlight-reel export remains source-audio disabled in this release. That path rebuilds selected timeline segments, so I am not folding it into the same claim. The goal here is narrower: normal video exports should keep audio when audio is part of the source.

## Texture Softness Is Not Blur

The second change is Texture Softness.

On Desktop it lives in Advanced Optics. On iOS it appears as a texture-softness control. It is separate from Lens Softness. Lens Softness belongs closer to lens and peripheral character. Texture Softness is for fine local contrast and over-sharpened texture across the frame.

Modern phone and small-camera footage can be very crisp. That can be useful, but after color work some fine edges can remain too strong. The problem is not focus. It is local acutance: small contrast around fine detail.

A plain blur would be the wrong answer. It softens text, hair, leaves, cloth, and generated grain at the same time, which flattens the whole image instead of easing only the parts that look too strong.

Filmtone's Texture Softness is built around an edge-aware detail layer ── a small processing step that separates fine detail from the rest of the image so the control can act on the fine detail only. It tries to reduce over-sharpened fine detail while keeping larger edges readable. When source metadata suggests heavily sharpened consumer footage, Filmtone can add a conservative source detail bias at runtime.

That bias is not saved into Looks. A Look should travel across source material without carrying an iPhone-specific or source-specific correction into unrelated footage. Source-specific help should stay runtime-only.

## Native Runtime, Shared Color Truth

There is also a structural story behind this release.

Filmtone started from a WebGPU / WebGL renderer and shared TypeScript color logic. React + Capacitor was a reasonable early iOS bridge because it brought that renderer path to the phone.

The product pressure changed when capture, Live Look monitoring, and export quality became central. Those areas needed native control through SwiftUI and AVFoundation on iOS, and a native macOS runtime on Desktop.

But the goal is not "native instead of web." The goal is shared color truth, with native runtime control where the product quality depends on it.

That distinction keeps the architecture honest. Filmtone can move closer to the platform without turning each platform into a separate color product.

## What to Try After Release

After release, the most direct test is simple:

1. Export a normal video source that has audio and confirm the output MP4 keeps that audio.
2. Choose a familiar Preset or Look.
3. Raise Texture Softness gently on footage with hair, fabric, leaves, small text, street lights, or noisy night detail.

Texture Softness is not a universal improvement switch. Some footage should stay crisp. The control is for source material where fine edges look too strong after grading.

This update is small in feature count, but it tightens an important part of the product: the finished file. Filmtone is still a little particular about small image details. This version tries to make that attention easier to understand and easier to use.
