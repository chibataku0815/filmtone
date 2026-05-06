# Filmtone Copy Quality Harness Handoff

- Date: 2026-04-30 JST
- Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- Purpose: next chat should use the new copy harness to improve Filmtone ASO / LP / features copy without repeating the previous low-quality AI-copy failure.
- Important: ASC upload, `release:metadata`, screenshot regeneration, and App Store submission changes are out of scope until explicit user approval and a fresh ASC read.

## 1. Why This Handoff Exists

The user rejected the earlier copy direction because it still sounded like AI prose:

- `撮った写真と動画を`
- `写真も動画も`
- `写真や動画`
- `photos and videos`
- `after you shoot`
- `device you shot`

The issue was not just phrase choice. The deeper failure was that the copy used obvious premises and category coverage as if they were product value.

Examples of the user's critique:

```text
「撮った写真と動画を」
撮ったとか不要でしょ、撮ってないものとかありえないし、そうゆう根本的なところから質が低い
```

```text
「写真も動画も」
じゃあ逆に写真、動画以外何があるんだよ、ほぼねーだろ
そうゆう根本的なところから低い
```

The harness was created to prevent this failure from coming back.

## 2. Harness Implemented

Added:

```text
docs/filmtone/filmtone-copy-quality-harness.md
scripts/check-filmtone-copy-quality.mjs
```

Root script added:

```sh
bun run check:filmtone-copy
```

The harness is strict and intentionally product-quality biased.

It scans public copy:

- `apps/web/messages/ja.json`
- `apps/web/messages/en.json`
- `apps/capacitor-film-lab-ios/fastlane/metadata/{ja,en-US}/{name,subtitle,promotional_text,description,keywords}.txt`

It does not scan docs / handoffs by default because those may contain bad examples for review context.

Keywords are treated as ASO search terms. They are checked for App Store limits and forbidden claims, not prose style.

## 3. Current Harness Rules

Hard fail rules:

- `obvious-premise`
  - Catches: `撮った写真`, `撮った後`, `撮影後`, `撮った端末`, `撮った素材`, `after-shoot`, `after you shoot`, `device you shot`, `capture device`.
  - Reason: obvious premise, not Filmtone-specific value.

- `category-as-value`
  - Catches high-impact fields using: `写真と動画`, `写真や動画`, `写真・動画`, `photos and videos`, `photo and video`, `photo & video`.
  - Reason: media category coverage is not positioning.

- `abstract-filler`
  - Catches: `安心`, `世界観`, `雰囲気`, `空気感`, `cinematic`, `movie-like`, `film snapshots`, `atmosphere`.
  - Reason: mood language without mechanical product value.

- `feature-list-copy`
  - Catches feature lists that do not attach to an action/result.
  - Reason: `presets, Quick controls, LUTs, compare, export` is a list, not copy.

- `surface-without-role`
  - Catches Web / iPhone / Mac being named without clear roles.
  - Required shape: Web tries, iPhone saves/shares locally, Mac checks/exports deeper.

- `forbidden-claim`
  - Catches: `.cube export`, `combined LUT export`, public sidecar schema, DaVinci, ProRes 422, dependable full Web production export.
  - Reason: unshipped or unverified claim.

The doctrine standard:

```text
Before accepting a hero, subtitle, promo, feature heading, or metadata line, it must answer at least one:
- What does the user do next?
- What changes in the result?
- Which surface should they use?
- What depth is available when simple controls are not enough?
- What claim is uniquely true enough for Filmtone to say?
```

## 4. Existing IA Brief Updated

The IA brief exists here:

```text
docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md
```

It was updated so the product definition is no longer category-first.

Current intended spine:

```text
JA:
Filmtone は、ルックを選び、再生や Before/After で色を確かめ、iPhone・Mac・ブラウザの役割に合わせて保存・書き出しへ進める仕上げツールです。

EN:
Filmtone is a finishing tool for choosing a look, checking the grade in playback or before/after, and saving or exporting through the right surface: iPhone, Mac, or browser.
```

