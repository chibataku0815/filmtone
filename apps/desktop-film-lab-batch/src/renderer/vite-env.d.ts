/**
 * @description Vite が注入する環境変数（型だけ）。実値は `.env` またはシェルで渡す。
 */
interface ImportMetaEnv {
  readonly VITE_FILM_LAB_API_ORIGIN?: string;
  /** @description `true` のときだけスマートルック UI を出す（Web の NEXT_PUBLIC と同義の挙動に寄せる） */
  readonly VITE_FILM_LAB_SMART_LOOK_UI?: string;
  /**
   * @description 開発用: `true` で「支援者済み」扱い（本番では P3 の認証まで使わないこと）。
   */
  readonly VITE_FILM_LAB_ASSUME_SUPPORTER?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
