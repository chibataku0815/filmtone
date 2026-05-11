# Filmtone Copy Quality Harness

Purpose: keep Filmtone public copy from drifting back into generic AI-like phrasing. This is a product-quality gate, not a polishing checklist.

This is the source of truth for Filmtone public and user-facing copy. Do not
start by drafting lines. First identify the surface, read the relevant product
truth, classify claims, then write.

## Source Map

Read only the smallest set that proves the copy surface:

| Surface | Read first | Claim truth |
|---|---|---|
| LP / hero / product positioning | this file, then `docs/filmtone/web/filmtone-lp-copy-handoff-2026-05-05-jst.md` | Run both truth scripts before version, App Store, download, or platform claims. |
| Implementation history / architecture story | this file, then `docs/filmtone/filmtone-implementation-history.md` | Verify current source before naming current runtime state or package boundaries. |
| Implementation change with possible copy impact | this file, then `docs/filmtone/filmtone-copy-context-sync.md` | Record `Copy / History Impact` or `No copy/history impact` before handoff. |
| App Store / ASO metadata | this file, `docs/filmtone/ios/README.md`, then the target `fastlane/metadata` files | Run `check-filmtone-ios-truth.sh`; report public App Store state and local candidate state separately. |
| Desktop / Mac App Store metadata | this file, `docs/filmtone/desktop/README.md`, then the target macOS metadata files | Run `check-filmtone-release-truth.sh`; do not infer Desktop version from Electron package.json. |
| Release notes | this file, the relevant lane `strategy.md` / archive, and the changed source if needed | Mention only shipped behavior for that release surface. |
| UI strings | this file, the exact UI source, and the relevant app guide | UI copy is literal and task-focused; no marketing language inside controls. |
| Support / privacy / legal | this file, current source, and the public support/privacy target | Prefer limitation clarity over mood. Verify privacy, account, cloud, analytics, and data claims from source. |
| Handoff / docs | the relevant `strategy.md` / `active.md` / archive | Docs can quote bad examples, but must label historical evidence as historical. |

## Authoring Protocol

Before writing public copy, fill this brief in the working notes or response:

- Primary reader: a concrete reader or habit, not `ユーザー`, `クリエイター`, or `動画を扱う人`.
- Moment: when the reader meets the problem.
- Unresolved feeling: the active desire, doubt, or dissatisfaction.
- Next action: what the copy should make them do.
- Not for: nearby readers this surface should not chase.
- Claim class: `Public Now`, `Candidate`, `Internal`, or `Forbidden`.
- Source evidence: truth script, current source, public metadata, or dated archive.
- Reversibility buffer: what part may need correction later, and how the copy
  avoids closing that door.

If any claim depends on release state, App Store state, pricing, platform
support, codec/export capability, privacy, account/cloud behavior, or parity,
run the truth scripts or inspect the live source before writing.

## Product Doctrine

- Product quality comes first: behavior, color, export quality, visual proof,
  and product copy are core work.
- Keep outer-shell work minimal until the core product result is good. Broad
  QA, matrix cleanup, and decorative docs come after the product surface works.
- Filmtone copy is video-first. Photos and stills can appear in instructions or
  support copy, but they are not the positioning spine.
- Desire beats feature inventory. A hero or promo line must give a reason to
  try Filmtone with the reader's own material, not only list controls.
- `Preset` is the curve/grade foundation. `Look` is reserved for the Stone /
  Urban Creative LUT Pack context and visible Look selection.
- Keep `Source Profile` / camera conversion separate from `Creative Look LUT`.
- Local workflow may be stated when true, but do not make cloud sync or login
  absence the main promise.
- Implementation history matters. React + Capacitor existed to reuse the
  original WebGPU / WebGL renderer path on iOS; the native SwiftUI /
  AVFoundation move happened because capture and Live Look monitoring needed
  native runtime quality. Do not flatten that into "Capacitor was a mistake" or
  "WebGPU was abandoned."
- Use a gentle, spoken Japanese tone for posts and release copy. Precise claims
  are still required, but the sentence should feel correctable: human,
  measured, and not like a legal verdict or internal report.

## Failure Mode

The rejected pattern is copy that treats obvious premises as value.

Bad examples:

- `撮った写真と動画を`
- `写真も動画も`
- `画像や動画`
- `写真動画`
- `動画と写真`
- `after you shoot`
- `photos and videos`
- `安心して`
- `世界観`
- `雰囲気`
- `フィルムの空気`
- `誰でも簡単`
- `プロ級`
- `cinematic`
- `LUTで色を整える`

These lines can sound harmless, but they do not say why Filmtone should exist. If the opposite is absurd or irrelevant, the phrase is probably filler.

## Copy Rules

1. Do not sell obvious premises.
   - Do not lead with the fact that media was shot, or that the app handles photos/videos.
   - Prefer the job Filmtone performs: choose a look, check it in playback or compare, export/save/share.

2. Do not turn categories into positioning.
   - `写真`, `動画`, `photos`, and `videos` are allowed in instructions and concrete support statements.
   - They are not enough for hero titles, subtitles, promotional text, or metadata headlines.