Surface roles:

- Web: try first.
- iPhone: finish locally, save/share from the iPhone workflow.
- Mac: deeper playback checks and export.

Important: `写真や動画`, `photos and videos`, `撮った後`, and `after you shoot` were removed from recommended vocabulary.

## 5. Current Worktree Warning

The worktree is dirty and includes unrelated iOS/core changes. Do not revert anything you did not author.

At the time of this handoff, the following relevant public-copy files are dirty:

```text
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/*.txt
apps/capacitor-film-lab-ios/fastlane/metadata/ja/*.txt
apps/web/messages/en.json
apps/web/messages/ja.json
package.json
scripts/check-filmtone-copy-quality.mjs
docs/filmtone/filmtone-copy-quality-harness.md
docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md
```

There are also unrelated iOS/core edits and untracked handoff docs. Treat them as user/parallel-agent work.

## 6. Direction A Evaluation

The user asked to evaluate Direction A:

```text
Direction A: "光が、奥から滲む。"
JA hero: 光が、奥から滲む。 / iPhone上のフィルム光学。
EN hero: Light bleeds from depth. / Film optics, on iPhone.
Core claim: 奥行きを読む / Reads scene depth / Depth-aware optics / where halation belongs.
```

### Harness Result

`bun run check:filmtone-copy` currently fails.

Latest observed output: 13 issues.

Main fail types:

- `category-as-value`
  - Remaining `写真と動画`, `Photo and video`, `photo and video` in metadata / features / promo / description.

- `surface-without-role`
  - Some features / metadata strings mention Web, iPhone, Mac without assigning enough role.

Example failing fields:

```text
apps/web/messages/ja.json
  film-lab.features.metadataDescription
  film-lab.features.heroLead
  film-lab.metadata.description
  film-lab.metadata.ogDescription

apps/web/messages/en.json
  film-lab.features.metadataDescription
  film-lab.features.heroLead
  film-lab.metadata.description
  film-lab.metadata.ogDescription

apps/capacitor-film-lab-ios/fastlane/metadata/ja/promotional_text.txt
apps/capacitor-film-lab-ios/fastlane/metadata/ja/description.txt
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/promotional_text.txt
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/description.txt
```

### App Store Limit Result

The latest observed App Store field lengths pass.

Observed examples:

```text
JA name: 22 chars / 44 bytes / 30 chars OK
JA subtitle: 19 chars / 51 bytes / 30 chars OK
JA promo: 85 chars / 233 bytes / 170 chars OK
JA keywords: 49 chars / 97 bytes / 100 bytes OK
EN name: 26 chars / 26 bytes / 30 chars OK
EN subtitle: 29 chars / 29 bytes / 30 chars OK
EN promo: 137 chars / 139 bytes / 170 chars OK
EN keywords: 78 chars / 78 bytes / 100 bytes OK
```

## 7. Direction A Qualitative Judgment

Direction A is much stronger than the earlier bland version.

Good:

- It stops leading with media categories.
- It has a visual center: light, depth, bleed/halation, grain.
- It is more differentiated than `写真も動画も`.
- It is memorable enough for ASO / LP direction.

But there is a major claim-truth problem:

```text
奥行きを読む
Reads scene depth
Depth-aware optics
where halation belongs
光のにじみを物理で返す
フィルム光学エンジン
```

These claims are not safe as broad public positioning unless the shipped public build truly makes them available and visible enough.

Relevant discovered implementation facts:

- `Phase0EditorState.depthEnabled` exists.
- `PHASE0_DEPTH_ENABLED_DEFAULT` is `false`.
- Export request emits `depthEnabled: true` only when the toggle is ON.
- Code comments state visual effect is still gated by hidden depth-gain values, currently `0`.
- `FilmtoneDepthPrefilter` exists for mist / bloom / halation depth prefiltering.
- There is an error string: `Depth-aware glow is not available for video sources in this version.`
- Docs say v1.3 depth pipeline / Portrait Depth Realism existed as an activation path, but may be source-limited and not necessarily a universal iOS public claim.

