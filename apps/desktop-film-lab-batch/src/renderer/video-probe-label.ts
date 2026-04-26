import type { CameraOptics } from "film-lab-core";

export interface CameraOpticsSourceLabels {
  metadata: string;
  assumed: string;
  manual: string;
}

const DEFAULT_SOURCE_LABELS: CameraOpticsSourceLabels = {
  metadata: "metadata",
  assumed: "assumed",
  manual: "manual",
};

export function formatCameraOpticsForProbeLabel(
  optics: CameraOptics | null | undefined,
  sourceLabels: CameraOpticsSourceLabels = DEFAULT_SOURCE_LABELS,
): string {
  if (!optics) {
    return "camera ?";
  }

  const cameraName = [optics.cameraMake, optics.cameraModel]
    .filter(
      (value): value is string =>
        typeof value === "string" && value.trim().length > 0,
    )
    .join(" ");
  const parts: string[] = [];
  if (cameraName) parts.push(cameraName);
  if (optics.lensModel) parts.push(optics.lensModel);
  if (
    typeof optics.focalLength35mm === "number" &&
    Number.isFinite(optics.focalLength35mm)
  ) {
    parts.push(`${Number(optics.focalLength35mm.toFixed(1))}mm eq`);
  }
  if (typeof optics.fovXDeg === "number" && Number.isFinite(optics.fovXDeg)) {
    parts.push(`HFOV ${Number(optics.fovXDeg.toFixed(1))}deg`);
  }
  parts.push(sourceLabels[optics.source] ?? optics.source);
  return parts.join(" · ");
}
