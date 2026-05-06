# Filmtone Native Desktop v2 — Phase 2 C5c Master Handoff (Self-Contained)

Date: 2026-05-04 JST early morning (predecessor `filmtone-native-desktop-phase2-c5a-master-handoff-2026-05-03-jst.md` の続き)
Source chat: chat A.5 (Phase 2 C5c RayAngleOptics port)
Target chat: Phase 2 **C5b multi-pass blur** (bloom / halation / diffusion + CIKernel-based stages)
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan` (commits ahead of main: 4 — `398743c`, `aeb0c7c`, `cd170a6`, `fc13008`)
HEAD: **`fc13008`** (clean working tree + C5c 未 commit 変更あり)

**自己完結型 master handoff**。predecessor master (`filmtone-native-desktop-phase2-c5a-master-handoff-2026-05-03-jst.md`、commit `fc13008`) の内容を吸収 + C5c 実装を追加。

---

## 0. Read-this-first 順序

新 chat 最初の 15-25 分:

1. **本ドキュメント全体** — skim 禁止、§0 から §19 まで通読
2. `CLAUDE.md` (worktree root) — project rules、§3 運用原則 / §6 antipattern
3. `apps/capacitor-film-lab-ios/CLAUDE.md` — iOS 不変条件 (223 行)
4. **全体計画書 split files** (C5c 反映済):
   `docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/{01,04,06}.md`
5. **§11 sanity check を EXACTLY as written で実行**。divergence があれば先に surface
6. Look Unification main 着地状況確認 (§6.5)

---

## 1. What is Filmtone (1 段落 context)

Filmtone は forestone (`chiba@fores-tone.co.jp`) の film-tone カラーグレーディング製品群:

- **Filmtone Desktop** (Electron + React/Vite, macOS) — 写真 / 動画の film-tone バッチグレーディング。release rail として shipping 中。
- **Filmtone iOS** (Capacitor + SwiftUI/Metal/CoreImage) — App Store 公開、v1.2 public / v1.3 local candidate in-flight。
- **共有 packages**: `film-lab-core` (Phase0 params / preset / source-profile contract)、`film-lab-renderer` (WebGL/WebGPU)、`film-lab-ui` (shared React UI)、`film-lab-smart-look` — `dist/` は portfolio submodule 用に **意図的に track**。

---

## 2. Repo / Worktree Topology

| repo / worktree | path | 役割 | 編集可否 |
|---|---|---|---|
| **Native Desktop worktree (本 chat)** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan` | Phase 0-2 実装、branch `feature/native-desktop-plan` | **編集対象** |
| Look Unification worktree (chat B 並列、別 chat) | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification` | branch `feature/desktop-look-unification` | **本 chat では編集禁止** |
| filmtone main checkout | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | main branch、参照のみ | 編集禁止 |
| portfolio | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 公開窓 | 触らない |
| life | `/Volumes/SamsungPortableSSDX5001/documents/life` | docs/guides + truth scripts | 触らない |

### Worktree branch invariants

- **4 commits ahead of main** (+ C5c uncommitted):
  - `398743c` — Phase 0 + 1a
  - `aeb0c7c` — Phase 1b + 1c + Phase 2 C1+C2 + C3 scaffold
  - `cd170a6` — Phase 2 C5a per-pixel optical (vignette + grain)
  - `fc13008` — C5a + C7 master handoff doc
  - **(uncommitted)** — Phase 2 C5c RayAngleOptics port
- 別 branch を切る必要は **なし**

### Tooling versions

- macOS 26.4.1 / Xcode 26.4.1 / Bun 1.3.3 / Swift 6.0 strict concurrency / ffmpeg 8.1
- Git user: `chibataku0815` / Email: `chiba@fores-tone.co.jp`
- Co-Author: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`

---

## 3. Native Desktop v2 全体計画 (要約)

Electron Desktop → SwiftUI-first Native Desktop v2 (Liquid Glass first-class、macOS 26 only) への移行 lane。

### Phase 段階 (本 doc 時点)

