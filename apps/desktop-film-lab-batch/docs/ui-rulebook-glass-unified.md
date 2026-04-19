# Filmtone Desktop — UI Rulebook (glass 統一)

> Batch / Export タブ glass 統一再設計のための **不変ルール**。
> 4 製品研究（Lightroom / Capture One / Apple Photos / DaVinci Deliver）の共通則から導出。
> 原典: `life/docs/guides/2026-04-19-filmtone-export-ui-reference-study.md`
>
> **本 rulebook は「好み」ではなく「pro 書き出し UI の業界収束点」**。4 中 3 以上で観察された規範のみを昇格した。
>
> 適用範囲: `apps/desktop-film-lab-batch/src/renderer/` 配下のみ。shared `packages/film-lab-ui` / `packages/film-lab-renderer` / `packages/film-lab-core` は **touch 禁止**（iOS v4 互換）。

---

## §1 Material（素材）

### R1.1 カードの唯一材質は `.fl-card--frost`
- 定義: `globals.css:519-531`
- 構成: `background: color-mix(… 72%)` + `backdrop-filter: blur(var(--fl-frost-blur)) saturate(1.2)`
- blur 値: `--fl-frost-blur: 28px`（変更禁止）

### R1.2 edit パネル類は `.fl-card-muted.fl-card--frost`
- 定義: `globals.css:533`
- 用途: look 設定など編集操作が集中するパネル
- ::before で gradient tint を乗せて frost より濃い

### R1.3 WebGPU 直背景は `.fl-card--frost-webgl-backdrop`（blur 無し）
- 定義: `globals.css:585`
- backdrop-filter 無し、代わりに video + gradient tint
- WebGPU canvas の下に敷く surface のみ使用

### R1.4 ソリッド黒系カード/バナー/チップは全廃（5 箇所）
| 現行位置 | 現行形態 | 新形態 |
|---|---|---|
| job mode intro strip `BatchTabPanel.tsx:1404-1420` | 独立 banner | § 1 セクションヘッダに吸収 |
| session resume banner `:1429-1448` | blue accent card | § 2 冒頭 inline 1 行 + 復元ボタン |
| proxy cache card `:1450-1467` | amber accent card | Advanced disclosure 最下部 |
| status chips `:1477-1485` | 黒ピル 3 個 | 削除（accordion header summary が同機能） |
| preview-export bridge banner `:1509-1545` | Info アイコン付 card | Advanced disclosure 内の 1 行プレーンテキスト |

### R1.5 カード外観は frost 既存スタイルのみ
- 追加 shadow 禁止
- 追加 border 禁止（`--fl-border-subtle/default/strong` のみ）
- card 内部に別 card を入れない（material 積層禁止）

### R1.6 区切りは hairline で
- セクション間の区切りは `--fl-border-subtle` の 1px ライン
- 背景色変化での区切りは禁止（Apple HIG の vibrancy separator 方式）

**根拠**: 4 製品すべてが「背景 material 1 段 + hairline で区切る」を採用。内側で card を重ねない。

---

## §2 Typography（タイポ階層）

### R2.1 既存トークン限定、新規追加禁止
- `--fl-text-primary` — 値・見出し（globals.css:43）
- `--fl-text-secondary` — label・本文（:44）
- `--fl-text-tertiary` — caption・hint（:45）
- `--font-family-sans` — Geist / Noto Sans JP / メイリオ（:51）

### R2.2 階層は 4 段階
| Level | 用途 | font-size | weight |
|---|---|---|---|
| H2 | セクション見出し（§ 1 ジョブ / § 2 ソース 等） | 17px | 600 |
| H3 | セクション内サブ見出し | 15px | 600 |
| Body | 本文・select 値 | 14px | 400 |
| Label / Caption | フォームラベル・helper text | 12px | 500（label）/ 400（caption） |

### R2.3 既存 utility クラス活用
- `.fl-label` — 0.6875rem / weight:600 / uppercase（:621）→ 専用ラベル用途のみ
- `.fl-caption` — 0.625rem / line-height:1.5（:629）→ hint / caption 用

### R2.4 font weight / size のバリエーション禁止
- 上記 4 段階を超える weight / size 組み合わせを作らない
- 「見出しを少し強調したい」→ 上位階層に昇格させる、weight 700 を追加しない

