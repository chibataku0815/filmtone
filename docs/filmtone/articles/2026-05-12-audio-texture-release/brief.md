# Filmtone Audio + Texture Release Article Pack Brief

Status: candidate article pack. Do not publish until both truth scripts report
Desktop public `1.7` and iOS public `1.9`.

## Theme

Latest true Filmtone release across Desktop and iOS:

```text
音と細部を見直した Filmtone。
```

## Voice

- Gentle spoken Japanese for the Japanese surfaces.
- Keep a correction buffer: `今回の更新では`, `素材によって変わります`,
  `見てもらうのが近いです`, `まずは`.
- The creator personality is an elegant oddball, but clarity comes first.
  Express that as precise attention to small details, not as obscure metaphors.
- Do not write like a release checklist, but do lead with the actual change.
  Every paragraph should answer one of these: what changed, why it matters, what
  remains limited, or what to try after release.
- Avoid poetic phrases that make the product claim harder to parse. If a line
  sounds tasteful but cannot be translated into a concrete product fact, rewrite
  it.

## Source Drafts

- iOS reference draft:
  `docs/filmtone/ios/2026-05-12-filmtone-ios-1.9-x-article-jp.md`
- Desktop reference draft:
  `docs/filmtone/desktop/native-desktop-v2/2026-05-12-filmtone-desktop-v1-7-article-jp.md`
- Desktop release notes:
  `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.7.md`
- iOS release handoff:
  `docs/filmtone/ios/2026-05-12-filmtone-ios-1.9-release-handoff.md`

## Audience Briefs

### note

- Primary reader: iPhone と Mac のどちらでも、自分の素材を見比べながら最後まで仕上げたい Filmtone 利用者。
- Moment: 更新内容を読んで、今すぐ試すか、あとで自分の素材で確認するか決める時。
- Unresolved feeling: 色は気に入っているが、書き出した後の音や、細かい輪郭の強さが少し気になる。
- Next action: 公開後に Desktop / iOS を更新し、通常の動画書き出しと Texture Softness を試す。
- Not for: 技術詳細だけを読みたい開発者、SNS用の短い告知だけを求める人。
- Claim class: Candidate until truth scripts report Desktop `1.7` and iOS `1.9` as public.

### Zenn

- Primary reader: SwiftUI / AVFoundation / video export 実装に関心がある日本語の開発者。
- Moment: 動画アプリの export 音声保持や画づくりの細部処理で同じように悩んでいる時。
- Unresolved feeling: `writer に audio input を足した` だけで本当に十分なのか、画像処理の softness をどう設計すべきか迷っている。
- Next action: Filmtone の方針を実装メモとして読み、完成ファイル検証と runtime-only 補正の考え方を持ち帰る。
- Not for: Filmtone の一般利用者向けリリース告知だけを読みたい人。
- Claim class: Technical candidate note; public release wording is gated.

### Medium

- Primary reader: English-speaking product/design readers who care about creator tools and image texture.
- Moment: They are evaluating why a small release can matter beyond a feature list.
- Unresolved feeling: They want creative software to feel trustworthy at the output stage, not just interesting in the editor.
- Next action: Read the release story, then try Filmtone after public release.
- Not for: deep AVFoundation implementation readers.
- Claim class: Candidate until public truth is confirmed.

### Hashnode

- Primary reader: English-speaking engineers building media/export pipelines or native creator tools.
- Moment: They are thinking about native runtime boundaries, export validation, or shared color contracts.
- Unresolved feeling: They need practical framing for preserving audio, adding source-aware image processing, and avoiding platform forks.
- Next action: Use the architectural pattern as a reference for their own export pipeline.
- Not for: broad product storytelling readers.
- Claim class: Technical candidate note; public release wording is gated.

### Behance

- Primary reader: design/product reviewers who want to see how Filmtone thinks about visual quality, UI, and before/after proof.
- Moment: They are scanning a case study and deciding whether the product has taste and craft.
- Unresolved feeling: A filter app can easily feel superficial; the case study must show that Filmtone cares about output, controls, and constraints.
- Next action: View the before/after images, understand the control logic, and follow through to the product page after public release.
- Not for: source-code-heavy engineering readers.
- Claim class: Candidate case study until public release truth is confirmed.

## Shared Claim Boundaries

- Audio applies to normal video export. Highlight-reel export remains
  source-audio disabled.
- iOS app-captured clips include microphone audio in the 1.9 candidate.
- Texture Softness eases over-sharpened fine detail and local contrast. It is
  not a universal beauty guarantee and not a manufacturer-certified transform.
- Source detail compensation is conservative, metadata-dependent, runtime-only,
  and not saved into Looks.
- Native runtime does not mean the shared color model was forked. Shared color
  truth remains in the shared packages / generated Swift payload path.
- React + Capacitor was a rational early bridge for the WebGPU/WebGL renderer
  path, not a mistake narrative.