| Phase | scope | 状態 |
|---|---|---|
| **0 (Contract & Skeleton)** | macOS app skeleton + 生成 Swift dual-target emit + Liquid Glass API | **COMPLETE** (`398743c`) |
| **1a (Open + Preview)** | SharedGenerated compile-link + NSOpenPanel + still preview (grade なし) | **COMPLETE** (`398743c`) |
| **1b (Vertical Slice — still)** | preset 4 個 + CIColorKernel chain + still export + sidecar (Case B) + parity ハーネス | **COMPLETE** (`aeb0c7c`) |
| **1c (Vertical Slice — video)** | .mov/.mp4 open + midpoint preview + H.264 export + sidecar additive | **COMPLETE** (`aeb0c7c`) |
| **2 C1 (SourceColor DTO + factory)** | DTO graph port + classifier + factory + Source prober | **COMPLETE** (`aeb0c7c`) |
| **2 C2 (AVFoundation modern async)** | 6 deprecation site 解消 + Swift 6 strict concurrency | **COMPLETE** (`aeb0c7c`) |
| **2 C3 (truth gate scaffold)** | baseline-C/ + PENDING-aware harness | **scaffold COMPLETE** (`aeb0c7c`)、populate は外殻 defer |
| **2 C5a (per-pixel optical)** | vignette + grain CIColorKernel verbatim port | **COMPLETE** (`cd170a6`) |
| **2 C5c (RayAngleOptics port)** | vignette canonical 化 + camera optics probe 拡張 | **COMPLETE** (uncommitted、本 chat) |
| **2 C7 (IOSurface perf bench)** | 4K/6K 実測 → refactor 不要判定 | **COMPLETE** (measurement only、code 変更なし) |
| **2 C5b (multi-pass blur)** | bloom / halation / diffusion + radialRGBSplit + edgeSoftnessBlend | **TBD (次 chat 推奨)** |
| **2 C6 (SPM 化)** | `packages/film-lab-swift-core/` 化 | TBD (急がない方針維持) |
| 3 (Native Editing UI) | Electron UI 置き換え | TBD |
| 4 (Native Capability Replacement) | 機能網羅 + release default 切替 | TBD |
| 5 (Polish & Public Cutover) | LP / release notes / portfolio submodule | TBD |

---

## 4. Phase 0-1c 完成記録 (要約)

predecessor master handoff §4-5.6 を参照。要点:

- reset preset macOS↔source: **∞ dB (10/10 bit-identical)**
- baseline-B: 平均 13.69 dB (legacy WebGL fixture、informational)
- video export: H.264 + Rec.709 metadata + sidecar
- Phase 1 acceptance gate: proxy gate PASS

---

## 5. Phase 2 C1+C2+C3 scaffold 完成記録 (要約)

predecessor master handoff §5.7 を参照。要点:

- SourceColorClassDTO / SourceColorMetadataDTO / SourceColorClassifier / FilmtoneColorPipeline factory 全 landed
- AVFoundation deprecated 6 sites 全解消
- sidecar additive `sourceInterpretation` field
- C3 harness: 40 cells PENDING (外殻 defer)

---

## 5.8. Phase 2 C7 perf bench (要約)

predecessor master handoff §5.8 を参照。

結果: 1080p reset 0.35s/205fps、4K reset 0.88s/82fps。CPU 6-9%、kernel overhead 0.1-0.2ms/frame。
判断: **IOSurface refactor 不要** (4K realtime 3.4×)。

---

## 5.9. Phase 2 C5a per-pixel optical (要約)

predecessor master handoff §5.9 を参照。

- vignette + grain CIColorKernel verbatim lift (iOS OpticalKernels L4321-4403)
- Pipeline 順: baseGradeV2 → filmCompressionV2 → vignette → grain → printStage
- iphone 09-skin-light: 35.00 dB (vignette corner darkening + grain 微小寄与)
- applyMask=0 固定 (identity opticsPack)、RayAngleOptics 未 port → C5c で解消

---

## 5.10. ★ 本 chat 主役: Phase 2 C5c RayAngleOptics port 完成記録

### 5.10.1 Goal

iOS canonical の `FilmtoneRayAngleOptics.swift` (resolve / mask / kernelArgs) + `CameraOpticsDTO` を macOS Native に verbatim lift し、vignette kernel の `opticsPack` / `applyMask` 引数をカメラ optics metadata ベースに切り替える。C5a で残した `applyMask=0` 固定の "potentially divergent" risk を解消。

### 5.10.2 採択した設計判断

