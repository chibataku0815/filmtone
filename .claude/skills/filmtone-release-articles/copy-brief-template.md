# Copy Brief Template

各記事の冒頭メタブロックとして毎回書く。lead を書く前に必ず埋める。

```markdown
## Copy Brief

- Primary reader: {認知ゼロ前提の対象読者。§2 表から選ぶ}
- Moment: {どの瞬間にこの記事に出会うか / どの状況の読者が読むか}
- Unresolved feeling: {読者が抱えている未解決の感情・課題}
- Next action: {読了後に取ってほしい具体 1 アクション (試す / 検討する / ダウンロード予約 等)}
- Not for: {この記事の対象外 / 隣接記事が扱う領域}
- Claim class: {Candidate / Public / Implementation note 等。truth script の状態と整合}
- Source evidence: {どの archive / strategy.md / proof file から事実を引いているか。truth script の出力日と数値も}
- Reversibility buffer: {確証外の範囲をどう柔らかく書くか。「素材によって効き方は変わります」など}
```

## 7 媒体別 Copy Brief パターン例 (2026-05-12 release を base に)

### note (統合)

- Primary reader: iPhone / Mac で撮った動画の色をどうにかしたい JP creator / 写真出身者 / Adobe Rush / Filmic Pro / VSCO Cinematic に物足りなさを感じている人
- Moment: 動画色アプリを検索している / Filmtone を初めて見聞きした / SNS 経由でリンクを開いた
- Unresolved feeling: DaVinci は重すぎ、Filmic Pro は色が浅い。両者の中間を探している
- Next action: Filmtone iOS / Desktop の公開後にダウンロード、Stone or Urban Creative LUT pack で自分の素材を試す
- Not for: DaVinci / Adobe SDK 開発者、Mac App Store 申請告知
- Claim class: Candidate (public truth 確定後に release wording に置換)
- Source evidence: release truth script (Desktop public 1.6 / candidate 1.7 build 4)、iOS truth script (public 1.8 / candidate 1.9 build 8)、`docs/filmtone/export-audio/archive/2026-05-12-export-audio-restoration-a.md`、`docs/filmtone/detail-softness/strategy.md`
- Reversibility buffer: 「素材によって効き方は変わります」「すべての素材で最適とは言いません」

### desktop-note

- Primary reader: Final Cut / iMovie / Premiere ユーザーで色だけ別アプリで扱いたい人、DaVinci の color page だけ使いたかった人
- Moment: Mac 動画編集の workflow を再構築している / LUT 文化を試したい
- Unresolved feeling: 動画の色を別アプリで仕上げる選択肢が欲しい
- Next action: v1.7 公開後にダウンロード、通常書き出しと Texture Softness を試す
- Not for: iOS 1.9 の App Store 公開告知 / Mac App Store 申請
- Claim class: Candidate
- Source evidence: release truth script (Desktop public 1.6 / candidate 1.7 build 4)、audio archive、detail-softness Phase 5 archive
- Reversibility buffer: 「素材によって効き方は変わります」

### x-long (iOS)

- Primary reader: X 上で creator (chibataku0815 / fores-tone) を follow している層、iPhone 動画編集ツールに関心ある JP user
- Moment: タイムラインで記事リンクが流れてきた / native iPhone 動画色アプリを検討している
- Unresolved feeling: Filmic Pro / LumaFusion / CapCut / VN の色工程に物足りなさを感じている
- Next action: 1.9 公開後に App Store で更新、Stone / Urban Creative で自分の素材を試す
- Not for: Desktop の Mac App Store 申請 / メーカー認定変換主張
- Claim class: Candidate
- Source evidence: iOS truth script、detail-softness strategy.md、export audio archive
- Reversibility buffer: 「素材によって効き方は変わります」「公開後の検証で更新があり得ます」

### zenn

- Primary reader: AVFoundation / Metal / SwiftUI / Capacitor / cross-platform color pipeline に関心ある JP iOS / macOS エンジニア
- Moment: 実装事例を検索している / 自分の AVFoundation pipeline を組んでいる / shared core + native runtime の構成を検討している
- Unresolved feeling: completed-file validation / amplitude-gated detail layer / runtime-only bias のような pattern の実装事例が少ない
- Next action: 自分の export pipeline に validate-finished-file pattern を取り入れる検討
- Not for: 製品リリース告知
- Claim class: Implementation note (candidate)
- Source evidence: `apps/capacitor-film-lab-ios/ios/App/App/Export/`、`packages/film-lab-core/src/`、strategy doc
- Reversibility buffer: 「素材依存」「広域 visual QA は今後も素材を足しながら」

### medium

- Primary reader: International product designers / indie creative tool builders / Linear / Things / Arc Browser のような small-release-strong-opinion 物語が好きな層
- Moment: design narrative を browse している / indie tool の release log を読んでいる
- Unresolved feeling: Adobe SDK / 大手 vendor に依存しない creative tool の事例を探している
- Next action: Filmtone を follow / 試用検討
- Not for: implementation tutorial
- Claim class: Candidate
- Source evidence: 同上
- Reversibility buffer: "material-dependent", "not a universal improvement"

### hashnode

- Primary reader: international iOS/macOS engineers / cross-platform tool builders / WebGPU / Capacitor / native hybrid に関心ある人
- Moment: 実装事例を検索 / 自分の pipeline 設計検討中
- Unresolved feeling: native runtime と shared color truth を両立する architecture pattern を探している
- Next action: validate-finished-file pattern / runtime-only bias を自分の pipeline に応用
- Not for: 製品リリース告知
- Claim class: Implementation note (candidate)
- Source evidence: same as zenn
- Reversibility buffer: "material-dependent", "not every source"

### behance

- Primary reader: international visual designers / motion designers / art directors / mobile-first creative tool に visual interest ある人
- Moment: case study を browse している / mobile creative tool を探している
- Unresolved feeling: indie creative tool で「丁寧さ」を視覚的に確認したい
- Next action: Filmtone の visual identity を覚える / follow / 試用検討
- Not for: implementation detail (visual case で示す)
- Claim class: Candidate
- Source evidence: 同上 + visual asset checklist
- Reversibility buffer: "material-dependent"
