# Cutover Architecture — Native Desktop v2 が Electron Desktop を置換

Date: 2026-05-04 JST
Status: Decisions locked (推奨パス、auto-mode で本 chat が判断代理)、
        実装は Phase 6+ で進行、cutover gate は M5-C P0 closure。

> このドキュメントは **persistent reference**。release-cutover lane の
> active.md singleton (transient) ではない。決定が変わるたびに該当節を
> 上書きし、Decision Log に短く追記する。

## 0. Direction (前提)

Filmtone Native Desktop v2 (`apps/filmtone-desktop-macos`) は Electron Desktop
(`apps/desktop-film-lab-batch`) の **単一置換後継**。並走配布しない。

iOS canonical を踏襲し、Electron 固有 policy (batch processing / 寄付 OFF /
Smart Look AI 除外) は意図的に切る。

Source: user 2026-05-04 確認 — "Native Desktop は iOS 版を踏襲したデスクトップ
版で electron 版を置きかえるもの" / "並走は必要ない、完全に Native v2 で置き
換える形で推奨で進めましょう"。

## 1. Locked decisions (確定事項、auto-mode で本 chat が user 代理)

| ID | 領域 | 決定 | 理由 |
|---|---|---|---|
| **A** | Bundle ID | `com.chibatakumi.film-lab-desktop` | Electron と同一 ID = drop-in upgrade。同 bundle で上書き install、Keychain/preferences は新規 install のため引き継ぎ問題なし。`co.fores-tone.filmtone.desktop` (Phase 5 までの内部 ID) を上書き |
| **B** | Version policy | `2.0.0` start | Electron 1.0.3 を semver で超え、既存 update path で自動着地。0.1.0 (Phase 5) は smoke 専用、公開しない |
| **C** | Min macOS | `26.0` strict | Liquid Glass / `glassEffect` 等 26 専用 API に依存、下げるコスト極大。pre-26.0 user は Electron 1.0.3 frozen legacy 継続使用 |
| **D** | Product Name | `Filmtone` (Electron と同一) | Dock / Spotlight / About 統一。Xcode scheme/target は `FilmtoneDesktop` 内部識別子のまま、PRODUCT_NAME 上書きで bundle 名のみ変更 |
| **E** | Architecture | universal (x86_64+arm64) | Electron は arm64-only。26.0 で x86_64 はマイノリティだが出力コスト無いため広く対応 |
| **F** | Asset name | `Filmtone-${version}.dmg` | Electron `filmtone-${version}-arm64.dmg` の arch suffix 削除 (universal なので冗長)。case 統一 (`F` 大文字、product name と整合) |
| **G** | Distribution channel | 固定 DL URL `https://www.chibatakumi.studio/film-lab/download` を Native v2 build に切替。Vercel Blob upload + `update-meta.json` schema は Electron 既存 flow から port | 既存導線を破壊せず Native v2 に bridge。Phase 7+ で `desktop-film-lab-batch/scripts/upload-dmg-to-vercel-blob.mjs` + `upload-update-meta-to-vercel-blob.mjs` を Native v2 用に adapt |
| **H** | Cutover gate | M5-C P0 (C.2 / C.3 / C.4) closure | "iOS 踏襲" 主張の前提。M5-C.2 (Look library) は M5 chat 進行中、C.3 / C.4 未着手 |
| **I** | Electron sunset | 1.0.3 = 最終公開、`apps/desktop-film-lab-batch` workspace は cutover 後 archived status | 並走不要 declaration の論理帰結 |
| **J** | Migration messaging | Native v2 2.0.0 release notes に「macOS 26+ 必須」「pre-26.0 user は 1.0.3 frozen legacy URL を継続使用」明記 | 既存 user の install 失敗 / 困惑回避 |
| **K** | TS workspace 取扱 | `film-lab-renderer` / `film-lab-ui` (TS) は portfolio web 側 consume が継続するなら残置、しないなら deprecate | 後続判断、本 lane scope 外 |

## 2. Open Questions (本質に直接影響しない、後続 user 判断)