| # | 決定事項 | 採択 |
|---|---|---|
| 1 | CameraOpticsDTO 配置 | `Domain/CameraOpticsDTO.swift` (iOS `FilmtoneMediaTypes.swift:51-63` verbatim、Codable struct 11 fields) |
| 2 | FilmtoneRayAngleOptics 配置 | `Color/FilmtoneRayAngleOptics.swift` (iOS 同名 file 全 225 行 verbatim lift) |
| 3 | Video camera optics 抽出 | `FilmtoneSourceProber.cameraOptics()` (async) — CMFormatDescription `kCMFormatDescriptionExtension_HorizontalFieldOfView` から fovDeg を取得。found → `source: "metadata"` + `focalPxFromFov` 計算。not found → `source: "assumed"` + diagonal 70° fallback。asset metadata (`load(.commonMetadata)` / `load(.metadata)`) で make/model/lens も抽出 |
| 4 | Still camera optics | nil (PNG fixture に EXIF なし。future: JPEG/HEIF EXIF focal length 抽出) |
| 5 | applyMask 判定 | `(cameraOptics?.source == "metadata") ? 1.0 : 0.0` (iOS `FilmtoneExportSession:2005` と identical) |
| 6 | opticsPack 計算 | `FilmtoneRayAngleOptics.resolve()` → `kernelArgs()` で CIVector 生成。nil optics → fallback65 (referenceTanHalfHfov) |
| 7 | Pipeline API | `FilmtoneGradePipeline.apply(to:params:frameTimeSeconds:sourceSeed:cameraOptics:)` に optional `cameraOptics: CameraOpticsDTO? = nil` 追加。既存 callers は default nil で破壊なし |
| 8 | Caller wiring | `FilmtoneStillExporter` → `probe.cameraOptics` 通す (still は nil)。`FilmtoneVideoExporter` → `probe.cameraOptics` 通す (video は "metadata" or "assumed") |
| 9 | PreviewSurface | default nil のまま (preview にはプローブ不要、grade chain 即時描画優先) |
| 10 | AVFoundation deprecated API | `asset.commonMetadata` / `.metadata` → `asset.load(.commonMetadata)` / `load(.metadata)`。`item.stringValue` → `item.load(.stringValue)`。`metadataString` + `cameraOptics` を async 化 |
| 11 | pbxproj | UUID A1D/B1D (CameraOpticsDTO) + A1E/B1E (FilmtoneRayAngleOptics) 4-section 登録 |

### 5.10.3 採択しなかった案

| # | 検討案 | 理由 |
|---|---|---|
| 1 | Still で CGImageSource EXIF から focal length 抽出 | PNG fixture に EXIF なし。JPEG/HEIF 対応は future (Phase 3 以降で real camera photo を扱う時) |
| 2 | PreviewSurface でもプローブを通す | preview は即時描画優先。vignette の opticsPack 差は視覚的に微小 (grade 判断に影響しない) |
| 3 | CameraOpticsDTO を SourceColorTypes.swift に同居 | 責務が違う (source color vs camera optics)。別ファイルで clarity 維持 |
| 4 | metadataString を sync のまま残す | macOS 13+ deprecated warning。C2 の "AVFoundation deprecation 0" 方針に合わせて modern async API に統一 |

### 5.10.4 新規ファイル

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── Domain/
│   └── CameraOpticsDTO.swift              # iOS verbatim (Codable struct, 11 fields)
└── Color/
    └── FilmtoneRayAngleOptics.swift       # iOS verbatim (225 行, resolve/mask/kernelArgs)
