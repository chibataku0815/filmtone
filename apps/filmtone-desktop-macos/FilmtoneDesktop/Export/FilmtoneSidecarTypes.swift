import Foundation

enum FilmtoneSourceKind: String, Sendable {
    case still
    case video
}

protocol FilmtoneSidecarRequest: Sendable {
    var sourceURL: URL { get }
    var outputURL: URL { get }
    var presetName: String { get }
    var presetStrength: Double { get }
    var sourceKind: FilmtoneSourceKind { get }
}
