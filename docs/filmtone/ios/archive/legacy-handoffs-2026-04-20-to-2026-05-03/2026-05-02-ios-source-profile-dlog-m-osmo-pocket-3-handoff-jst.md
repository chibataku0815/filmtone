# Filmtone iOS Source Profile Handoff — DJI Osmo Pocket 3 D-Log M (cube-fitted approximation)

Date: 2026-05-02 JST
Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
Branch: `main` (ahead of `origin/main` by 3 commits, latest = `739d94b`)
Scope: 次 chat で **DJI Osmo Pocket 3 D-Log M to Rec.709 を近似 synthesized math として実装**

---

## 0. このハンドオフの目的

DJI の公式 .cube (`/Users/chibatakumi/Downloads/DJI OSMO Pocket 3 D-Log M to Rec.709 V1.cube`) を **black-box reference** として解析し、Filmtone 既存の Source Profile アーキテクチャ (decode → gamut matrix → Filmtone shoulder → Rec.709 OETF) と同形の近似変換を新規 SourceProfile `dji-dlog-m` として実装する。

**前 handoff (`2026-05-02-ios-source-profile-dlog-clog-handoff-jst.md`)** で D-Log M は「formal spec が無いので bundled-cube 路線で別 chat / license レビュー先行」と書かれていた。今 chat 終了時点で user の判断でその方針を変更:

> bundled-cube ではなく、**DJI の公式 cube を解析して近似 synthesized math** として実装する。

理由:
- bundled-cube は DJI LUT データ自体を再配布する形になり license review が重い
- 近似 math は係数だけを派生物として保持するので license 上クリア
- Filmtone 既存 8 profile すべて synthesized 経路に揃うので architecture が単一化される
- 「近似値で OK」と user が明示

---

## 1. 直前 chat (= 今 chat) で出荷済みの内容

### 1.1 commit
```
739d94b feat(ios): add Canon Log 3 + Cinema Gamut source profile  ← 今 chat の commit
fd1f512 feat(desktop): add built-in Camera Profile catalog parity with iOS  (pre-existing, user の v1.4 lane)
0fc5141 feat(ios): add D-Log and C-Log source profiles  (前 chat、origin/main の HEAD)
```

`739d94b` には Canon Log 3 + Cinema Gamut の本体に加え、前 chat 以降にユーザーが進めていた v1.4 in-flight 作業 (mezzanine quality variants、desktop-film-lab-batch metadata-json runtime、film-lab-core source-profile-conversion module、fastlane v1.4 screenshots/metadata、handoff 2 件) が **bundle されている**。これは user が「混入してて何が問題?」と明示したため意図的にまとめた (memory: `feedback_dont_overengineer_dirty_state_split.md`)。

### 1.2 Source Profile Catalog (現在 = 8 件)

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`:

| catalog id | curve | impl | detection hint |
|---|---|---|---|
| `built-in:source-profile.apple-log` | `.appleLog` | `.nativePolicy(.appleLogToRec709)` | `.appleLog` |
| `built-in:source-profile.apple-log-2` | `.appleLog2` | `.nativePolicy(.appleLog2ToRec709)` | `.appleLog2` |
| `built-in:source-profile.dji-dlog` | `.djiDLog` | `.synthesized(.djiDLog)` | nil |
| `built-in:source-profile.canon-clog` | `.canonCLog` | `.synthesized(.canonCLog)` | nil |
| `built-in:source-profile.canon-log3-cinema-gamut` | `.canonLog3CinemaGamut` | `.synthesized(.canonLog3CinemaGamut)` | nil |
| `built-in:source-profile.panasonic-vlog` | `.panasonicVLog` | `.synthesized(.panasonicVLog)` | nil |
| `built-in:source-profile.sony-slog3` | `.sonySLog3` | `.synthesized(.sonySLog3)` | nil |
| `built-in:source-profile.rec709` | nil | `.nilProfile` | `.sdrBt709` |

次 chat で **9 件目** = `built-in:source-profile.dji-dlog-m` を追加する。

### 1.3 Canon Log 3 + Cinema Gamut の数値検証 (今 chat の最終結果)

```
==> C-Log 3 + Cinema Gamut accuracy gate
    C-Log 3 linearization max |Δ| = 0.000000 (budget 1e-3)
    C-Log 3 Macbeth ΔE2000 max = 0.000 mean = 0.000 (budget 2.0/1.0)
    C-Log 3 Macbeth full-frame max = 0.000 mean = 0.000 /255 (budget 2.0/0.5)