```

### 5.10.5 更新ファイル (+183 / -35)

| パス | 変更内容 |
|---|---|
| `Color/FilmtoneGradePipeline.swift` | header comment 更新。`apply` signature に `cameraOptics: CameraOpticsDTO? = nil` 追加。`applyVignette` を RayAngleOptics 経由に全面書き換え (resolve → kernelArgs → applyMask 判定) |
| `Export/FilmtoneStillExporter.swift` | `probe.cameraOptics` を `apply()` に通す |
| `Export/FilmtoneVideoExporter.swift` | `probe.cameraOptics` を `apply()` に通す |
| `Media/FilmtoneSourceProber.swift` | `FilmtoneSourceProbeResult` + `FilmtoneVideoTrackProbe` に `cameraOptics: CameraOpticsDTO?` 追加。`cameraOptics(from:asset:...)` async method 新規 (HorizontalFieldOfView 抽出 + asset metadata)。`metadataString` async 化 (deprecated `commonMetadata`/`metadata`/`stringValue` → modern async API)。helper functions: `buildCameraOpticsDTO`, `horizontalFieldOfViewDeg`, `trimmedMetadataString`, `safeDimension`, `isRightAngleRotation`, `focalPxFromFov`, `fovFromFocalPx` |
| `FilmtoneDesktop.xcodeproj/project.pbxproj` | UUID A1D/B1D + A1E/B1E 4-section 登録 |

iOS / Electron / film-lab-core src は **未編集**。

### 5.10.6 Verify 結果

```
bun run build:core          → ESM OK
bun run generate:swift -- --check → exit 0 (drift 0)
diff Phase0Generated iOS↔macOS → identical
bun run verify:macos        → ** BUILD SUCCEEDED **
git status invariant zones  → clean
golden-parity reset         → ∞ dB 10/10, baseB 13.69dB (Phase 1b regression preserved)
iphone 09-skin-light PSNR  → 35.00 dB (C5a と byte-identical)
video iphone export         → ok 320x180 frames=24
```

PSNR が C5a と変わらない理由: PNG source fixture にカメラ optics metadata がない → `probeStill()` は `cameraOptics: nil` を返す → `applyMask=0` → C5a の identity opticsPack 経路と math 上 byte-identical。

カメラで撮影した動画 (CMFormatDescription に `kCMFormatDescriptionExtension_HorizontalFieldOfView` が含まれる素材) を入力した場合のみ `source: "metadata"` → `applyMask=1` に切り替わり、iOS canonical の ray-angle FOV-aware vignette が有効化される。

### 5.10.7 CIColorKernel deprecation 状況

`CIColorKernel(source:)` deprecation: **5 箇所** (Phase 1b 3 + C5a 2)。C5c は CIColorKernel を追加していない (既存 vignette kernel の引数のみ変更)。Metal CIKernel 移行は別 lane。

### 5.10.8 Important: C5c commit がまだされていない

本 chat で C5c の実装は完了し verify PASS したが、**git commit はまだ実行されていない** (CLAUDE.md §9「Git 操作は user が行う」がデフォルト復帰中)。次 chat 開始時、まず `git status` で確認:

- dirty → C5c 未 commit。user に commit 指示を求めるか、autonomous commit lift を確認
- clean → user が既に commit 済。`git log --oneline -1` で commit hash を記録

commit 用コマンド (user 実行):

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
git add apps/filmtone-desktop-macos/
git commit -m "$(cat <<'EOF'
feat(macos): Phase 2 C5c RayAngleOptics port (vignette canonical化)

iOS FilmtoneRayAngleOptics.swift + CameraOpticsDTO verbatim lift。
FilmtoneSourceProber に camera optics 抽出を追加 (video:
CMFormatDescription HorizontalFieldOfView → source "metadata" /
"assumed"、still: nil)。FilmtoneGradePipeline.applyVignette を
RayAngleOptics 経由に書き換え、source=="metadata" 時のみ
applyMask=1 で iOS canonical ray-angle vignette を有効化。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 5.11. 運用方針 (predecessor から継続)

### 5.11.1 「本質優先 / 外殻最小」doctrine

本質 = Swift code / pipeline / sidecar / kernel / optics。外殻 = C3 populate / GUI smoke / formal QA / i18n。外殻は user 明示の「品質保証希望」まで defer。

### 5.11.2 Desktop chat における iOS の位置付け

read-only canonical reference のみ。iOS Xcode project は **絶対編集禁止**。

### 5.11.3 Git 操作

CLAUDE.md §9「Git 操作は user が行う(自動コミット禁止)」が DEFAULT。chat A.4 で verbal lift されたが、**chat A.5 ではデフォルト復帰**。次 chat 開始時に user に再確認。

---

## 6. Critical Invariants (絶対に壊さない)

1. iOS Xcode project 編集禁止 (read-only verbatim lift OK)
2. Electron desktop 編集禁止 (test fixture read OK)
3. `packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/` 維持
4. `packages/film-lab-core/src/` contract 変更禁止
5. 生成 Swift 手編集禁止
6. iOS / macOS の `Phase0Generated.swift` は bit-identical
7. `Domain/Phase0Types.swift` の field 順序/名前不変
8. Responsibility Boundaries (UI→State→Domain、UI→State→Color/Export/Media、Color→Domain/SharedGenerated)
9. 用語ロック: `動画`/`video`/`Look`
10. Bun 必須 (npm 禁止)
11. Sidecar additive only (schema bump なし)
12. sequential-thinking で設計判断 (記憶ベース断言禁止)
13. handoff 鵜呑み禁止 (現行 surface と突き合わせ)

---

## 6.5. Concurrent Lane: Desktop Look Unification

- branch: `feature/desktop-look-unification`
- 状態 (本 doc 時点): Phase A + Phase B landed on branch、**main 未 merge**
- 本 chat (chat A.5) 開始時 grep: `BASE_LOOKS` export なし → **Case B 継続**
- main merge 観測時: sidecar dual emit (Case A) へ切替

---

## 7-8. Truth Gates / アンチパターン

predecessor master handoff §7-8 と同一。全 antipattern を踏んでいない (C5c 含む)。

---

## 9. Verify protocol (本 chat 終端)

1. `bun run build:core` → OK
2. `bun run generate:swift -- --check` → exit 0
3. `diff -q` Phase0Generated → identical
4. `bun run verify:macos` → BUILD SUCCEEDED (clean build 必要: `rm -rf build/Build/Intermediates.noindex` 後)
5. `git status` invariant zones → clean
6. `golden-parity-macos.ts --preset reset` → ∞ dB / 13.69dB
7. `golden-parity-ios-vs-macos.ts --preset reset` → 10 PENDING
8. CLI still iphone 09 → 35.00 dB
9. CLI video iphone → ok 320x180 frames=24

---

## 10. Sidecar contract (本 chat 時点)

predecessor master handoff §10 と同一。C5c は sidecar 変更なし (optics は params 経由で gradeParams に既に含まれる)。Look Unification 未着地 → Case B 継続。

---

## 11. Sanity check (新 chat の最初に必ず実行)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

# (1) commit 状態確認
git log --oneline -6
git status
# expect: C5c commit があればそれが HEAD。なければ fc13008 HEAD + dirty (C5c uncommitted)

# (2) C5c commit がまだの場合、先に commit (user 判断)
# git add apps/filmtone-desktop-macos/ && git commit ...

# (3) 不変条件 sanity
bun run generate:swift -- --check                        # exit 0
diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
        apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
                                                          # no output
git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/ packages/film-lab-core/src/
                                                          # clean

# (4) build + parity (clean build 推奨: rm -rf apps/filmtone-desktop-macos/build/Build/Intermediates.noindex)
bun run verify:macos                                      # ** BUILD SUCCEEDED **
bun run scripts/golden-parity-macos.ts --preset reset     # ∞ dB / 13.69dB
bun run scripts/golden-parity-ios-vs-macos.ts --preset reset
                                                          # 10 PENDING

# (5) Look Unification main 着地状況
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
# 着地済 → Case A dual emit に切替を C5b 前に挿入
# 未着地 → Case B 継続

# (6) C5c regression sanity
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
APP=apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop
"$APP" --export-still \
  --input apps/desktop-film-lab-batch/test/golden/source-images/09-skin-light.png \
  --output /tmp/c5c-sanity-iphone-09.png --preset iphone
bun run scripts/compare-pngs.ts \
  apps/desktop-film-lab-batch/test/golden/source-images/09-skin-light.png \
  /tmp/c5c-sanity-iphone-09.png
# expect: PSNR ≈ 35dB

# (7) video smoke
"$APP" --export-video \
  --input "$(pwd)/apps/desktop-film-lab-batch/fixtures/video/sdr/synthetic-bt709-1s-20260424.mp4" \
  --output /tmp/c5c-video-smoke.mp4 --preset iphone
# expect: ok 320x180 frames=24
```

