# Filmtone iOS — Direct Writer prototype frozen (2026-05-03 JST)

v1.5 Quality export Phase 2 段階 2 として、Metal renderer の最終出力を AVAssetWriter pixel buffer に直接書く direct-writer prototype を実機検証した結果、**採用基準未達のため凍結**。コードは revert 済み（branch tip = `88199db feat(ios): v1.5 Quality export Metal optics chain (Glow + Vignette)`）。本 doc は知見のみ残す。

## 試した内容

`FILMTONE_EXPORT_METAL_DIRECT_WRITER=1` で、`appendVideoSample` の `ciContext.render(_, to: CVPixelBuffer)` を `ciContext.render(_, to: MTLTexture, commandBuffer: cb)` に切替。writer pixel buffer pool に `kCVPixelBufferMetalCompatibilityKey` を付与し、`CVMetalTextureCache` 経由で `bgra8Unorm` MTLTexture として wrap。CB は per-frame `commit + waitUntilCompleted`。CI graph (Glow / Vignette / Grain / Print) は不変、最終 encode の target type のみ swap。

## 実機実測（iPhone 17 Pro / A001_03270631_C008.mov / 1920x1080 24fps / 3751 frames）

| 状態 | export | render | avgRender/frame |
|---|---:|---:|---:|
| C: 段階 1 (Glow+Vignette Metal) | 94.8 s | 42.5 s | 11.34 ms |
| D: 段階 1 + Direct Writer | 95.6 s | 44.7 s | 11.91 ms |

差分 +0.8s ≒ run-to-run の thermal/scheduler 変動（段階 1 自身も Phase 1 から -0.8s で同レンジ）。**null result**（improvement でも regression でもない）。`acceleratedRenderStages` には `["GlowFamily/metal", "Vignette/metal", "WriterOutput/metal"]` が出ており、direct path は 3751 frame 全てで実走したことを確認。

## 推定原因

- `cb.waitUntilCompleted()` で frame 間 pipelining が消えた。CIContext の CVPixelBuffer target は内部で次 frame の build と現 frame の encode を overlap する余地がある。
- `CVMetalTextureCacheCreateTextureFromImage` + `Flush` × 3751 frame の per-frame overhead。
- `renderMs` が +2.1s、`buildGraphMs` が -0.55s で trade-off は出るが net で +0.8s。

## 別 lane 候補

1. **`waitUntilCompleted` → `waitUntilScheduled` 試行**: encoder と GPU encode の race を検証してから。安全条件が確認できれば pipelining が戻る可能性。
2. **AVAssetReader → MTLTexture 直接化 / full Metal source-color pipeline**: prompt で「別 lane 級」と明記済み。CI/Metal 境界を入口側で消す方針。

これらを試す場合は本 doc を起点に、Direct Writer のコード自体は再実装（残置していない）。