```
Python fixture と Swift 実装が完全一致。既存 D-Log/C-Log/V-Log/S-Log3 も同じく 0.000。

---

## 2. リポジトリ前提 (60 秒オンボーディング)

### 2.1 リポジトリ境界

| リポ | パス | 関係 |
|---|---|---|
| filmtone (this) | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | apps + packages 実装の正本 |
| portfolio | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 公開窓のみ、`vendor/filmtone` submodule |
| life | `/Volumes/SamsungPortableSSDX5001/documents/life/` | docs/guides・truth scripts・5 ロール憲法 |

`bun` 必須(`npm` 禁止、`bun.lock` が正本)。Git 操作は user 判断(自動 push 禁止、commit は user 指示時のみ)。

### 2.2 必読

- `CLAUDE.md` (リポ root)
- `apps/capacitor-film-lab-ios/CLAUDE.md` (iOS 専用、§13 Built-in Catalog 8 件)
- 前 handoff: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/2026-05-02-ios-source-profile-dlog-clog-handoff-jst.md`
- このファイル

### 2.3 Truth gate (release/iOS 状態を主張する前)
```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

### 2.4 運用原則 (最優先)

| 原則 | 意味 |
|---|---|
| **本質優先 / 外殻最小** | Swift / native / wiring / sidecar / Profile / shader = 本質。XCTest 6 並列・装飾的 banner = 外殻、user が「QA 希望」と明示時のみ |
| **保守的ヘッジ優先しない** | 「念のため fallback」「v1.x 後回し」のような逃げを優先しない |
| **思考は sequential-thinking** | 設計判断は `mcp__sequential-thinking`、記憶ベース断言禁止 |
| **不確かなら検索** | API/SDK/spec が曖昧なら `gemini-search` → `WebSearch`、一次資料を取り直す |
| **handoff 鵜呑み禁止** | 旧 chat の handoff doc を引用する前に、現行 surface (`grep`/Swift) と突き合わせて live/frozen を確認 |

---

## 3. NEW DIRECTION: Cube-fitted approximation の方針

### 3.1 Source material (DJI 公式 cube)

| 項目 | 値 |
|---|---|
| ファイル | `/Users/chibatakumi/Downloads/DJI OSMO Pocket 3 D-Log M to Rec.709 V1.cube` |
| サイズ | `LUT_3D_SIZE 33` (33³ = 35,937 RGB triplets) |
| 行数 | 35,947 (header + data) |
| Header コメント | `# Mavic 3 Pro, D-Log M, 2023-03-24` (DJI は consumer 機種で同一 LUT を共有 — Pocket 3 と Mavic 3 Pro は curve/gamut が同じ) |
| Generator | DaVinci Resolve LUT Editor |
| ダウンロード元 | https://www.dji.com/downloads/softwares/osmo-pocket-3-dlog-to-rec709 |

「Pocket 3」と「Mavic 3 Pro」が同じ LUT を共有する事実は user が明示できるので、catalog の display label は `DJI D-Log M` (機種非依存) にして良い。

### 3.2 License posture

- **OK (本路線)**: cube を **解析対象** として読み、係数を派生してコードに literal で書く。cube 自体は repo に commit しない。LUT データを再配布しないので license 上クリア(派生物の係数のみ配布)。
- **NG (前 handoff の bundled-cube 路線)**: cube ファイルを Bundle resource として App に同梱。DJI LUT user guide PDF の license review が必要で、ユースケース許諾が曖昧。

### 3.3 アーキテクチャ option (sequential-thinking で議論せよ)

#### Option A — Pure analytic decomposition (推奨)

cube を `decode → gamut → DJI shoulder → Rec.709 OETF` の合成と仮定し、4 段に分解する:

1. **D-Log M decode 抽出**: cube の grayscale 軸 (R=G=B) サンプルから `V → L` の 1D 逆変換を逆算。
   - DJI cube は output が Rec.709 encoded なので、**まず Rec.709 OETF を inverse**(既存 `rec709InverseEncode` が再利用可)してから DJI shoulder を inverse する必要がある。
   - DJI shoulder が不明なため、grayscale 軸が D-Log M の純粋 EOTF 逆変換 (= 既存 D-Log の `dlogDecode` を 0–1 にスケーリング縮退したもの) と仮定して fit する。
2. **D-Gamut M → Rec.709 matrix 抽出**: cube の primary (1,0,0)/(0,1,0)/(0,0,1) 出力点と (0,0,0) からの差分を線型回帰で求める。
3. **DJI shoulder の処理**: 抽出した shoulder は破棄し、Filmtone shoulder (`filmtoneSdrShoulder`) で代替する。これにより他の Source Profile と display look が揃う(D-Log と同じ思想)。
4. **Rec.709 OETF**: 既存 `rec709Encode` を reuse。

**Pros**: 既存 architecture と完全同型 / coefficient のみ commit / Filmtone shoulder で他 profile と look 一致。
**Cons**: 近似なので residual がある。Macbeth ΔE2000 の budget を緩めるか、Filmtone shoulder ありきで fixture を再生成するか、判断が要る。

#### Option B — Black-box cube resampling + bundled .cube
DJI cube を 33³ のまま Bundle に embed して `CIColorCubeWithColorSpace` に直接食わせる。`SourceProfileImpl.bundledCube` enum case が既に schema にあるが v1.3 で未使用。
**却下**: license 課題と、Filmtone shoulder が後段で適用できず別 source profile と look が割れる。

#### Option C — Hybrid (cube as forward, math for backward fit)
forward path は cube、backward path (e.g., preview round-trip) は math、というハイブリッド。**却下**: 複雑度が高くデバッグ困難。

→ **Option A 一択**。次 chat はまず sequential-thinking で Option A の数値分解手順を検証してから実装に入ること。

### 3.4 Accuracy budget (推奨)

近似なので gate を D-Log/C-Log と同水準にできるか不明。**初期 budget 提案**:

| Metric | 提案 budget | 理由 |
|---|---|---|
| Linearization (V→L) | `max |Δ| ≤ 5e-3` | DJI shoulder を破棄するため純粋 EOTF と仮定する近似誤差を許容 |
| Macbeth ΔE2000 | `max ≤ 4.0, mean ≤ 2.0` | Filmtone shoulder で再構築するので DJI cube との residual は不可避 |
| Full-frame /255 | `max ≤ 5.0, mean ≤ 1.5` | 近似の積み残し |

実装後の実測値が大きく下回ったら budget を引き締める(D-Log/C-Log は実測 0.000 で 2.0/1.0 budget に収まった、同じ流儀)。

実測値が proposal を超えた場合は **設計を見直す**(silent budget 緩和は禁止)。

---

## 4. Implementation plan (step-by-step)

### 4.1 Phase 1: 数値分解 (Python script)

新規 fixture generator: `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/dji-dlog-m/encode-ramp.py`

骨子:
```python
# 1. cube parser
def parse_cube(path: Path) -> tuple[int, np.ndarray]:
    """Returns (size, rgb[size, size, size, 3])."""
    ...

# 2. grayscale axis extraction (R=G=B 33 samples)
gray_in = np.linspace(0, 1, 33)
gray_out_encoded = cube[i, i, i] for i in range(33)  # Rec.709-encoded RGB

# 3. invert Rec.709 OETF on output -> linear-ish (still mixed with DJI shoulder)
gray_out_linear_dji = rec709_inverse_encode(gray_out_encoded)

# 4. assume DJI applies negligible shoulder for grayscale axis at low/mid grays
#    (validate with sanity check: 0.18 input should map to ≈0.18 output before shoulder)
#    -> 1D fit: V_dlogm -> L_scene piecewise, similar shape to D-Log original
#    -> publish as DLOGM_LOG_A/B/C/D + DLOGM_LINEAR_SLOPE constants

# 5. matrix extraction: sample (1,0,0) (0,1,0) (0,0,1) (1,1,0) (1,0,1) (0,1,1) (1,1,1) (0,0,0)
#    -> linear regression in linearized space recovers D-Gamut M -> Rec.709 3×3
#    -> publish as DGAMUT_M_TO_REC709 matrix

# 6. validate: re-build a 33³ cube from (decode + matrix + filmtone shoulder + rec709 encode)
#    compare against DJI cube voxel-by-voxel -> residual stats
#    write provenance.md with residual + spec citation
```