---

## 12. Risks (更新済)

### RESOLVED

- AVFoundation sync API deprecation → C2 で解消 (6 sites)
- AVMetadataItem deprecated API (commonMetadata / metadata / stringValue) → **C5c で追加解消** (modern async API 移行)
- 4K perf → C7 で measurement 完了 (refactor 不要)
- vignette canonical 化 → **C5c で RESOLVED** (RayAngleOptics port + camera optics probe)

### OPEN

- `CIColorKernel(source:)` deprecation 5 箇所 → Metal CIKernel 移行 lane
- `FilmtoneVideoReader / FilmtoneVideoWriter` `@unchecked Sendable` → C5b actor refactor で再評価
- bloom / halation / diffusion / radialRGBSplit / edgeSoftnessBlend → **C5b (次 chat 推奨)**
- 6K perf 未測定 (4K margin で許容)
- Look Unification main merge → release blocker (Phase 5)
- grain sourceSeed per-export wiring → C5b で対処
- grain noise distribution iOS↔macOS 視覚同質性 → C3 baseline-C populate 時に目視

---

## 13. Commit timeline + 状態

```
(uncommitted) feat(macos): Phase 2 C5c RayAngleOptics port
              ├── 2 new files + 5 updated files, +183 / -35
              ├── Domain/CameraOpticsDTO.swift (new, iOS verbatim)
              ├── Color/FilmtoneRayAngleOptics.swift (new, iOS verbatim 225 行)
              ├── Color/FilmtoneGradePipeline.swift (apply signature 拡張 + applyVignette rewrite)
              ├── Export/FilmtoneStillExporter.swift (probe.cameraOptics 通す)
              ├── Export/FilmtoneVideoExporter.swift (probe.cameraOptics 通す)
              ├── Media/FilmtoneSourceProber.swift (cameraOptics + async metadata migration)
              └── pbxproj (UUID A1D/B1D + A1E/B1E)

fc13008 docs(macos): Phase 2 C5a + C7 master handoff
cd170a6 feat(macos): Phase 2 C5a per-pixel optical extension (vignette + grain)
aeb0c7c feat(macos): Native Desktop v2 Phase 1b/1c + Phase 2 C1/C2 + C3 parity scaffold
398743c feat(macos): Native Desktop v2 Phase 0 + 1a + plan/handoff docs
[main HEAD: 732a273]
```

