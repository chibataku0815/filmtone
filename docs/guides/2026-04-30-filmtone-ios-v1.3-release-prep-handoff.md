# Filmtone iOS v1.3 — Release Prep Handoff

- **作成日**: 2026-04-30 JST
- **目的**: 次チャットで「変更点確認 → リリース」を一気通貫で実行するための入口
- **対象 repo**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- **iOS app**: `apps/capacitor-film-lab-ios`
- **入力 handoff**: `docs/guides/2026-04-30-filmtone-ios-v1.3-built-in-pack-camera-profiles-handoff.md`（実装計画 + Phase A〜D 着手時点の handoff）

---

## 0. 最重要方針

- 本質優先 / 外殻最小。判断 cost を細切れに払わない（CLAUDE.md `feedback_minimize_decision_cost`）。
- 保守的ヘッジは取らない、プロダクト品質を最優先。
- 設計分岐 / リリース判断 / Phase I bump タイミングは `mcp__sequential-thinking` で考える。
- handoff は鵜呑みにしない（CLAUDE.md `feedback_verify_before_quoting_handoff`）。引用前に live code / `git log` / truth script で再確認。
- 不明点は記憶ベースで断言せず、`gemini-search` または `WebSearch` で確認。

---

## 1. Status snapshot (verified at handoff time)

`bash /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh` を必ず再実行すること。2026-04-30 JST 時点：

| 項目 | 値 |
|---|---|
| Public App Store | `1.1` (`currentVersionReleaseDate 2026-04-26`) |
| Local Xcode `MARKETING_VERSION` | **`1.2`**（v1.3 bump はまだ — Phase I で実行） |
| Local Xcode `CURRENT_PROJECT_VERSION` | `1` |
| Working branch | `feat/filmtone-ios-built-in-look-pack` |
| Branch HEAD | `7e7917f3` |
| Ahead of `main` | **14 commits**（v1.3 lane 全部 + ナレッジ 1） |
| Dirty tracked files | none |
| Untracked | DaVinci spike handoff 3 件（別作業所有、触らない）+ この handoff doc + 既存 handoff doc |

**Branch は未マージ・未プッシュ**。next chat の判断点：(1) main にマージするか、(2) PR 経由か、(3) Phase I 後にまとめてマージするか。

---

## 2. v1.3 で ship する変更点（本質サマリ）

3 並走 lane の現状：

### Item 3 — Library + Saved Looks  ✅ shipped to local main (pre-session)
`ced4c215`. v1.3 entry schema = 2、UUID dedup + 200 MB quota、Saved Looks の apply path、Recent strip、Save current Look。

### Item 2 — Built-in Filmtone Look Pack  ✅ Phase A〜E shipped (this session + prior)
- Phase A〜D（pre-session）: `bundled` / `immutable` / `bundledSlug` schema、5 built-in Looks（フィルムトーン / クリーンベース / アンバーグロー / ソフトブルー / ナイトソフト）、library merge、UI chip + FILMTONE badge。
- **Phase E（this session, `b227d118`）**: sidecar に `savedLook` block 新規。built-in 適用時は `bundled: true` + `bundledSlug` を populate、user look 時は省略（encodeIfPresent）。`appliedSavedLook` を facade chain 経由で配線（DTO ではなく iOS-side state、理由: `.claude/knowledge/patterns/2026-04-30-ios-state-vs-wire-dto.md`）。

### Camera Profiles — Source Profile Catalog  ✅ Phase A〜G shipped (this session)
PeekLut 差別化の中核。

