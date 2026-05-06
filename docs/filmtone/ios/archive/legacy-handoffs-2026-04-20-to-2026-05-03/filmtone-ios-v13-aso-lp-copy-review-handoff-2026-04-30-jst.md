# Filmtone iOS v1.3 ASO / LP Copy Review Handoff

- 作成日: 2026-04-30 JST
- 目的: 次チャットで Filmtone の App Store 文言と LP 文言をゼロから精査し直すための完全引き継ぎ
- 対象 repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- iOS app: `apps/capacitor-film-lab-ios`
- LP / web: `apps/web`
- App Store ID: `6762564806`
- Bundle ID: `com.chibatakumi.film.lab.ios`

## 0. 結論

Filmtone iOS v1.3 は TestFlight upload 済みで、user が App Store Connect UI から手動で審査提出した。
ASC API で 2026-04-30 夜に確認した状態は `1.3 WAITING_FOR_REVIEW`。

ただし、ASO / LP / App Store 文言は品質上かなり危険。user は「何をするアプリなのかが意味不明」「AI文章丸出し」「意味不明なキャッチコピーは禁止」と明確に指摘している。

次チャットの主目的は、実装や release rail ではなく、**App Store と LP の文言を、意味が通る日本語・英語・機能説明へ再設計すること**。

## 1. 絶対に守ること

1. **次チャットでいきなり `release:metadata` を実行しない。**
   - user が ASC UI で手動修正した内容があり、local repo の metadata は ASC と完全一致していない。
   - 先に ASC 現在値を read-only で取得してから比較する。
2. **意味が曖昧な雰囲気コピーを禁止する。**
   - 例: 「映画の色から、使い捨てカメラまで。」は user が明確に reject。
   - 「見比べながら、安心して仕上げられる。」も user が reject。
3. **「短い動画」と書く必要はない。**
   - user 指示: 「短い動画と記載する必要がない、動画でよい」。
4. **プロダクトが何をするかを最初に伝える。**
   - App Store / LP / feature page のどこを見ても、何をするアプリかが即わかる状態にする。
5. **機能を抽象語で逃がさない。**
   - 最低限、Desktop と iOS それぞれの使い方を説明し、その流れの中で機能紹介する。
6. **未出荷機能を ASO / LP で訴求しない。**
   - DaVinci / Pro Tool bridge の本格訴求は、`.cube export` や sidecar schema 公開などが未出荷なら断定しない。
7. **スクリーンショットは勝手に再生成・上書きしない。**
   - v1.1 由来の既存 screenshot set が正しい前提。
8. **レビュー連絡先や ASC secret はドキュメントに転記しない。**

## 2. 現在の release / ASC 状態

### 2.1 Local truth

2026-04-30 夜の `scripts/check-filmtone-ios-truth.sh`:

- branch/head: `main @ be1311d3`
- upstream: `origin/main`
- commits ahead of upstream: `26`
- commits behind upstream: `0`
- local Xcode `MARKETING_VERSION`: `1.3`
- local Xcode `CURRENT_PROJECT_VERSION`: `2`
- public App Store version: `1.2`
- public bundle ID: `com.chibatakumi.film.lab.ios`

Recent commits:

```text
be1311d3 fix(filmtone-ios): upload ASO metadata fields
808903ef fix(filmtone-ios): target v1.3 metadata release rail
5fe99ff7 docs(filmtone-ios): land creative LUT export feasibility handoff
a3a644c1 Merge feat/filmtone-ios-built-in-look-pack into main for v1.3
a3441269 chore(filmtone-ios): bump to v1.3 build 2 (Phase I)
```

### 2.2 App Store Connect state

ASC API read confirmed:

```text
app_info_edit_state=WAITING_FOR_REVIEW
version=1.3 state=WAITING_FOR_REVIEW
```

User manually submitted v1.3 review in App Store Connect after the TestFlight / metadata work.

## 3. Current ASC copy, not repo copy

Treat ASC as current truth. Local files are stale/dirty in places.

### 3.1 App Info / localized app name and subtitle

ASC currently has:

