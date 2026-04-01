# Filmtone Web Visual Parity — Phase 2 Handoff

> 作成: 2026-04-01 21:07 JST  
> 前提: Phase 1 は layout / panel / i18n を改善したが、canvas rendering が未解決

## 結論

Phase 2 の主題は **CSS ではなく rendering path**。

現時点の Web は:

- demo section の全幅 breakout は入っている
- 右 panel overlay と frost toolbar は入っている
- Quick / Pro の折り返しは修正済み
- i18n error は解消済み
- ただし **left canvas が黒い**

したがって、次の担当は **`FilmLabCanvas.tsx` の sample image 読み込みから `viewport.setTexture()` までを直線的に debug** すること。

## 触ってよいファイル

- `packages/film-lab-ui/src/FilmLabCanvas.tsx`
- 必要最小限なら `apps/web/src/features/interactive/film-lab/components/FilmLabFullPage.tsx`
- 必要最小限なら `apps/web/src/app/[locale]/film-lab/og/route.tsx`

## できるだけ触らないファイル

- `apps/web/src/app/globals.css`
- `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx`
- `apps/web/messages/ja.json`
- `apps/web/messages/en.json`

これらは Phase 1 で改善済み。今は rendering 原因切り分けを優先する。

## 既知の事実

### 表示面

- `/film-lab` の demo section は全幅化済み
- 右 panel は overlay 表示されている
- コンソールの `MISSING_MESSAGE` は解消済み
- Playwright 実画面では left canvas が黒い

### asset 面

- `apps/web/public/images/film-lab/default.jpg` は存在する
- `curl -I http://localhost:3000/images/film-lab/default.jpg` は `200 OK`
- つまり「sample asset が無い」は現時点の説明にならない

### 設計面

- fallback は削除済み
- sample source は **canonical asset 1 本を直接読む** 方針に戻した

## Phase 2 の最短手順

1. `packages/film-lab-ui/src/FilmLabCanvas.tsx` に限定して読む
2. `mediaLoader.loadURL(publicAssetUrlFromWebPublic("images/film-lab/default.jpg"))`
3. `.then()` 内で `viewport.setTexture(result.texture)` / `setImageResolution()` / `setParams()` が本当に呼ばれるか確認
4. `renderer`, `scene`, `viewport`, `texture` の初期化順に race が無いか確認
5. `chromeLayout="stacked"` + `fullScreen` の組み合わせで、container size が 0 になっていないか確認
6. sample が表示されたら初めて glass / spacing / overlay の最終 polish に戻る

## 受け入れ条件

1. left canvas に sample image が表示される
2. right panel の frosted glass 越しに画像が透けて見える
3. console error なし
4. `bun run build` 成功
5. Desktop screenshot と比較して、demo section が「黒いカード」ではなく「プロアプリ風 overlay」に見える

## 禁止

- fallback image / fallback canvas / fallback SVG を再導入しない
- sample asset を複数化しない
- まず CSS を触ってごまかさない
- Web 側で新しい Batch / Export UI を増やさない

## 参照

- `.claude/tasks/archive/2026-04-01-filmtone-web-visual-parity-phase1.md`
- `.claude/knowledge/2026-04-01-filmtone-web-visual-parity-agent-teams.md`
- `docs/guides/2026-03-31-filmtone-web-ui-parity-handoff.md`
