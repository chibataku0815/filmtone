# Source Facts - Audio + Texture Release

Status: candidate facts checked on 2026-05-12 JST.

## Truth Scripts

Commands run:

```sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Summary:

- Desktop public latest: `1.6`.
- Desktop local candidate: `1.7` build `4`.
- Desktop public update metadata is not yet `1.7`.
- iOS public App Store version: `1.8`.
- iOS local candidate: `1.9` build `8`.
- iOS App Store Connect state in the supplied handoff: `WAITING_FOR_REVIEW`.
- Therefore all article variants in this pack must remain candidate drafts
  until Desktop public `1.7` and iOS public `1.9` are both true.

## Product Facts

- Desktop v1.7 candidate:
  - Restores audio in normal video export.
  - Reads source audio, writes AAC audio into MP4, and validates the completed
    output file before reporting success.
  - Adds `Texture softness`.
  - Applies conservative runtime-only source detail bias in preview, still
    export, and video export.
  - Does not save source detail bias into Looks.
  - Requires macOS 26 or later.
  - Desktop v1.0.4 remains frozen legacy for pre-macOS-26 users.

- iOS 1.9 candidate:
  - App-captured clips include microphone audio.
  - Normal video export preserves source audio when the source has audio.
  - Completed output files are checked for audio tracks before success is
    reported.
  - Highlight-reel export remains source-audio disabled.
  - Adds Texture Softness / texture softness parameter for easing
    over-sharpened fine detail and local contrast.
  - Uses an amplitude-gated bilateral detail layer rather than plain blur.
  - Applies conservative runtime-only source detail bias from source metadata.
  - Keeps source-specific compensation out of saved Looks.
  - Includes iOS feature-folder architecture cleanup around capture, editor,
    export, look, optics, source, services, smoke, strings, and root surfaces.

## Publish Guard

Before finalizing any platform article, rerun both truth scripts. Only after
they report Desktop public `1.7` and iOS public `1.9`, replace candidate
phrases such as `次の更新では` with public phrases such as `公開しました`.
