# iOS-side State vs Wire DTO の境界判断

- **日付**: 2026-04-30 JST
- **場所**: Filmtone iOS (`apps/capacitor-film-lab-ios/`)
- **発見**: v1.3 で `appliedSavedLook` (Item 2 Phase E) と `cameraProfile` (Camera Profiles Phase E) を `Phase0ExportRequestDTO` に詰めようとして両者とも facade chain 経由に切り替えた経緯から
- **関連**: CLAUDE.md §4 / §5、`feedback_no_fallback_bug_hotbed`

## TL;DR

Swift 側で「export pipeline に渡したい新 state」が出てきたとき、**`Phase0ExportRequestDTO` に追加する前に「JS bridge が知る必要があるか」で判断**。iOS-internal なら facade chain (`FilmtoneEditorFacade.runExport(...)` → `FilmtoneMediaRuntime.runExport(...)` → `FilmtoneMediaRuntime.makeExportSession(...)` → `FilmtoneExportSession.init(...)`) に optional パラメータで通す。

DTO に追加すると Phase 0 contract gate (`scripts/verify-phase0-contract.sh`) 側の Codable synthesis と衝突しがち。

## 理由

`Phase0ExportRequestDTO` は **JS Capacitor bridge のラインプロトコル**。次の制約がある：

1. `phase0-contract-support.swift`（`scripts/swift/`）にも同じ shape の stub が必要
2. Stub 側は production の type graph（`FilmtoneMediaTypes.swift` 全体）を import できない（standalone compile）
3. `let cameraProfile: CameraProfileSelection?` のような複雑な associated-value enum を追加すると、Stub 側で **Encodable synthesis** が "type does not conform" で fail する。問題は Swift の whole-module compile 順序ではなく、enum の Codable conformance が manual `init/encode` 持ちの場合にコンパイラ側で synthesis 判定が揺れる挙動

実際の症状（v1.3 Camera Profiles Phase E 中に発生）:

```
phase0-contract-support.swift:274:8: error: Type 'Phase0ExportRequestDTO' does not conform to protocol 'Encodable'
note: cannot automatically synthesize 'Encodable' because 'CameraProfileSelection?' does not conform to 'Encodable'
```

`CameraProfileSelection` は `: Codable` 宣言済み + manual `init(from:)` / `encode(to:)` あり。理屈上 Encodable + Decodable conformance を持つ。が、stub 側 standalone compile で synthesis pass が見つけられないケースがある。

## 判断フロー

```
新しい state を export pipeline に渡したい
    ↓
JS bridge (Capacitor TS) が値を生成 / 解釈する？
    ├─ YES → DTO に追加。CodingKeys 拡張、Codable synthesis に注意。
    │        TS schema (iosPhase0ExportPayloadSchema) も更新。
    │        Phase 0 contract gate stub も同期。
    └─ NO  → facade chain 経由で別パラメータとして通す。
             DTO は触らない。
```

## facade chain 経由の典型 diff

```swift
// FilmtoneEditorFacade.swift
func runExport(
    request: Phase0ExportRequestDTO,
    protectedCacheURIs: [String] = [],
    appliedSavedLook: SavedLookEntry? = nil,
    cameraProfile: CameraProfileSelection? = nil,   // 追加
    onProgress: @escaping @MainActor (Phase0ExportProgressDTO) -> Void
) async throws -> Phase0ExportResultDTO {
    return try await runtime.runExport(
        request: request,
        protectedCacheURLs: ...,
        appliedSavedLook: appliedSavedLook,
        cameraProfile: cameraProfile        // forward
    ) { ... }
}

// FilmtoneMediaRuntime.swift — runExport + makeExportSession 両方
func runExport(... cameraProfile: CameraProfileSelection? = nil, ...) { ... }
func makeExportSession(... cameraProfile: CameraProfileSelection? = nil) throws -> FilmtoneExportSession {
    return try FilmtoneExportSession(... cameraProfile: cameraProfile)
}

// FilmtoneExportSession.swift
init(... cameraProfile: CameraProfileSelection? = nil) throws {
    self.cameraProfileSelection = cameraProfile
    ...
}

// FilmtoneEditorStore.swift export() / exportAndSave()
let cameraProfileSelection = project.cameraProfile
let result = try await facade.runExport(
    ...,
    appliedSavedLook: resolvedSavedLook,
    cameraProfile: cameraProfileSelection
) { ... }
```

全層に optional 既定値 `= nil` を持たせると、touch していない call site は壊れない。

## DTO に乗せる場合（reference）

JS bridge が知る必要がある場合（例: `renderMode`, `depthEnabled`）：

1. `FilmtoneMediaTypes.swift` の `Phase0ExportRequestDTO` に追加
2. `phase0-contract-support.swift` の stub にも同じ field を追加（**stub 側は単純型を使う** — `Phase0RenderMode?` は stub では `String?`, 同じ pattern を踏襲）
3. TS 側 `iosPhase0ExportPayloadSchema` に optional 追加
4. Existing fixture JSON (`scripts/fixtures/phase0-contract/*.json`) は optional フィールドなので無更新で OK

## 過去の事例

| 追加 state | 判断 | commit |
|---|---|---|
| `appliedSavedLook` (built-in look provenance) | NO → facade chain | `b227d118` (Item 2 Phase E) |
| `cameraProfile` (Camera Profile selection) | NO → facade chain（最初 DTO に詰めて Codable synthesis fail で revert） | `5dd29086` (Camera Profiles Phase E) |
| `renderMode` (quality/speed) | YES → DTO（JS が picker UI で生成） | v1.2 |
| `depthEnabled` (depth opt-in) | YES → DTO（WebView feature flag 経由） | v1.3 D3.1 |

## アンチパターン

- ❌ stub の `phase0-contract-support.swift` を「production と完全に揃える」原則で動く → stub の目的は contract test の自己完結であって、production graph をミラーすることではない。`String?` 等の wire-stub 型でよい。
- ❌ Codable synthesis が fail しているときに `: Encodable, Decodable` を別々に明示する → 効果なし。manual init/encode を持つ enum の synthesis 判定が揺れる構造的な問題なので、設計を変える方が正しい。
- ❌ iOS-side の transient state（appliedSavedLookId 等）を DTO に詰めて persistence と混同する → DTO は wire 用、project state は durable。境界を混ぜない。