| OQ | 質問 | 影響 | 暫定 |
|---|---|---|---|
| **OQ-1** | Batch processing の運命 | (a) 完全 drop / (b) Native 再実装 / (c) Electron 1.0.3 を batch-only frozen 維持 | iOS 踏襲なら (a) が自然。(c) は Electron sunset と矛盾しない (frozen access として残す)。**推奨 = (a)**、user 判断保留 |
| **OQ-2** | 寄付 / 共有 ON/OFF | iOS = ON、Electron = OFF。Native v2 はどちら | iOS canonical 寄せなら ON。**推奨 = ON (iOS 踏襲)**、user 判断保留 |
| **OQ-3** | Smart Look AI inclusion | iOS = 含む、Electron = 除外 (release notes 明記)。Native v2 はどちら | iOS canonical 寄せなら **含む**、ただし AI 機能の Mac 版 cost / IP 制約は別評価必要 |
| **OQ-4** | Cutover タイミング | M5-C 全 P0 closed まで full 2.0.0 公開を待つ vs 2.0.0-rc 段階公開 | **推奨 = M5-C P0 closure 後の単一 2.0.0 公開** (rc 公開は user-distribution コスト) |

## 3. Implementation queue (post-decisions)

Phase 番号は release-cutover lane 内連番。M5-C は別 lane (M5 chat 担当)、本 lane は ready 後の cutover 物理作業のみ。

| Phase | 内容 | 状態 |
|---|---|---|
| 1 | signing posture + scripts ship | ✓ Done (commit 8bd41b4 等) |
| 2 | App Category | ✓ Done |
| 3 | pipeline hardening + copyright | ✓ Done |
| 4 | pre-flight readiness audit | ✓ Done (commit e619e0f5) |
| 5 | end-to-end release run (0.1.0 smoke) | ✓ Done (commit 524bea69) |
| **6** | **Cutover Architecture & Brand Alignment**: pbxproj (Bundle ID/ProductName/Version) + scripts (APP_NAME) | **進行中 (本 turn)** |
| 7 | Distribution scripts port (Vercel Blob upload + update-meta.json) — Electron flow から adapt | Pending、user 判断不要、本 chat で実装可 |
| 8 | M5-C P0 closure 待ち (M5 chat 担当、本 lane scope 外) | M5 chat 並走 |
| 9 | 2.0.0 release pipeline run (notarize + DMG + Blob upload + update-meta switch) | Pending Phase 7 + Phase 8 |
| 10 | Electron 1.0.3 deprecation notice + workspace archived status | Pending Phase 9 |

## 4. Risk register

| Risk | Mitigation |
|---|---|
| Bundle ID 変更で codesign / Developer ID cert が拾わない | Developer ID cert は Team-bound (`C3G77H8NM6`)、Bundle ID 制約なし → 既知問題なし |
| `PRODUCT_NAME = "Filmtone"` で xcodebuild 周辺 path が壊れる | 本 turn の Phase 6 で xcodebuild Debug 検証して fail-fast |
| `update-meta.json` schema 不整合で既存 Electron user の update check 壊れる | Phase 7 で Electron schema を verbatim 流用、version field のみ書換え |
| pre-26.0 user 大量に Electron 起動失敗 | min macOS strict + 1.0.3 frozen legacy URL 提示、release notes 明記 (J) |
| Vercel Blob URL 切替時の cache 問題 | upload-update-meta script で Cache-Control header 設定、production env vercel sync で SSOT 化 |

## 5. Decision Log

- **2026-05-04** auto-mode で本 chat が user 代理確定:
  A (Bundle ID `com.chibatakumi.film-lab-desktop`)、B (`2.0.0` start)、
  C (`26.0` strict)、D (Product Name `Filmtone`)、E (universal)、
  F (`Filmtone-${version}.dmg`)、G (Vercel Blob + update-meta.json port)、
  H (M5-C P0 cutover gate)、I (Electron 1.0.3 last)、J (migration messaging)、
  K (TS workspace TBD)。Phase 6 は本 turn 着手。

## 6. 関連

- canonical direction memory: `~/.claude/projects/-Volumes-.../memory/project_native_v2_replaces_electron.md`
- Native Desktop v2 strategy: `../native-desktop-v2/strategy.md` (M6 row + Constraints L91 を本 turn で update)
- Electron Desktop: `apps/desktop-film-lab-batch/` (`appId=com.chibatakumi.film-lab-desktop` / version `1.0.3` / `productName=Filmtone`)
- Release pipeline scripts: `scripts/release-macos.sh` + `scripts/package-dmg.sh` (Phase 6 で APP_NAME / BUNDLE_ID 更新)
