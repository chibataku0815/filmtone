# Filmtone Audio + Texture Release Case Study

Status: candidate Behance article. Do not publish until Desktop public `1.7`
and iOS public `1.9` are both confirmed by truth scripts.

Publication switch:

- Before public truth: keep `release focuses on`, `meant to`, `is added`
  framing. Avoid `released`, `is available`, `we shipped`.
- After public truth: confirm the case-study copy is consistent with the public
  release notes, add the App Store and Desktop download links, and replace any
  remaining `candidate` qualifiers in the body copy.

## Cover

Title:

```text
Filmtone: Audio Export and Texture Softness
```

Subtitle:

```text
A release case study about preserving audio in normal video export, adding Texture Softness, and keeping source-specific compensation out of saved Looks.
```

Suggested cover visual:

- Split frame: graded footage with visible fine texture.
- Small UI crop: `Texture softness` / `質感のやわらかさ`.
- Optional waveform strip or audio-track marker to make the audio change visible without over-explaining it.

## Project Summary

Filmtone is a video color tool for choosing a grade, comparing it on real material, and exporting the result on iPhone and Mac.

This release focuses on two product details:

1. Normal video exports should keep audio when the source has audio.
2. Fine digital detail should be adjustable without turning the image into a simple blur.

The release is small in feature count, but it affects the final output file. That makes it important for a video editing tool.

## Problem

The product problem had two parts.

On the export side, a video could look correct in the editor while the completed file did not carry the expected audio. On the image side, highly sharpened phone or small-camera footage could keep hard fine edges after grading. The grade might be working, but small details could still feel too crisp.

Both problems show up after the edit, when the file is supposed to be finished.

## Design Direction

The design decision was to keep the product surface clear.

Audio preservation does not need a dramatic UI. It needs a pipeline that checks the completed output file.

Texture Softness does need a visible control, but it should sit in Advanced Optics, near other material/optical decisions. It is separate from Lens Softness:

- Lens Softness: lens/periphery character.
- Texture Softness: fine local detail, strong edges, and local acutance.

The control should feel like a small adjustment for material where hair, cloth, leaves, text, or night noise look too hard after color work.

## Visual System Notes

Suggested case-study sections:

1. **Before / After: Fine Detail**
   - Show crop-level comparison at low and moderate Texture Softness.
   - Use hair, cloth, leaves, small text, or night noise.
   - Avoid claiming universal improvement. Caption as `material-dependent`.

2. **Control Placement**
   - Show the Desktop Advanced Optics panel and iOS control surface.
   - Explain that Texture Softness is not Lens Softness.

3. **Output Trust**
   - Show a minimal export flow diagram:

```text
Source video with audio
  -> normal export
  -> completed MP4
  -> audio-track validation
```

4. **Portable Looks**
   - Show a simple diagram:

```text
Look / Preset: reusable grade intent
Source metadata: material-specific reading
Source detail bias: runtime-only assist
```

## Case Study Copy

Filmtone's release work often starts from a concrete output problem.

This one started with two of them: a video file should not lose its sound during normal export, and sharp footage should not always stay sharp in the same hard way after grading.

The first change is about trust. Filmtone now treats the completed file as the thing to verify. If a source has audio and the user runs a normal video export, the output should carry audio too. The pipeline writes audio into the MP4 and checks the completed file before reporting success.

The second change is about texture. Texture Softness was added as a separate control from Lens Softness. It is not a general blur. It is meant to reduce over-sharpened fine detail while preserving readable edges.

The visual goal is modest: reduce over-sharpened fine detail when the source is too digitally crisp. Not every source needs it. Some footage should stay sharp. But when small edges are too strong, Texture Softness gives Filmtone a more specific answer than blur.

The release also keeps source-specific compensation out of saved Looks. That matters for design as much as engineering. A Look should travel. Source-specific correction should help the current material, then stay out of the reusable creative state.

The result is focused product work: no huge new screen, no exaggerated promise, just a more reliable normal video export and a more precise control for image texture.

That is a very Filmtone kind of update: careful about small details, but still tied to a concrete output problem.

## Asset Checklist

- [ ] Desktop export screenshot or short capture showing normal video export.
- [ ] iOS export / editor screenshot after public 1.9 release.
- [ ] Texture Softness control screenshot on Desktop.
- [ ] Texture Softness control screenshot on iOS.
- [ ] Before/after crop set for fine detail.
- [ ] One full-frame before/after pair.
- [ ] Small diagram for audio validation.
- [ ] Small diagram for runtime-only source detail bias.

## Publish Guard

Before publishing:

- rerun Desktop and iOS truth scripts;
- confirm Desktop public `1.7`;
- confirm iOS public `1.9`;
- add final product/download links;
- add actual visual assets and remove unchecked asset placeholders.