3. Do not make feature lists into copy.
   - A list such as `presets, Quick controls, LUTs, compare, export` must be attached to an action or decision.
   - Good shape: `Start with a preset, adjust only what you need, then compare before export.`

4. Do not make mechanisms the lead.
   - LUT, codec, pipeline, shader, schema, sidecar, and architecture are proof or detail, not the first public promise.
   - Use them when the surface is a feature page, support page, or technical release note and the reader needs the detail.

5. Do not use mood words as proof.
   - Avoid `安心`, `世界観`, `雰囲気`, `空気感`, `cinematic`, `movie-like`, and `film snapshots` in public copy.
   - If a mood word is ever used, the same sentence must still describe the product action and result.

6. Do not overpromise ease or professional results.
   - Avoid `誰でも簡単`, `プロ級`, `魔法`, `perfect`, `best`, and similar claims.
   - Prefer the real entry path: start from a Preset / Look, compare on the user's material, then save/share/export.

7. Write the Filmtone-specific difference.
   - Web: try a look quickly in the browser.
   - iPhone: save/share from the iPhone workflow.
   - Mac: check video in playback and export with deeper controls.
   - Quick controls: start without opening the full control surface.
   - LUT/profile depth: available when the job needs it.
   - Local workflow: avoid making cloud sync or login the main path.

8. Do not turn gated depth work into a broad public claim.
   - Avoid `奥行きを読む`, `Depth-aware optics`, `where halation belongs`, and `rendered as physics` unless the shipped public build makes that behavior visible, default-relevant, and source-safe.
   - Prefer supportable output language: tune light bloom, grain, compare before/after, check playback, export/save/share.

9. Leave a correction buffer in public posts and release copy.
   - Public facts can be clear, but avoid unnecessary totalizing words such as
     `完全に`, `必ず`, `すべての`, `全端末`, `唯一`, `決して`, `保証`, `always`,
     `never`, `guaranteed`, and `perfectly`.
   - Prefer scoped language: `今回の更新では`, `現時点では`, `対応する iPhone では`,
     `〜しやすくしました`, `〜として扱っています`, `必要に応じて`,
     `確認しやすくしています`.
   - Do not write causal verdicts unless the current source proves them. Prefer
     `〜が理由です` only when sourced; otherwise use `〜を優先しました`,
     `〜が必要になりました`, or `〜という判断です`.
   - Gentle口語 is acceptable for posts: short `です / ます` sentences, fewer
     internal nouns, and direct verbs. Avoid stiff noun chains such as
     `録画フロー品質改善対応` when `録画から編集へ渡しやすくしました` is enough.
   - This is not permission to blur facts. If a version, device, codec, or App
     Store state is uncertain, classify it first, then write the uncertainty
     plainly.

## LP / Hero Gate

LP hero copy must be reviewed as a unit:

1. Appeal line: why the result matters.
2. Explanation line: what Filmtone is and what action it enables.

Reject a hero if it is only:

- a feature explanation: `動画の色を、再生しながら見比べる`
- a platform route summary: `Webで試し、iPhoneで保存、Macで書き出す`
- sensory inventory: `光、影、粒子を見て決める`
- vague film mood: `動画を、フィルムの空気へ`
- target explanation: `人に見せる動画だから`
- object grammar with no desire: `その動画に、似合うルックを`
- mechanics-first: `LUTで色を整え、フィルムルックで書き出す`

For Filmtone, the strongest current demand hypothesis is:

```text
自分の動画を、普通の記録ではなく、見せたくなる仕上がりにしたい。
色作りは難しいので、Preset や Look から始めて、自分の素材で見比べながら近づけたい。
```

This is not approved final copy. Use it as the brief to test stronger lines,
not as text to paste into a hero.

## Mechanical Gate

Run:

```sh
bun run check:filmtone-copy
```

The gate checks public copy only:

- `messages/{ja,en}.json`
- `apps/capacitor-film-lab-ios/fastlane/metadata/{ja,en-US,en-GB}/*.txt`
- `apps/filmtone-desktop-macos/fastlane/metadata/{ja,en-US}/*.txt`

Docs and handoffs may include bad examples for review context; they are not scanned by default.

Keywords are treated as ASO search terms. They are checked for length and forbidden claims, but not for prose style.

When implementation changes may affect public copy, release claims, or the
implementation-history story, also run:

```sh
bun run check:filmtone-context
```

That gate does not approve copy. It verifies that a changed context source or a
`Copy / History Impact` / `No copy/history impact` decision exists for
high-risk product changes.

For an LP hero candidate, also run the local Japanese copy checker:

```sh
python3 /Users/chibatakumi/.codex/skills/japanese-product-copy/scripts/check_japanese_copy.py \
  --surface hero-unit \
  --require-audience \
  --audience "<concrete reader, moment, and unresolved feeling>" \
  --text "<appeal line>. <product explanation line>."
```

Mechanical pass is not approval. If the line lacks desire, reader fit, surface
fit, or claim truth, reject it even if the scripts pass.

## Rewrite Standard

Before accepting a hero, subtitle, promo, feature heading, or metadata line, it must answer at least one concrete question:

- What does the user do next?
- What changes in the result?
- Which surface should they use?
- What depth is available when simple controls are not enough?
- What claim is uniquely true enough for Filmtone to say?
