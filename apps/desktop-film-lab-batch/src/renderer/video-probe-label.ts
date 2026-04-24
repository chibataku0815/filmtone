import type { CameraOptics } from "film-lab-core";

export function formatCameraOpticsForProbeLabel(
  optics: CameraOptics | null | undefined,
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
  parts.push(optics.source);
  return parts.join(" · ");
}
