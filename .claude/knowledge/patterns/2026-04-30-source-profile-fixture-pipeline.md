# Source Profile (S) Curve 追加の完全パターン

- **日付**: 2026-04-30 JST
- **場所**: Filmtone iOS (`apps/capacitor-film-lab-ios/`)
- **発見**: v1.3 Camera Profiles Phase B (V-Log) + Phase C (S-Log3) 実装中
- **対象**: v1.4 で ARRI LogC4 / Nikon N-Log / Canon Log 3 / BMD Film Gen 5 を追加する未来の自分

## 設計原則

カメラログカーブの追加は **数学・fixture・accuracy test を同一 PR で揃える hard gate** が必須。silent fallback 禁止（CLAUDE.md `feedback_no_fallback_bug_hotbed`）。circular dependency を避けるため、メーカー LUT を真値にしない。

## ファイル増分（curve 1 本につき）

```
apps/capacitor-film-lab-ios/
├── ios/App/App/FilmtoneSourceProfileMath.swift     # +decode + matrix + pixelToRec709 + makeCube
├── ios/App/App/FilmtoneSourceProfileCatalog.swift  # +CameraProfileCatalogEntry 1 行
├── ios/App/App/FilmtoneStrings.swift               # +localized name + builtInSourceProfileName 分岐
├── docs/source-profile-math/<curve-slug>.md        # spec citation + 定数表
├── Tests/Fixtures/source-profile/<curve-slug>/
│   ├── encode-ramp.py                              # colour-science で fixture 生成
│   ├── source-encoded.png                          # 4096pt ramp (visual)
│   ├── linearization-ramp.json                     # 4096 pt 期待値
│   ├── macbeth-patches.json                        # 24 patch 期待値
│   ├── expected-rec709.png                         # full-frame 期待値
│   └── provenance.md                               # spec URL + 生成日時 + commit hash
└── scripts/swift/test-source-profile-math.swift    # +linearization + Macbeth assertion 4 件
```

## 手順（curve = "<my-log>" として）

### 1. Spec 確認

メーカー公式 PDF を WebFetch で確認 → mirror（Antler Post 等）と定数を突合。記憶ベース禁止。

### 2. Python fixture 生成スクリプト

`Tests/Fixtures/source-profile/<my-log>/encode-ramp.py` を既存 `panasonic-vlog/encode-ramp.py` をテンプレートにコピー。決定的に変更するのは：

- decoder 関数（spec の式を transcribe）
- gamut → Rec.709 matrix（precomputed）
- Macbeth fixture 出力時、**Python の pipeline 出力**を `rec709EncodedExpected` にすること（X-Rite linear reference を直接書かない — Filmtone shoulder で必ず drift する）

`filmtoneSdrShoulder` 定数（`gain=1.18 / knee=0.18 / falloff=0.42`）と `rec709Encode` 定数は **Swift 側からコピーせずに spec 側から独立に transcribe**。両者が一致することが cross-language verification の意味。

### 3. uv で fixture 生成

`package.json` に `gen:fixtures:<my-log>` script を追加：

```json
"gen:fixtures:<my-log>": "uv run --with colour-science --with numpy --with pillow python Tests/Fixtures/source-profile/<my-log>/encode-ramp.py"
```

`bun run gen:fixtures:<my-log>` で 6 ファイル生成。

### 4. Swift math 実装

`FilmtoneSourceProfileMath.swift` に 4 関数追加：

```swift
@inline(__always) static func <myLog>Decode(_ encoded: Double) -> Double { ... }
@inline(__always) static func <myGamut>ToRec709(red: Double, green: Double, blue: Double) -> (red: Double, green: Double, blue: Double) { ... }
@inline(__always) static func <myLog>PixelToRec709(red:green:blue:) -> (red:green:blue:) { ... }
static func make<MyLog>ToRec709Cube(size: Int = 33) -> [Float] { ... }
```

`pixelToRec709` の合成は必ず `decode → matrix → filmtoneSdrShoulder → rec709Encode` の順。SSOT は Phase B-1 で移行済 `filmtoneSdrShoulder` / `rec709Encode` を再利用。

### 5. Catalog 1 行追加

