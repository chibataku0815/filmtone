# Filmtone for DaVinci Resolve — インストール / アンインストールガイド · Installation & Uninstallation Guide

このガイドは日本語（先）と English（後）の同一内容を収録しています。DaVinci
Resolve の画面や本プラグインに表示される文言は英語のままなので、UI 上の文字列
（メニュー名・Status 表示・ウォーターマーク文言）は翻訳せず、表示どおりに記載
しています。

This guide contains the same content in Japanese (first) and English (second).
The DaVinci Resolve interface and this plugin display their labels in English,
so on-screen strings (menu names, Status text, watermark text) are shown
verbatim and are not translated.

---

## 日本語

- 製品名: **Filmtone**（DaVinci Resolve 向け Film Damage OpenFX プラグイン）
- 配布物: 署名・notarization・staple 済みのインストーラ `Filmtone-<version>.pkg`
- 動作確認環境: **macOS 26.5.1 と DaVinci Resolve Studio 21.0.2 で確認済み**
  （この組み合わせでの実測です。他バージョンでの動作は別途確認が必要です）

### 1. インストール

1. DaVinci Resolve を起動している場合は終了します。
2. 受け取ったインストーラ `Filmtone-<version>.pkg`（購入確認またはトライアルの
   案内で入手）をダブルクリックします。署名・notarization 済みのため、macOS は
   セキュリティ警告なしでインストーラを開きます。
3. インストーラの指示に従います。インストール先の `/Library/OFX/Plugins` は
   システム領域のため、途中で macOS の管理者パスワードを求められます。
4. 完了すると `/Library/OFX/Plugins/Filmtone.ofx.bundle` が配置されます。
5. DaVinci Resolve を起動（すでに開いていた場合は再起動）します。起動時に
   プラグインが読み込まれます。

### 2. Resolve 内での場所（初回利用）

インストール後に Resolve を起動すると、次の場所から適用できます。

- **Color ページ**: `Effects Library` から OpenFX の `Filmtone` を、クリップ
  または Color ノードに適用します。エフェクトリスト上では `OFX: Filmtone` と
  表示されます。
- **Fusion ページ**: `Add Tool` メニューから `Filmtone` を選びます。

適用すると、パラメータパネルに Film Damage のコントロールグループと、読み取り
専用の `License` グループ（`Status` 行）が表示されます。

### 3. ライセンスファイルの配置

- ライセンスファイルは次の場所に置きます:
  `~/Library/Application Support/Filmtone/Filmtone.license`
- Finder でファイル `Filmtone.license` をこのフォルダへ 1 回ドラッグするだけです。
  購入版（フル）・トライアル版のどちらも、同じファイル名・同じ場所を使います。
- `Filmtone` フォルダが存在しない場合は作成してください。`~/Library` は Finder
  で通常は非表示のため、Finder の `Go > Go to Folder`（⇧⌘G）で
  `~/Library/Application Support/Filmtone` を開くと確実です。
- ライセンスはレンダー時に読み込まれます。ファイルを置いた（または差し替えた）
  あとはフレームを再レンダーしてください。`Status` 行の表示は、パラメータパネルを
  開き直した（再表示した）ときに更新されます。

### 4. Status 表示の意味

`License` グループの `Status` 行に表示される文言（画面表示のまま）と意味は次の
とおりです。

| Status 表示 | 意味 |
|---|---|
| `Licensed to <name>` | 購入（フル）ライセンスが有効です。ウォーターマークは付きません。 |
| `Trial — expires YYYY-MM-DD` | トライアルライセンスが有効です。表示された日付まではウォーターマークが付きません。 |
| `Trial mode (watermarked)` | 有効なライセンスがありません（未配置・期限切れ・ファイル不正のいずれか）。プラグインは通常どおり動作しますが、出力にウォーターマークが合成されます。 |

ファイルを正しく置けたかどうかは、この `Status` 表示で判断できます。

### 5. アンインストール

1. DaVinci Resolve を終了します。
2. プラグイン本体を削除します（システム領域のため `sudo` が必要です）:
   ```sh
   sudo rm -rf /Library/OFX/Plugins/Filmtone.ofx.bundle
   ```
