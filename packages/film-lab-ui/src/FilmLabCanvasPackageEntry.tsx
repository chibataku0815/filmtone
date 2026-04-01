"use client";

import {
  forwardRef,
  useEffect,
  useState,
  type ComponentPropsWithoutRef,
  type CSSProperties,
} from "react";
import {
  FilmLabCanvas as FilmLabCanvasInner,
  type FilmLabCanvasRef,
  type FilmLabInteractiveSourceInfo,
} from "./FilmLabCanvas";

/**
 * @description Web の overlay プレビューでは、外側の箱が最初に高さを持ってから
 * 内側の Three.js canvas を作る必要があります。
 * Tailwind の arbitrary utility が package 側で落ちても崩れないよう、
 * package entry でだけ aspect ratio を先に確保します。
 */
const FILM_LAB_CANVAS_SM_MEDIA_QUERY = "(min-width: 640px)";
const FILM_LAB_CANVAS_COMPACT_ASPECT_RATIO = "4 / 3";
const FILM_LAB_CANVAS_WIDE_ASPECT_RATIO = "16 / 9";

type FilmLabCanvasInnerProps = ComponentPropsWithoutRef<typeof FilmLabCanvasInner>;

/**
 * @description 画面幅に応じたプレビュー比率を返します。
 * 小さい画面は 4:3、`sm` 以上は 16:9 に揃えます。
 */
function getFilmLabCanvasAspectRatio(): string {
  if (
    typeof window !== "undefined" &&
    window.matchMedia(FILM_LAB_CANVAS_SM_MEDIA_QUERY).matches
  ) {
    return FILM_LAB_CANVAS_WIDE_ASPECT_RATIO;
  }

  return FILM_LAB_CANVAS_COMPACT_ASPECT_RATIO;
}

/**
 * @description shared package 向けの Film Lab canvas entry。
 * Web の overlay モードだけ外側に高さ用 wrapper を付け、
 * Desktop の stacked / fullScreen は既存挙動をそのまま使います。
 */
export const FilmLabCanvas = forwardRef<FilmLabCanvasRef | null, FilmLabCanvasInnerProps>(
  function FilmLabCanvas(
    { chromeLayout = "overlay", className, fullScreen = false, ...props },
    ref,
  ) {
    const [aspectRatio, setAspectRatio] = useState(() =>
      getFilmLabCanvasAspectRatio(),
    );

    useEffect(() => {
      if (typeof window === "undefined") return;

      const mediaQueryList = window.matchMedia(FILM_LAB_CANVAS_SM_MEDIA_QUERY);
      const syncAspectRatio = () => {
        setAspectRatio(
          mediaQueryList.matches
            ? FILM_LAB_CANVAS_WIDE_ASPECT_RATIO
            : FILM_LAB_CANVAS_COMPACT_ASPECT_RATIO,
        );
      };

      syncAspectRatio();
      mediaQueryList.addEventListener("change", syncAspectRatio);

      return () => {
        mediaQueryList.removeEventListener("change", syncAspectRatio);
      };
    }, []);

    if (fullScreen || chromeLayout === "stacked") {
      return (
        <FilmLabCanvasInner
          ref={ref}
          {...props}
          className={className}
          fullScreen={fullScreen}
          chromeLayout={chromeLayout}
        />
      );
    }

    const wrapperStyle: CSSProperties = {
      aspectRatio,
    };

    return (
      <div className={className ?? ""} style={wrapperStyle}>
        <FilmLabCanvasInner
          ref={ref}
          {...props}
          className="h-full w-full"
          fullScreen
          chromeLayout={chromeLayout}
        />
      </div>
    );
  },
);

FilmLabCanvas.displayName = "FilmLabCanvas";

export type { FilmLabCanvasRef, FilmLabInteractiveSourceInfo };
