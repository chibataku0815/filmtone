import Foundation

/// Swift port of Desktop `video-probe-label.ts` (`formatCameraOpticsForProbeLabel`).
///
/// Produces compact (`・` separated) and accessibility-friendly strings from a
/// `CameraOpticsDTO`. Empty fields are skipped so we never render dangling
/// separators. When `cameraMake` is fully contained inside `cameraModel`
/// (common pattern: `"Apple"` + `"Apple iPhone 15 Pro"`), the make is trimmed
/// so the output does not duplicate the vendor name.
///
/// The separator is `・` (U+30FB) for both `ja` and `en` — matches the
/// existing in-app typography for metadata chips and renders well in both
/// locales.
enum FilmtoneCameraOpticsFormatter {
    /// Compact single-line label for preview / export metric chips.
    /// Returns `nil` when no meaningful content is available.
    static func formatCompact(
        _ optics: CameraOpticsDTO?,
        strings: FilmtoneStrings = FilmtoneStringsCatalog.current
    ) -> String? {
        guard let optics else { return nil }

        var parts: [String] = []

        if let cameraName = combinedCameraName(make: optics.cameraMake, model: optics.cameraModel) {
            parts.append(cameraName)
        }

        if let lens = optics.lensModel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lens.isEmpty {
            parts.append(lens)
        }

        if let focal = optics.focalLength35mm,
           focal.isFinite {
            parts.append(String(format: "%.1fmm eq", focal))
        }

        if let fov = optics.fovXDeg, fov.isFinite {
            parts.append(hfovLabel(fov: fov, strings: strings))
        }

        parts.append(sourceLabel(for: optics.source, strings: strings))

        let filtered = parts.filter { !$0.isEmpty }
        guard !filtered.isEmpty else { return nil }
        return filtered.joined(separator: strings.opticsSeparator)
    }

    /// Verbose speech-friendly label used as `.accessibilityLabel(...)`
    /// override. Swaps the `・` separator for `", "` and expands the source
    /// tag ("from metadata" / "assumed defaults") to avoid VoiceOver reading
    /// "metadata" in isolation.
    static func formatAccessibility(
        _ optics: CameraOpticsDTO?,
        strings: FilmtoneStrings = FilmtoneStringsCatalog.current
    ) -> String? {
        guard let optics else { return nil }

        var parts: [String] = []

        if let cameraName = combinedCameraName(make: optics.cameraMake, model: optics.cameraModel) {
            parts.append(cameraName)
        }

        if let lens = optics.lensModel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lens.isEmpty {
            parts.append(lens)
        }

        if let focal = optics.focalLength35mm, focal.isFinite {
            parts.append(String(format: "%.1f millimetres equivalent", focal))
        }

        if let fov = optics.fovXDeg, fov.isFinite {
            parts.append(String(format: "horizontal field of view %.1f degrees", fov))
        }

        parts.append(accessibilitySourceLabel(for: optics.source, strings: strings))

        let filtered = parts.filter { !$0.isEmpty }
        guard !filtered.isEmpty else { return nil }
        return filtered.joined(separator: ", ")
    }

    // MARK: - Helpers

    private static func combinedCameraName(make: String?, model: String?) -> String? {
        let trimmedMake = make?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedModel = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedMake.isEmpty && trimmedModel.isEmpty {
            return nil
        }
        if trimmedMake.isEmpty {
            return trimmedModel
        }
        if trimmedModel.isEmpty {
            return trimmedMake
        }

        // Deduplicate when the model already contains the make, e.g.
        // make="Apple", model="Apple iPhone 15 Pro" → "Apple iPhone 15 Pro".
        if trimmedModel.range(of: trimmedMake, options: [.caseInsensitive]) != nil {
            return trimmedModel
        }

        return "\(trimmedMake) \(trimmedModel)"
    }

    private static func hfovLabel(fov: Double, strings: FilmtoneStrings) -> String {
        let rounded = (fov * 10).rounded() / 10
        let numeric = String(format: "%.1f", rounded)
        return String(
            format: strings.opticsHfovFormat,
            locale: Locale.current,
            arguments: [numeric]
        )
    }

    private static func sourceLabel(for source: String, strings: FilmtoneStrings) -> String {
        switch source {
        case "metadata":
            return strings.opticsSourceMetadata
        case "assumed":
            return strings.opticsSourceAssumed
        default:
            // Pass-through for any future vocabulary; do not invent translations.
            return source
        }
    }

    private static func accessibilitySourceLabel(for source: String, strings: FilmtoneStrings) -> String {
        switch source {
        case "metadata":
            return strings.opticsSourceAccessibilityMetadata
        case "assumed":
            return strings.opticsSourceAccessibilityAssumed
        default:
            return source
        }
    }
}