`FilmtoneSourceProfileCatalog.swift` の `allProfiles` に：

```swift
CameraProfileCatalogEntry(
    id: "built-in:source-profile.<my-log>",
    englishName: "<MyLog>",
    curve: .<myLog>,                       // SourceProfileCurve に新 case 追加
    impl: .synthesized(.<myLog>),
    detectionHint: nil,                    // (S) は container metadata から検出不可
    bundled: true,
    immutable: true
)
```

`SourceProfileCurve` に新 case を追加（`FilmtoneSourceProfileSchema.swift`）。

### 6. Strings 追加

`FilmtoneStrings.swift`:

```swift
let camera<MyLog>: String  // struct field
camera<MyLog> = filmtoneLocalized("filmtone.camera.<my_log>", defaultValue: "<MyLog>", comment: "...")  // init
```

`builtInSourceProfileName(for:)` の switch に `<my-log>` slug 分岐追加。

### 7. Pipeline dispatch 拡張

`FilmtoneExportSession.makeSynthesizedInputLut(curve:)` の switch に：

```swift
case .<myLog>:
    rgb = FilmtoneSourceProfileMath.make<MyLog>ToRec709Cube(size: cubeSize)
```

NSCache のキー名は `synthesized.<rawValue>.33` を踏襲。

### 8. Accuracy test 4 件追加

`scripts/swift/test-source-profile-math.swift`:

- `run<MyLog>LinearizationCheck` — 4096pt ramp、`max |Δ| ≤ 1e-3`
- `run<MyLog>MacbethCheck` — 24 patch、`max ΔE2000 ≤ 2.0, mean ≤ 1.0`、`max フルフレーム ≤ 2/255, mean ≤ 0.5/255`
- main の if-block 1 個追加して fixture フォルダ存在時に走らせる

`MacbethPatch` Decodable struct の field 名を curve 名に合わせる（`vlogEncoded` / `slog3Encoded` パターン）。

### 9. UI Menu 1 行（自動）

`FilmtoneRootView.swift` の `cameraProfileCard` Menu は `ForEach(FilmtoneSourceProfileCatalog.allProfiles, ...)` で自動列挙。Catalog に追加するだけで Menu に出る。

### 10. pbxproj 4-section 登録

新 Swift ファイルは `PBXBuildFile` / `PBXFileReference` / `PBXGroup` / `PBXSourcesBuildPhase` の 4 セクション全部に登録。`grep -c <ファイル名>` ≥ 4。

新規ファイルは増えないことが多い（curve 追加は既存ファイルへの編集が中心）。

### 11. Gate 順

```bash
bun run gen:fixtures:<my-log>            # fixture 再生成
bun run verify:swift-contract            # accuracy gate green 確認
xcodebuild ... build CODE_SIGNING_ALLOWED=NO   # production build
bun run build                            # tsc + vite
```

期待結果: `<MyLog> linearization max |Δ| = 0.000000` / `<MyLog> Macbeth ΔE2000 max = 0.000` — Python と Swift が同一定数を transcribe したので byte-identical になるのが正しい状態。

## アンチパターン（やった結果ハマったので避ける）

- ❌ Macbeth 期待値に X-Rite linear reference をそのまま書く → Filmtone shoulder で必ず drift する。Python pipeline 出力を期待値にする。
- ❌ メーカー公式 LUT を真値として fixture 比較する → 循環参照 + license issue。
- ❌ `colour-science` API を直接呼ぶ → 意図的に独立実装 + 定数 transcribe で cross-verify する。
- ❌ DTO (`Phase0ExportRequestDTO`) に `curve: SourceProfileCurve?` を追加する → 標準偏差 contract gate stub と Codable synthesis 衝突する（→ `2026-04-30-ios-state-vs-wire-dto.md` 参照）。

## 既存 reference

- v1.3 V-Log: commits `7382e3bd` (B-1 SSOT migration) + `7bbddc8c` (B-2/3)
- v1.3 S-Log3: commit `88943855` (Phase C)
- spec citations: `apps/capacitor-film-lab-ios/docs/source-profile-math/{panasonic-vlog,sony-slog3}.md`
