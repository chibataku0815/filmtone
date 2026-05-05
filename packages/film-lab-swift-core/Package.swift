// swift-tools-version: 6.0
//
// film-lab-swift-core — repo-local Swift Package shared between
// apps/capacitor-film-lab-ios and apps/filmtone-desktop-macos.
// Owns the Foundation-only Phase 0 data layer:
//   - FilmtonePhase0Generated (kernel constants generator output)
//   - FilmtoneQuickState
//   - FilmtonePhase0Params
//   - FilmtonePhase0ParamsPatch
//   - Phase0OutputProfileDTO
//
// Pure Foundation. No CoreImage, SwiftUI, AppKit, UIKit, Metal,
// SIMD-math, or platform shell. Math, UI, sidecar I/O, and platform
// idioms remain in the consumer apps.
import PackageDescription

let package = Package(
    name: "film-lab-swift-core",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FilmLabSwiftCore",
            targets: ["FilmLabSwiftCore"]
        )
    ],
    targets: [
        .target(
            name: "FilmLabSwiftCore"
        ),
        .testTarget(
            name: "FilmLabSwiftCoreTests",
            dependencies: ["FilmLabSwiftCore"]
        )
    ]
)
