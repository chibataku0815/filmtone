/**
 * @file esbuild の define で埋め込む定数の型宣言
 * @description `scripts/build-electron.mjs` が `--define:FILM_LAB_EMBEDDED_UPDATE_CHECK_URL=...` を付与します。
 * @limitations 未ビルドの tsserver でもエラーにしないよう、空文字を許容します。
 */
declare const FILM_LAB_EMBEDDED_UPDATE_CHECK_URL: string;
