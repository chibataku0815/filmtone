# Filmtone Audio + Texture Release Case Study

Status: candidate Behance article. Do not publish until Desktop public `1.7`
and iOS public `1.9` are both confirmed by truth scripts.

Publication switch:

- Before public truth: keep `release focuses on`, `meant to`, `is added`
  framing. Avoid `released`, `is available`, `we shipped`.
- After public truth: confirm the case-study copy is consistent with the public
  release notes, add the App Store and Desktop download links, and replace any
  remaining `candidate` qualifiers in the body copy.

TOC policy: Behance case studies are scroll-based visual sequences and do not
expose a TOC widget. The H2 sections in this draft (Cover, Project Summary,
Problem, Design Direction, Visual System Notes, Case Study Copy, Asset
Checklist, Publish Guard) are production checkpoints for the layout, not
reader navigation. Do not add a TOC, and do not rename these section
headings to "1." / "2." style — they map to Behance project blocks, not to
a numbered article.

## Cover

Title:

```text
Filmtone: Texture Softness
```

Subtitle:

```text
Filmtone is a small app for adjusting the color of video on iPhone and Mac. This case study covers a release that adds a new control for softening the in-camera sharpening baked into phone and action-cam footage, and keeps source-specific corrections out of saved Looks. The same release also fixes a bug where normal video exports could lose their original audio.
```

Suggested cover visual:

- Split frame: graded footage with visible fine texture.
- Small UI crop: `Texture softness` / `質感のやわらかさ`.
- No audio waveform on the cover — the audio change is a bug fix, not the headline.

## Project Summary

Filmtone is a video color tool for choosing a grade, comparing it on real material, and exporting the result on iPhone and Mac.

This release adds one new control:

- The in-camera sharpening that phone and action-cam sources bake into their files should be adjustable, without turning the image into a simple blur.

It also fixes one bug:

- Normal video exports now keep audio when the source has audio.

Both changes are about what the finished output file looks and sounds like — the part of a video tool that the audience actually receives.

## Problem

The new-control side of the problem is straightforward. Phone and action-cam sensors / ISPs / encoders apply heavy sharpening in-camera, and that sharpening is baked into the source file before any color work begins. Grading does not add to it (and cannot remove it). The picture ends up reading correctly in tonality, while the source's pre-existing fine acutance still feels too crisp.

The audio side of the problem is a bug: normal video exports could look correct in the editor while the completed file did not carry the expected audio. The fix restores audio in the finished file when the source has it.

Both show up after the edit, when the file is supposed to be finished.

## Design Direction

The design decision was to keep the product surface clear.

Texture Softness is the only new control in this release. It sits in Advanced Optics, near other material/optical decisions. It is separate from Lens Softness:

- Lens Softness: lens/periphery character.
- Texture Softness: fine local detail, strong edges, and local acutance.

The control should feel like a small adjustment for material where the source's in-camera sharpening makes hair, cloth, leaves, text, or night noise look too hard — most often phone and action-cam footage.

The audio fix does not need a dramatic UI. It needs a pipeline that checks the completed output file. There is no new screen attached to it.

## Visual System Notes

Suggested case-study sections:

1. **Before / After: Fine Detail**
   - Show crop-level comparison at low and moderate Texture Softness.
   - Use hair, cloth, leaves, small text, or night noise.
   - Avoid claiming universal improvement. Caption as `material-dependent`.

2. **Control Placement**
   - Show the Desktop Advanced Optics panel and iOS control surface.
   - Explain that Texture Softness is not Lens Softness.

3. **Portable Looks**
   - Show a simple diagram:

```text
Look: reusable grade intent (curve / grade foundations also live here as bundled entries)
Source metadata: material-specific reading
Source detail bias: runtime-only assist
```

4. **Bug Fix Footnote: Audio Validation**
   - Treat as a small footnote at the end of the visual sequence, not a main section.
   - Optional minimal flow diagram:

```text
Source video with audio
  -> normal export
  -> completed MP4
  -> audio-track validation
```

   - Caption as `bug fix: normal video exports now keep their original audio`.

## Case Study Copy

Filmtone's next release adds one new control: Texture Softness softens the in-camera sharpening baked into phone and action-cam footage, without flattening readable edges. The same release also fixes a bug where normal video exports could lose their original audio.

Texture Softness is a separate control from Lens Softness. Lens Softness shapes lens-and-periphery character. Texture Softness targets the fine local acutance the source file arrives with — the in-camera sharpening baked into hair, fabric, leaves, small text, and night noise on most phone and action-cam material — without applying a general blur. The effect is material-dependent. Some footage should stay crisp.

When source metadata suggests heavy in-camera sharpening (e.g. recent iPhone or action-cam profiles), Filmtone applies a conservative source detail bias at runtime. That bias never bakes into a saved Look. A Look should travel across material; source-specific correction belongs in the runtime, not in the reusable creative state.

Normal video exports now keep their original audio in the completed MP4, and the export pipeline confirms the audio track is in the finished file before reporting success. Highlight-reel export remains source-audio disabled in this release.

The result is a release that adds one new screen for fine detail and restores audio in the completed file when the source has it.

## Asset Checklist

- [ ] Texture Softness control screenshot on Desktop.
- [ ] Texture Softness control screenshot on iOS.
- [ ] Before/after crop set for fine detail.
- [ ] One full-frame before/after pair.
- [ ] Small diagram for runtime-only source detail bias.
- [ ] Optional small diagram for audio validation (bug fix footnote only).

## Publish Guard

Before publishing:

- rerun Desktop and iOS truth scripts;
- confirm Desktop public `1.7`;
- confirm iOS public `1.9`;
- add final product/download links;
- add actual visual assets and remove unchecked asset placeholders.

## External Links

Filmtone iOS is available on the App Store:

```text
https://apps.apple.com/jp/app/filmtone-%E3%83%95%E3%82%A3%E3%83%AB%E3%83%A0%E8%AA%BF%E3%82%AB%E3%83%A9%E3%82%B0%E3%83%AClut/id6762564806
```

When publishing on Behance, add this URL to the project's external link / description field. Filmtone Desktop download link is added here after Desktop public `1.7` is confirmed.
