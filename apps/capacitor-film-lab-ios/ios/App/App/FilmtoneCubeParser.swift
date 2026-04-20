import Foundation

enum FilmtoneCubeParser {
    static func parse(text: String, defaultTitle: String) throws -> ParsedCubeLutDTO {
        var title = defaultTitle
        var size: Int?
        var domainMin: [Double]?
        var domainMax: [Double]?
        var values: [Double] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            if line.hasPrefix("TITLE") {
                title = parseTitle(line) ?? defaultTitle
                continue
            }

            if line.hasPrefix("LUT_3D_SIZE") {
                size = parseTrailingInt(line)
                continue
            }

            if line.hasPrefix("DOMAIN_MIN") {
                domainMin = parseTriple(line)
                continue
            }

            if line.hasPrefix("DOMAIN_MAX") {
                domainMax = parseTriple(line)
                continue
            }

            let triple = parseTriple(line)
            if triple.count == 3 {
                values.append(contentsOf: triple)
            }
        }

        guard let size, size > 1 else {
            throw FilmtoneMediaError.unsupportedSource(
                filmtoneLocalized(
                    "filmtone.error.lut.missing_size",
                    defaultValue: "The .cube file is missing LUT_3D_SIZE.",
                    comment: "Error shown when an imported LUT file is missing LUT_3D_SIZE."
                )
            )
        }

        let expectedCount = size * size * size * 3
        guard values.count == expectedCount else {
            throw FilmtoneMediaError.unsupportedSource(
                filmtoneLocalizedFormat(
                    "filmtone.error.lut.value_count",
                    defaultValue: "The .cube file has %@ values, but %@ are required.",
                    arguments: [String(values.count), String(expectedCount)],
                    comment: "Error shown when an imported LUT file contains the wrong number of values."
                )
            )
        }

        _ = domainMin
        _ = domainMax

        return ParsedCubeLutDTO(
            title: title,
            size: size,
            data: values,
            intensity: 1
        )
    }

    private static func parseTitle(_ line: String) -> String? {
        guard let firstQuote = line.firstIndex(of: "\""),
              let lastQuote = line.lastIndex(of: "\""),
              firstQuote < lastQuote else {
            return line
                .components(separatedBy: .whitespaces)
                .dropFirst()
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(line[line.index(after: firstQuote)..<lastQuote])
    }

    private static func parseTrailingInt(_ line: String) -> Int? {
        line
            .components(separatedBy: .whitespaces)
            .compactMap { Int($0) }
            .last
    }

    private static func parseTriple(_ line: String) -> [Double] {
        line
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .compactMap { Double($0) }
    }
}
