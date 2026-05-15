import FilmLabSwiftCore
import SwiftUI

// M5-C.3b: Direct per-key editing of `paramOverrides` matching the iOS canonical
// `FilmtoneStrengthSheet` advanced section. Recipe chips stay visible
// at the group level; each group can expand into rows of (label, value,
// slider, per-row reset). The popover frame is sized once (480×600) so the user can scroll
// through the full catalog without the window jumping; the right rail uses
// the same controls inline at 220pt.
//
// M5-I.1: every user-facing string flows through `FilmtoneDesktopStrings`
// so JA/EN host locale picks up the iOS canonical 階調 / なし / 標準 /
// 強め / 爽やか / 夕景 / 深み labels without per-call branching here.
struct AdvancedAdjustEditor: View {
    enum Presentation: Equatable {
        case popover
        case inline
    }

    @Bindable var state: EditorState
    var strings: FilmtoneDesktopStrings = .current
    var presentation: Presentation = .popover
    var onClose: (() -> Void)?

    @State private var expandedGroupIds: Set<String> = []

    init(
        state: EditorState,
        strings: FilmtoneDesktopStrings = .current,
        presentation: Presentation = .popover,
        onClose: (() -> Void)? = nil
    ) {
        self.state = state
        self.strings = strings
        self.presentation = presentation
        self.onClose = onClose
        let expanded = presentation == .inline
            ? Set(AdvancedAdjustCatalog.groups(forVideo: state.sourceKind == .video, strings: strings).map(\.id))
            : []
        self._expandedGroupIds = State(initialValue: expanded)
    }

    private var groups: [AdvancedAdjustCatalog.Group] {
        AdvancedAdjustCatalog.groups(forVideo: state.sourceKind == .video, strings: strings)
    }

    var body: some View {
        switch presentation {
        case .popover:
            popoverBody
        case .inline:
            inlineBody
        }
    }

    private var popoverBody: some View {
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

    private var inlineBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
                .background(Color.white.opacity(0.10))
            VStack(alignment: .leading, spacing: 10) {
                ForEach(groups) { group in
                    groupSection(group)
                }
            }
            Divider()
                .background(Color.white.opacity(0.10))
            footer
        }
        .frame(width: 220, alignment: .leading)
        .preferredColorScheme(.dark)
        .onAppear {
            expandedGroupIds.formUnion(groups.map(\.id))
        }
        .onChange(of: state.sourceKind) { _, _ in
            expandedGroupIds = Set(groups.map(\.id))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(presentation == .inline ? strings.adjustTitle : strings.advancedTitle)
                .font((presentation == .inline ? Font.callout : Font.title3).weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Text(activeBadge)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if presentation == .popover {
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(FilmtoneGlassIconButtonStyle())
                .help(strings.advancedClose)
                .filmtonePointingHandCursor()
            }
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

        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(group.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
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
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.68))
                        .frame(width: 18, height: 18)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .filmtonePointingHandCursor()

            if !group.recipes.isEmpty {
                recipeChipRow(for: group)
                    .padding(.leading, 4)
                    .padding(.bottom, isExpanded.wrappedValue ? 2 : 8)
            }

            if isExpanded.wrappedValue {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(group.controls) { control in
                        paramRow(control)
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func recipeChipRow(for group: AdvancedAdjustCatalog.Group) -> some View {
        let activeId = state.activeRecipeId(in: group)
        if presentation == .inline {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 58), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(group.recipes) { recipe in
                    recipeChip(recipe, in: group, isActive: recipe.id == activeId)
                }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(group.recipes) { recipe in
                    recipeChip(recipe, in: group, isActive: recipe.id == activeId)
                }
                Spacer(minLength: 0)
            }
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
                recipeChipLabel(recipe)
            }
            .buttonStyle(FilmtoneGlassSegmentButtonStyle(isSelected: true))
            .help(helpText)
            .filmtonePointingHandCursor()
        } else {
            Button {
                state.applyAdvancedRecipe(recipe, in: group)
            } label: {
                recipeChipLabel(recipe)
            }
            .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
            .help(helpText)
            .filmtonePointingHandCursor()
        }
    }

    private func recipeChipLabel(_ recipe: AdvancedAdjustCatalog.Recipe) -> some View {
        Text(recipe.label)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 4)
            .frame(maxWidth: presentation == .inline ? .infinity : nil)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
                Text(AdvancedAdjustCatalog.formatValue(valueBinding.wrappedValue, digits: control.digits))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .frame(minWidth: presentation == .inline ? 40 : 48, alignment: .trailing)
                Button {
                    state.clearParamOverride(for: control.key)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.medium))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(FilmtoneGlassIconButtonStyle())
                .disabled(!isActive)
                .help(strings.advancedResetParamHelp(control.label))
                .filmtonePointingHandCursor(isActive)
            }
            FilmtoneGlassSlider(value: valueBinding, range: control.range)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .buttonStyle(FilmtoneGlassSecondaryButtonStyle())
            .disabled(state.paramOverridesActiveCount == 0)
            .filmtonePointingHandCursor(state.paramOverridesActiveCount > 0)
        }
    }
}