```text
APPINFO ja
name="Filmtone - iPhoneでフィルムの世界観へ"
subtitle="いつもの動画・日常を素敵な世界観/雰囲気に仕上げる"

APPINFO en-US
name="Filmtone: iPhone Film Looks"
subtitle="Movie color, film snapshots"
```

User manually edited at least the Japanese name/subtitle in ASC.

### 3.2 Version 1.3 metadata

ASC currently has:

```text
VERSION ja
keywords="写真加工,動画編集,フィルター,映画風,カラグレ,LUT,Log,ProRes,HDR,cube"
promo="写真や動画を、フィルムの世界観へ。プリセット、Quick調整、比較プレビューで、いつもの日常を雰囲気のある色に仕上げます。"
description prefix="Filmtone は、iPhone で撮った写真や動画を、映画みたいな世界観へ仕上げるアプリです。素材を選び、プリセットを選んで、明るさ・コントラスト・彩度を Quick 調整し、..."

VERSION en-US
keywords="photo editor,video editor,filter,cinematic,disposable camera,film,lut,grading,prores,hdr,p3,local"
promo="Make iPhone photos and short videos feel cinematic or like film snapshots with presets, Quick controls, and compare preview."
description prefix="Filmtone helps you turn iPhone photos and short videos into movie-like color or disposable..."
```

Important mismatch:

- Local `fastlane/metadata/ja/keywords.txt` still uses `カラーグレーディング`, while ASC uses `カラグレ`.
- Local `fastlane/metadata/ja/description.txt` still contains `短い動画` and older phrasing, while ASC has at least some manual edits such as `写真や動画` and `映画みたいな世界観`.
- Local `fastlane/metadata/en-US/promotional_text.txt` was changed by Codex during an interrupted turn, but ASC still has the older English promotional text.

## 4. Local worktree warning

At handoff creation time, the worktree is dirty with unrelated product/code changes.
Do not revert or overwrite these.

Relevant dirty metadata files:

```text
 M apps/capacitor-film-lab-ios/fastlane/metadata/en-US/promotional_text.txt
 M apps/capacitor-film-lab-ios/fastlane/metadata/ja/name.txt
 M apps/capacitor-film-lab-ios/fastlane/metadata/ja/promotional_text.txt
 M apps/capacitor-film-lab-ios/fastlane/metadata/ja/subtitle.txt
```

Also dirty, unrelated to ASO copy review:

```text
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift
 M apps/capacitor-film-lab-ios/package.json
 M apps/capacitor-film-lab-ios/scripts/fixtures/phase0-contract/*.json
 M apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
 M packages/film-lab-core/src/ios-preset-overrides.ts
 M packages/film-lab-core/src/ios-swift-payload.test.ts
 M packages/film-lab-core/src/ios-swift-payload.ts
 M packages/film-lab-core/src/look-ids.ts
?? apps/capacitor-film-lab-ios/scripts/swift/test-baseGrade-v2-clipping.swift
```

Untracked docs already present:

```text
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-davinci-overall-plan-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-davinci-real-package-export-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md
?? docs/guides/2026-04-30-filmtone-ios-v1.3-release-rail-resume-handoff.md
```

## 5. How release got here

### 5.1 v1.3 release rail

The v1.3 rail started from:

```text
docs/guides/2026-04-30-filmtone-ios-v1.3-release-rail-resume-handoff.md
```

Completed in this session:

- Content review gate was added before ASC upload.
- `fastlane/metadata/copyright.txt` was changed from `© 2026 Takumi Chiba` to `2026 Takumi Chiba`.
- Fastfile was fixed to pass `app_version` from Xcode `MARKETING_VERSION` because `deliver` initially waited for an editable version.
- `release:metadata` succeeded for `1.3`.
- `release:beta` succeeded.
- TestFlight build `1.3 (2)` processed and was distributed to internal testers.
- User later manually submitted the app for review in ASC.

### 5.2 ASO upload bug that was fixed

User noticed ASO changes were not present in ASC.
Investigation found:

- Repo had first-pass ASO metadata from commit `28b0ded2 chore(filmtone-ios): update app store metadata`.
- ASC still had old app info / localized values.
- Fastfile was only explicitly passing some fields, so name/subtitle/keywords/promotional/description were not reliably uploaded.