- **Phase A**（`490c336c`）: `CameraProfileSelection` / `SourceProfileCurve` / `SourceProfileImpl` / `CameraProfileCatalogEntry`、`FilmtoneProjectState.cameraProfile = .auto` 既定。Profile.version は 4 のまま。
- **Phase B-1**（`7382e3bd`）: `filmtoneSdrShoulder` + `rec709Encode` を `FilmtoneSourceProfileMath` namespace に SSOT 移行（no-behavior-change refactor）。
- **Phase B-2/3**（`7bbddc8c`）: V-Log decoder + V-Gamut→Rec.709 matrix + 33³ cube。Python (colour-science BSD-3-Clause) で fixture 生成、4096pt linearization + 24-patch Macbeth ΔE2000 + full-frame 8-bit drift gate。**accuracy = 0.000 across all metrics**。
- **Phase C**（`88943855`）: 同形で S-Log3 + S-Gamut3.Cine。**0.000**。
- **Phase D**（`05a5b0e7`）: `FilmtoneSourceProfileCatalog` 5 entries（Apple Log / Apple Log 2 / V-Log / S-Log3 / Rec.709）。`FilmtoneStrings.builtInSourceProfileName(for:)` ヘルパー。
- **Phase E**（`5dd29086`）: `makeActiveInputLut(for:probe:)` で `.auto` / `.builtIn` / `.userImport` 分岐。33³ cube は NSCache（~575 KB / curve）。`cameraProfile` は facade chain 経由（DTO 非搭載）。
- **Phase F**（`ec11b1ed`）: `FilmtoneRootView.cameraProfileCard` Menu に Auto + 5 catalog + Import 列挙。`applyCameraProfile`、D-CP4 retention rule（V-Log / S-Log3 / Rec.709 sticky、Apple Log mismatch reset to `.auto`）。
- **Phase G**（`3f2f8f7c`）: sidecar に `cameraProfile` block 新規。selectionKind / catalogId / curve / impl / resolvedFromAutoVia の stringly-typed 5 field。auto 解決の証跡を残す。

### ナレッジ
- `.claude/knowledge/patterns/2026-04-30-source-profile-fixture-pipeline.md` — v1.4 で curve を増やすときの完全手順
- `.claude/knowledge/patterns/2026-04-30-ios-state-vs-wire-dto.md` — DTO vs facade chain 判断フロー

---

## 3. v1.3 で ship しないもの

| 領域 | 状態 | 取り扱い |
|---|---|---|
| Item 2 Phase F (unit tests) | 未実装 | Optional polish。v1.3 ship gate ではない。v1.4 候補。 |
| Item 2 Phase G (snapshot tests) | 未実装 | Optional polish。Phase H と同じ。 |
| Item 2 Phase H (docs cleanup) | 未実装 | **ship 直前に実行**。§5 を参照。Camera Profiles Phase I (docs) と coordinate。 |
| Item 2 Phase I (release rail bump 1.2→1.3) | 未実装 | **v1.2 ASC closure 後**にトリガー。§6 を参照。 |
| Camera Profiles Phase H (snapshot tests) | 未実装 | 見送り（v1.3 ship gate ではない）。 |
| Camera Profiles Phase I (docs) | 未実装 | Item 2 Phase H と同時実行。 |
| Camera Profiles Phase J (release rail) | 未実装 | Item 2 Phase I に統合。 |
| DaVinci connect package spike 完成 | 別 worktree | `feature/filmtone-davinci-connect-package @ 63622a8d`。v1.3 ship 対象外。 |
| Nikon N-Log / Canon Log 3 / BMD Film Gen 5 / ARRI LogC4 | 未着手 | v1.4 候補。`.claude/knowledge/patterns/2026-04-30-source-profile-fixture-pipeline.md` 参照。 |
| Bundled `.cube` (`SourceProfileImpl.bundledCube`) | スキーマ slot のみ | v1.3 catalog は使わない。v1.4+ 候補。 |

---

## 4. Pre-ship verification checklist

next chat で release 着手前に走らせる canonical 順序：

```sh
# 0. truth re-confirm
bash /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh

cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios

# 1. TS / web 層
bun run build

# 2. Swift contract gate（V-Log / S-Log3 accuracy 含む）
bun run verify:swift-contract
# 期待: 全 7 件 + V-Log/S-Log3 が "max = 0.000" で pass

# 3. Production iOS build
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
# 期待: ** BUILD SUCCEEDED **
```

すべて green でなければ release に進まない。stale-cache で undefined symbols が出たら `xcodebuild ... clean` → rebuild。

---

## 5. Phase H (docs cleanup) — ship 直前タスク

Item 2 Phase H + Camera Profiles Phase I を**同時に**実行する。

