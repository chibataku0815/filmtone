import Foundation

struct ParsedCubeLutDTO: Codable, Equatable {
    let title: String
    let size: Int
    let data: [Double]
    let intensity: Double
}

enum FilmtoneMediaError: Error {
    case unsupportedSource(String)
}

func filmtoneLocalized(
    _ key: String,
    defaultValue: String,
    comment: String
) -> String {
    defaultValue
}

func filmtoneLocalizedFormat(
    _ key: String,
    defaultValue: String,
    arguments: [CVarArg],
    comment: String
) -> String {
    String(format: defaultValue.replacingOccurrences(of: "%@", with: "%@"), arguments: arguments)
}

private enum CubeParserTestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

@main
struct CubeParserTests {
    static func main() throws {
        try parsesDefaultDomainWithoutChangingValues()
        try bakesExplicitDomainIntoUnitCube()
        print("cube parser tests passed")
    }

    private static func parsesDefaultDomainWithoutChangingValues() throws {
        let lut = try FilmtoneCubeParser.parse(
            text: """
            TITLE "identity"
            LUT_3D_SIZE 2
            0 0 0
            1 0 0
            0 1 0
            1 1 0
            0 0 1
            1 0 1
            0 1 1
            1 1 1
            """,
            defaultTitle: "fallback"
        )

        try assertEqual(lut.title, "identity", "title")
        try assertEqual(lut.size, 2, "size")
        try assertClose(
            lut.data,
            [
                0, 0, 0,
                1, 0, 0,
                0, 1, 0,
                1, 1, 0,
                0, 0, 1,
                1, 0, 1,
                0, 1, 1,
                1, 1, 1,
            ],
            "default domain data"
        )
    }

    private static func bakesExplicitDomainIntoUnitCube() throws {
        let lut = try FilmtoneCubeParser.parse(
            text: """
            TITLE "domain"
            LUT_3D_SIZE 2
            DOMAIN_MIN -1 -1 -1
            DOMAIN_MAX 1 1 1
            0 0 0
            1 0 0
            0 1 0
            1 1 0
            0 0 1
            1 0 1
            0 1 1
            1 1 1
            """,
            defaultTitle: "fallback"
        )

        try assertClose(
            lut.data,
            [
                0.5, 0.5, 0.5,
                1, 0.5, 0.5,
                0.5, 1, 0.5,
                1, 1, 0.5,
                0.5, 0.5, 1,
                1, 0.5, 1,
                0.5, 1, 1,
                1, 1, 1,
            ],
            "explicit domain data"
        )
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) throws {
        if actual != expected {
            throw CubeParserTestFailure.failed("\(label): expected \(expected), got \(actual)")
        }
    }

    private static func assertClose(
        _ actual: [Double],
        _ expected: [Double],
        _ label: String,
        tolerance: Double = 0.000001
    ) throws {
        try assertEqual(actual.count, expected.count, "\(label) count")

        for (index, pair) in zip(actual, expected).enumerated() {
            if abs(pair.0 - pair.1) > tolerance {
                throw CubeParserTestFailure.failed(
                    "\(label)[\(index)]: expected \(pair.1), got \(pair.0)"
                )
            }
        }
    }
}