依存: `numpy`, `pillow`, optionally `scipy.optimize` for piecewise log fit.

### 4.2 Phase 2: Swift 実装 (`FilmtoneSourceProfileMath.swift`)

既存 `dlogDecode` / `dgamutToRec709` / `dlogPixelToRec709` / `makeDlogToRec709Cube` (line 89-158) と完全に同じ pattern で 4 関数追加:

```swift
@inline(__always)
static func dlogMDecode(_ encoded: Double) -> Double {
    // piecewise log function with constants fitted from DJI cube grayscale axis
    // (constants embedded as literal — Tests/Fixtures/.../dji-dlog-m/encode-ramp.py
    // is the SSOT for the fit and must be re-run if the cube version changes)
    ...
}

@inline(__always)
static func dgamutMToRec709(red: Double, green: Double, blue: Double) -> (red: Double, green: Double, blue: Double) {
    // 3×3 matrix fitted from DJI cube primary samples
    ...
}

@inline(__always)
static func dlogMPixelToRec709(red: Double, green: Double, blue: Double) -> (...) {
    // decode -> dgamutMToRec709 -> filmtoneSdrShoulder -> rec709Encode
    ...
}

static func makeDlogMToRec709Cube(size: Int = 33) -> [Float] { ... }
```

### 4.3 Phase 3: Schema / Catalog / Export / Strings / TS / docs

完全に Canon Log 3 + Cinema Gamut の commit (`739d94b`) と同形:

| ファイル | 変更内容 |
|---|---|
| `FilmtoneSourceProfileSchema.swift` | `case djiDLogM = "dji-dlog-m"` 追加 |
| `FilmtoneSourceProfileCatalog.swift` | `built-in:source-profile.dji-dlog-m` row 追加、`detectionHint: nil` |
| `FilmtoneExportSession.swift` | `makeSynthesizedInputLut` switch に `.djiDLogM` case |
| `FilmtoneStrings.swift` | `cameraDLogM` var + 初期化 + switch case (en: `DJI D-Log M`、ja: `DJI D-Log M` 固有名詞のまま) |
| `FilmtoneEditorStore.swift` | retention rule comment に `.djiDLogM` 追加 |
| `FilmtoneExportSidecarBuilder.swift` | curve raw value list に `dji-dlog-m` 追加 |
| `src/features/editor/CameraProfilePill.tsx` | type union `"dji-dlog-m"` + `DEFAULT_PROFILE_ORDER` (`dji-dlog` の隣) |
| `src/features/editor/MobilePhase0Editor.tsx` | `cameraProfileLabels` に key |
| `src/lib/messages.ts` | `cameraProfileDlogM: "DJI D-Log M"` (en/ja 共通) |
| `apps/capacitor-film-lab-ios/CLAUDE.md` §13 | Source Profiles 件数 8 → 9 |
| `Tests/Fixtures/source-profile/dji-dlog-m/` | 新規ディレクトリ |
| `scripts/swift/test-source-profile-math.swift` | `runDlogMLinearizationCheck` + `runDlogMMacbethCheck` 追加、main entry point に分岐 |
| `package.json` | `gen:fixtures:dlogm` script |
| `apps/capacitor-film-lab-ios/docs/source-profile-math/dji-dlog-m.md` | 新規 math doc |

### 4.4 Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

# 1. Fixture 再生成
bun run --cwd apps/capacitor-film-lab-ios gen:fixtures:dlogm

# 2. Swift contract / source profile gate
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
bun run verify:ios   # repo root の swift script suite (CacheStore + classifier + ray-angle + source-profile + sidecar)

