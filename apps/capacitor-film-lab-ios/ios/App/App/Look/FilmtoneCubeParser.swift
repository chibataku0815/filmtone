import Foundation

enum FilmtoneCubeParser {
    private static let defaultDomainMin = [0.0, 0.0, 0.0]
    private static let defaultDomainMax = [1.0, 1.0, 1.0]

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

        let resolvedDomainMin = resolveDomain(domainMin, fallback: defaultDomainMin)
        let resolvedDomainMax = resolveDomain(domainMax, fallback: defaultDomainMax)
        let unitDomainValues = bakeDomainIntoUnitCube(
            values,
            size: size,
            domainMin: resolvedDomainMin,
            domainMax: resolvedDomainMax
        )

        return ParsedCubeLutDTO(
            title: title,
            size: size,
            data: unitDomainValues,
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

    private static func resolveDomain(_ parsed: [Double]?, fallback: [Double]) -> [Double] {
        guard let parsed else {
            return fallback
        }

        var resolved = fallback
        for index in 0..<min(parsed.count, resolved.count) where parsed[index].isFinite {
            resolved[index] = parsed[index]
        }
        return resolved
    }

    private static func bakeDomainIntoUnitCube(
        _ values: [Double],
        size: Int,
        domainMin: [Double],
        domainMax: [Double]
    ) -> [Double] {
        guard domainMin != defaultDomainMin || domainMax != defaultDomainMax else {
            return values
        }

        let ranges = zip(domainMin, domainMax).map { minimum, maximum in
            maximum - minimum
        }
        guard ranges.allSatisfy({ $0.isFinite && $0 != 0 }) else {
            return values
        }

        var remapped: [Double] = []
        remapped.reserveCapacity(values.count)

        for blueIndex in 0..<size {
            for greenIndex in 0..<size {
                for redIndex in 0..<size {
                    let red = Double(redIndex) / Double(size - 1)
                    let green = Double(greenIndex) / Double(size - 1)
                    let blue = Double(blueIndex) / Double(size - 1)
                    let samplePoint = [
                        clamp((red - domainMin[0]) / ranges[0]),
                        clamp((green - domainMin[1]) / ranges[1]),
                        clamp((blue - domainMin[2]) / ranges[2]),
                    ]
                    remapped.append(contentsOf: sample(values, size: size, at: samplePoint))
                }
            }
        }

        return remapped
    }

    private static func sample(_ values: [Double], size: Int, at point: [Double]) -> [Double] {
        let red = interpolationBounds(for: point[0], size: size)
        let green = interpolationBounds(for: point[1], size: size)
        let blue = interpolationBounds(for: point[2], size: size)
        var result = [0.0, 0.0, 0.0]

        for blueCorner in 0...1 {
            let blueIndex = blueCorner == 0 ? blue.lower : blue.upper
            let blueWeight = blueCorner == 0 ? 1 - blue.fraction : blue.fraction
            for greenCorner in 0...1 {
                let greenIndex = greenCorner == 0 ? green.lower : green.upper
                let greenWeight = greenCorner == 0 ? 1 - green.fraction : green.fraction
                for redCorner in 0...1 {
                    let redIndex = redCorner == 0 ? red.lower : red.upper
                    let redWeight = redCorner == 0 ? 1 - red.fraction : red.fraction
                    let weight = redWeight * greenWeight * blueWeight

                    for channel in 0..<3 {
                        result[channel] += value(
                            values,
                            size: size,
                            red: redIndex,
                            green: greenIndex,
                            blue: blueIndex,
                            channel: channel
                        ) * weight
                    }
                }
            }
        }

        return result
    }

    private static func interpolationBounds(
        for coordinate: Double,
        size: Int
    ) -> (lower: Int, upper: Int, fraction: Double) {
        let scaled = coordinate * Double(size - 1)
        let lower = max(0, min(size - 1, Int(floor(scaled))))
        let upper = min(size - 1, lower + 1)
        return (lower, upper, scaled - Double(lower))
    }

    private static func value(
        _ values: [Double],
        size: Int,
        red: Int,
        green: Int,
        blue: Int,
        channel: Int
    ) -> Double {
        values[((blue * size * size) + (green * size) + red) * 3 + channel]
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