Conclusion:

```text
Copy direction: promising.
Harness result: fail.
Claim safety: not yet safe enough.
Use as north-star direction, not final ASC/LP public copy.
```

## 8. Safer Claim Shape

Do not say this as a universal claim:

```text
奥行きを読み、光のにじみを物理で返す。
Reads scene depth and renders where halation belongs.
Depth-aware optics for iPhone.
```

Safer versions, if implementation truth supports supported-depth-source behavior:

```text
対応素材では、奥行きに応じて光のにじみ方を変えられます。
```

```text
On supported depth sources, Filmtone can shape glow and halation with depth-aware controls.
```

If depth is not public / not enabled / not reliable enough, avoid depth as the lead. Lead with:

```text
ルックを選び、光のにじみと粒子を分けて調整し、iPhone上で書き出す。
```

```text
Choose a look, tune halation and grain separately, then export locally from iPhone.
```

## 9. Current Metadata Snapshot To Review

At this handoff, local metadata appears to have moved beyond the first harness-pass copy. Treat it as experimental and not final.

Observed current local metadata includes:

```text
JA name:
Filmtone - ルックを選んで書き出し

JA subtitle:
フィルム調の色をローカル書き出し

JA promotional_text:
写真と動画をフィルムルックに。LUT、カラグレ、グレインを物理ベースで操作。奥行きを読む光のにじみが、Filmtoneの違いです。完全ローカル、課金なし、アカウント不要。

EN name:
Filmtone: Film Look Editor

EN subtitle:
LUT, color grade, depth-aware

EN promotional_text:
Photo and video, finished in film looks. LUT, color grade, grain, and halation rendered as physics. Depth-aware halation is what makes Filmtone different. Fully local.
```

These fail the harness because category phrases remain and the depth claim is too broad.

## 10. Next Chat Task

The next chat should do copywriting improvement using the harness.

Core task:

1. Run the harness.
2. Fix every hard failure.
3. Separately verify claim truth before accepting `depth-aware`, `scene depth`, `film optics engine`, or similar.
4. Produce candidate copy and explain which product fact supports each line.
5. Do not upload to ASC.