3. （任意）インストーラのレシートを破棄します:
   ```sh
   sudo pkgutil --forget com.chibatakumi.filmtone.resolve.pkg
   ```
4. DaVinci Resolve を再起動します。

補足: この手順ではライセンスファイル
`~/Library/Application Support/Filmtone/Filmtone.license` は削除されません。手動で
消さない限り残るため、あとで再インストールした場合もライセンスを置き直す必要は
ありません。

### 6. ウォーターマーク（サインアップ不要の評価下限）について

有効なライセンスがない状態でもプラグインは全機能そのまま動作し、出力に
`FILMTONE — TRIAL` のウォーターマークが合成されます。これは不具合ではなく、
サインアップ不要でいつでも試せる恒久的な評価下限です。

---

## English

- Product: **Filmtone** — a Film Damage OpenFX plugin for DaVinci Resolve.
- Distributable: a signed, notarized, and stapled installer,
  `Filmtone-<version>.pkg`.
- Compatibility: **Verified on macOS 26.5.1 with DaVinci Resolve Studio
  21.0.2** (measured on this combination; other versions are not yet verified).

### 1. Install

1. Quit DaVinci Resolve if it is running.
2. Double-click the installer `Filmtone-<version>.pkg` (received with your
   purchase confirmation or trial). Because it is signed and notarized, macOS
   opens the installer without a security warning.
3. Follow the installer. The install location `/Library/OFX/Plugins` is a
   system folder, so macOS will ask for your administrator password.
4. When it finishes, the plugin is placed at
   `/Library/OFX/Plugins/Filmtone.ofx.bundle`.
5. Launch DaVinci Resolve (or restart it if it was already open). The plugin
   loads at startup.

### 2. Where it appears in Resolve (first use)

After installing and launching Resolve, apply the effect from either page:

- **Color page**: from the `Effects Library`, apply the OpenFX effect
  `Filmtone` to a clip or Color node. It appears in the effects list as
  `OFX: Filmtone`.
- **Fusion page**: choose `Filmtone` from the `Add Tool` menu.

Once applied, the parameter panel shows the Film Damage control group and a
read-only `License` group with a `Status` line.

### 3. Place your license file

- Put the license file at:
  `~/Library/Application Support/Filmtone/Filmtone.license`
- In Finder, drag `Filmtone.license` once into that folder. Both purchased
  (full) and trial licenses use the same filename and the same location.
- If the `Filmtone` folder does not exist, create it. `~/Library` is normally
  hidden in Finder, so `Go > Go to Folder` (⇧⌘G) and entering
  `~/Library/Application Support/Filmtone` is the reliable way to open it.
- The license is read at render time. After placing (or replacing) the file,
  re-render the frame. The `Status` line updates when the parameter panel is
  reopened / re-displayed.

### 4. What each Status string means

The `Status` line in the `License` group shows one of the following (shown
verbatim as it appears on screen):

| Status text | Meaning |
|---|---|
| `Licensed to <name>` | A purchased (full) license is active. No watermark. |
| `Trial — expires YYYY-MM-DD` | A trial license is active. No watermark until the shown date. |
| `Trial mode (watermarked)` | No valid license is present (missing, expired, or an invalid file). The plugin still works normally, but a watermark is composited into the output. |

Use this `Status` line to confirm whether the file was placed correctly.

### 5. Uninstall

1. Quit DaVinci Resolve.
2. Delete the plugin bundle (a system folder, so `sudo` is required):
   ```sh
   sudo rm -rf /Library/OFX/Plugins/Filmtone.ofx.bundle
   ```
3. (Optional) Discard the installer receipt:
   ```sh
   sudo pkgutil --forget com.chibatakumi.filmtone.resolve.pkg
   ```
4. Relaunch DaVinci Resolve.

Note: this process does not delete your license file at
`~/Library/Application Support/Filmtone/Filmtone.license`. It remains unless you
remove it manually, so reinstalling later does not require placing the license
again.

### 6. About the watermark (no-signup evaluation floor)

Without a valid license, the plugin still runs with full functionality and
composites a visible `FILMTONE — TRIAL` watermark into the output. This is not
an error — it is the permanent, no-signup evaluation floor you can use at any
time.