---

## §3 Spacing（余白・8px grid）

### R3.1 基準単位は 8px
- 4 / 8 / 12 / 16 / 24 / 32 / 48 の倍数のみ使用
- 0.5rem = 8px、1rem = 16px 基準

### R3.2 スケール
| 場面 | 値 |
|---|---|
| セクション間 | 24px |
| カード内 padding | 16px |
| カード内要素間 | 12px |
| chip / pill 間 | 8px |
| 見出し → 本文 | 8px |
| footer CTA 内 padding | 垂直 12px / 水平 16px |

### R3.3 border-radius は既存値を変更しない
- `.fl-card` の既定 `border-radius` を維持
- カード種別で radius を変えない

### R3.4 sticky footer のマージン
- viewport 底から 0px（直接吸着）
- 内容物は上 padding 12px / 下 padding 12px

---

## §4 Color / Priority（色と優先度）

### R4.1 Primary accent = amber は 1 箇所のみ
- `--fl-accent` (amber-9) / `--fl-emphasis` (amber-10) は **footer primary CTA** のみに使用
- 使用禁止: step indicator / active tab / highlight / link / icon tint / selected border
- **現状の `編集タブどおりにする` button の amber は撤回**（look section 内 secondary に降格）

### R4.2 Primary CTA の動的ラベル
| 状態 | ラベル | 色 |
|---|---|---|
| 未準備 | `動画を書き出す` / `写真を書き出す` | neutral（disabled） |
| 準備完了 | 同上 | amber |
| 実行中 | `中断` | red text ghost |

### R4.3 Secondary = neutral border + transparent fill
- `--fl-border-default` の 1px border
- 背景透明、hover で `--fl-border-strong` + 薄い tint

### R4.4 Destructive = red text-only
- 「プロキシキャッシュを消す」「キャンセル」の destructive 形態は red text + icon のみ
- solid red button 禁止（背景は neutral のまま）
- primary CTA と同じ画面位置に並べない（Advanced disclosure 内に沈める）

### R4.5 Status 色は status 文脈のみ
| 用途 | 色 |
|---|---|
| in-progress | amber（primary CTA と同色だが status バナー文脈でのみ） |
| success | green |
| error | red |

**禁止**: feature toggle の active を amber で示す、selected state を amber で示す、など status 以外での amber 使用。

### R4.6 Border の使い分け
| 状態 | 値 |
|---|---|
| 通常 | `--fl-border-subtle` |
| 選択（hover / focus） | `--fl-border-default` |
| active / focus-visible | `--fl-border-strong` |

---

## §5 ⓘ Icon 方針（17 → 目標 0〜3）

### R5.1 第一選択: ラベル自己説明化
- 「出力形式 ⓘ」→ 「出力形式（JPEG / PNG / TIFF）」
- 「プリセット ⓘ」→ 「プリセット: cinematic」（値を一緒に出す）

### R5.2 第二選択: placeholder / helper text 降格
- input の placeholder に hint を入れる
- form field 下に 12px caption で補足

### R5.3 第三選択: `HelpHint` 残存（最大 2〜3 箇所）
- 許容される残存: **外部用語のみ**（例: LUT 色空間 / ICC profile / proxy cache）
- それ以外は第一・第二選択で消す

### R5.4 現行 17 箇所の処理マップ
| 現行位置 (`BatchTabPanel.tsx`) | 処理 |
|---|---|
| jobType 写真/動画 (924, 954) | 削除 |
| sources 写真フォルダ/動画ファイル (986, 1006) | 削除（placeholder） |
| output フォルダ命名/接尾辞 (1196, 1178) | 削除（placeholder） |
| look 編集グレード適用 (1081) | 削除 |
| look JSON メタデータ読み込み (1095) | 削除 |
| run keyboard (1221) | 削除（footer hint） |
| intro エクスポート説明 (1348) | 削除（§1 吸収） |
| photo intro (1369) | 削除（§1 吸収） |
| video intro (1393) | 削除（§1 吸収） |
| resume セッション (1437) | 削除（inline text） |
| proxy cache (1453) | Advanced 内で HelpHint 残存 |
| footer 設定永続化 (1682) | 削除 |
| LUT 色空間（look 内、推定） | HelpHint 残存 |

