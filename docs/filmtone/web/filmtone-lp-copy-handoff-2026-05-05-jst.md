# Filmtone LP Copy Handoff - 2026-05-05 JST

## Purpose

This document preserves the full working context for the Filmtone landing page
copy discussion after repeated failed Japanese hero-copy attempts. It is meant
to let a new chat continue without repeating the same mistakes.

Current state: do not implement LP copy yet. The Japanese positioning is still
not approved. The next session should clarify the demand hypothesis and produce
stronger Japanese LP copy before touching `chibatakumi-portfolio`.

## Repositories And Surfaces

Primary public web implementation repo:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
```

Filmtone implementation / product truth repo:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Native Desktop planning / reference docs:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/native-desktop-v2
```

Current LP implementation files in portfolio:

```text
apps/web/src/app/[locale]/(satellite)/filmtone/page.tsx
apps/web/src/features/interactive/film-lab/components/FilmLabFullPage.tsx
apps/web/messages/ja.json
apps/web/messages/en.json
```

Feature-detail page should remain the detailed manual surface:

```text
apps/web/src/app/[locale]/(satellite)/filmtone/features/page.tsx
apps/web/src/features/interactive/film-lab/components/FilmtoneFeaturesContent.tsx
```

Do not duplicate feature matrices or detailed compatibility explanations on the
top LP. Route those to `/filmtone/features`, `/support`, `/download`, or
`/release-notes`.

## Important Worktree / Git Notes

- The first requested implementation attempt was canceled by the user.
- The temporary portfolio worktree / branch for that attempt was removed:
  `chibatakumi-portfolio-filmtone-lp-appeal-refresh`,
  `feature/filmtone-lp-appeal-refresh`.
- The dev server used during that attempt was stopped.
- No portfolio LP code changes from that attempt should remain.
- The current handoff document was written in the Filmtone repo under
  `docs/filmtone/`.
- Local skill files under `/Users/chibatakumi/.codex/skills/japanese-product-copy`
  were edited during the conversation. They are outside the repo.

## Release Truth Captured During This Thread

Truth scripts were run earlier against the former Native Desktop worktree.
That worktree has since been retired; future checks should run against:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Desktop truth script result captured in this thread:

- `public_latestVersion: 1.4` from public update metadata.
- `latest_desktop_tag: desktop-v1.4`.
- `package_version: 1.0.3` in the referenced repo, so repo package state and
  public update metadata were not identical.
- Do not infer next release version from package.json alone.

iOS truth script result captured in this thread:

- Public App Store version: `1.4`.
- Public minimum OS: `26.0`.
- Public App Store release date: `2026-04-21T07:00:00Z`.
- Current version release date: `2026-05-03T04:40:36Z`.
- App Store name at lookup time:
  `Filmtone - iPhoneでフィルムの世界観へ`.

Before publishing any release/version claim in future work, re-run:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

## Original LP Problem

The current LP is understandable but too mechanical. Current JA hero in
portfolio:

```text
LUTで色を整え、
フィルムルックで
書き出す。
```

Problems identified:

- It leads with LUTs, export, surfaces, and repeated capability explanations.
- It explains what the app does before making the viewer want the result.
- It repeatedly explains Web / iPhone / macOS roles.
- It risks becoming a feature manual instead of an appeal-first landing page.
- The strongest public asset is actual Filmtone output and motion proof, but
  copy has not yet made that desire work.

## Copy Constraints That Must Remain

Vocabulary / positioning:

- Use `動画`, not `短尺動画`.
- Avoid `写真や動画`, `写真も動画も`, `photos and videos` as lead copy.
- Avoid `撮った後`, `撮影後`, `after you shoot`.
- Do not collapse Source Profile / Camera LUT and Creative Look LUT.
- Use `Preset` for the curve/grade foundation.
- Use `Look` only for Stone / Urban Creative LUT Pack context when needed.

Forbidden or risky claims:

- No cloud sync claim.
- No DaVinci workflow claim.
- No ProRes output claim.
- No universal browser video export claim.
- Do not claim unreleased Desktop parity features.
- Do not claim Native Desktop replacement status unless public cutover and
  parity truth are verified.

LP information architecture:

- Hero should create desire / trial motive.
- Motion proof should show actual Filmtone output.
- Web / iPhone / macOS should be a bridge after the desire/proof, not the first
  idea.
- Feature details belong on `/filmtone/features`.

## Created / Updated Skill

Skill path:

```text
/Users/chibatakumi/.codex/skills/japanese-product-copy
```

