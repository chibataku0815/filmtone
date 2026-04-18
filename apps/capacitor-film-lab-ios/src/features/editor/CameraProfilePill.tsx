import { useEffect, useState } from "react";

export type CameraProfile =
  | "auto"
  | "rec709"
  | "apple-log"
  | "slog3"
  | "vlog"
  | "custom";

export interface CameraProfilePillProps {
  active: CameraProfile;
  customLutTitle?: string;
  onSelect: (profile: CameraProfile) => void;
  onPickCustomLut: () => void;
  cameraLabel: string;
  profileLabels: Record<CameraProfile, string>;
  /** Optional whitelist; defaults to all 6 profiles. v1.0 surface uses ["auto","custom"]. */
  profiles?: ReadonlyArray<CameraProfile>;
}

const DEFAULT_PROFILE_ORDER: CameraProfile[] = [
  "auto",
  "rec709",
  "apple-log",
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
        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full glass-panel border border-white/12 text-[11px] text-white hover:bg-white/[0.06]"
      >
        <span className="text-[10px] uppercase tracking-[0.12em] text-[var(--text-muted)]">
          {cameraLabel}
        </span>
        <span className="text-[11px] text-white">{activeLabel}</span>
        <svg
          width="12"
          height="12"
          viewBox="0 0 12 12"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          aria-hidden="true"
          className="text-white/70"
        >
          <path
            d="M3 4.5L6 7.5L9 4.5"
            stroke="currentColor"
            strokeWidth="1.4"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>

      {mounted && (
        <>
          <div
            className={`fixed inset-0 z-30 bg-black/40 transition-opacity duration-200 ease-out ${
              open ? "opacity-100" : "opacity-0"
            }`}
            onClick={() => setOpen(false)}
            aria-hidden="true"
          />
          <div
            role="dialog"
            aria-modal="true"
            className={`fixed bottom-0 left-0 right-0 z-40 glass-panel border-t border-white/12 rounded-t-[28px] p-5 pb-8 transition-transform duration-200 ease-out ${
              open ? "translate-y-0" : "translate-y-full"
            }`}
          >
            <div className="flex justify-center mb-3">
              <span className="block w-9 h-1 rounded-full bg-white/20" />
            </div>
            <div className="section-header mb-2">{cameraLabel}</div>
            <ul className="flex flex-col">
              {visibleProfiles.map((profile) => {
                const isActive = profile === active;
                const label =
                  profile === "custom" && customLutTitle && isActive
                    ? customLutTitle
                    : profileLabels[profile];
                return (
                  <li key={profile}>
                    <button
                      type="button"
                      onClick={() => handleRowClick(profile)}
                      className="w-full flex items-center justify-between py-3 text-sm text-white border-b border-white/[0.06] last:border-b-0 active:bg-white/[0.06]"
                    >
                      <span>{label}</span>
                      {isActive && (
                        <span
                          className="text-[var(--accent-amber1)] text-base"
                          aria-label="selected"
                        >
                          ✓
                        </span>
                      )}
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
