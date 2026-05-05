import FilmLabSwiftCore
import SwiftUI

// M5-C.3b: Popover content for the right-rail "Adjust…" button. Direct
// per-key editing of `paramOverrides` matching the iOS canonical
// `FilmtoneStrengthSheet` advanced section. DisclosureGroup × N
// categories, each with rows of (label, value, slider, per-row reset).
// The popover frame is sized once (480×600) so the user can scroll
// through the full catalog without the window jumping.
//
// M5-I.1: every user-facing string flows through `FilmtoneDesktopStrings`
// so JA/EN host locale picks up the iOS canonical 階調 / なし / 標準 /
// 強め / 爽やか / 夕景 / 深み labels without per-call branching here.
struct AdvancedAdjustEditor: View {
    @Bindable var state: EditorState
    var strings: FilmtoneDesktopStrings = .current
    var onClose: () -> Void

    @State private var expandedGroupIds: Set<String> = ["basic"]

    private var groups: [AdvancedAdjustCatalog.Group] {
        AdvancedAdjustCatalog.groups(forVideo: state.sourceKind == .video, strings: strings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
            Divider()
                .background(Color.white.opacity(0.10))
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(groups) { group in
                        groupSection(group)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            Divider()
                .background(Color.white.opacity(0.10))
            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 480, height: 600)
        .background(Color.black.opacity(0.55))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(strings.advancedTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Text(activeBadge)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help(strings.advancedClose)
        }
    }

    private var activeBadge: String {
        let active = state.paramOverridesActiveCount
        let total = state.paramOverridesAvailableCount
        return strings.advancedActiveBadgeFormat(active, total)
    }

    @ViewBuilder
    private func groupSection(_ group: AdvancedAdjustCatalog.Group) -> some View {
        let isExpanded = Binding(
            get: { expandedGroupIds.contains(group.id) },
            set: { open in
                if open { expandedGroupIds.insert(group.id) }
                else { expandedGroupIds.remove(group.id) }
            }
        )
        let activeInGroup = group.controls.filter { state.isParamOverridden($0.key) }.count

        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if !group.recipes.isEmpty {
                    recipeChipRow(for: group)
                }
                ForEach(group.controls) { control in
                    paramRow(control)
                }
            }
            .padding(.top, 8)
            .padding(.leading, 4)
        } label: {
            HStack(spacing: 8) {
                Text(group.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                Text("(\(group.controls.count))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                if activeInGroup > 0 {
                    Text("\(activeInGroup) on")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.85), in: Capsule())
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func recipeChipRow(for group: AdvancedAdjustCatalog.Group) -> some View {
        let activeId = state.activeRecipeId(in: group)
        HStack(spacing: 8) {
            ForEach(group.recipes) { recipe in
                recipeChip(recipe, in: group, isActive: recipe.id == activeId)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func recipeChip(_ recipe: AdvancedAdjustCatalog.Recipe,
                              in group: AdvancedAdjustCatalog.Group,
                              isActive: Bool) -> some View {
        let helpText = recipe.kind == .none
            ? strings.advancedClearGroupHelp(group.title)
            : strings.advancedApplyRecipeHelp(recipe.label, group.title)
        // SwiftUI button styles don't share a common erased type, so a
        // ternary on the modifier is not allowed — branch the View tree
        // instead. Both arms keep the same label / action / size so only
        // the visual posture differs (.glassProminent for active).
        if isActive {
            Button {
                state.applyAdvancedRecipe(recipe, in: group)
            } label: {
                Text(recipe.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .help(helpText)
        } else {
            Button {
                state.applyAdvancedRecipe(recipe, in: group)
            } label: {
                Text(recipe.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help(helpText)
        }
    }

    @ViewBuilder
    private func paramRow(_ control: AdvancedAdjustCatalog.Control) -> some View {
        let isActive = state.isParamOverridden(control.key)
        let valueBinding = Binding(
            get: { state.effectiveParamValue(for: control.key) },
            set: { state.setParamOverride($0, for: control.key) }
        )

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if isActive {
                    Circle()
                        .fill(Color.yellow.opacity(0.85))
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 6, height: 6)
                }
                Text(control.label)
                    .font(.callout)
                    .foregroundStyle(.white)
                Spacer()
                Text(AdvancedAdjustCatalog.formatValue(valueBinding.wrappedValue, digits: control.digits))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(minWidth: 48, alignment: .trailing)
                Button {
                    state.clearParamOverride(for: control.key)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.medium))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(!isActive)
                .help(strings.advancedResetParamHelp(control.label))
            }
            Slider(value: valueBinding, in: control.range)
                .tint(.white)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            Button {
                state.clearAllParamOverrides()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(strings.advancedResetAllOverrides)
                }
            }
            .buttonStyle(.glass)
            .controlSize(.regular)
            .disabled(state.paramOverridesActiveCount == 0)
        }
    }
}
