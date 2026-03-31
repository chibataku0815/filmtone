"use client";

import { useState } from "react";
import { parseCube } from "film-lab-core";
import { ControlSlider } from "./ui/ControlSlider";
import type { Viewport } from "film-lab-renderer";

interface LUTPanelProps {
  viewport: Viewport | null;
  /** .cube の読み込みが成功したとき（寄付バナー用のフック） */
  onCubeLutLoaded?: () => void;
}

export function LUTPanel({ viewport, onCubeLutLoaded }: LUTPanelProps) {
  const [lutName, setLutName] = useState<string | null>(null);
  const [intensity, setIntensity] = useState(1.0);
  const [error, setError] = useState<string | null>(null);

  const handleLoad = () => {
    if (!viewport) {
      setError("Viewport not ready");
      return;
    }
    setError(null);

    const input = document.createElement("input");
    input.type = "file";
    // accept を除去 — .cube はカスタム拡張子のため OS によって表示されない
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) return;

      if (!file.name.endsWith(".cube")) {
        setError("Only .cube files are supported");
        return;
      }

      try {
        const text = await file.text();
        const lut = parseCube(text);
        viewport.setLUT(lut.data, lut.size);
        setLutName(lut.title || file.name);
        setError(null);
        onCubeLutLoaded?.();
      } catch (err) {
        console.error("LUT load failed:", err);
        setError("Failed to load LUT");
      }
    };
    input.click();
  };

  const handleClear = () => {
    viewport?.clearLUT();
    setLutName(null);
    setIntensity(1.0);
    setError(null);
  };

  const handleIntensity = (value: number) => {
    setIntensity(value);
    viewport?.setLUTIntensity(value);
  };

  return (
    <div>
      <h3 className="mb-2 mt-3 text-[10px] font-medium uppercase tracking-[0.15em] text-white/40">
        LUT
      </h3>

      <div className="mb-2.5 flex items-center gap-2">
        <button
          onClick={handleLoad}
          disabled={!viewport}
          className="rounded bg-white/5 px-2.5 py-1 text-[11px] text-white/60 transition-colors hover:bg-white/10 hover:text-white/80 disabled:cursor-not-allowed disabled:opacity-30"
        >
          Load .cube
        </button>
        {lutName && (
          <>
            <span className="flex-1 truncate font-mono text-[10px] text-[var(--accent-amber1)]">
              {lutName}
            </span>
            <button
              onClick={handleClear}
              className="text-[10px] text-white/30 transition-colors hover:text-white/60"
            >
              Clear
            </button>
          </>
        )}
      </div>

      {error && (
        <p className="mb-2 text-[10px] text-red-400">{error}</p>
      )}

      {lutName && (
        <ControlSlider
          label="Intensity"
          value={intensity}
          min={0}
          max={1}
          step={0.01}
          defaultValue={1}
          onChange={handleIntensity}
        />
      )}
    </div>
  );
}