Main files:

```text
SKILL.md
references/japanese-copy-rubric.md
references/product-copy-rubric.md
references/claim-truth-gate.md
references/filmtone-vocabulary.md
references/appeal-scorecard.md
scripts/check_japanese_copy.py
```

Validation command used:

```bash
/tmp/codex-skill-validate-venv/bin/python /Users/chibatakumi/.codex/skills/.system/skill-creator/scripts/quick_validate.py /Users/chibatakumi/.codex/skills/japanese-product-copy
```

Last observed result:

```text
Skill is valid!
```

The skill now attempts to reject:

- Literal English-to-Japanese translation smell.
- Feature-only hero copy.
- Platform matrix hero copy.
- Mechanics-first hero copy.
- Unsupported release/product claims.
- Ambiguous internal metaphors.
- Audience briefs that are missing or too broad.
- Sensory inventory used as hero appeal.
- Operation disguised as appeal.
- Audience brief pasted literally into hero copy.
- Negative-premise hero copy.
- Dangling demonstratives such as `その動画に`.
- Vague film mood wording such as `フィルムの空気`.
- Copy that has no action motive.

However, the skill is still only a guardrail. It has not solved the strategic
copy problem.

## Key User Feedback And Lessons

### 1. "止めた一枚では、" failed

Rejected because:

- `止めた一枚` is an internal editor metaphor.
- A cold reader asks: what was stopped? why one frame?
- It did not reveal who the line was for.

Skill changes:

- Added unclear internal metaphor checks.
- Added reader/situation visibility requirements.

### 2. "動画の色を、再生しながら見比べる..." failed

Rejected because:

- It is just feature explanation.
- It describes operations: compare, choose, save, export.
- It does not create desire.

Skill changes:

- Added feature-only hero detection.
- Added platform matrix detection.

### 3. "光のにじみも、影の残り方も..." failed

Rejected because:

- Concrete visual nouns are not automatically appeal.
- It still says "look at X and decide Y".
- It remains an operation disguised as a poetic line.

Skill changes:

- Added `sensory_inventory_as_hero`.
- Added `operation_as_appeal`.

### 4. Audience was too weak

The line cannot be for generic `ユーザー`, `クリエイター`, or
`動画を扱う人`. Those are categories, not addressable situations.

Skill changes:

- Added required Audience Brief:
  Primary reader / Moment / Unresolved feeling / Next action / Not for.
- Added `--require-audience` and `--audience` to the mechanical checker.

### 5. "人に見せる動画だから、色で失敗したくない" failed

Rejected because:

- `人に見せる動画だから` pastes the audience brief into the headline.
- `色で失敗したくない` starts from a negative premise and lowers mood.
- It explains the target rather than speaking to them.

Skill changes:

- Added `overexplained_audience_hero`.
- Added `negative_premise_hero`.

### 6. "その動画に、ちゃんと似合う..." failed

Rejected because:

- `その` has no antecedent.
- `動画に、` is explanatory object grammar.
- It asks the reader to resolve context that is not present.

Skill changes:

- Added `dangling_demonstrative_hero`.
- Added `overexplained_object_hero`.

### 7. "フィルムらしさはほしい。色だけが浮くのは違う。" failed

Rejected because:

- It is a taste complaint, not a buying or trial motive.
- It does not explain why to try Filmtone, download it, or continue down the LP.
- It is a fragment of dissatisfaction, not an offer.

Skill changes:

- Added Action Motive Gate.
- Added `no_action_motive_hero`.

### 8. "動画を、フィルムの空気へ。" failed

Rejected because:

- `フィルムの空気` is just `世界観` in softer wording.
- It sounds aspirational but is unclear.
- It does not communicate enough concrete transformation.

Skill changes:

- Added `フィルムの空気` to vague mood checks.
- Removed it as a good example.

### 9. "選ぶだけで、動画をフィルム調に。" was "better but still bad"

User said this was "ましだけどまだダメ".

Why it improved:

- It includes an action (`選ぶだけで`).
- It includes transformation (`動画をフィルム調に`).
- It hints at ease.

Why it still fails:

- `フィルム調` is a category label, not the emotional payoff.
- It does not yet explain the user's deeper desire.
- It does not yet make the transformation feel valuable.
- `選ぶだけで` may overpromise because Filmtone also supports adjustment and
  comparison, not only choosing.

## Current Strategic Understanding

The user corrected the core motivation:

```text
"自分の動画を、見せたくなる仕上がりにしたい。"
```