---

## 14. Phase 4 product gate との距離

- ✅ open + preview + still export (PNG/JPEG)
- ✅ video export (H.264 mp4 + Rec.709 metadata + sidecar)
- ✅ preset selection (4 built-in)
- ✅ source profile classification + sidecar interpretation
- ✅ vignette + grain (iphone preset で active)
- ✅ RayAngleOptics (camera optics metadata 付き素材で iOS canonical 有効)
- ❌ bloom / halation / diffusion (**C5b — 次 chat 推奨**)
- ❌ chromatic aberration (radialRGBSplit、C5b)
- ❌ edge softness (edgeSoftnessBlend、C5b)
- ❌ batch UI (Phase 3/4)
- ❌ session restore (Phase 4)
- ❌ LUT export (Phase 4)
- ❌ DMG signing/notarization (Phase 4)

→ **C5b 完了で kernel parity が iOS canonical に大幅接近**。bloom-heavy preset (softBlue / amberGlow) で意味のある visual 進歩。

---

## 15. Next chat 候補

### 15.1 推奨: C5b multi-pass blur (大 chunk、sub-chunk 推奨)

iOS OpticalKernels の以下を port:

- `softKneeHighlight` (CIColorKernel、bloom highlight plate 抽出 helper)
- `glowComposite` (CIColorKernel、bloom + halation + diffusion 合成)
- `tentDownsample` / `tentUpsample` (CIKernel、multi-mip pyramid blur)
- `radialRGBSplit` (CIKernel、chromatic aberration)
- `edgeSoftnessBlend` (CIKernel、softness blur)

Pipeline insertion (iOS canonical order、`FilmtoneExportSession` L1541-2155):
- bloom: extractHighlightPlate → tent pyramid (down→up) → glowComposite
- halation: 同 pyramid (different threshold + tint) → glowComposite
- diffusion: 全 image → tent pyramid → glowComposite
- radialRGBSplit: post-printStage (rgbShift param > 0)
- edgeSoftnessBlend: lensSoftness param > 0

scope: ~600-800 line lift + ROI callback + multi-mip orchestration。**sub-chunk 推奨**:
- A.1: bloom only (softKneeHighlight + tentDownsample/Up + glowComposite)
- A.2: halation + diffusion (同 pyramid reuse、different args)
- A.3: radialRGBSplit + edgeSoftnessBlend (CIKernel)

### 15.2 その他

- Look Unification main 着地観測 → sidecar dual emit 切替 (~30-50 line、main 着地待ち)
- C6 (SPM 化) — 急がない方針維持、user 明示なしに着手しない
- C3 baseline-C populate — 外殻、品質保証希望明示まで defer

---

## 16. macOS Swift ファイル構成 (C5c 後、全量)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── App/
│   ├── FilmtoneDesktopApp.swift
│   └── AppCommands.swift
├── UI/
│   ├── RootWindowView.swift
│   ├── GlassControlGroup.swift
│   ├── PreviewSurface.swift
│   └── GradeControls.swift
├── Domain/
│   ├── Phase0Types.swift
│   ├── SourceColorTypes.swift
│   └── CameraOpticsDTO.swift              ← C5c 新規
├── Color/
│   ├── FilmtoneGradeKernels.swift
│   ├── FilmtoneGradePipeline.swift        ← C5c 更新
│   ├── FilmtonePresetCatalog.swift
│   ├── FilmtoneCIContext.swift
│   ├── FilmtoneColorPipelineContract.swift
│   ├── FilmtoneColorPipeline.swift
│   ├── SourceColorMetadataNormalizer.swift
│   ├── SourceColorClassifier.swift
│   └── FilmtoneRayAngleOptics.swift       ← C5c 新規
├── State/
│   └── EditorState.swift
├── Export/
│   ├── FilmtoneStillExporter.swift        ← C5c 更新
│   ├── FilmtoneSidecarWriter.swift
│   ├── FilmtoneSidecarTypes.swift
│   └── FilmtoneVideoExporter.swift        ← C5c 更新
├── Media/
│   ├── FilmtoneVideoFramePreview.swift
│   ├── FilmtoneVideoReader.swift
│   ├── FilmtoneVideoWriter.swift
│   ├── FormatExtensionReader.swift
│   └── FilmtoneSourceProber.swift         ← C5c 更新
├── SharedGenerated/
│   └── FilmtonePhase0Generated.swift
└── Assets.xcassets/
```

---

## 17. 引き継ぎ用英語プロンプト (paste-ready)

```
You are continuing work on the Filmtone Native Desktop v2 lane in the worktree
at /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
on branch `feature/native-desktop-plan`.