→ **想定残存 2〜3 箇所**（proxy cache / LUT 色空間 / ICC）

---

## §6 i18n 規約（ja.json ↔ en.json）

### R6.1 キー追加・削除は両ファイル同時
- `messages/ja.json` と `messages/en.json` の key set 差分を 0 に保つ
- 片方追加・他方未対応は CI（vitest）で捕捉

### R6.2 keyset 一致 assertion を test に追加
- `BatchTabPanel.test.tsx` または新規 `messages.test.ts` に:
  ```typescript
  const jaKeys = flattenKeys(jaMessages);
  const enKeys = flattenKeys(enMessages);
  expect(jaKeys.sort()).toEqual(enKeys.sort());
  ```

### R6.3 unused キーの枝刈り
- 実装完了後、`grep -r "film-lab.desktop.batch" apps/desktop-film-lab-batch/src/` で使用キーを抽出
- 未参照キーを ja.json / en.json から削除（両ファイル同時）

### R6.4 日本語ラベル変更時はテストも同期更新
- `BatchTabPanel.test.tsx` の日本語固定文字列 assertion（例: `"ルック: プリセット「cinematic」"`）を変更する場合、test も同時更新
- 固定文字列を変更しない場合は test 保全

---

## §7 禁止事項（前回失敗からの教訓）

### R7.1 scrim / luma 適応駆動は禁止
- CSS 変数で preview 輝度を右レール opacity に flow する実装は **glass を殺す**
- 2026-04-19 に 2 回 revert 済み

### R7.2 機械的削除のみの refactor 禁止
- 削除後の IA を設計しないまま 100 行削除する approach は **階層を壊す**
- 2026-04-19 に 1 回 revert 済み

### R7.3 coefficient 微調整ループ禁止
- α=0.28 → 0.38 → 0.94 → 0.18 の retune は問題の次元が違う
- material 衝突は CSS 値の調整では解決しない

### R7.4 solid black カードの新設禁止
- 「強調したい要素」を黒カードで浮かせる衝動を封じる
- material 濃度変化 + タイポ強度で階層を作る

### R7.5 amber を primary CTA 以外に使う禁止
- step indicator / active tab / highlight / link / icon に amber を使わない
- accent の意味（「次のアクション」）が壊れる

### R7.6 user 承認前のコード変更禁止
- rulebook + IA mock を user が承認する前に `.tsx` / `.css` を触らない
- Phase 5 以前は docs のみ編集

---

## §8 Deferred Additions（rulebook 拡張候補、承認後検討）

本 rulebook で不足が出た場合の追加候補。**承認後に user に諮る**：

- `.fl-disclosure` utility class — Advanced disclosure 用の共通ヘッダ/動作
- preset strip 用 tile component — 横 1 行スクロール可能タイル
- footer sticky bar layout — viewport 底吸着 + backdrop-filter
- toast / status banner（実行中表示用）

これらは Phase 5 実装中に必要性を再評価。不要なら追加しない（最小主義）。

---

## §9 Success Criteria（本 rulebook 適用後の検証基準）

### 定量
| 指標 | 現状 | 目標 |
|---|---|---|
| `BatchTabPanel.tsx` 行数 | 1687 | ≤ 500 |
| 情報ブロック（top-level） | 7 | ≤ 4 |
| ソリッド黒系カード | 5 | 0 |
| ⓘ HelpHint 呼び出し | 17 | ≤ 3 |
| primary CTA 数 | 複数 amber 競合 | 1（amber only） |
| 新規 CSS トークン追加 | — | 0（理想）〜 1 |
| `bun run test` | — | 全 pass |
| `bun run typecheck` / `build` | — | 成功 |

### 定性
- material 言語が 1 つ（frost 統一、WebGPU 背景のみ例外）
- Lightroom / Capture One / Apple Photos のうち 2 本以上と「同じ格」に見える
- プロキシキャッシュが画面最上段に来ない
- 視線導線が 1 本（上 → 下 → 右下 CTA で完結）
- ⓘ icon の視覚ノイズが解消

---

## §10 改訂履歴

- 2026-04-19 初版 — 4 製品研究結果から導出、Phase 2 成果物として起票