This motivation is likely correct.

The previously proposed counter-motivation was wrong:

```text
"でも、作りすぎた色にはしたくない。"
```

User rejected that. The stronger hypothesis is:

```text
難しいからできない。プロみたいに作りたい。
```

Interpretation:

- The user wants a result that feels better than ordinary phone/video output.
- They want a film-like / professional-looking color treatment.
- They likely do not want to learn difficult color grading first.
- They want an easier path into a more finished look.
- The public copy should not literally say `プロ級` or overpromise, but the
  internal desire is "I want it to look like someone skilled handled the color."

Therefore the current demand hypothesis is:

```text
自分の動画を、普通の記録ではなく、見せたくなる仕上がりにしたい。
色作りは難しいので、プリセットやフィルムルックから始めて、
自分でも本格的に見える方向へ近づけたい。
```

The likely solution hypothesis is:

```text
Filmtone helps users start from presets / film looks instead of building color
from zero, preview the result on their own material, and then save/share/export
the finished video.
```

The next session should test whether this demand hypothesis is actually the
right one before writing hero copy.

## Candidate Lines Tried And Status

Do not reuse these as-is:

```text
止めた一枚では、決めきれない色がある。
```

Status: rejected. Internal metaphor, unclear, no audience.

```text
動画の色を、再生しながら見比べる。
気に入ったルックを選び、iPhoneで保存、Macで書き出せます。
```

Status: rejected. Pure feature/platform explanation.

```text
光のにじみも、影の残り方も。
動画で見てから色を決める。
```

Status: rejected. Sensory inventory + operation.

```text
人に見せる動画だから、色で失敗したくない。
```

Status: rejected. Audience brief pasted into copy + negative premise.

```text
その動画に、ちゃんと似合うフィルムルックを。
```

Status: rejected. Dangling `その`; explanatory `動画に`.

```text
フィルムらしさはほしい。
色だけが浮くのは違う。
```

Status: rejected. Taste complaint; no action motive.

```text
動画を、フィルムの空気へ。
```

Status: rejected. Vague mood; unclear meaning.

```text
動画の色を、
ちゃんと仕上がって見えるところまで。
```

Status: partially understood but rejected by user as too explanatory.

```text
選ぶだけで、
動画をフィルム調に。
```

Status: "better but still bad." It has ease + transformation, but lacks the
emotional payoff and may overpromise.

## Useful Direction That Emerged

The strongest direction so far is not final copy but a strategic bridge:

```text
難しい色作りなしで、動画をフィルムルックに。
```

Why it is stronger than earlier attempts:

- It names the obstacle: difficult color work.
- It names the desired transformation: film look.
- It creates a reason to try the product.
- It is more concrete than `世界観` / `空気`.

Why it may still be insufficient:

- It may still sound like a functional promise, not a distinctive LP hero.
- It may under-sell the emotional payoff: "showable / finished / professional
  feeling".
- It still needs proof and a better surrounding structure to feel convincing.

## What Is Still Missing

The current unresolved copy problem:

```text
How do we express "make my video feel filmic / professionally finished without
learning hard color grading" in natural, desirable Japanese, without becoming
feature explanation or vague mood copy?
```

The missing ingredient is likely the emotional payoff:

- "ordinary video" becomes "worth showing".
- "raw / plain output" becomes "finished-looking".
- "hard color grading" becomes "start from a look and adjust by eye".
- "I cannot make pro color" becomes "I can get close enough to the look I want".

Need to avoid:

- `世界観` alone.
- `空気` alone.
- `プロ級`, `誰でも簡単`, `魔法`, or overpromise.
- Shame / negative premise.
- "人に見せる動画だから" target explanation.
- Feature-only "save/share/export" in hero.

## Recommended Next Workflow

1. Do not start by writing hero lines.
2. First write a one-paragraph demand hypothesis in Japanese:
   - Who is the user?
   - What do they want emotionally?
   - What prevents them?
   - Why would Filmtone be the easier path?
3. Ask whether the hypothesis is correct.
4. Only then produce 6-10 hero directions.
5. For each direction, explicitly state:
   - Desired user feeling.
   - Action motive.
   - Why it is not mere feature explanation.
6. Reject any line that cannot answer:
   - Why would the reader try this with their own material?
   - What does the reader get emotionally beyond "film look"?
7. Run mechanical checks only after human-level reasoning. The checker is not
   sufficient.

## Suggested Japanese Brief For Next Session

Use this as the current best working brief, not as approved copy:

```text
Filmtone のLPは、色作りに詳しくないが、自分の動画を素のままより
仕上がって見える映像にしたい人へ向ける。

その人は「フィルムルック」「映画っぽい色」「プロが整えたような雰囲気」
への憧れがあるが、カラーグレーディングは難しそうで、何から始めれば
いいか分からない。

Filmtone が提示する解決は、色を一から組むことではなく、
プリセットやフィルムルックから始め、自分の素材で見比べながら、
保存・共有・書き出しまで進めること。

Hero は「難しい色作りなしで、見せたくなる仕上がりへ」という欲求と
解決を表現したい。ただし、説明文・機能紹介・曖昧な世界観コピーには
しない。
```

## Mechanical Check Examples

Use the local skill checker for candidate hero units:

```bash
python3 /Users/chibatakumi/.codex/skills/japanese-product-copy/scripts/check_japanese_copy.py \
  --surface hero-unit \
  --require-audience \
  --audience "自分の動画をフィルムのような雰囲気に近づけたいが、色作りが難しくてどこから始めればいいか分からない人" \
  --text "候補hero。製品説明。"
```

Known current checker behavior:

```text
動画を、フィルムの空気へ。
=> error: vague_mood

むずかしい色作りなしで、動画をフィルムルックに。
=> passes mechanical check

選ぶだけで、動画をフィルム調に。
=> passes mechanical check, but human review says still weak
```

## English Handoff Prompt For A New Chat

Use the following prompt to resume at high precision:

```text
You are helping refine Japanese landing-page copy for Filmtone.

Do not implement code. Do not edit the portfolio yet. First reason through the
Japanese positioning and produce copy directions only.

Context:
- Product: Filmtone, a color / film-look finishing app for video.
- Public surfaces: Web demo, iPhone app, macOS app.
- Detailed feature explanations belong on /filmtone/features, not the top LP.
- Use 動画, not 短尺動画.
- Avoid leading with 写真や動画, 撮った後, short videos, cloud sync, DaVinci,
  ProRes output, universal browser export, or unreleased Desktop parity.
- Keep Source Profile / camera conversion separate from Creative Look LUT.

Current verified release truth from the previous session:
- iOS public App Store version was 1.4, minimum iOS 26.0.
- Desktop public update metadata reported latestVersion 1.4.
- Re-run the truth scripts before publishing any version claim.

Important previous failures:
- "止めた一枚では..." failed: unclear internal metaphor.
- "動画の色を、再生しながら見比べる..." failed: feature/platform explanation.
- "光のにじみも、影の残り方も..." failed: sensory inventory plus operation.
- "人に見せる動画だから、色で失敗したくない" failed: target explanation
  plus negative premise.
- "その動画に、ちゃんと似合う..." failed: dangling demonstrative and
  explanatory object grammar.
- "フィルムらしさはほしい。色だけが浮くのは違う。" failed: taste
  complaint with no action motive.
- "動画を、フィルムの空気へ。" failed: vague mood copy.
- "動画の色を、ちゃんと仕上がって見えるところまで。" was understood but
  rejected as too explanatory.
- "選ぶだけで、動画をフィルム調に。" was considered somewhat better but still
  insufficient because it lacks emotional payoff and may overpromise.

Current best strategic hypothesis:
The user does not primarily want a feature called "film look." They want their
own video to feel more finished, filmic, and worth showing. They want something
closer to a professional-looking color treatment, but color grading feels hard
and they do not know where to start. Filmtone should offer an easier entry:
start from presets / film looks, preview on their own material, compare in
playback, then save/share/export.

Your task:
1. First state the user desire, obstacle, and Filmtone solution in Japanese.
2. Do not write hero lines until the demand hypothesis is clear.
3. Then propose 6-10 Japanese hero directions.
4. For each direction, state:
   - the target reader feeling,
   - the action motive,
   - why it is not just feature explanation,
   - why it is not vague mood copy.
5. Avoid direct "プロ級", "誰でも簡単", or "魔法" style overpromise.
6. Avoid vague words like 世界観 or 空気 unless anchored by concrete product
   action and clear meaning.
7. Do not force brevity. If a short line becomes unclear, use a longer line.
8. Japanese first. English adaptation only after the Japanese axis is approved.

The likely direction to explore is not "avoid over-processing." The user has
corrected that. The stronger motivation is: "I want to make my video look more
filmic / professionally finished, but color work is difficult." Find natural,
desirable Japanese wording for that without making it a feature manual.
```