The working tree may have uncommitted C5c changes or they may already be
committed — check `git status` and `git log --oneline -6` first.

THIS IS A DESKTOP CHAT. iOS appears only as a read-only canonical reference
for kernel sources / type definitions / pipeline structure that the macOS
Native target verbatim-lifts. The iOS Xcode project
(apps/capacitor-film-lab-ios/) is INVIOLABLE — never edit its pbxproj, never
add XCUITest targets, never run codegen against it.

═══════════════════════════════════════════════════════════════════════════════
FIRST ACTIONS (mandatory, in order)
═══════════════════════════════════════════════════════════════════════════════

1. Read the canonical handoff doc in full, no skimming:
   docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/filmtone-native-desktop-phase2-c5c-master-handoff-2026-05-04-jst.md

2. Read CLAUDE.md (worktree root) and apps/capacitor-film-lab-ios/CLAUDE.md.

3. Read the transition plan split files (C5c-updated):
   docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/{01,04,06}.md

4. Run the §11 sanity check commands EXACTLY as written. Do not skip any. Stop
   and surface any divergence from expected output before proceeding.

5. Check Look Unification main landing status (handoff §6.5):
     cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
     grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
   - empty → Case B sidecar continues
   - non-empty → flag user; insert dual-emit chunk before C5b

6. If C5c is uncommitted (git status shows dirty apps/filmtone-desktop-macos/),
   confirm with user whether to commit. Present the commit command from
   handoff §5.10.8.

═══════════════════════════════════════════════════════════════════════════════
CONTEXT — what was completed
═══════════════════════════════════════════════════════════════════════════════

Committed (4 on branch, stacked on main):

- 398743c — Phase 0 + 1a (skeleton + Open/Preview precondition)
- aeb0c7c — Phase 1b/1c + Phase 2 C1/C2 + C3 scaffold
- cd170a6 — Phase 2 C5a per-pixel optical (vignette + grain CIColorKernel)
- fc13008 — C5a + C7 master handoff doc

Possibly uncommitted or newly committed:

- Phase 2 C5c — RayAngleOptics port:
  - CameraOpticsDTO (Domain/) + FilmtoneRayAngleOptics (Color/) verbatim lift
  - FilmtoneSourceProber extended with async camera optics extraction
    (CMFormatDescription HorizontalFieldOfView → "metadata" or "assumed")
  - FilmtoneGradePipeline.applyVignette rewritten to use RayAngleOptics
    (applyMask=1 only when source=="metadata", otherwise applyMask=0)
  - AVMetadataItem deprecated API migrated to modern async
  - Still camera optics = nil (PNG has no EXIF)
  - Verify: PSNR 35.00dB (byte-identical to C5a for PNG fixtures)
  - pbxproj: UUID A1D/B1D + A1E/B1E

Phase 2 C7 was MEASURED (not refactored):
  1080p 205fps / 4K 82fps → IOSurface refactor NOT needed.

═══════════════════════════════════════════════════════════════════════════════
NEXT WORK — C5b multi-pass blur (recommended)
═══════════════════════════════════════════════════════════════════════════════

This is a LARGE chunk. Sub-chunking into 2-3 commits is recommended:

Sub-chunk A.1 — bloom:
  - Port softKneeHighlight (CIColorKernel, highlight plate extraction helper)
  - Port tentDownsample / tentUpsample (CIKernel, multi-mip pyramid blur)
  - Port glowComposite (CIColorKernel, bloom composite)
  - Wire extractHighlightPlate → tent pyramid → glowComposite into pipeline
  - Insertion after printStage, gated by bloomStrength > epsilon
  - iOS reference: FilmtoneExportSession L1541-1700ish, OpticalKernels