Required commands:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
bun run check:filmtone-copy
node -e "JSON.parse(require('fs').readFileSync('apps/web/messages/ja.json','utf8')); JSON.parse(require('fs').readFileSync('apps/web/messages/en.json','utf8')); console.log('OK JSON')"
```

Metadata length check:

```sh
node - <<'NODE'
const fs = require('fs');
const base = 'apps/capacitor-film-lab-ios/fastlane/metadata';
const checks = [
  ['ja/name.txt', 30, 'chars'],
  ['ja/subtitle.txt', 30, 'chars'],
  ['ja/promotional_text.txt', 170, 'chars'],
  ['ja/description.txt', 4000, 'chars'],
  ['ja/keywords.txt', 100, 'bytes'],
  ['en-US/name.txt', 30, 'chars'],
  ['en-US/subtitle.txt', 30, 'chars'],
  ['en-US/promotional_text.txt', 170, 'chars'],
  ['en-US/description.txt', 4000, 'chars'],
  ['en-US/keywords.txt', 100, 'bytes'],
];
for (const [rel, max, metric] of checks) {
  const text = fs.readFileSync(`${base}/${rel}`, 'utf8').trim();
  const chars = [...text].length;
  const bytes = Buffer.byteLength(text, 'utf8');
  const count = metric === 'bytes' ? bytes : chars;
  console.log(`${count <= max ? 'OK' : 'NG'} ${rel}: ${chars} chars, ${bytes} bytes, ${metric} ${count}/${max}`);
}
NODE
```

## 11. Highest-Precision Next-Chat Prompt

Copy this into the next chat:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-copy-quality-harness-handoff-2026-04-30-jst.md

上記 handoff を入口に、Filmtone の ASO / LP / features copy を Copy Quality Harness に通しながら改善してください。

最重要目的:
- Filmtone の public copy が「当たり前の説明」「媒体羅列」「抽象語の雰囲気コピー」に戻らないようにする。
- ただし保守的で弱いコピーに戻さない。プロダクト品質と差別化を優先する。
- Direction A「光が、奥から滲む。」の強さは評価しつつ、実装事実に接続できない claim は断定しない。

最初に必ず行うこと:
1. handoff を読む。
2. `docs/filmtone/filmtone-copy-quality-harness.md` を読む。
3. `scripts/check-filmtone-copy-quality.mjs` のルールを読む。
4. `bun run check:filmtone-copy` を実行し、fail一覧を現在値として扱う。
5. `apps/web/messages/ja.json` / `apps/web/messages/en.json` の `film-lab.lp`, `film-lab.features`, `film-lab.metadata`, `film-lab.jsonLd` を読む。
6. `apps/capacitor-film-lab-ios/fastlane/metadata/{ja,en-US}` の name/subtitle/promotional_text/description/keywords を読む。

コピー方針:
- `撮った写真`, `撮った後`, `撮影後`, `撮った端末`, `写真と動画`, `写真や動画`, `photos and videos`, `photo and video`, `after you shoot`, `device you shot`, `capture device` を主要コピーに使わない。
- `安心`, `世界観`, `雰囲気`, `空気感`, `cinematic`, `movie-like`, `film snapshots` を public marketing copy に使わない。
- Web / iPhone / Mac を並べるだけにしない。必ず役割を出す:
  - Web = 試す
  - iPhone = ローカルに保存・共有
  - Mac = 再生で確認して深く書き出す
- feature list をコピーにしない。必ず workflow / result / decision に接続する。

Direction A の扱い:
- 「光が、奥から滲む。」は強い方向性として残してよい。
- ただし `奥行きを読む`, `Reads scene depth`, `Depth-aware optics`, `where halation belongs`, `フィルム光学エンジン` は実装事実を再確認してから使う。
- depth が supported-source 限定、default off、hidden gain 0、video非対応などの制約を持つ場合は、hero / subtitle / promo で断定しない。
- 安全な形は、必要なら `対応素材では...` / `On supported depth sources...` と限定する。
- もし depth claim が弱いなら、hero は `ルックを選び、光のにじみと粒子を分けて調整し、iPhone上で書き出す` 系へ寄せる。

作業内容:
1. 現在の fail を表にする:
   - surface
   - file / key
   - current text
   - harness rule
   - なぜ低品質か
   - claim truth risk
   - rewrite direction
2. JA/ENを別々に設計する。直訳しない。
3. App Store metadata候補を作る:
   - name
   - subtitle
   - promotional text
   - keywords
   - description first paragraph
4. LP / features候補を作る:
   - hero title/body/subtitle
   - surface matrix copy
   - features hero
   - metadata/jsonLd
5. 候補ごとに、どの実装事実に基づくか明記する。
6. 変更後に:
   - `bun run check:filmtone-copy`
   - JSON parse
   - App Store field length / keyword byte count
   - targeted `rg` for banned phrases / forbidden claims
   - `bun run --cwd apps/web build`
   を実行する。

禁止:
- ASC upload
- `release:metadata`
- screenshot regeneration
- App Store submission操作
- dirty worktree の無関係変更のrevert
- 未出荷 `.cube export`, public sidecar schema, DaVinci workflow/replacement, ProRes 422 output, dependable full Web export の断定

出力:
- 最終的に、変更したコピー、ハーネス結果、claim truth判断、残リスクを短くまとめてください。
- コピーがハーネスを通っても、実装事実に接続できない場合は合格扱いしないでください。
```
