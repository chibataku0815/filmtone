import FilmLabSwiftCore
import Foundation

// M5-C.3b: paramOverrides editing surface for AdvancedAdjustEditor.
// Split out of EditorState.swift so the per-key override read / write /
// clear lives on its own responsibility seam — the main EditorState
// declaration stays focused on source / preset / look / quick / export
// state, and the override editing helpers compose against it through
// `paramOverrides` (storage) + `presetParams` (resolved view) + the
// canonical `AdvancedAdjustCatalog` clamp catalog.
extension EditorState {
    /// Resolved param value at `key` after preset → look → strength →
    /// quick → override layering. AdvancedAdjustEditor sliders bind
    /// their `value` getter here so the thumb always shows the visible
    /// result, not just the raw override entry.
    func effectiveParamValue(for key: String) -> Double {
        presetParams.value(for: key)
    }

    /// True when `paramOverrides` carries an explicit value at `key` —
    /// i.e. the slider is acting on top of the layered base, not just
    /// reflecting it.
    func isParamOverridden(_ key: String) -> Bool {
        paramOverrides.values[key] != nil
    }

    /// Number of override entries currently set. Drives the QuickAdjust
    /// override-count chip and the AdvancedAdjustEditor header badge.
    var paramOverridesActiveCount: Int {
        paramOverrides.values.count
    }

    /// Total catalog field count for the active source kind. Used as
    /// the denominator on the "N / M active" badge so the user can see
    /// how many knobs are reachable.
    var paramOverridesAvailableCount: Int {
        AdvancedAdjustCatalog
            .groups(forVideo: sourceKind == .video)
            .reduce(0) { $0 + $1.controls.count }
    }

    /// Write `value` to the override patch at `key`, clamped via the
    /// canonical AdvancedAdjustCatalog range (mirror of iOS
    /// FilmtonePhase0Math.clampParam). Used by the editor's Slider
    /// binding.
    func setParamOverride(_ value: Double, for key: String) {
        let clamped = AdvancedAdjustCatalog.clamp(value, for: key)
        var values = paramOverrides.values
        values[key] = clamped
        paramOverrides = FilmtonePhase0ParamsPatch(values: values)
    }

    /// Drop the override at `key` so the param falls back to whatever
    /// the preset → look → quick layering produces.
    func clearParamOverride(for key: String) {
        guard paramOverrides.values[key] != nil else { return }
        paramOverrides = paramOverrides.removingValue(for: key)
    }

    /// Clear every paramOverrides entry. Drives the popover footer's
    /// "Reset All Overrides" button.
    func clearAllParamOverrides() {
        guard !paramOverrides.isEmpty else { return }
        paramOverrides = .empty
    }
}
