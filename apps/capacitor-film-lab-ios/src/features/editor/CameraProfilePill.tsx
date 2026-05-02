import { useEffect, useState } from "react";
import {
  CheckIcon,
  ChevronDownIcon,
} from "@/components/FilmtoneIcons";

export type CameraProfile =
  | "auto"
  | "rec709"
  | "apple-log"
  | "dji-dlog"
  | "canon-clog"
  | "slog3"
  | "vlog"
  | "custom";

export interface CameraProfilePillProps {
  active: CameraProfile;
  customLutTitle?: string;
  onSelect: (profile: CameraProfile) => void;
  onPickCustomLut: () => void;
  cameraLabel: string;
  description: string;
  closeLabel: string;
  profileLabels: Record<CameraProfile, string>;
  /** Optional whitelist; defaults to all 6 profiles. v1.0 surface uses ["auto","custom"]. */
  profiles?: ReadonlyArray<CameraProfile>;
}

const DEFAULT_PROFILE_ORDER: CameraProfile[] = [
  "auto",
  "rec709",
  "apple-log",
  "dji-dlog",
  "canon-clog",
  "slog3",
  "vlog",
  "custom",
];

export function CameraProfilePill({
  active,
  customLutTitle,
  onSelect,
  onPickCustomLut,
  cameraLabel,
  description,
  closeLabel,
  profileLabels,
  profiles,
}: CameraProfilePillProps) {
  const visibleProfiles = profiles ?? DEFAULT_PROFILE_ORDER;
  const [open, setOpen] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    if (open) {
      setMounted(true);
    } else {
      const t = setTimeout(() => setMounted(false), 200);
      return () => clearTimeout(t);
    }
    return undefined;
  }, [open]);

  const activeLabel =
    active === "custom" && customLutTitle
      ? customLutTitle
      : profileLabels[active];

  const handleRowClick = (profile: CameraProfile) => {
    if (profile === "custom") {
      onPickCustomLut();
      setOpen(false);
      return;
    }
    onSelect(profile);
    setOpen(false);
  };

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="group w-full squircle-lg bg-white/[0.02] p-4 text-left shadow-panel transition-transform active:scale-[0.98]"
      >
        <div className="flex items-baseline justify-between gap-3">
          <div className="min-w-0 flex items-baseline gap-2">
            <p className="truncate text-[1.1rem] font-semibold tracking-[-0.02em] text-white">
              {activeLabel}
            </p>
            <span className="text-[11px] text-white/50">{cameraLabel}</span>
          </div>
          <ChevronDownIcon className="h-5 w-5 shrink-0 text-white/56" />
        </div>
      </button>

      {mounted && (
        <>
          <div
            className={`fixed inset-0 z-30 bg-black/55 backdrop-blur-sm transition-opacity duration-200 ease-out ${
              open ? "opacity-100" : "opacity-0"
            }`}
            onClick={() => setOpen(false)}
            aria-hidden="true"
          />
          <div
            role="dialog"
            aria-modal="true"
            aria-label={cameraLabel}
            className={`fixed bottom-0 left-0 right-0 top-[calc(env(safe-area-inset-top,0px)+18px)] z-40 flex flex-col squircle-top-xl px-5 pt-4 liquid-panel-strong transition-transform duration-200 ease-out ${
              open ? "translate-y-0" : "translate-y-full"
            }`}
          >
            <div className="mx-auto mb-4 h-1.5 w-12 rounded-full bg-white/22" />
            <div className="mb-3 flex items-center justify-between gap-3">
              <h2 className="truncate text-[1.3rem] font-semibold tracking-[-0.02em] text-white">
                {activeLabel}
              </h2>
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="min-h-[44px] px-3 text-sm font-medium text-[var(--accent-amber1)] active:opacity-70"
                aria-label={closeLabel}
              >
                {closeLabel}
              </button>
            </div>
            <p className="mb-5 text-sm leading-6 text-[var(--text-base-70)]">
              {description}
            </p>
            <ul className="flex flex-1 flex-col gap-2 overflow-y-auto pb-[calc(env(safe-area-inset-bottom,0px)+18px)]">
              {visibleProfiles.map((profile) => {
                const isActive = profile === active;
                const label =
                  profile === "custom" && customLutTitle && isActive
                    ? customLutTitle
                    : profileLabels[profile];
                const showSecondary =
                  profile === "custom" && !!customLutTitle && !isActive;
                return (
                  <li key={profile}>
                    <button
                      type="button"
                      onClick={() => handleRowClick(profile)}
                      className={[
                        "flex w-full items-center gap-3 squircle-md p-4 text-left transition",
                        isActive
                          ? "bg-[var(--accent-amber1)]/10 text-white"
                          : "bg-white/[0.02] text-white active:bg-white/[0.05]",
                      ].join(" ")}
                    >
                      <span className="min-w-0 flex-1">
                        <span className="block text-sm font-medium text-white">{label}</span>
                        {showSecondary ? (
                          <span className="mt-1 block text-[12px] leading-5 text-[var(--text-base-70)]">
                            {customLutTitle}
                          </span>
                        ) : null}
                      </span>
                      {isActive ? (
                        <CheckIcon className="h-4 w-4 shrink-0 text-[var(--accent-amber1)]" />
                      ) : null}
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>
        </>
      )}
    </>
  );
}

export default CameraProfilePill;
