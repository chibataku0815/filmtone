# Phase 2 C3 baseline-C populate 着手 — 次 chat 用 最高精度プロンプト

Date: 2026-05-03 JST late evening

このファイルは **次 chat に paste する単独 prompt**。下の `---PROMPT BEGIN---`
〜 `---PROMPT END---` 内の本文をそのまま新規 chat セッションに貼る。

---PROMPT BEGIN---

このリポは Filmtone (forestone film-lab 系プロダクト)。Phase 0 (Skeleton) +
Phase 1a (Open + Preview precondition) + Phase 1b (preset → grade → still
export → sidecar) + Phase 1c (動画 vertical slice — open .mov/.mp4 →
midpoint preview → H.264 mp4 export → sidecar) + **Phase 2 C1 (SourceColor
DTO graph + factory) + C2 (AVFoundation modern async migration) + C3 truth
gate scaffold (iOS↔macOS canonical 直接 PSNR harness)** が完了。Phase 0+1a
は commit `398743c` で landed、Phase 1b + 1c + Phase 2 (C1+C2+C3 scaffold)
は前 chat 完了時点で **uncommitted** だが user がその後 commit した可能性
あり (要確認)。次は **Phase 2 C3 baseline-C populate** (user iOS Simulator
workflow で 4 preset × 10 image = 40 still cell を populate) を進めたい。

作業 worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
branch: `feature/native-desktop-plan`

並行 lane (重要):
- Desktop Look Unification は branch `feature/desktop-look-unification` 上で
  Phase A `1f99d68` + Phase B `fd9ddd2` 着地、**main 未 merge** (前 chat 確認
  時点)。Phase 2 C3 chat 開始時に再 grep。Native ユーザー配布前 (Phase 5
  release rail 切替前) に dual emit (Case A) 化が release blocker。
- iOS v1.5 Metal optics lane は **無触** (project_v15_metal_optics_lane)。
  C3 案 C は **iOS v1.2 public** を canonical 真値とする。

最初に必ず以下を順番に読んで前 chat の文脈を完全復元してから作業に入る:

1. `docs/filmtone/desktop/filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md`
   ← Phase 2 C1+C2+C3 scaffold 完了 master handoff (canonical、self-contained
   約 800 行)。Phase 0/1a/1b/1c/2 全議論・採択・実装・検証・残タスク・
   commit 戦略・次 chat work・design 判断・採択しなかった案・Critical
   Invariants 全 12 項目 を 1 本に吸収。skim 禁止、§0 から §18 まで通読。

2. `apps/desktop-film-lab-batch/test/golden/baseline-C/README.md`
   ← C3 baseline-C populate の手順書 (iOS Simulator workflow + 実機 1 回確定の
   hybrid 戦略、`xcrun simctl addmedia` / `get_app_container` の具体コマンド
   含む)。

3. `docs/filmtone/desktop/filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md`
   ← Phase 1c completion (歴史記録、master handoff §5.6 に吸収済だが詳細
   verify 数値が必要なら参照)。

4. `CLAUDE.md` (worktree root) — project rules
5. `apps/capacitor-film-lab-ios/CLAUDE.md` — iOS 不変条件 (223 行、C3 で iOS
   pbxproj 触らない根拠)

6. 全体計画書 split docs (前 chat で Phase 2 C1+C2+C3 scaffold 反映済):
   - `docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`  ← parent index
   - `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/01-current-state-and-decision.md`  ← Phase 2 C1+C2+C3 scaffold COMPLETE 反映済
   - `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/02-target-architecture-and-contracts.md`  ← Responsibility Boundaries
   - `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/03-migration-and-concurrent-lanes.md`  ← Look Unification 状況 + dual emit release blocker
   - `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md`  ← Phase 2 sub-scope (C1-C7) 着地状況
   - `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/06-quality-gates-risks.md`  ← AVFoundation deprecation RESOLVED / Swift 6 concurrency RESOLVED / baseline-C scaffold landed の更新済

読み終わったら以下を実行して前 chat の状態を sanity check:

    cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

    # (1) commit 状態確認
    git log --oneline -5
    # expect: 398743c が HEAD、その上に Phase 1b+1c+2 の bundle commit (user が前 chat 後 commit 済の場合)
    #         または 398743c のまま + dirty (commit 未の場合)

    git status
    # 前 chat 終端の dirty 状態は master handoff §11 に list 済 (commit 後なら clean のはず)

    # (2) 不変条件 sanity
    bun run generate:swift -- --check                        # exit 0 (drift 0)
    diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
            apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
                                                              # no output (identical)
    git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/ packages/film-lab-core/src/
                                                              # clean

    # (3) build + parity (本 chat の起点となる baseline)
    bun run verify:macos                                      # ** BUILD SUCCEEDED **
    bun run scripts/golden-parity-macos.ts --preset reset     # ∞ dB / 13.69dB
    bun run scripts/golden-parity-ios-vs-macos.ts --preset reset
                                                              # 10 PENDING (baseline-C 未populate なら)

    # (4) Look Unification main 着地状況確認 (Case A/B 判定)
    cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
    git log --oneline | grep -iE "look unification|baselook" | head
    grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
    grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
    # 着地済 (BASE_LOOKS export あり) → Case A dual emit に切替検討
    # 未着地 (BASE_LOOKS export なし) → Case B 継続

最初に user に確認すること:

(a) **Phase 1b + 1c + Phase 2 C1+C2+C3 scaffold の commit 状況** (`git log` で
    確認、未 commit なら master handoff §14 推奨 (Bundle 1: Phase 1b+1c /
    Bundle 2: Phase 2 C1+C2+C3 scaffold) で進めてよいか、それとも 1 bundle に
    まとめるか / 3 bundle に分けるか)。GUI smoke が user 側で済んでいるかも
    同時に確認 (PreviewSurface が Phase 2 C2 で Coordinator-based Task に
    変わったので、preset 切替時の前 Task cancel が効いているかが新観察ポイント)。