# 3. 完全 build
bun run --cwd apps/capacitor-film-lab-ios build
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
    -scheme App \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    build CODE_SIGNING_ALLOWED=NO

# 4. Copy / hygiene
bun run check:filmtone-copy
git diff --check

# 5. (optional) Truth gate
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

### 4.5 期待 gate output (実装が正しければ)

```
==> D-Log M + D-Gamut M accuracy gate
    D-Log M linearization max |Δ| = 0.00X (budget 5e-3)
    D-Log M Macbeth ΔE2000 max = X.X mean = X.X (budget 4.0/2.0)
    D-Log M Macbeth full-frame max = X.X mean = X.X /255 (budget 5.0/1.5)
```

---

## 5. アンチパターン (踏むと前 handoff §6 違反)

1. **`dji-dlog` curve に alias しない** — D-Log と D-Log M は curve 形状も gamut も別物
2. **DJI cube を repo に commit しない** — license posture が崩れる(派生係数のみ commit)
3. **DJI shoulder を分解せずそのまま含めない** — Filmtone shoulder で他 profile と look が揃う仕様。DJI shoulder を残すと cross-profile で chroma が割れる
4. **silent budget 緩和禁止** — accuracy gate が proposal を超えたら設計見直し、緩和して通すのは禁止
5. **記憶ベースで coefficient を書かない** — fixture 生成 script の出力を Swift に **literal copy** すること
6. **detectionHint nil 維持** — DJI 機種を iOS asset metadata で reliably 判別できる証拠が出るまで manual 選択
7. **Apple Log path を改変しない** — Apple Log / Apple Log 2 は `nativePolicy` で別系統。今回触らない
8. **fastlane / pbxproj / Profile.version は変更不要** — Profile.version は schema additive (`decodeIfPresent`) なので bump 不要

---

## 6. Out of scope (この chat で扱わない)

- DJI D-Log original (既に shipped、`dji-dlog`)
- Canon Log 3 + Cinema Gamut (今 chat で shipped、`canon-log3-cinema-gamut`)
- Canon Log 2 / Cinema Gamut バリエーション
- Nikon N-Log / BMD Film Gen 5 / ARRI LogC4
- iOS metadata-based detection hint
- Apple Log 2 の Rec.2020 → AVFoundation native gamut refinement (v1.4 別 lane)
- v1.4 mezzanine quality variants (in-flight、user の別 lane)

---

## 7. 引き継ぎ前の要確認事項

次 chat 開始時に以下を必ず確認(handoff 鵜呑み禁止 = §2.4 運用原則):

1. `git log --oneline -5` で `739d94b` が main HEAD であることを確認
2. `git status` で working tree が clean か、in-flight 作業が残っているか確認
3. cube ファイルが `/Users/chibatakumi/Downloads/DJI OSMO Pocket 3 D-Log M to Rec.709 V1.cube` に存在することを確認
4. 既存 8 profile の fixture gate がまだ通ることを `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract` で確認
5. `apps/capacitor-film-lab-ios/CLAUDE.md` §13 の catalog 件数が 8 件であることを確認 (今 chat 終了時点)

---

## 8. Highest-precision 引き継ぎ詳細プロンプト (新 chat にコピー)

