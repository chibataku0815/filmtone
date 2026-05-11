// Filmtone V2 native camera capture — completed-take picker.

import SwiftUI
import UIKit

#if os(iOS)

struct FilmtoneCaptureTakePickerOverlay: View {
    let packages: [FilmtoneCapturePackage]
    let makeGradeProcessor: ((FilmtoneCapturePackage) async -> FilmtoneSharedGradeProcessor?)?
    let onPick: (Int) -> Void
    let onCancel: () -> Void

    @State private var focusedIndex: Int?

    var body: some View {
        GeometryReader { proxy in
            let isCompactHeight = proxy.size.height < 520
            let maxPanelHeight = isCompactHeight
                ? max(250, proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom - 12)
                : min(proxy.size.height * 0.74, 680)
            let horizontalPadding: CGFloat = isCompactHeight ? 8 : 14
            let bottomPadding = isCompactHeight
                ? max(proxy.safeAreaInsets.bottom + 6, 8)
                : max(proxy.safeAreaInsets.bottom + 12, 18)

            ZStack(alignment: .bottom) {
                Color.black.opacity(0.20)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onCancel)

                panel(isCompactHeight: isCompactHeight)
                    .frame(maxHeight: maxPanelHeight)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            if focusedIndex == nil {
                focusedIndex = latestIndex
            }
        }
        .onChange(of: packages.count) { _, _ in
            focusedIndex = clampedIndex(focusedIndex ?? latestIndex)
        }
        .accessibilityIdentifier("filmtone.capture.takePicker")
    }

    private func panel(isCompactHeight: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: isCompactHeight ? 22 : 28, style: .continuous)
        let index = currentIndex
        let package = packages[index]

        return GlassEffectContainer(spacing: 8) {
            VStack(spacing: isCompactHeight ? 9 : 12) {
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(width: 54, height: 5)
                    .padding(.top, 10)
                    .accessibilityHidden(true)

                header(
                    focusedIndex: index,
                    isCompactHeight: isCompactHeight
                )

                if isCompactHeight {
                    HStack(alignment: .top, spacing: 10) {
                        focusedInspector(
                            package: package,
                            index: index,
                            isCompactHeight: true
                        )

                        VStack(spacing: 10) {
                            FilmtoneCaptureTakeSelector(
                                packages: packages,
                                focusedIndex: index,
                                isCompactHeight: true,
                                onFocus: focusTake
                            )

                            openFocusedButton(index: index)
                        }
                        .frame(width: 144)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                } else {
                    focusedInspector(
                        package: package,
                        index: index,
                        isCompactHeight: false
                    )
                    .padding(.horizontal, 18)

                    FilmtoneCaptureTakeSelector(
                        packages: packages,
                        focusedIndex: index,
                        isCompactHeight: false,
                        onFocus: focusTake
                    )
                    .padding(.horizontal, 18)

                    HStack {
                        Text("Earlier takes stay on disk")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)

                        Spacer(minLength: 12)

                        openFocusedButton(index: index)
                            .frame(width: 132)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                }
            }
            .padding(.top, 2)
            .glassEffect(.clear.tint(.white.opacity(0.055)), in: shape)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(.white.opacity(0.20), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.34), radius: 32, x: 0, y: 18)
        }
    }

    private func header(
        focusedIndex index: Int,
        isCompactHeight: Bool
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Choose take")
                    .font(.system(size: isCompactHeight ? 18 : 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))

                Text("\(packages.count) takes · Take \(index + 1)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 0)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .foregroundStyle(.white)
            .accessibilityLabel("Cancel")
            .accessibilityIdentifier("filmtone.capture.takePicker.cancel")
        }
        .padding(.horizontal, isCompactHeight ? 14 : 18)
    }

    private func focusedInspector(
        package: FilmtoneCapturePackage,
        index: Int,
        isCompactHeight: Bool
    ) -> some View {
        FilmtoneCaptureFocusedTakeInspector(
            package: package,
            takeNumber: index + 1,
            isLatest: index == latestIndex,
            isCompactHeight: isCompactHeight,
            makeGradeProcessor: makeGradeProcessor
        )
        .id("\(package.captureId)-\(isCompactHeight)")
        .accessibilityIdentifier("filmtone.capture.takePicker.focusedTake\(index + 1)")
    }

    private func openFocusedButton(index: Int) -> some View {
        Button {
            FilmtoneCaptureHaptics.selection()
            onPick(index)
        } label: {
            HStack(spacing: 7) {
                Text("Open")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.95))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Open Take \(index + 1) in editor")
    }

    private func focusTake(_ index: Int) {
        guard packages.indices.contains(index), index != currentIndex else { return }
        FilmtoneCaptureHaptics.selection()
        focusedIndex = index
    }

    private var currentIndex: Int {
        clampedIndex(focusedIndex ?? latestIndex)
    }

    private var latestIndex: Int {
        max(packages.count - 1, 0)
    }

    private func clampedIndex(_ index: Int) -> Int {
        guard !packages.isEmpty else { return 0 }
        return min(max(index, 0), packages.count - 1)
    }
}

private struct FilmtoneCaptureFocusedTakeInspector: View {
    let package: FilmtoneCapturePackage
    let takeNumber: Int
    let isLatest: Bool
    let isCompactHeight: Bool
    let makeGradeProcessor: ((FilmtoneCapturePackage) async -> FilmtoneSharedGradeProcessor?)?

