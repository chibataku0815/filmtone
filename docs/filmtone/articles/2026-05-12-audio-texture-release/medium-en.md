# Filmtone Is Updating Audio Export and Texture Softness

Status: candidate draft. Do not publish until Desktop public `1.7` and iOS
public `1.9` are both confirmed by the truth scripts.

Publication switch:

- Before public truth: keep `upcoming update` and `after release`.
- After public truth: change title to
  `Filmtone Updated Audio Export and Texture Softness`
  and first line to `Filmtone Desktop 1.7 and Filmtone iOS 1.9 are now available.`

TOC policy: Medium has no native table of contents and manual in-body anchor
links are impractical (anchor IDs are not exposed by the editor). Do not add
a TOC. Keep H2 subheads short and self-contained so the article reads
linearly and the section change is visible from typography alone.

---

Filmtone is a small app for adjusting the color of video on iPhone and Mac. You load a clip you have already shot, and it writes out a finished video with clean fine texture.

Filmtone's next release adds a new control, Texture Softness, that softens the in-camera sharpening already baked into phone and action-cam footage, without flattening readable edges. The release also fixes a bug where normal video exports could lose their original audio.

## Texture Softness Is Not Blur

The new control is Texture Softness.

On Desktop it lives in Advanced Optics. On iOS it appears as a texture-softness control. It is separate from Lens Softness. Lens Softness belongs closer to lens and peripheral character. Texture Softness is for the fine local sharpening that the source file already arrives with.

Modern phone and small-camera footage is rarely soft out of the box. The sensor, image signal processor, and encoder inside the device apply heavy sharpening at capture time, and that sharpening is baked into the file long before any color work happens. Filmtone's grading stages do not add to it, but they do not remove it either, and once contrast and print processing settle the picture, that pre-existing fine acutance often becomes the loudest part of the frame. The problem is not focus. It is local acutance: small contrast around fine detail, already in the file.

A plain blur would be the wrong answer. It softens text, hair, leaves, cloth, and generated grain at the same time, which flattens the whole image instead of easing only the parts where the source's baked sharpening is loud.

Filmtone's Texture Softness is built around an edge-aware detail layer ── a small processing step that separates fine detail from the rest of the image so the control can act on the fine detail only. It tries to reduce the source's in-camera sharpening while keeping larger edges readable. When source metadata suggests heavily sharpened consumer footage, Filmtone can add a conservative source detail bias at runtime.

That bias is not saved into Looks. A Look should travel across source material without carrying an iPhone-specific or source-specific correction into unrelated footage. Source-specific help should stay runtime-only.

## The Audio Fix

Normal video exports could leave their original audio out of the completed MP4. The new release fixes that path on Desktop and iOS, and on iOS, clips recorded inside the app also include microphone audio. The symptom showed up only in the finished file, which is why the fix is interesting to talk about even as a bug fix.

Internally the fix is structural: the export pipeline reopens the completed file and confirms the audio track is there before reporting success. The intent is to judge the output on the output, not on the writer's configuration mid-process.

Highlight-reel export remains source-audio disabled in this release. The fix is scoped to normal video export.

## Native Runtime, Shared Color Truth

There is also a structural story behind this release.

The Filmtone iOS and Mac apps now ship as native Swift apps. AVFoundation handles capture, decode, and encode. Core Image (Apple's GPU image-processing framework) runs the actual grading work. SwiftUI and AppKit handle the UI.

The color logic itself — which Look does what, which kernels run in which order, where Texture Softness sits — is not duplicated per platform. It lives in a single TypeScript core, which is regenerated into a Swift package that both native apps import. So both platforms read from the same color source of truth, even though the runtime under them is native Swift.

Historically, the iOS app reused the project's WebGPU / WebGL renderer through a React + Capacitor shell. That was a reasonable bridge while the renderer was the only place the color pipeline existed. Capture, Live Look monitoring, and export quality eventually needed native control, so the iOS runtime moved to native (1.8) and the Mac runtime followed with a native macOS app. The WebGPU renderer is still maintained — it powers the project's web landing surface — but it is no longer on the iOS or Mac app's runtime path.

The architecture rule is: one color spec, native runtime where capture and export quality depend on it. That distinction lets Filmtone move closer to each platform without each platform drifting into its own color product.

## What to Try After Release

After release, the most direct test is simple:

1. Choose a familiar Look — a film-style entry like `Stone`, a city-style entry like `Urban Creative`, or a Look you have already saved.
2. Raise Texture Softness gently on footage with hair, fabric, leaves, small text, street lights, or noisy night detail.
3. If your source has audio, export a normal video and confirm the audio track is in the finished file.

Texture Softness is not a universal improvement switch. Some footage should stay crisp. The control is for source material where the in-camera sharpening makes fine edges read as too loud.

This update tightens an important part of the product: the finished file — what readers and viewers actually receive. Filmtone is still a little particular about small image details. This version tries to make that attention easier to understand and easier to use.

Filmtone iOS is available on the App Store: https://apps.apple.com/jp/app/filmtone-%E3%83%95%E3%82%A3%E3%83%AB%E3%83%A0%E8%AA%BF%E3%82%AB%E3%83%A9%E3%82%B0%E3%83%AClut/id6762564806