### 修正ファイル

1. `apps/capacitor-film-lab-ios/src/presets/luts/README.md` — 「v1.3 ships zero bundled `.cube`. Camera profiles handled via native Apple Log/Apple Log 2 detection (`HdrPreparationPolicyDeriver`) + V-Log/S-Log3 synthesized math (`FilmtoneSourceProfileMath`) + Rec.709 default. Built-in Looks are params-only via `FilmtoneBuiltInCatalog.swift`. v1.4 may revisit bundled `.cube` paths pending licensing.」に書き換え。

2. `apps/capacitor-film-lab-ios/src/presets/signature.ts` — `SIGNATURE_PRESET_BUNDLE_NOTE` を `FilmtoneBuiltInCatalog` 参照に。`SIGNATURE_LUT_PLAN.bundledRelPath: null` 維持。

3. `apps/capacitor-film-lab-ios/CLAUDE.md` — §13 「Built-in Catalog (v1.3+)」追加。`FilmtoneBuiltInCatalog.swift` + `FilmtoneSourceProfileCatalog.swift` ポインタ、canonical UUID 表（FB1A namespace）、immutability rule、UserDefaults favorites key、Camera Profile catalog id 形式（`built-in:source-profile.<slug>`）。**30 行以内に収める**（CLAUDE.md は harness budget）。

4. `apps/capacitor-film-lab-ios/fastlane/metadata/ja/release_notes.txt`：

```
v1.3 では、起動直後から Filmtone のトーンを選べるようにしました。Look には Filmtone Signature を含む 5 種類の組み込みフィルムルックを追加し、各 Look は強さ 0–100% で調整できます。インポートした .cube LUT はライブラリで再利用でき、現在のグレードを Look として保存して、別の素材に同じトーンを当てられます。Camera Profile では Apple Log / Apple Log 2 の自動検出に加えて、Panasonic V-Log と Sony S-Log3 を選択できるようになりました。
```

5. `apps/capacitor-film-lab-ios/fastlane/metadata/en-US/release_notes.txt`:

```
v1.3 makes Filmtone usable from first launch. Five built-in Filmtone Looks — including Filmtone Signature — are available immediately, each with 0–100% intensity. Imported .cube LUTs are reusable from the library, and you can save the current grade as a Look to apply the same tone to another clip. The Camera Profile picker now adds Panasonic V-Log and Sony S-Log3 alongside the existing Apple Log / Apple Log 2 auto-detection.
```

### Vocabulary gate（リリース copy 必須）

- **JP**: `短尺動画` 禁止。`動画` を使う。
- **EN**: `short-form video` / `short-form clips` / `short clips` 禁止。`video` / `videos` / `footage` / `clip` を使う。
- App Store description.txt は無変更（v1.2 + cap）。
- Filmtone Connect for DaVinci の non-claim ガード（`docs/filmtone/ios/filmtone-connect-davinci-overall-plan-2026-04-30-jst.md` §6 Gate E）：「complete recreation」「DaVinci replacement」「all Filmtone effects editable in Resolve」を release notes に書かない（今は問題なし、`feature/filmtone-davinci-connect-package` ブランチ向け）。

---

## 6. Phase I (release rail) — version bump + archive

**前提**: v1.2 ASC submit lane が closure 済みであること（main の `cc01bf52` が ASC で公開フェーズに到達、または超過 lane として明示破棄）。closure 前に v1.3 を bump すると ASC で v1.2 と衝突する。

### 6.1 Xcode build settings 更新

`apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`：

- `MARKETING_VERSION = 1.2;` → `MARKETING_VERSION = 1.3;`（Debug + Release 両方）
- `CURRENT_PROJECT_VERSION = 1;` → `CURRENT_PROJECT_VERSION = 2;`（v1.3 build 1 として）

**Info.plist は手で書き換えない**（CLAUDE.md §2: build settings から注入される）。

`FilmtoneExportActivity` ターゲットの version も同期確認（`apps/capacitor-film-lab-ios/RELEASE.md` checklist）。

### 6.2 Branch merge 戦略

選択肢（next chat で決定）:

1. **直マージ + push**（CLAUDE.md `feedback_minimize_decision_cost` 観点で最速）。`main` の保護ガードに当たる場合は `.claude/settings.local.json` に Bash permission を追加するか、ユーザーが `!` プレフィックスで実行。
2. **PR 経由**（review path）。`gh pr create` で v1.3 lane 全体を PR 化、ユーザー承認後 squash/merge。
3. **Phase I 含めて 1 commit 追加 → 直マージ**。bump commit を branch tip に積んでから main へ。

**現セッションでは main への merge は permission ガードでブロックされた**。next chat で permission rule を追加するか、user 自身で実行。

### 6.3 Archive + TestFlight + ASC

`apps/capacitor-film-lab-ios/RELEASE.md` のリリース手順に従う：

```sh
cd apps/capacitor-film-lab-ios
bun run release:archive
IPA_PATH=build/fastlane/Filmtone.ipa bun run release:beta
# TestFlight で 1 端末以上で smoke
IPA_PATH=build/fastlane/Filmtone.ipa REVIEW_PHONE='+81-...' bun run release:appstore
```

ASC submit 前 smoke：
- iPhone 17 Pro Max iOS 26.2 (UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`) で実機 install
- Built-in Look chip strip に FILMTONE badge 5 件描画
- Camera Profile picker で V-Log / S-Log3 / Rec.709 が選択可能、選択時の preview 視覚的に妥当
- Apple Log 素材で Auto → "Auto -> Apple Log detected" 表示
- export sidecar に `savedLook` + `cameraProfile` block が出る（Files で .json 確認）

---

## 7. Risks / known limitations

| Risk | Status |
|---|---|
| Apple Log 2 が Rec.2020-matrix-as-approximation で動く | **Documented known limitation**。CD signed off via AskUserQuestion 2026-04-30。`apps/capacitor-film-lab-ios/docs/source-profile-math/apple-log-2.md` 未作成（v1.3 出荷前に作成推奨だが ship gate ではない）。v1.4 で AVFoundation native gamut info で refine。 |
| `feature/filmtone-davinci-connect-package @ 63622a8d` (DaVinci spike) が `packageFileUris` の完全配線を持つ | v1.3 lane の `b25c08d8` precursor fix が build を unblock しただけ。spike が main に入る前に v1.3 が land すると、DaVinci spike を rebase する必要が出る。merge 順を意識。 |
| Synthesized math drift（V-Log / S-Log3） | accuracy fixture が hard gate。`max = 0.000` を維持していれば問題なし。spec 改訂時は fixture を再生成して PR 同梱。 |
| User が V-Log 素材に S-Log3 を選択する誤操作 | UI 露出 + reversible。silent auto-detect は意図的に入れていない（CLAUDE.md `feedback_no_fallback_bug_hotbed`）。 |
| Snapshot test 端末固定 (iPhone 17 Pro Max iOS 26.2 UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`) | fastlane `screenshots` lane が決め打ち。fallback / runtime discovery 禁止。 |
| Sidecar 8KB cap | 既存 ~3KB、`savedLook` + `cameraProfile` 両 block 追加でも余裕。contract test が cap 検証中。 |

---

## 8. Hard constraints (do NOT violate)

- `Profile.version` = `4`（無変更）
- Sidecar V1 schema 維持（schemaVersion bump なし、追加は additive optional only）
- iOS preset names locked: `["reset", "iphone", "softBlue", "amberGlow"]`（`packages/film-lab-core/src/ios-preset-overrides.ts:10`）
- 新 `.swift` ファイル追加時は pbxproj 4 セクション全部に登録（`grep -c <ファイル名> ios/App/App.xcodeproj/project.pbxproj` ≥ 4）
- Custom Codable は extension に書く（synthesized memberwise init 維持）
- ASC 関連 env var (`ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_CONTENT` or `ASC_KEY_PATH`) はコミット禁止
- DaVinci 3 untracked handoff docs（`docs/filmtone/ios/filmtone-connect-*`）を commit / move / delete しない
- `--no-verify` / `--no-gpg-sign` 禁止（user 明示承認時のみ）
- Push は明示承認後のみ
- Vocabulary gate: JP `短尺動画` 禁止 / EN `short-form video` 禁止

