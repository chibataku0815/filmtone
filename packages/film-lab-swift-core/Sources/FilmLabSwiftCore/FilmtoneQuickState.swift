import Foundation

public struct FilmtoneQuickState: Codable, Equatable, Hashable, Sendable {
    public var filmCharacter: Double
    public var era: Double
    public var dynamics: Double

    public init(filmCharacter: Double, era: Double, dynamics: Double) {
        self.filmCharacter = filmCharacter
        self.era = era
        self.dynamics = dynamics
    }

    public static let zero = FilmtoneQuickState(
        filmCharacter: 0,
        era: 0,
        dynamics: 0
    )

    public func clamped() -> FilmtoneQuickState {
        .init(
            filmCharacter: Self.clampAxis(filmCharacter),
            era: Self.clampAxis(era),
            dynamics: Self.clampAxis(dynamics)
        )
    }

    public func value(forAxis axis: String) -> Double {
        switch axis {
        case "filmCharacter":
            return filmCharacter
        case "era":
            return era
        case "dynamics":
            return dynamics
        default:
            return 0
        }
    }

    public static func clampAxis(_ value: Double) -> Double {
        max(
            FilmtonePhase0Generated.quickAxisMin,
            min(FilmtonePhase0Generated.quickAxisMax, value)
        )
    }
}