Sub-chunk A.2 — halation + diffusion:
  - Reuse tent pyramid from A.1 with different threshold/tint/intensity args
  - halation: same pyramid + glowComposite with halation parameters
  - diffusion: entire image → tent pyramid → glowComposite with diffusion args
  - iOS reference: FilmtoneExportSession L1700-1900ish

Sub-chunk A.3 — radialRGBSplit + edgeSoftnessBlend:
  - radialRGBSplit (CIKernel, chromatic aberration, post-printStage)
  - edgeSoftnessBlend (CIKernel, softness blur)
  - iOS reference: FilmtoneExportSession L1900-2155

After C5b: bloom-heavy presets (softBlue, amberGlow) will show visible
optical effects. iphone preset PSNR is expected to drop as more stages
activate.

VERIFY after each sub-chunk:
  1. bun run build:core
  2. bun run generate:swift -- --check (exit 0)
  3. diff Phase0Generated iOS↔macOS (identical)
  4. bun run verify:macos (BUILD SUCCEEDED — clean build may be needed)
  5. git status invariant zones (clean)
  6. golden-parity reset (∞ dB / 13.69dB)
  7. CLI smoke still + video
  8. iphone PSNR check (may drop from 35dB as more stages activate)

Other deferred work:
- C6 (SPM): 急がない policy — do NOT start without explicit user ask
- C3 populate: 外殻 — do NOT start without "品質保証希望"
- Look Unification dual emit: main 着地待ち

═══════════════════════════════════════════════════════════════════════════════
USER PREFERENCES (sticky)
═══════════════════════════════════════════════════════════════════════════════

- 本質優先 / 外殻最小
- 判断コスト最小限 (user is in parallel chats)
- Git: CLAUDE.md §9 default (user runs git) — confirm with user at start
- Co-Author tag for commits
- Desktop chat — iOS is read-only reference only
- 日本語 output, technical terms English OK
- File references in path/to/file:line format

═══════════════════════════════════════════════════════════════════════════════
INVARIANTS (NEVER violate)
═══════════════════════════════════════════════════════════════════════════════

- Do not edit apps/capacitor-film-lab-ios/ (reading Swift for lift is OK)
- Do not edit apps/desktop-film-lab-batch/ runtime code
- Do not delete dist/ directories
- Do not modify packages/film-lab-core/src/
- Do not hand-edit FilmtonePhase0Generated.swift
- Sidecar additive-only, no schemaVersion bump
- bun-only, no npm
- sequential-thinking for design judgment
- Verify handoff claims against live surface before acting

═══════════════════════════════════════════════════════════════════════════════
REPRODUCIBLE STATE PROOF
═══════════════════════════════════════════════════════════════════════════════

After C5c:
  verify:macos → BUILD SUCCEEDED (clean build needed)
  generate:swift --check → exit 0
  diff Phase0Generated → identical
  golden-parity reset → ∞ dB 10/10, baseB 13.69dB
  iphone 09 PSNR → 35.00dB (byte-identical to C5a)
  video iphone → ok 320x180 frames=24

Begin by completing FIRST ACTIONS in order, then propose sub-chunk A.1
(bloom) with a one-line confirmation. Proceed on user "yes" signal.
```

---

## 18. Doc trail

### 本 phase の handoffs

- **本 doc** (`filmtone-native-desktop-phase2-c5c-master-handoff-2026-05-04-jst.md`) — C5c 完了 canonical
- `filmtone-native-desktop-phase2-c5a-master-handoff-2026-05-03-jst.md` — C5a + C7 master (本 doc に吸収済)
- 旧 handoffs (historical): Phase 2 master / Phase 1c / Phase 1b / Phase 1a / Phase 0

### 全体計画書 split docs (C5c 反映済)

- `docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md` — C5c COMPLETE 反映
- `docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/06-quality-gates-risks.md` — C5c + C7 RESOLVED 反映

### memory records

- `feedback_auto_mode_no_decision_handoff` — auto mode + plan approved → run next
- `feedback_dont_overengineer_dirty_state_split` — bundle in-flight work
- `project_phase1b_baseline_b_fixture_mismatch` — baseline-B fixture mismatch
- `project_v15_metal_optics_lane` — iOS v1.5 Metal optics (本 chat 無触)

---

## 19. このドキュメントについて

- role: Phase 2 C5c 完了 → Phase 2 C5b onboarding canonical
- 作成: chat A.5 (C5c RayAngleOptics port)
- naming: `filmtone-native-desktop-phase2-c5c-master-handoff-2026-05-04-jst.md`