---

## 9. Next-chat prompt（このまま貼る）

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/guides/2026-04-30-filmtone-ios-v1.3-release-prep-handoff.md

上記 release-prep handoff を入口に、Filmtone iOS v1.3 のリリース直前作業（変更点確認 → Phase H docs cleanup → Phase I version bump → archive → TestFlight → ASC submit）を実行してください。

最重要方針:
- 本質の進行を最優先にしてください。
- 外殻、過剰 QA、装飾、過剰 i18n、保守的な v1.4 持ち越し提案は不要です。
- 保守的なヘッジではなく、プロダクト品質を最優先する判断を取ってください。
- 設計分岐、リリース判断、merge タイミングは sequential-thinking で考えてください。
- 不明点は記憶ベースで断言せず、gemini-search または WebSearch で確認してください。
- 並列で走らせられる独立操作はまとめて invoke してください。
- 既存 dirty / untracked files (DaVinci 3 docs) は触らないでください。

まず以下を実行:

bash /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
git log --oneline main..feat/filmtone-ios-built-in-look-pack
cd apps/capacitor-film-lab-ios
bun run verify:swift-contract
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
bun run build

その後、以下の順で作業:

1. 変更点を `docs/guides/2026-04-30-filmtone-ios-v1.3-release-prep-handoff.md` §2 と git log を突き合わせて確認・要約報告。Apple Log 2 known limitation を含む §7 risks も明示。

2. user に release 着手の承認を得る。

3. v1.2 ASC closure 状態を check-filmtone-ios-truth.sh + ASC で確認。closure 前なら停止して user 判断を仰ぐ。closure 後なら Phase H + Phase I を実行:
   - apps/capacitor-film-lab-ios/src/presets/luts/README.md 書き換え
   - apps/capacitor-film-lab-ios/src/presets/signature.ts 更新
   - apps/capacitor-film-lab-ios/CLAUDE.md §13 追加（30 行以内）
   - apps/capacitor-film-lab-ios/fastlane/metadata/ja/release_notes.txt 更新
   - apps/capacitor-film-lab-ios/fastlane/metadata/en-US/release_notes.txt 更新
   - Vocabulary gate: 短尺動画 / short-form video 禁止
   - MARKETING_VERSION 1.2 → 1.3
   - CURRENT_PROJECT_VERSION 1 → 2
   - FilmtoneExportActivity version 同期

4. feat/filmtone-ios-built-in-look-pack を main にマージ。permission ガードに当たる場合は user に判断を仰ぐ（直マージ vs PR 経由 vs permission rule 追加）。

5. Phase H + Phase I の commit を済ませた後 release rail:
   bun run release:archive
   IPA_PATH=build/fastlane/Filmtone.ipa bun run release:beta
   IPA_PATH=build/fastlane/Filmtone.ipa REVIEW_PHONE='+81-...' bun run release:appstore

6. Smoke verification on iPhone 17 Pro Max iOS 26.2 (UDID D3011FE4-52CA-4B7F-B181-A55D9998E192):
   - 5 built-in Looks render with FILMTONE badge
   - Camera Profile picker shows Auto + Apple Log + Apple Log 2 + V-Log + S-Log3 + Rec.709 + Import
   - Sidecar JSON contains savedLook + cameraProfile blocks (read via Files share)

7. ASC submit + 結果を user に報告。

時間がかかってもよいので正確に推論してください。
```

---

## 10. 完了基準（このセッションは done）

- ✅ Item 2 Phase E + Camera Profiles Phase A〜G の 9 commits land
- ✅ feat/filmtone-ios-built-in-look-pack ブランチ build green、accuracy gate green
- ✅ ナレッジ 2 件 commit (`7e7917f3`)
- ✅ release-prep handoff 作成（this doc）+ 既存 v1.3 build handoff land
- 未: main merge（next chat で実行）
- 未: Phase H docs cleanup（next chat で実行）
- 未: Phase I version bump（v1.2 closure 後）
- 未: archive / TestFlight / ASC submit
