"use client";

import { useState, useCallback, useRef } from "react";
import { useTranslations } from "next-intl";
import {
  buildSourceProfileLut,
  parseCube,
  SOURCE_PROFILE_CATALOG,
  type SourceProfileCatalogEntry,
} from "film-lab-core";
import { FILM_LAB_NEXT_INTL_NAMESPACE } from "./filmLabUiContract";
import { ControlSlider } from "./ui/ControlSlider";
import type { Viewport } from "film-lab-renderer";

interface Lut1ChangePayload {
  name: string;
  data: Float32Array;
  size: number;
  intensity: number;
  /** Set when lut1 was filled from a built-in Camera Profile. */
  sourceProfileId?: string | null;
}

interface Lut2ChangePayload {
  name: string;
  data: Float32Array;
  size: number;
  intensity: number;
}

interface LUTPanelProps {
  viewport: Viewport | null;
  /** .cube の読み込みが成功したとき（寄付バナー用のフック） */
  onCubeLutLoaded?: () => void;
  /** LUT が変更されたとき（Creative / Log 両スロットの最新状態） */
  onLutChange?: (state: {
    lut1: Lut1ChangePayload | null;
    lut2: Lut2ChangePayload | null;
  }) => void;
}

/**
 * Source-profile chip ordering for the compact built-in selector. iOS
 * keeps Apple Log / Apple Log 2 at the head because they're the auto-detect
 * pair; the rest are manual-select curves Desktop ships in v1.4 parity.
 */
const SOURCE_PROFILE_CHIP_ORDER = [
  "built-in:source-profile.apple-log",
  "built-in:source-profile.apple-log-2",
  "built-in:source-profile.arri-logc3",
  "built-in:source-profile.dji-dlog",
  "built-in:source-profile.dji-dlog-m",
  "built-in:source-profile.canon-clog",
  "built-in:source-profile.canon-log3-cinema-gamut",
  "built-in:source-profile.panasonic-vlog",
  "built-in:source-profile.sony-slog3",
] as const;

const REC709_PROFILE_ID = "built-in:source-profile.rec709";

function findCatalog(id: string): SourceProfileCatalogEntry | undefined {
  return SOURCE_PROFILE_CATALOG.find((entry) => entry.id === id);
}

