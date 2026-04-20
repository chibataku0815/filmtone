/**
 * @description Vite が注入する環境変数（型だけ）。実値は `.env` またはシェルで渡す。
 */
interface ImportMetaEnv {
  /** @description Vite 既定: development / production */
  readonly MODE: string;
  readonly DEV: boolean;
  readonly PROD: boolean;

  readonly VITE_FILM_LAB_API_ORIGIN?: string;
  /** @description `true` のときだけスマートルック UI を出す（Web の NEXT_PUBLIC と同義の挙動に寄せる） */
  readonly VITE_FILM_LAB_SMART_LOOK_UI?: string;
  /**
   * @description 開発用: `true` で「支援者済み」扱い（本番では P3 の認証まで使わないこと）。
   */
  readonly VITE_FILM_LAB_ASSUME_SUPPORTER?: string;
  /**
   * @description `true` のとき BFF に `includeRasterCorrection: true` を送り、返却 PNG でキャンバスを差し替える（`vite.config` の define と整合）。
   */
  readonly VITE_FILM_LAB_SMART_LOOK_RASTER?: string;
  /**
   * @description `vite.config` が `FILM_LAB_DEBUG_VIDEO_EXPORT` から埋める。`true` のとき WebCodecs bucket ログを出す。
   */
  readonly VITE_FILM_LAB_DEBUG_VIDEO_EXPORT?: string;
  /**
   * @description `vite.config` が `FILM_LAB_VERBOSE_VIDEO_EXPORT` から埋める。`true` のときだけ各フレームの詳細ログを出す。
   */
  readonly VITE_FILM_LAB_VERBOSE_VIDEO_EXPORT?: string;
  /** @description デスクトップ版 Filmtone の公開バージョン。metadata sidecar に埋め込む。 */
  readonly VITE_FILMTONE_DESKTOP_VERSION?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