    @StateObject private var model = FilmtoneCaptureTakePreviewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactHeight ? 7 : 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Take \(takeNumber)")
                    .font(.system(size: isCompactHeight ? 16 : 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.97))

                if isLatest {
                    Text("Latest")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.80))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.10), in: Capsule())
                }

                Spacer(minLength: 0)

                if model.isRenderingExactLook {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white.opacity(0.70))
                }
            }

            Text("\(filmtoneCaptureTakeDuration(package.recordedDurationSeconds)) · \(filmtoneCaptureTakeDetailLine(package))")
                .font(.system(size: isCompactHeight ? 11 : 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            previewSurface
        }
        .task(id: "\(package.captureId)-\(isCompactHeight)") {
            model.focus(
                package: package,
                isCompactHeight: isCompactHeight,
                makeGradeProcessor: makeGradeProcessor
            )
        }
        .onDisappear {
            model.cancel()
        }
        .accessibilityLabel(
            Text("Take \(takeNumber), \(filmtoneCaptureTakeDuration(package.recordedDurationSeconds)), \(filmtoneCaptureTakeDetailLine(package))")
        )
    }

    private var previewSurface: some View {
        let shape = RoundedRectangle(cornerRadius: isCompactHeight ? 13 : 16, style: .continuous)
        let image = model.selectedImage

        return ZStack(alignment: .bottom) {
            shape.fill(.black.opacity(0.28))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 16)
                    .opacity(0.62)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, isCompactHeight ? 12 : 16)
                    .padding(.horizontal, 10)
                    .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 5)
            } else {
                ProgressView()
                    .tint(.white.opacity(0.64))
            }

            HStack {
                Text(filmtoneCaptureTakeClock(model.selectedSeconds))
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.90))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.24), in: Capsule())

                Spacer(minLength: 0)

                Text(filmtoneCaptureTakeClock(package.recordedDurationSeconds))
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.74))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.18), in: Capsule())
            }
            .padding(.horizontal, 11)
            .padding(.bottom, isCompactHeight ? 38 : 50)

            scrubRail
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isCompactHeight ? 156 : 312)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 0.7))
    }

    private var scrubRail: some View {
        GeometryReader { proxy in
            HStack(spacing: isCompactHeight ? 2 : 3) {
                ForEach(model.samples) { sample in
                    let isSelected = sample.index == model.selectedFrameIndex
                    let shape = RoundedRectangle(cornerRadius: isCompactHeight ? 4 : 5, style: .continuous)

                    ZStack {
                        shape.fill(.black.opacity(0.28))

                        if let image = sample.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Image(systemName: "video")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.36))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(shape)
                    .overlay(
                        shape.strokeBorder(
                            isSelected ? .white.opacity(0.92) : .white.opacity(0.14),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        model.selectFrame(atX: value.location.x, width: proxy.size.width)
                    }
            )
        }
        .frame(height: isCompactHeight ? 24 : 36)
        .accessibilityHidden(true)
    }
}

private struct FilmtoneCaptureTakeSelector: View {
    let packages: [FilmtoneCapturePackage]
    let focusedIndex: Int
    let isCompactHeight: Bool
    let onFocus: (Int) -> Void

    var body: some View {
        if isCompactHeight {
            ScrollView(.vertical) {
                LazyVStack(spacing: 6) {
                    selectorButtons
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 104)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    selectorButtons
                }
                .padding(.horizontal, 1)
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var selectorButtons: some View {
        ForEach(packages.indices.reversed(), id: \.self) { index in
            FilmtoneCaptureTakeSelectorButton(
                title: "Take \(index + 1)",
                subtitle: filmtoneCaptureTakeDuration(packages[index].recordedDurationSeconds),
                isLatest: index == packages.indices.last,
                isSelected: index == focusedIndex,
                isCompactHeight: isCompactHeight,
                action: { onFocus(index) }
            )
        }
    }
}

private struct FilmtoneCaptureTakeSelectorButton: View {
    let title: String
    let subtitle: String
    let isLatest: Bool
    let isSelected: Bool
    let isCompactHeight: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: isCompactHeight ? 12 : 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)

                    Text(isLatest ? "\(subtitle) · Latest" : subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                if !isCompactHeight {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(isSelected ? 0.90 : 0.38))
                }
            }
            .frame(maxWidth: isCompactHeight ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, isCompactHeight ? 9 : 11)
            .padding(.vertical, isCompactHeight ? 7 : 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.16 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(isSelected ? 0.42 : 0.12), lineWidth: isSelected ? 1.1 : 0.6)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)\(isLatest ? ", latest" : "")")
    }
}

private func filmtoneCaptureTakeDetailLine(_ package: FilmtoneCapturePackage) -> String {
    var parts: [String] = []
    if let lens = package.lens?.magnificationLabel {
        parts.append(lens)
    }
    if let look = package.selectedLook?.englishName {
        parts.append(look)
    } else if let customLut = package.customLut {
        parts.append(customLut.displayName)
    } else {
        parts.append("Filmtone")
    }
    return parts.joined(separator: " · ")
}

private func filmtoneCaptureTakeDuration(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0.0s" }
    if seconds < 10 {
        return String(format: "%.1fs", seconds)
    }
    return filmtoneCaptureTakeClock(seconds)
}

private func filmtoneCaptureTakeClock(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0s" }
    let total = Int(seconds.rounded(.down))
    if total < 60 {
        return "\(total)s"
    }
    return String(format: "%d:%02d", total / 60, total % 60)
}

#endif
