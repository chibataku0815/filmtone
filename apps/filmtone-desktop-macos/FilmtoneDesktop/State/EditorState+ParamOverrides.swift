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

    // MARK: - M5-H.2 Recipe application

    /// Resolve preset + look + strength + Quick **without** the
    /// `paramOverrides` patch. iOS recipe closures take this as their
    /// `base` argument so `max(base.bloomStrength, 0.34)` reads against
    /// the canonical preset value rather than whatever the user has
    /// already moved a slider to.
    func resolvedBaseWithoutOverrides() -> FilmtonePhase0Params {
        FilmtonePresetCatalog.resolved(
            presetName: presetName,
            strength: presetStrength,
            lookSlug: lookSlug,
            quickState: quickState,
            paramOverrides: .empty
        )
    }

    /// Apply a recipe chip selection. The recipe owns every key in its
    /// group: keys returned by the closure overwrite (clamped) and keys
    /// the closure omits drop back to base — chip selection is a group
    /// preset, not an additive overlay.
    ///
    /// `none` recipes (the iOS canonical clear-group chip) short-circuit
    /// to `clearGroupOverrides`.
    func applyAdvancedRecipe(_ recipe: AdvancedAdjustCatalog.Recipe,
                              in group: AdvancedAdjustCatalog.Group) {
        if recipe.kind == .none {
            clearGroupOverrides(in: group)
            return
        }
        let base = resolvedBaseWithoutOverrides()
        let recipeValues = recipe.values(base)
        var next = paramOverrides.values
        for control in group.controls {
            if let value = recipeValues[control.key] {
                next[control.key] = AdvancedAdjustCatalog.clamp(value, for: control.key)
            } else {
                next.removeValue(forKey: control.key)
            }
        }
        paramOverrides = FilmtonePhase0ParamsPatch(values: next)
    }

    /// Drop overrides for every key in `group`. Drives the recipe row's
    /// `none` chip and any future per-group reset button.
    func clearGroupOverrides(in group: AdvancedAdjustCatalog.Group) {
        var next = paramOverrides.values
        var changed = false
        for control in group.controls where next[control.key] != nil {
            next.removeValue(forKey: control.key)
            changed = true
        }
        guard changed else { return }
        paramOverrides = FilmtonePhase0ParamsPatch(values: next)
    }

    /// Best-match recipe for the current overrides — used to highlight a
    /// chip as "active". A chip matches when, for every control in its
    /// group, the override (or base if absent) matches the recipe value
    /// (or absence) within `tolerance`. The first matching `.stamp`
    /// wins; if none match and the group has no overrides, the `.none`
    /// chip wins (mirrors iOS's "currently neutral" cue).
    func activeRecipeId(in group: AdvancedAdjustCatalog.Group,
                         tolerance: Double = 1e-4) -> String? {
        let base = resolvedBaseWithoutOverrides()
        let groupHasOverride = group.controls.contains { isParamOverridden($0.key) }
        if !groupHasOverride {
            return group.recipes.first(where: { $0.kind == .none })?.id
        }
        for recipe in group.recipes where recipe.kind == .stamp {
            let recipeValues = recipe.values(base)
            var matches = true
            for control in group.controls {
                let target: Double
                if let recipeValue = recipeValues[control.key] {
                    target = AdvancedAdjustCatalog.clamp(recipeValue, for: control.key)
                } else {
                    // Recipe omits this key → expect base (no override).
                    if isParamOverridden(control.key) {
                        matches = false
                        break
                    }
                    continue
                }
                let actual = effectiveParamValue(for: control.key)
                if abs(actual - target) > tolerance {
                    matches = false
                    break
                }
            }
            if matches { return recipe.id }
        }
        return nil
    }
}