Fix commit:

```text
be1311d3 fix(filmtone-ios): upload ASO metadata fields
```

This made `metadata`, `release`, and `submit_review` pass:

- `name`
- `subtitle`
- `keywords`
- `promotional_text`
- `description`
- `release_notes`

Then metadata was re-uploaded and ASC API confirmed values matched the repo at that moment.
After that, user manually edited copy in ASC again and submitted review.

## 6. ASO docs / strategy docs already present

### 6.1 Release to ASO handoff

```text
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-v12-release-to-aso-handoff-2026-04-29-jst.md
```

Key points:

- User concern: App Store search / ASO perspective is weak.
- Current metadata was product-description heavy, not search-intent driven.
- Need Japanese and English ASO keyword design separately.
- Need competitor and keyword research before serious ASO changes.
- Do not regenerate screenshots.
- Confirm current ASC state before metadata edits.

### 6.2 PeekLut competitive pivot handoff

```text
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md
```

Key points:

- PeekLut is positioned as a broad iPhone/iPad color editing app and quasi-DaVinci replacement.
- Filmtone should not chase full feature parity.
- Strategic direction proposed: iPhone snapshot ritual + Pro Tool handoff bridge.
- However, many of the proposed Pro Tool bridge marketing claims depend on features not yet shipped in v1.3:
  - `.cube` export
  - sidecar schema public page
  - DaVinci Lua sample
  - ProRes 422 output
  - Apple Log pass-through
- Do not use these as current App Store claims unless implementation status is verified.

## 7. User feedback to preserve exactly

User wants a severe copy quality reset.
Do not soften this into generic "polish".

User rejected / warned:

```text
映画の色から、 使い捨てカメラまで。
文言が意味がわからない、意味がわからないのは絶対に禁止

簡単にフィルムルックに変更できる的なことで良いが伝わらないキャッチコピーとか言語道断、ゴミカス以下

短い動画と記載する必要がない、動画でよい

機能詳細がほぼ意味わからない、最低限使い方をデスクトップ版、iOSで記載しつつ機能紹介する

見比べながら、安心して仕上げられる。

安心してとか意味がわからない、別に見比べなくても怖くないし、見比べられるから安心があるわけでもない
```

Interpretation:

- Copy must be concrete and mechanically understandable.
- The user does not want atmospheric lines that sound good but do not explain product value.
- "世界観", "雰囲気", "映画みたい", "安心", "仕上げる" can be used only if each sentence still clearly says what the app does.
- Avoid telling users how they should feel.
- Do not hide product mechanics behind abstract mood words.

## 8. Current LP copy locations

Primary files:

```text
apps/web/messages/ja.json
apps/web/messages/en.json
```

Primary namespaces:

```text
film-lab.lp
film-lab.features
film-lab.metadata
film-lab.jsonLd
```

Routes:

```text
apps/web/src/app/[locale]/(satellite)/filmtone/page.tsx
apps/web/src/app/[locale]/(satellite)/filmtone/features/page.tsx
```

Other related routes:

```text
apps/web/src/app/[locale]/(satellite)/filmtone/download/page.tsx
apps/web/src/app/[locale]/(satellite)/filmtone/release-notes/page.tsx
apps/web/src/app/[locale]/(satellite)/filmtone/roadmap/page.tsx
apps/web/src/app/[locale]/(satellite)/filmtone/support/page.tsx
apps/web/src/app/[locale]/(satellite)/filmtone/privacy/page.tsx
apps/web/src/app/[locale]/(satellite)/filmtone/og/route.tsx
```

Current problematic examples in `apps/web/messages/ja.json`:

```json
"heroTitle": "映画の色から、\n使い捨てカメラまで。",
"heroBody": "iPhoneで撮った写真や短い動画を、映画みたいな色にも、使い捨てカメラのフィルム感にも。撮った端末の中で仕上げて、そのまま保存・共有できます。",
"demoBody": "写真や短い動画を開いて、雰囲気を確かめてください。深く仕上げたくなったら、Mac版へ。",
"cardsTitle": "見比べながら、安心して仕上げられる。"
```

More copy that likely needs review:

```json
"surfaceSplitEyebrow": "3つの面で、ひとつの世界観",
"surfaceSplitTitle": "Web、Mac、iPhone — どこから始めても、同じ Filmtone。",
"surfaceSplitWebBody": "ブラウザで自分の素材を開いて、雰囲気を試す。",
"premiumCompareBody": "光、影、空気感 — 止まらないままで確認できます。",
"capabilitiesTitle": "光のにじみと空気感が、動きの中で揃う。",
"capability1Body": "実際に Filmtone で仕上げた動画です。光のにじみ方や色のまとまりが、動きの中でも自然に変わることがわかります。",
"capability2Body": "別の場面でも、色味や空気感がまとまり、動画全体の印象が整って見えることを確かめられます。"
```

## 9. Product truth for copy rewrite

Use these facts; verify in code/docs before turning into final public claims.

### 9.1 iOS v1.3 product truth

Filmtone iOS currently:

- imports photo/video from iPhone
- applies presets / built-in Looks
- supports Quick controls: brightness / contrast / saturation etc.
- supports Before / After compare
- exports and saves/shares locally on iPhone
- supports Source Profile + Film Look `.cube` LUT slots
- ships 5 built-in Look chips with `FILMTONE` badges
- has Camera Profile picker:
  - Auto
  - Apple Log
  - Apple Log 2
  - V-Log
  - S-Log3
  - Rec.709
  - Import .cube
- supports library reuse:
  - imported LUT reuse
  - Saved Looks apply path
- emits export sidecar with `savedLook` and `cameraProfile` blocks
- is local-first:
  - no login required
  - no cloud sync required
  - no subscription/IAP claim should be made unless reverified

Avoid saying:

- "DaVinci replacement"
- "complete recreation"
- "all Filmtone effects editable"
- ".cube export" unless implemented and shipped
- "Sidecar schema public" unless the public page exists
- "ProRes 422 output" unless shipped

### 9.2 Desktop / macOS product truth

Desktop claims must be checked against current public version and code before rewrite.
Likely safe starting points from existing LP:

- macOS Apple Silicon DMG
- deeper finishing/export workflow
- folder/media processing
- playback and comparison
- LUT / Source Profile / Film Look workflow
- HDR / Log / P3 / ProRes handling, but verify exact current support before writing final copy

### 9.3 Web product truth

Existing LP positions web as:

- browser demo / try-first surface
- open own media in browser
- audition the look
- use Mac/iPhone for deeper finish/export

Verify current web limitations before final copy:

- Browser export is beta / browser-dependent
- Safari limitations may exist
- Do not overpromise full production export from web

## 10. Recommended next workflow

1. Read this handoff.
2. Read current ASC state before touching metadata.
3. Read current local metadata and diff against ASC.
4. Read LP copy in `apps/web/messages/ja.json` and `apps/web/messages/en.json`.
5. Build an inventory table:
   - surface: App Store / LP / features / metadata / JSON-LD
   - key
   - current text
   - problem
   - product truth it should communicate
   - proposed replacement
6. Do not start by writing clever catchphrases.
7. First write a one-sentence product definition in plain Japanese:
   - "Filmtone is an app that does X for Y by Z."
8. Then derive:
   - App Store name/subtitle
   - promo text
   - description first paragraph
   - LP hero title/body
   - feature page headings
9. Search current ASO constraints and competitor positioning with web/Gemini before final ASO decisions.
10. Present candidate copy to user for approval before editing files or uploading to ASC.

## 11. Useful read-only commands

