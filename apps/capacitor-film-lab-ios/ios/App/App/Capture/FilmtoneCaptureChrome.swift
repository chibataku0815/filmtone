// Filmtone V2 native camera capture — Apple Liquid Glass primitives.
//
// M13-M-2 invariants:
//   1. Liquid Glass material is the BODY of a control surface, not a coat
//      painted on top of an opaque dark fill. An opaque fill in the same
//      composite kills the material's ability to sample the preview.
//   2. Glass.regular.tint(_:) is reserved for active / selected state.
//      Tint is a *hint*, not a fill — `selectedGlassTint` is intentionally
//      low (white opacity ≤ 0.12) so refraction at the rim still reads.
//      Selected weight is carried by tint + a 0.6pt rim stroke + bold text,
//      not by opacity alone.
//   3. Adjacent glass shapes that should merge live inside a shared
//      `GlassEffectContainer` at the call site — the primitives here are
//      composable building blocks, not full surfaces.
//   4. Cockpit chips / HUD pills / peripheral buttons use angular
//      `RoundedRectangle` shapes (radii 8-11pt). `Capsule()` is reserved
//      for status timecodes (and shutter circles use `Circle()`). M13-M-1
//      pill silhouettes were too consumer; M13-M-2 reads as a pro camera
//      surface.

import SwiftUI
import UIKit

#if os(iOS)

enum FilmtoneCaptureChromeOrientation: Equatable {
    case portrait
    case landscapeLeft
    case landscapeRight
    case portraitUpsideDown

    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait:
            self = .portrait
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .faceUp, .faceDown, .unknown:
            return nil
        @unknown default:
            return nil
        }
    }

    var readableRotation: Angle {
        switch self {
        case .portrait:
            return .zero
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        }
    }

    var usesLandscapeLayout: Bool {
        switch self {
        case .landscapeLeft, .landscapeRight:
            return true
        case .portrait, .portraitUpsideDown:
            return false
        }
    }
}

enum FilmtoneCaptureChrome {
    // TIDE accent — kept for future warm-state usage.
    static let amber = Color(red: 0.88, green: 0.80, blue: 0.56)
    static let amberDeep = Color(red: 0.72, green: 0.60, blue: 0.36)

    // Recording.
    static let recordRed = Color(red: 0.92, green: 0.12, blue: 0.10)
    static let recordRedDeep = Color(red: 0.55, green: 0.02, blue: 0.02)

    // Status text.
    static let mutedText = Color.white.opacity(0.66)
    static let warning = Color(red: 0.92, green: 0.78, blue: 0.42)

    // Selected-state tokens — tint-as-hint per Apple HIG. Tint stays
    // light enough to let the Liquid Glass refraction signature pass
    // through; the visual weight comes from tint + rim stroke + bold
    // type, not from a near-opaque fill.
    static let selectedGlassTint = Color.white.opacity(0.10)
    static let selectedRim = Color.white.opacity(0.22)
    static let selectedRimWidth: CGFloat = 0.6

    // Geometry — angular pro-camera radii (M13-M-2). Single source of
    // truth so cockpit components do not drift back into Capsule.
    static let chipCornerRadius: CGFloat = 9
    static let lensChipCornerRadius: CGFloat = 8
    static let hudCornerRadius: CGFloat = 10
    static let peripheralCornerRadius: CGFloat = 11
    static let rulerCornerRadius: CGFloat = 11

    // Bottom shelf rail removed in M13-M-2 (glass-on-glass slab killed
    // the per-edge Liquid Glass refraction). Token retained at a small
    // angular value in case a future lane reintroduces a slim rail; it
    // is not consumed by `FilmtoneCaptureBottomDeck` today.
    static let shelfCornerRadius: CGFloat = 14
    static let shelfHorizontalInset: CGFloat = 16
    static let shelfTopInset: CGFloat = 6
    static let shelfBottomInset: CGFloat = 8

    static let trayCornerRadius: CGFloat = 12
    static let railRowHeight: CGFloat = 34
    static let railInterGap: CGFloat = 4
    static let peripheralButtonSize: CGFloat = 38
    static let recordDiameter: CGFloat = 72
    static let recordCoreDiameter: CGFloat = 44
    static let recordCoreStopSide: CGFloat = 24

    // Chip dimensions.
    static let parameterChipMinHeight: CGFloat = 42
    static let parameterChipMinWidth: CGFloat = 54
    static let parameterChipSpacing: CGFloat = 6
    static let lensChipMinHeight: CGFloat = 36
    static let lensChipMinWidth: CGFloat = 50

