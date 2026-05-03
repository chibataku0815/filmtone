# Built-in Catalog 不変条件

`apps/capacitor-film-lab-ios` の Built-in Look / Source Profile catalog についての product invariants。
件数や spec の現行スナップショットは陳腐化が速いので、ここでは **触ったら壊れること** だけ書く。
カタログの実体は `FilmtoneBuiltInCatalog.swift` / `FilmtoneSourceProfileCatalog.swift`、math 仕様は `docs/source-profile-math/` を一次ソースとして読む。

---

## Built-in Looks

- **Canonical UUID namespace**: `FB1A...`。dedup key として library merge から参照される。
- **Deprecated UUID は再利用禁止**:
  - v1.3 の 4 件 preset-wrapper (`...000001` 〜 `...000004`)
  - `...000005`(retired Night Soft)
  既存ユーザーの favorites に残っていても silent skip。新規 Look に同一 UUID を割り当てない。
- **`immutable: true`** の built-in は不変。ユーザー編集は新規 user look として保存される。
- **`paramOverrides` の構造**: color-only ops は cube が SSOT なので neutral pin。lens-filter optics (`rgbShift` / `bloom` / `halation` / `diffusion` / `lensSoftness` / `grain` / `vignette`) のみ override。
- **`rgbShift` は Filmtone signature optical effect**。Stone=0.0032 / Urban=0.0028 は Adjust-sheet "Default"=0.0038 より **小さい** — ユーザーが Default を上から押しても visible step up になる方向で設計されている。逆転させない。
- **保存 Look の densify**: `FilmtonePhase0ParamsPatch.densifyingOpticsGlow` で 14 個の optics+glow keys を埋める。schema は `[String: Double]` のまま、bump 不要。

### Creative Pack 01 cube SHA-256 pin

- `Tests/Fixtures/creative-pack-01/manifest.json` に SHA-256 を pin。
- `bun run scripts/build-creative-luts.ts --regenerate` 後は **manifest 更新を同一 PR に含める**。
- pin 不一致は CI gate を fail させる。

### UserDefaults

- お気に入り key: `filmtone.builtinLookFavorites`(`Set<UUID>` シリアライズ)

---

## Source Profiles

- **catalog id 形式**: `built-in:source-profile.<slug>`(例: `built-in:source-profile.panasonic-vlog`)。sidecar `cameraProfile.catalogId` で書き出される。
- **Synthesized math の accuracy gate**: spec 非公開 / cube fit から係数を起こしたプロファイル(DJI D-Log / DJI D-Log M / Canon C-Log / Canon Log 3 + Cinema Gamut / V-Log / S-Log3) は accuracy fixture が `max = 0.000` で hard gate。spec 改訂時は fixture を再生成して PR に同梱。
- **DJI D-Log M (license posture)**: spec が非公開のため cube から fit した synthesized 係数を使う。**cube そのものは repo に commit しない**。SSOT は `Tests/Fixtures/source-profile/dji-dlog-m/encode-ramp.py`、license 記述は `docs/source-profile-math/dji-dlog-m.md`。
- **Apple Log 2 known limitation**: Rec.2020-matrix-as-approximation で動く(CD signed off via AskUserQuestion 2026-04-30)。AVFoundation native gamut info への refine は将来 lane で。

---

## v1.4 候補 curve 追加 lane

`/Volumes/SamsungPortableSSDX5001/documents/life/.claude/knowledge/patterns/2026-04-30-source-profile-fixture-pipeline.md` を参照。Nikon N-Log / Canon Log 3 / BMD Film Gen 5 / ARRI LogC4 + bundled `.cube` 経路。