export function LUTPanel({ viewport, onCubeLutLoaded, onLutChange }: LUTPanelProps) {
  const tFilmLab = useTranslations(FILM_LAB_NEXT_INTL_NAMESPACE);

  // --- Creative LUT (main slot) ---
  const [lutName, setLutName] = useState<string | null>(null);
  const [intensity, setIntensity] = useState(1.0);
  const [error, setError] = useState<string | null>(null);

  const lut2Ref = useRef<{ data: Float32Array; size: number } | null>(null);
  const lut1Ref = useRef<{ data: Float32Array; size: number } | null>(null);

  // --- Log Conversion (open by default) ---
  const [logOpen, setLogOpen] = useState(true);
  const [logLutName, setLogLutName] = useState<string | null>(null);
  const [logIntensity, setLogIntensity] = useState(1.0);
  const [logError, setLogError] = useState<string | null>(null);
  /**
   * Tracks the active built-in source-profile catalog id (or "none" when
   * Rec.709/cleared, "custom" when a user `.cube` is loaded). Drives chip
   * `aria-pressed` styling and survives sidecar restore.
   */
  const [sourceProfileSelection, setSourceProfileSelection] = useState<
    "none" | "custom" | string
  >("none");

  const pickCubeFile = useCallback(
    (
      onSuccess: (
        lut: { data: Float32Array; size: number; title: string },
        fileName: string,
      ) => void,
      onError: (msg: string) => void,
    ) => {
      if (!viewport) {
        onError("Viewport not ready");
        return;
      }
      const input = document.createElement("input");
      input.type = "file";
      input.onchange = async () => {
        const file = input.files?.[0];
        if (!file) return;
        if (!file.name.endsWith(".cube")) {
          onError("Only .cube files are supported");
          return;
        }
        try {
          const text = await file.text();
          const lut = parseCube(text);
          onSuccess(lut, file.name);
        } catch (err) {
          console.error("LUT load failed:", err);
          onError("Failed to load LUT");
        }
      };
      input.click();
    },
    [viewport],
  );

  // ── Creative LUT handlers ──

  /** 両スロットの最新状態を親へ通知 */
  const fireLutChange = useCallback(
    (patch: {
      lut2?: Lut2ChangePayload | null;
      lut1?: Lut1ChangePayload | null;
    }) => {
      if (!onLutChange) return;
      const c2 = lut2Ref.current;
      const c1 = lut1Ref.current;
      const lut1Default: Lut1ChangePayload | null = c1
        ? {
            name: logLutName ?? "",
            data: c1.data,
            size: c1.size,
            intensity: logIntensity,
            sourceProfileId:
              sourceProfileSelection !== "none" &&
              sourceProfileSelection !== "custom"
                ? sourceProfileSelection
                : null,
          }
        : null;
      const lut2Default: Lut2ChangePayload | null = c2
        ? { name: lutName ?? "", data: c2.data, size: c2.size, intensity }
        : null;
      onLutChange({
        lut2: "lut2" in patch ? patch.lut2! : lut2Default,
        lut1: "lut1" in patch ? patch.lut1! : lut1Default,
      });
    },
    [
      onLutChange,
      lutName,
      intensity,
      logLutName,
      logIntensity,
      sourceProfileSelection,
    ],
  );

  const handleLoad = useCallback(() => {
    setError(null);
    pickCubeFile(
      (lut, fileName) => {
        viewport!.setLUT2(lut.data, lut.size);
        const name = lut.title || fileName;
        lut2Ref.current = { data: lut.data, size: lut.size };
        setLutName(name);
        setError(null);
        onCubeLutLoaded?.();
        fireLutChange({ lut2: { name, data: lut.data, size: lut.size, intensity } });
      },
      setError,
    );
  }, [viewport, pickCubeFile, onCubeLutLoaded, fireLutChange, intensity]);

  const handleClear = useCallback(() => {
    viewport?.clearLUT2();
    lut2Ref.current = null;
    setLutName(null);
    setIntensity(1.0);
    setError(null);
    fireLutChange({ lut2: null });
  }, [viewport, fireLutChange]);

  const handleIntensity = useCallback(
    (value: number) => {
      setIntensity(value);
      viewport?.setLUT2Intensity(value);
      const d = lut2Ref.current;
      if (d) fireLutChange({ lut2: { name: lutName ?? "", data: d.data, size: d.size, intensity: value } });
    },
    [viewport, fireLutChange, lutName],
  );

  // ── Log Conversion handlers ──

  const handleLogLoad = useCallback(() => {
    setLogError(null);
    pickCubeFile(
      (lut, fileName) => {
        viewport!.setLUT1(lut.data, lut.size);
        const name = lut.title || fileName;
        lut1Ref.current = { data: lut.data, size: lut.size };
        setLogLutName(name);
        setLogError(null);
        setSourceProfileSelection("custom");
        onCubeLutLoaded?.();
        if (!logOpen) setLogOpen(true);
        fireLutChange({
          lut1: {
            name,
            data: lut.data,
            size: lut.size,
            intensity: logIntensity,
            sourceProfileId: null,
          },
        });
      },
      setLogError,
    );
  }, [viewport, pickCubeFile, onCubeLutLoaded, logOpen, fireLutChange, logIntensity]);

  const handleLogClear = useCallback(() => {
    viewport?.clearLUT1();
    lut1Ref.current = null;
    setLogLutName(null);
    setLogIntensity(1.0);
    setLogError(null);
    setSourceProfileSelection("none");
    fireLutChange({ lut1: null });
  }, [viewport, fireLutChange]);

  const handleLogIntensity = useCallback(
    (value: number) => {
      setLogIntensity(value);
      viewport?.setLUT1Intensity(value);
      const d = lut1Ref.current;
      if (d) {
        const builtIn =
          sourceProfileSelection !== "none" &&
          sourceProfileSelection !== "custom"
            ? sourceProfileSelection
            : null;
        fireLutChange({
          lut1: {
            name: logLutName ?? "",
            data: d.data,
            size: d.size,
            intensity: value,
            sourceProfileId: builtIn,
          },
        });
      }
    },
    [viewport, fireLutChange, logLutName, sourceProfileSelection],
  );

  /**
   * Apply a built-in Camera Profile selection. Rec.709 / "none" clears
   * the renderer's lut1 (nilProfile) but still records the explicit
   * selection so sidecar metadata round-trips. Other built-ins generate
   * the cube via shared core math and upload it to the viewport.
   */
  const handleSourceProfileSelect = useCallback(
    (catalogId: string | "none") => {
      if (!viewport) {
        setLogError("Viewport not ready");
        return;
      }
      setLogError(null);
      if (catalogId === "none" || catalogId === REC709_PROFILE_ID) {
        viewport.clearLUT1();
        lut1Ref.current = null;
        setLogLutName(null);
        setLogIntensity(1.0);
        setSourceProfileSelection(
          catalogId === "none" ? "none" : REC709_PROFILE_ID,
        );
        fireLutChange({ lut1: null });
        return;
      }
      const built = buildSourceProfileLut(catalogId);
      if (!built) {
        setLogError(`Unknown camera profile: ${catalogId}`);
        return;
      }
      viewport.setLUT1(built.data, built.size);
      viewport.setLUT1Intensity(1.0);
      lut1Ref.current = { data: built.data, size: built.size };
      setLogLutName(built.displayName);
      setLogIntensity(1.0);
      setSourceProfileSelection(catalogId);
      if (!logOpen) setLogOpen(true);
      fireLutChange({
        lut1: {
          name: built.displayName,
          data: built.data,
          size: built.size,
          intensity: 1.0,
          sourceProfileId: catalogId,
        },
      });
    },
    [viewport, fireLutChange, logOpen],
  );

  const noneActive = sourceProfileSelection === "none";
  const rec709Active = sourceProfileSelection === REC709_PROFILE_ID;

  return (
    <div className="mb-4">
      {/* ── Section header ── */}
      <h3 className="mb-2 mt-3 text-[10px] font-medium uppercase tracking-[0.15em] text-white/40 first:mt-0">
        LUT
      </h3>

      {/* ── Creative LUT: main slot（内側 Inset は Log と同じ p-4、ボタンは py-2 で枠に貼り付かない） ── */}
      <div className="rounded-lg border border-white/[0.08] bg-white/[0.02] p-4">
        <div className="flex min-h-10 items-center gap-3">
          <button
            type="button"
            onClick={handleLoad}
            disabled={!viewport}
            className="shrink-0 rounded-md bg-white/5 px-3 py-2 text-[11px] leading-tight text-white/60 transition-colors hover:bg-white/10 hover:text-white/80 disabled:cursor-not-allowed disabled:opacity-30"
          >
            Load .cube
          </button>
          {lutName ? (
            <>
              <span className="min-w-0 flex-1 truncate py-1 font-mono text-[10px] text-[var(--accent-amber1)]">
                {lutName}
              </span>
              <button
                type="button"
                onClick={handleClear}
                className="shrink-0 rounded-md px-2 py-2 text-[10px] text-white/30 transition-colors hover:bg-white/[0.06] hover:text-white/60"
              >
                Clear
              </button>
            </>
          ) : (
            <span className="py-1 text-[10px] leading-snug text-white/25">
              Film look / creative grade
            </span>
          )}
        </div>

        {error && (
          <p className="mt-3 text-[10px] text-red-400">{error}</p>
        )}

        <div className="mt-4">
          <ControlSlider
            label={tFilmLab("lutPanel.creativeMix")}
            hint={!lutName ? tFilmLab("lutPanel.creativeMixDisabledHint") : undefined}
            labelResetHint={tFilmLab("controls.sliderLabelReset")}
            value={intensity}
            min={0}
            max={1}
            step={0.01}
            defaultValue={1}
            onChange={handleIntensity}
            disabled={!lutName || !viewport}
          />
        </div>
      </div>

      {/* ── Log Conversion: advanced slot（見出しとカードの間は gap、カード内は四方同じ p-4） ── */}
      <div className="mt-3 flex flex-col gap-3">
        <button
          type="button"
          className="flex w-full items-center gap-1.5 rounded-md px-1 py-2 text-left text-[10px] font-medium uppercase tracking-[0.15em] text-white/40 transition-colors hover:bg-white/[0.03] hover:text-white/60"
          onClick={() => setLogOpen(!logOpen)}
        >
          <span
            className={`text-[8px] transition-transform duration-150 ${logOpen ? "rotate-90" : ""}`}
          >
            &#9654;
          </span>
          Log Conversion
          {/* Active dot when collapsed + LUT loaded */}
          {!logOpen && logLutName && (
            <span className="ml-auto flex items-center gap-1.5 font-mono text-[9px] normal-case tracking-normal text-[var(--accent-amber1)]/70">
              <span className="inline-block h-1.5 w-1.5 rounded-full bg-[var(--accent-amber1)]" />
              {logLutName}
            </span>
          )}
        </button>

        {logOpen && (
          <div className="rounded-lg border border-white/[0.08] bg-white/[0.02] p-4">
            <p className="mb-3 text-[10px] leading-relaxed text-white/35">
              {tFilmLab("lutPanel.cameraProfileHelp")}
            </p>

            {/* Built-in Camera Profile chip selector. None / Rec.709 + manual curves. */}
            <div className="mb-4 flex flex-wrap gap-1.5">
              <button
                type="button"
                aria-pressed={noneActive}
                disabled={!viewport}
                onClick={() => handleSourceProfileSelect("none")}
                className={chipClass(noneActive)}
              >
                {tFilmLab("lutPanel.cameraProfileNone")}
              </button>
              <button
                type="button"
                aria-pressed={rec709Active}
                disabled={!viewport}
                onClick={() => handleSourceProfileSelect(REC709_PROFILE_ID)}
                className={chipClass(rec709Active)}
              >
                Rec.709
              </button>
              {SOURCE_PROFILE_CHIP_ORDER.map((id) => {
                const entry = findCatalog(id);
                if (!entry) return null;
                const active = sourceProfileSelection === id;
                return (
                  <button
                    key={id}
                    type="button"
                    aria-pressed={active}
                    disabled={!viewport}
                    onClick={() => handleSourceProfileSelect(id)}
                    className={chipClass(active)}
                  >
                    {entry.displayName}
                  </button>
                );
              })}
            </div>

            <div className="flex min-h-10 items-center gap-3">
              <button
                type="button"
                onClick={handleLogLoad}
                disabled={!viewport}
                className="shrink-0 rounded-md bg-white/5 px-3 py-2 text-[11px] leading-tight text-white/60 transition-colors hover:bg-white/10 hover:text-white/80 disabled:cursor-not-allowed disabled:opacity-30"
              >
                {tFilmLab("lutPanel.cameraProfileCustom")}
              </button>
              {logLutName ? (
                <>
                  <span className="min-w-0 flex-1 truncate py-1 font-mono text-[10px] text-[var(--accent-amber1)]">
                    {logLutName}
                  </span>
                  <button
                    type="button"
                    onClick={handleLogClear}
                    className="shrink-0 rounded-md px-2 py-2 text-[10px] text-white/30 transition-colors hover:bg-white/[0.06] hover:text-white/60"
                  >
                    Clear
                  </button>
                </>
              ) : (
                <span className="py-1 text-[10px] leading-snug text-white/25">
                  S-Log3, V-Log, Apple Log ...
                </span>
              )}
            </div>

            {logError && (
              <p className="mt-3 text-[10px] text-red-400">{logError}</p>
            )}

            <div className="mt-3.5">
              <ControlSlider
                label={tFilmLab("lutPanel.logMix")}
                hint={!logLutName ? tFilmLab("lutPanel.logMixDisabledHint") : undefined}
                labelResetHint={tFilmLab("controls.sliderLabelReset")}
                value={logIntensity}
                min={0}
                max={1}
                step={0.01}
                defaultValue={1}
                onChange={handleLogIntensity}
                disabled={!logLutName || !viewport}
              />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function chipClass(active: boolean): string {
  return [
    "h-7 min-w-12 rounded-md border px-2 text-center text-[10px] font-semibold leading-none transition-colors disabled:cursor-not-allowed disabled:opacity-30",
    active
      ? "border-[var(--accent-amber1)]/70 bg-[var(--accent-amber1)]/16 text-[var(--accent-amber1)] shadow-[0_0_0_1px_rgba(255,200,69,0.18)]"
      : "border-white/[0.09] bg-white/[0.03] text-white/68 hover:border-white/[0.16] hover:bg-white/[0.06] hover:text-white/88",
  ].join(" ");
}
