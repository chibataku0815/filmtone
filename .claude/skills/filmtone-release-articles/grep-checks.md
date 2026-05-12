# Grep-based 改稿チェック

draft 完成後に毎回走らせる。1 つでも hit したら lead / 本文を見直す。

## 禁忌語 (絶対入れない)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

# 対象ディレクトリを変える時は最初の引数を変える
TARGET="docs/filmtone/articles/2026-05-12-audio-texture-release"

# JP 禁忌
grep -rn -E "細部の硬さ|世界観|魔法|プロ級|必ず[^々]|完璧|すべての素材で|短尺動画" "$TARGET"

# EN 禁忌
grep -rn -iE "magic|pro-grade|always [a-z]+ better|perfectly|every source|short-form video" "$TARGET"

# Web を捨てた / React mistake 系
grep -rn -E "Webを捨て|Web を捨て|instead of web|React.*間違い|React.*mistake|Capacitor.*失敗" "$TARGET"

# 旧 iOS preset alias
grep -rn -E "\biphone\b|\bsoftBlue\b|\bamberGlow\b|BaseLookName|BASE_LOOKS|lookPresetId|currentExportLookPreset" "$TARGET"

# Liquid Glass 短縮
grep -rn -E "Liquid Glass" "$TARGET" | grep -v "Apple Liquid Glass"

# 公開状態の主張 (truth gate 前に出てたら NG)
grep -rn -E "公開しました|released|now available|is available|we shipped|今日から" "$TARGET"

# 保守的ヘッジ
grep -rn -E "念のため|安全側|fallback|後回し" "$TARGET"

# positioning anxiety section (本文に直書きされてたら NG)
grep -rn -E "^## 目次|^## 誰に向けた更新か|^## 作っている側の補足" "$TARGET"
```

## 用語ロック確認

```bash
# Texture Softness を blur と説明していないか
grep -rn -E "Texture Softness.*blur|Texture Softness.*ぼかし|Texture Softness は.*ぼかし" "$TARGET"
# blur と書いていれば「ではない」「は wrong answer」とセットになっているか手で確認

# transform LUT の方向
grep -rn -E "transform LUT" "$TARGET"
# Rec.709→Log と書いてないか / technical-only と書いてないか手で確認

# Preset と Look の混同 (Preset を curve、Look を LUT pack 文脈に限定)
grep -rn -E "Preset" "$TARGET"
grep -rn -E "Look" "$TARGET"
# 混同が無いか手で確認

# SHOT ON iPhone (camera-agnostic 軸違反)
grep -rn -E "SHOT ON iPhone|iPhoneで撮った.*Filmtone" "$TARGET"

# bun / npm
grep -rn -E "npm install|npm run|package-lock\.json" "$TARGET"
```

## 認知ゼロ前提チェック

各記事の冒頭 30 行に Filmtone definition があるか確認:

```bash
for f in "$TARGET"/*.md; do
  echo "=== $f ==="
  head -30 "$f" | grep -E "Filmtone は|Filmtone is" | head -3
done
```

ヒット 0 件のファイルがあったら、§3.1 のテンプレから当てる。

## 構造チェック (note / X long-form / Desktop / iOS note)

```bash
# H2 が 4 ブロックで揃っているか (1. audio / 2. Texture Softness / 3. 試してほしい / 4. 作っている側で考えていること)
for f in "$TARGET"/note-ja.md "$TARGET"/../../desktop/native-desktop-v2/2026-*-filmtone-desktop-*.md "$TARGET"/../../ios/2026-*-filmtone-ios-*.md; do
  [ -f "$f" ] || continue
  echo "=== $f ==="
  grep -E "^## " "$f"
done
```

## Truth gate 状態 (実行する側)

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

doc 内の version 主張 (`v1.7`, `1.9`, `build 4`, `build 8`) が script 出力と一致しているか確認。食い違ったら script を信頼。