```text
You are working in:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

主要言語: 日本語(技術用語は英語可)。Git 操作は user 判断、自動 commit/push 禁止。
パッケージマネージャは bun(npm 禁止、bun.lock が正本)。

## Task

DJI Osmo Pocket 3 D-Log M を Filmtone iOS の **9 件目の Source Profile** として
追加する。前提として DJI が D-Log M の formal transfer/gamut spec を公開して
いないので、ユーザー手元にダウンロード済みの DJI 公式 cube ファイルを
**black-box reference として解析** し、既存 SourceProfile アーキテクチャ
(decode → gamut matrix → Filmtone shoulder → Rec.709 OETF) と同形の
**近似 synthesized math** に分解して実装する。

cube は repo に commit しない(license posture: 派生係数のみ配布)。

## 必読(優先順)

1. `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/2026-05-02-ios-source-profile-dlog-m-osmo-pocket-3-handoff-jst.md`
   ← このプロンプトの起点となる詳細 handoff
2. `apps/capacitor-film-lab-ios/CLAUDE.md`
3. リポ root `CLAUDE.md`
4. `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/2026-05-02-ios-source-profile-dlog-clog-handoff-jst.md`
   ← 前々 chat の D-Log/C-Log 着手 handoff(D-Log M を別工程として明示)

## Source material

- 解析対象 cube: `/Users/chibatakumi/Downloads/DJI OSMO Pocket 3 D-Log M to Rec.709 V1.cube`
- Header: `# Mavic 3 Pro, D-Log M, 2023-03-24`(DJI は consumer 機種で同一 LUT を共有)
- LUT_3D_SIZE: 33
- DJI ダウンロード元: https://www.dji.com/downloads/softwares/osmo-pocket-3-dlog-to-rec709

## Start sequence

1. `git status` / `git log --oneline -5` で main HEAD = `739d94b feat(ios): add Canon Log 3 + Cinema Gamut source profile` を確認。
2. `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileSchema.swift`、
   `FilmtoneSourceProfileMath.swift`、`FilmtoneSourceProfileCatalog.swift`、
   `FilmtoneExportSession.swift`(line 2583-2610 の switch)、
   `scripts/swift/test-source-profile-math.swift`、
   `Tests/Fixtures/source-profile/dji-dlog/encode-ramp.py`、
   `Tests/Fixtures/source-profile/canon-log3-cinema-gamut/encode-ramp.py`
   を読み、新規 SourceProfile 追加の現行 pattern を完全に把握する。
3. `mcp__sequential-thinking` で **Option A (Pure analytic decomposition)** の
   数値分解手順を立ててから実装に入る。記憶ベース禁止。
4. 不明点(spec / Antler Post / OCIO に D-Log M のヒントがないか等)は
   `gemini-search` → `WebSearch` の順で必ず一次資料を取り直す。

## 実装手順(handoff §4 の通り、要約)

Phase 1: Python fixture generator
- `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/dji-dlog-m/encode-ramp.py`
- cube parser、grayscale 軸 1D fit、primary 行列回帰、Filmtone shoulder
  なしの forward を再構築し DJI cube との residual を取る
- 出力: `linearization-ramp.json`(4096 サンプル)、`macbeth-patches.json`
  (24 patch、`dlogmEncoded` フィールド)、`source-encoded.png`、
  `expected-rec709.png`、`provenance.md`(cube path / DJI URL / fit residual stats)

Phase 2: Swift math
- `FilmtoneSourceProfileMath.swift` に
  `dlogMDecode` / `dgamutMToRec709` / `dlogMPixelToRec709` /
  `makeDlogMToRec709Cube` を追加(既存 `dlog*` パターンを完全踏襲)
- 係数は Phase 1 fixture script の出力を **literal copy**

Phase 3: Schema / Catalog / Export / Strings / TS shell
- `SourceProfileCurve` に `case djiDLogM = "dji-dlog-m"`
- catalog row `built-in:source-profile.dji-dlog-m`、`detectionHint: nil`、
  englishName `DJI D-Log M`
- `FilmtoneExportSession.makeSynthesizedInputLut` switch に case 追加
- `FilmtoneStrings`: `cameraDLogM` var + init + switch、
  ローカライズキー `filmtone.camera.dji_dlog_m`、en/ja とも `DJI D-Log M`
- `FilmtoneEditorStore` retention rule comment + `FilmtoneExportSidecarBuilder` curve list comment 更新
- TS: `CameraProfilePill.tsx`(type + DEFAULT_PROFILE_ORDER)、
  `MobilePhase0Editor.tsx`(labels)、`messages.ts` (en/ja)
- `apps/capacitor-film-lab-ios/CLAUDE.md` §13 の Source Profiles 件数 8→9

Phase 4: Test gate + script
- `scripts/swift/test-source-profile-math.swift` に
  `Clog3CineGamutMacbethPatch` と同形の `DlogMMacbethPatch` struct、
  `runDlogMLinearizationCheck` / `runDlogMMacbethCheck`、main entry の分岐