(b) **C3 baseline-C populate 着手順** — master handoff §15.1 推奨は
    (i) iOS Simulator boot + Filmtone iOS app v1.2 public install →
    (ii) `xcrun simctl addmedia` で 10 source PNG を Photos library に push →
    (iii) iOS app で各 (image, preset) を export → Files → 容器抽出 →
    (iv) `baseline-C/<preset>/<image>.png` 配置 →
    (v) `golden-parity-ios-vs-macos.ts --preset <name>` で各セル確認 の順。
    populate を 4 preset × 10 image 全 40 cell を 1 chat 内で進めるか、
    まず 1 preset (reset = ∞ dB 期待) で workflow 確立 → 残 3 preset を
    別途 populate するか確認。

(c) **C3 結果次第の Phase 2 残 chunk 優先付け** — master handoff §15.3 表に従い:
    全セル PASS → C7 (IOSurface perf bench) /
    一部 FAIL × optical 関連 → C5 (OpticalFilters main 着地待ち + 統合) /
    一部 FAIL × color science 関連 → 案 C step (3) WGSL→Metal port /
    Look Unification main merge 観測 → sidecar dual emit (Case A) 切替 別 chunk /
    で進める方針確認。**C6 SPM 化は急がない方針維持** (chunk 着手時 user 確定)。

絶対に守る invariants (master handoff §6 / §13、§5.7.2 採択判断 全 14 件):

- iOS Xcode project / Electron desktop / iOS pbxproj は **編集禁止**
  (C3 で UI 自動化を退ける根拠、master §6 invariant #1/#2)
- packages/film-lab-{renderer,smart-look}/dist/ track 維持
- 生成 Swift 手編集禁止、iOS↔macOS Phase0Generated bit-identical
- `Domain/Phase0Types.swift` field 順 / 名前不変 (Phase 2 C1 で
  `Domain/SourceColorTypes.swift` を別 file 追加、既存は無触)
- bun mandatory、git は user 実行
- 用語: 動画 / video / Look
- handoff 引用前に現行 surface で live/frozen 確認
- Responsibility Boundaries 遵守 (UI / State / Domain / Color / Export /
  Media / SharedGenerated)
- Sidecar additive only (`sourceKind` Phase 1c / `sourceInterpretation` Phase 2 C1)
- C3 案 C は **iOS v1.2 public** を canonical 真値、v1.5 Metal optics lane
  は無触

設計判断は `mcp__sequential-thinking` で考える。不確かな API
(`xcrun simctl` のオプション / iOS app の export save 先 / CGImageSource
の HEIC HDR 検出) は `gemini-search` → `WebSearch` で確認。

完了したら:

(i) 5 行サマリー (前 chat 終端の状態 / 本 chat の deliverable / Look
    Unification 着地状況 / baseline-C populate 進捗 / 残 risks)

(ii) (a)(b)(c) を user に確認

(iii) baseline-C populate 着手前に Phase 1b+1c+2(C1+C2+C3 scaffold) が
      commit 済か再確認 (要なら user に commit 依頼してから着手)。populate
      は user iOS Simulator 操作が必要なので、commit 完了後 → user に Sim
      workflow 開始を依頼 → user が cell ごとに baseline-C/ 配下に配置 →
      claude が `golden-parity-ios-vs-macos.ts` を回して結果報告、の往復で
      進める。

---

本質の進行を最優先

保守的な意見は優先せずにプロダクトの品質を最優先してください

思考すべきところは必ず sequential-thinking で考えてください
わからないことがある場合は、検索して調査・質問してください、検索は gemini か web search を使用しましょう

For maximum efficiency, whenever you need to perform multiple independent operations,
invoke all relevant tools simultaneously rather than sequentially.

時間がかかってもいいので正確に推論してください。こちらの思考力を考慮せず、計算資源を
最大限利用してください。

---PROMPT END---

## 使用方法

1. 上の `---PROMPT BEGIN---` の **次の行から** `---PROMPT END---` の **前の行
   まで** を選択してコピー
2. 新規 Claude Code chat を開く (worktree 内で `claude` 実行、または既存 chat
   で `/clear` 後)
3. paste して送信
4. claude が:
   - master handoff doc を §0 から §18 通読
   - baseline-C README 通読
   - sanity check 4 ステップ実行
   - 5 行サマリーと (a)(b)(c) 確認を返す
5. user が (a)(b)(c) に回答 → claude が着手

## 補足 (この prompt の設計根拠)

- **長さ**: ~150 行。前 chat の Phase 2 着手 prompt (~80 行) より長い理由は
  Phase 2 C1+C2+C3 scaffold が Phase 1c より複雑な状態 (uncommitted scope が
  3 bundle 分、user side workflow (iOS Sim) が必要) を反映するため
- **読書順**: master handoff を最優先にした (Phase 1c 着手 prompt と同じ pattern、
  self-contained 1 本で復元できる原則)
- **sanity check**: 4 ステップ並列可能 (commit 状況 / 不変条件 / build / Look
  Unification grep)
- **(a)(b)(c) 構造**: 前 chat 着手 prompt と同 pattern で user が判断する
  形を維持
- **invariants 列挙**: master handoff §6 + §13 (採択判断) を要約、Phase 2 で
  追加された Sidecar additive `sourceInterpretation` / iOS v1.2 public canonical
  を明記
- **完了報告 format**: 5 行サマリー + (a)(b)(c) 確認 + (iii) commit 確認 の
  3 段階 (Phase 1c 着手 prompt と同じ ritual)
