/**
 * LUT library manager (M3).
 *
 * Fullscreen modal that lists imported .cube files with import / rename /
 * delete actions, plus a tap-to-activate flow. The active LUT is rendered
 * with an amber badge.
 */

import { useState, useEffect } from "react";
import type { ImportedLut } from "@/lib/phase0-storage";

interface LutManagerStrings {
  lutManagerTitle: string;
  lutManagerEmpty: string;
  lutManagerImport: string;
  lutManagerActiveBadge: string;
  lutManagerRename: string;
  lutManagerDelete: string;
  lutManagerClose: string;
}

interface LutManagerModalProps {
  isOpen: boolean;
  onClose: () => void;
  imports: readonly ImportedLut[];
  activeLutId: string | null;
  onPickFreshLut: () => void | Promise<void>;
  onActivateLut: (id: string) => void;
  onDeactivateLut: () => void;
  onRenameLut: (id: string, name: string) => void;
  onDeleteLut: (id: string) => void;
  strings: LutManagerStrings;
}

export function LutManagerModal({
  isOpen,
  onClose,
  imports,
  activeLutId,
  onPickFreshLut,
  onActivateLut,
  onDeactivateLut,
  onRenameLut,
  onDeleteLut,
  strings,
}: LutManagerModalProps) {
  const [renamingId, setRenamingId] = useState<string | null>(null);
  const [draftName, setDraftName] = useState("");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    if (isOpen) {
      setMounted(true);
      return;
    }
    const timer = setTimeout(() => {
      setMounted(false);
      setRenamingId(null);
      setDraftName("");
    }, 200);
    return () => clearTimeout(timer);
  }, [isOpen]);

  if (!mounted && !isOpen) return null;

  function commitRename(id: string) {
    const trimmed = draftName.trim();
    if (trimmed.length > 0) {
      onRenameLut(id, trimmed);
    }
    setRenamingId(null);
    setDraftName("");
  }

  function cancelRename() {
    setRenamingId(null);
    setDraftName("");
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={strings.lutManagerTitle}
      className={[
        "fixed inset-0 z-50 transition-opacity duration-200",
        isOpen ? "opacity-100 pointer-events-auto" : "opacity-0 pointer-events-none",
      ].join(" ")}
    >
      <div
        className="absolute inset-0 bg-black/55 backdrop-blur-md"
        onClick={onClose}
        aria-hidden="true"
      />
      <div
        className={[
          "absolute inset-x-0 bottom-0 top-[calc(env(safe-area-inset-top,0px)+24px)]",
          "flex flex-col glass-panel border-t border-white/12 rounded-t-[28px] overflow-hidden",
          "transition-transform duration-200 ease-out",
          isOpen ? "translate-y-0" : "translate-y-full",
        ].join(" ")}
      >
        <header className="flex items-center justify-between px-5 pt-4 pb-3 border-b border-white/[0.06]">
          <div>
            <p className="section-header">{strings.lutManagerTitle}</p>
            <p className="mt-1 text-[11px] text-[var(--text-muted)]">
              {imports.length}
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="text-sm text-[var(--accent-amber1)] font-medium px-3 py-1 rounded-full hover:bg-white/[0.06]"
          >
            {strings.lutManagerClose}
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-5 py-4">
          {imports.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full gap-4 text-center px-6 py-10">
              <p className="text-sm text-[var(--text-base-70)] leading-6 max-w-xs">
                {strings.lutManagerEmpty}
              </p>
              <button
                type="button"
                onClick={() => onPickFreshLut()}
                className="rounded-full bg-[var(--accent-amber1)] px-5 py-2.5 text-xs font-medium text-black"
              >
                {strings.lutManagerImport}
              </button>
            </div>
          ) : (
            <ul className="flex flex-col gap-1">
              {imports.map((entry) => {
                const isActive = entry.id === activeLutId;
                const isRenaming = renamingId === entry.id;
                return (
                  <li
                    key={entry.id}
                    className="rounded-2xl border border-white/[0.06] bg-white/[0.02] p-3"
                  >
                    {isRenaming ? (
                      <div className="flex items-center gap-2">
                        <input
                          autoFocus
                          value={draftName}
                          onChange={(event) => setDraftName(event.target.value)}
                          onKeyDown={(event) => {
                            if (event.key === "Enter") commitRename(entry.id);
                            if (event.key === "Escape") cancelRename();
                          }}
                          className="flex-1 bg-transparent border-b border-white/30 text-sm text-white py-1 outline-none focus:border-[var(--accent-amber1)]"
                        />
                        <button
                          type="button"
                          onClick={() => commitRename(entry.id)}
                          className="text-xs text-[var(--accent-amber1)] px-2 py-1"
                        >
                          OK
                        </button>
                      </div>
                    ) : (
                      <>
                        <div className="flex items-center justify-between gap-3">
                          <button
                            type="button"
                            onClick={() => {
                              if (isActive) onDeactivateLut();
                              else onActivateLut(entry.id);
                            }}
                            className="flex-1 text-left"
                          >
                            <div className="flex items-center gap-2">
                              <span className="text-sm text-white truncate max-w-[60%]">
                                {entry.name}
                              </span>
                              {isActive ? (
                                <span className="text-[9px] uppercase tracking-[0.16em] text-[var(--accent-amber1)] border border-[var(--accent-amber1)]/40 rounded-full px-2 py-0.5">
                                  {strings.lutManagerActiveBadge}
                                </span>
                              ) : null}
                            </div>
                            <div className="mt-1 text-[10px] text-[var(--text-muted)]">
                              {entry.lut.size}³ ·{" "}
                              {new Date(entry.importedAt).toLocaleDateString()}
                            </div>
                          </button>
                          <div className="flex items-center gap-1">
                            <button
                              type="button"
                              onClick={() => {
                                setRenamingId(entry.id);
                                setDraftName(entry.name);
                              }}
                              className="text-[10px] uppercase tracking-[0.12em] text-[var(--text-base-70)] px-2 py-1 rounded-full hover:bg-white/[0.06] hover:text-white"
                            >
                              {strings.lutManagerRename}
                            </button>
                            <button
                              type="button"
                              onClick={() => onDeleteLut(entry.id)}
                              className="text-[10px] uppercase tracking-[0.12em] text-rose-300/80 px-2 py-1 rounded-full hover:bg-rose-500/10 hover:text-rose-200"
                            >
                              {strings.lutManagerDelete}
                            </button>
                          </div>
                        </div>
                      </>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        {imports.length > 0 ? (
          <footer className="px-5 pb-[calc(env(safe-area-inset-bottom,0px)+12px)] pt-3 border-t border-white/[0.06]">
            <button
              type="button"
              onClick={() => onPickFreshLut()}
              className="w-full rounded-full bg-[var(--accent-amber1)] px-5 py-3 text-xs font-medium text-black"
            >
              {strings.lutManagerImport}
            </button>
          </footer>
        ) : null}
      </div>
    </div>
  );
}