- `package.json` に `gen:fixtures:dlogm` script
- `apps/capacitor-film-lab-ios/docs/source-profile-math/dji-dlog-m.md`
  (decode formula + 行列 + pipeline + accuracy budget + DJI cube 起点 spec citation)

## Accuracy budget(初期 proposal、handoff §3.4)

- Linearization max |Δ| ≤ 5e-3 (近似許容)
- Macbeth ΔE2000 max ≤ 4.0 / mean ≤ 2.0 (Filmtone shoulder 再構築のため)
- Full-frame max ≤ 5.0/255 / mean ≤ 1.5/255

実測が proposal を大きく下回るなら gate 引き締め、超えるなら **設計見直し**
(silent 緩和禁止)。

## Verification

```bash
bun run --cwd apps/capacitor-film-lab-ios gen:fixtures:dlogm
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
bun run verify:ios
bun run --cwd apps/capacitor-film-lab-ios build
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
    -scheme App -destination 'generic/platform=iOS Simulator' \
    -configuration Debug build CODE_SIGNING_ALLOWED=NO
bun run check:filmtone-copy
git diff --check
```

UI/copy 変更があれば `bun run check:filmtone-copy` も pass を確認。

期待 output(実装後):
```
==> D-Log M + D-Gamut M accuracy gate
    D-Log M linearization max |Δ| = 0.00X (budget 5e-3)
    D-Log M Macbeth ΔE2000 max = X.X mean = X.X (budget 4.0/2.0)
    D-Log M Macbeth full-frame max = X.X mean = X.X /255 (budget 5.0/1.5)
```

## アンチパターン(handoff §5)

- `dji-dlog` に alias しない(curve も gamut も別物)
- cube ファイルを repo に commit しない(派生係数のみ)
- DJI shoulder を残さず、Filmtone shoulder で再構築する
- silent budget 緩和禁止 — gate 越えたら設計見直し
- 記憶ベースで coefficient を書かない、fixture script 出力を Swift に literal copy
- `detectionHint: nil` を維持(DJI 機種 metadata の判別証拠が出るまで manual)
- Apple Log path / fastlane / pbxproj / Profile.version は触らない

## Out of scope

D-Log original / Canon Log 3 / Canon Log 2 / Nikon N-Log / BMD Film Gen 5 /
ARRI LogC4 / iOS metadata 自動検出 / v1.4 mezzanine quality variants(別 lane)。

## Dirty worktree note

`739d94b` には v1.4 in-flight 作業(mezzanine quality variants、desktop-film-lab-batch
metadata-json runtime、film-lab-core source-profile-conversion module、fastlane
v1.4 screenshots/metadata、handoff 2 件) が user 指示で bundle 済み。新たな
in-flight 作業が working tree に残っていても、user 明示なしに勝手に revert / split
しないこと(memory: feedback_dont_overengineer_dirty_state_split.md)。

## 完了基準(Definition of Done)

- [ ] `SourceProfileCurve.djiDLogM` が enum に存在
- [ ] catalog row `built-in:source-profile.dji-dlog-m` が UI Pill / 設定で選択可
- [ ] `makeDlogMToRec709Cube` が export pipeline から呼ばれる
- [ ] accuracy gate 3 budget 全 pass(初期 proposal の範囲内)
- [ ] verify:swift-contract / verify:ios / xcodebuild build が pass
- [ ] git diff --check pass
- [ ] sidecar に `dji-dlog-m` raw value が記録される
- [ ] check:filmtone-copy pass
- [ ] provenance.md に DJI cube path、DJI ダウンロード URL、fit residual stats を記載
- [ ] cube 自体が repo に commit されていないことを git status で確認
```

---

## 9. このハンドオフの責任所在

このドキュメントは **次 chat の唯一の起点**。chat 終了時(D-Log M 実装完了後)に
新規 handoff doc (`docs/filmtone/ios/2026-XX-XX-...`) を **§8.5 4 セクション** で書くこと
(Plan Compliance / Cross-Stream Visibility / Scope Diff / 残タスク enumeration —
`feedback_no_silent_stream_redefine`)。
