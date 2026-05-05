import FilmLabSwiftCore
import SwiftUI


struct FilmtoneAdvancedParamGroup: Identifiable {
    let id: String
    let title: String
    let recipes: [FilmtoneAdvancedParamRecipe]
    let controls: [FilmtoneAdvancedParamControl]

    var keys: [String] {
        controls.map(\.key)
    }
}

struct FilmtoneAdvancedParamRecipe: Identifiable {
    let id: String
    let label: String
    let values: (FilmtonePhase0Params) -> [String: Double]
}

enum FilmtoneAdvancedRecipeSelection: Equatable {
    case recipe(String)
    case custom(activeCount: Int)
}

struct FilmtoneAdvancedParamControl: Identifiable {
    let key: String
    let label: String
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var id: String { key }
}

struct FilmtoneAdvancedParamGroupSection<Content: View>: View {
    let id: String
    let title: String
    let selection: FilmtoneAdvancedRecipeSelection
    let recipes: [FilmtoneAdvancedParamRecipe]
    let customLabel: String
    let helpAccessibilityLabel: String
    @Binding var isExpanded: Bool
    let onSelectRecipe: (FilmtoneAdvancedParamRecipe) -> Void
    let onHelp: () -> Void
    let content: Content

    private var disclosureAnimation: Animation {
        .smooth(duration: 0.22, extraBounce: 0)
    }

    init(
        id: String,
        title: String,
        selection: FilmtoneAdvancedRecipeSelection,
        recipes: [FilmtoneAdvancedParamRecipe],
        customLabel: String,
        helpAccessibilityLabel: String,
        isExpanded: Binding<Bool>,
        onSelectRecipe: @escaping (FilmtoneAdvancedParamRecipe) -> Void,
        onHelp: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.title = title
        self.selection = selection
        self.recipes = recipes
        self.customLabel = customLabel
        self.helpAccessibilityLabel = helpAccessibilityLabel
        self._isExpanded = isExpanded
        self.onSelectRecipe = onSelectRecipe
        self.onHelp = onHelp
        self.content = content()
    }

    var body: some View {
        let groupShape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Button {
                        withAnimation(disclosureAnimation) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.58))

                                Text(statusText)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(statusColor)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 12)

                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(isExpanded ? 0.88 : 0.62))
                                .frame(width: 28, height: 28)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filmtone.sheet.advanced.group.\(id)")

                    FilmtoneHelpIconButton(
                        accessibilityLabel: helpAccessibilityLabel,
                        accessibilityIdentifier: "filmtone.help.advanced.group.\(id)",
                        action: onHelp
                    )
                    }

                if !recipes.isEmpty {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(recipes) { recipe in
                                FilmtoneParamPresetChip(
                                    label: recipe.label,
                                    isSelected: selection == .recipe(recipe.id),
                                    accessibilityIdentifier: "filmtone.sheet.advanced.group.\(id).\(recipe.id)",
                                    action: {
                                        onSelectRecipe(recipe)
                                    }
                                )
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            if isExpanded {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                content
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
        .clipShape(groupShape)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .animation(disclosureAnimation, value: isExpanded)
        .animation(disclosureAnimation, value: selection)
    }

    private var statusText: String {
        switch selection {
        case .recipe(let id):
            return recipes.first(where: { $0.id == id })?.label ?? customLabel
        case .custom:
            return customLabel
        }
    }

    private var statusColor: Color {
        switch selection {
        case .recipe(let id) where recipes.first?.id == id:
            return .white.opacity(0.74)
        case .recipe, .custom(_):
            return Color.filmtoneAmber.opacity(0.88)
        }
    }
}

private struct FilmtoneParamPresetChip: View {
    let label: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .black.opacity(0.88) : .white.opacity(0.78))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .glassEffect(
                    isSelected ? .regular.tint(Color.filmtoneAmber) : .regular,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