ASC current state:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
set -a; source .env.local; set +a
./scripts/bundle.sh exec ruby -e 'require "spaceship"; Spaceship::ConnectAPI.auth(key_id: ENV.fetch("ASC_KEY_ID"), issuer_id: ENV.fetch("ASC_ISSUER_ID"), filepath: ENV.fetch("ASC_KEY_PATH"), duration: 1200); client = Spaceship::ConnectAPI; app = Spaceship::ConnectAPI::App.find("com.chibatakumi.film.lab.ios", client: client); info = app.fetch_edit_app_info(client: client, includes: nil); puts "app_info_edit_state=#{info&.state}"; info&.get_app_info_localizations(client: client)&.sort_by(&:locale)&.each { |l| puts "APPINFO #{l.locale}\tname=#{l.name.inspect}\tsubtitle=#{l.subtitle.inspect}" }; v = app.get_app_store_versions(client: client, filter: { versionString: "1.3", platform: "IOS" }, includes: nil).first; puts "version=#{v&.version_string} state=#{v&.app_version_state}"; v&.get_app_store_version_localizations(client: client)&.sort_by(&:locale)&.each { |l| puts "VERSION #{l.locale}\tkeywords=#{l.keywords.inspect}\tpromo=#{l.promotional_text.inspect}\tdesc_prefix=#{l.description&.slice(0,120).inspect}\twhats_new_prefix=#{l.whats_new&.slice(0,80).inspect}" }'
```

Release truth:

```sh
bash /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

LP copy locations:

```sh
sed -n '240,370p' apps/web/messages/ja.json
sed -n '240,370p' apps/web/messages/en.json
find 'apps/web/src/app/[locale]/(satellite)/filmtone' -maxdepth 3 -type f | sort
```

Search problem phrases:

```sh
rg -n "映画の色|使い捨てカメラ|見比べながら|安心して|短い動画|世界観|雰囲気|film snapshots|short clips|cinematic" apps/web/messages apps/capacitor-film-lab-ios/fastlane/metadata
```

## 12. Highest-precision next-chat prompt

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-v13-aso-lp-copy-review-handoff-2026-04-30-jst.md

上記 handoff を入口に、Filmtone の App Store ASO 文言と LP 文言を全面的に精査してください。

目的:
- App Store / LP / features page のどこを見ても、Filmtone が何をするアプリなのかが即わかる状態にする。
- AI文章っぽい抽象コピー、意味が曖昧なキャッチコピー、雰囲気だけの言い回しを排除する。
- iOS / Desktop / Web の使い方と機能差を、ユーザーが迷わない文章にする。

最重要方針:
- 「意味がわからない」文言は絶対禁止。
- 「映画の色から、使い捨てカメラまで。」のように聞こえは良いが何をするのかわからないコピーは禁止。
- 「見比べながら、安心して仕上げられる。」のように、なぜ安心なのか説明できない感情語は禁止。
- 「短い動画」と書く必要はない。動画でよい。
- まず機能・使い方を説明し、その上で必要なら雰囲気や世界観を添える。
- 未出荷の機能は訴求しない。
- 手動提出済みの ASC metadata を上書きしない。最初に ASC 現在値を read-only で取得する。

まず実行すること:
1. handoff を読む。
2. ASC API で v1.3 の現在値と state を read-only 取得する。
3. local `fastlane/metadata` と ASC の差分を出す。
4. `apps/web/messages/ja.json` / `apps/web/messages/en.json` の `film-lab.lp` と `film-lab.features` を読む。
5. 現在の App Store / LP / feature page 文言を、以下の表で棚卸しする:
   - surface
   - key / field
   - current text
   - 何が意味不明か
   - 伝えるべきプロダクト事実
   - rewrite direction

調査:
- Apple公式の metadata 制限を現在情報で確認する。
- 必要なら App Store / web search で競合・検索語を確認する。
- ただし競合の言い回しを真似るのではなく、Filmtone の実装事実から言葉を作る。

作業範囲:
- まずはレビューと候補文案の提示まで。
- user 承認前に ASC upload / release:metadata / screenshots / App Store submission は実行しない。
- user 承認前に LP ファイルの大規模編集をしない。

出力してほしいもの:
1. 現状診断: どの文言が意味不明で、なぜダメか。
2. Filmtone の一文定義案: 日本語・英語。
3. App Store metadata 改稿案:
   - name
   - subtitle
   - promotional text
   - keywords
   - description first paragraph
4. LP hero / feature page 改稿案:
   - hero title/body
   - iOS / Desktop / Web の使い方説明
   - feature headings
5. 各案がどの実装事実に基づくか。
6. 変更する場合の対象ファイルと upload 手順。ただし実行は user 承認後。

時間がかかってもよいので、意味が通ることを最優先にしてください。こちらの思考力を考慮せず、計算資源を最大限使って正確に精査してください。
```