    // MARK: Shape factories
    //
    // Returning `RoundedRectangle` rather than wrapping in `AnyShape`
    // keeps `glassEffect(_:in:)` happy (it requires `InsettableShape`).
    // Use the corresponding factory at the call site so the radii stay
    // consistent with the tokens above.

    static func chipShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: chipCornerRadius, style: .continuous)
    }

    static func lensChipShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: lensChipCornerRadius, style: .continuous)
    }

    static func hudShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: hudCornerRadius, style: .continuous)
    }

    static func peripheralShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: peripheralCornerRadius, style: .continuous)
    }

    static func rulerShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: rulerCornerRadius, style: .continuous)
    }
}

enum FilmtoneCaptureHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func softImpact() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func recordImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

struct FilmtoneCaptureChromeOverlay<Content: View>: View {
    let orientation: FilmtoneCaptureChromeOrientation
    private let content: () -> Content

    init(
        orientation: FilmtoneCaptureChromeOrientation,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.orientation = orientation
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let chromeSize = orientation.usesLandscapeLayout
                ? CGSize(width: size.height, height: size.width)
                : size

            content()
                .frame(width: chromeSize.width, height: chromeSize.height)
                .rotationEffect(orientation.readableRotation)
                .frame(width: size.width, height: size.height)
                .position(x: size.width / 2, y: size.height / 2)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: orientation)
    }
}

struct FilmtoneCaptureChromeScaffold<TopContent: View, Badge: View, BottomContent: View>: View {
    private let topContent: () -> TopContent
    private let badge: () -> Badge
    private let bottomContent: () -> BottomContent

    init(
        @ViewBuilder topContent: @escaping () -> TopContent,
        @ViewBuilder badge: @escaping () -> Badge,
        @ViewBuilder bottomContent: @escaping () -> BottomContent
    ) {
        self.topContent = topContent
        self.badge = badge
        self.bottomContent = bottomContent
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 0) {
                topContent()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                badge()

                Spacer()

                bottomContent()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            }
        }
    }
}

extension View {
    /// Apple Liquid Glass primitive for thin segmented rails. No tint —
    /// HIG reserves tint for active state. Today's only consumer is the
    /// ruler region stub; the bottom shelf rail was dropped in M13-M-2.
    func captureGlassRail<S: InsettableShape>(in shape: S) -> some View {
        glassEffect(.regular, in: shape)
    }

    /// Apple Liquid Glass primitive for tappable controls. `.interactive()`
    /// produces Apple's pressed-state ripple — never paint our own pressed
    /// background underneath.
    func captureGlassControl<S: InsettableShape>(in shape: S) -> some View {
        glassEffect(.regular.interactive(), in: shape)
    }

    /// Apple Liquid Glass primitive for HUD readouts (close, storage,
    /// quality contract, status timecode). Same material as a rail, named
    /// for the call site so the intent of each zone is grep-able.
    func captureGlassHUD<S: InsettableShape>(in shape: S) -> some View {
        glassEffect(.regular, in: shape)
    }

    /// Apple Liquid Glass primitive for the active / selected state of a
    /// pill or segment. HIG-compliant — tint represents an active state,
    /// not decoration. A subtle rim stroke is layered on so the selected
    /// surface still reads at low tint opacity.
    func captureGlassSelected<S: InsettableShape>(in shape: S) -> some View {
        glassEffect(
            .regular.tint(FilmtoneCaptureChrome.selectedGlassTint).interactive(),
            in: shape
        )
        .overlay(
            shape.strokeBorder(
                FilmtoneCaptureChrome.selectedRim,
                lineWidth: FilmtoneCaptureChrome.selectedRimWidth
            )
        )
    }

    /// Branches between the idle (`captureGlassControl`) and active
    /// (`captureGlassSelected`) Liquid Glass primitives on the same
    /// shape. Use this anywhere a chip toggles between idle and selected
    /// so the highlight pass uses the same clip path as the chip itself
    /// — the M13-L overflow trap is gone by construction.
    @ViewBuilder
    func captureGlassChip<S: InsettableShape>(active: Bool, in shape: S) -> some View {
        if active {
            self.captureGlassSelected(in: shape)
        } else {
            self.captureGlassControl(in: shape)
        }
    }
}

#endif
