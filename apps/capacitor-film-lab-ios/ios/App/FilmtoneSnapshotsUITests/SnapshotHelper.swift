import Foundation
import XCTest

// Keep this helper version marker aligned with the bundled fastlane template.
// fastlane checks this string before running snapshot.

@MainActor
func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
    Snapshot.setup(app, waitForAnimations: waitForAnimations)
}

@MainActor
func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
    Snapshot.capture(name, timeWaitingForIdle: timeout)
}

@MainActor
private enum Snapshot {
    static var app: XCUIApplication?
    static var waitForAnimations = true

    static func setup(_ app: XCUIApplication, waitForAnimations: Bool) {
        self.app = app
        self.waitForAnimations = waitForAnimations

        if let language = readCacheFile(named: "language.txt")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !language.isEmpty {
            app.launchArguments += ["-AppleLanguages", "(\(language))"]
        }

        if let locale = readCacheFile(named: "locale.txt")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !locale.isEmpty {
            app.launchArguments += ["-AppleLocale", "\"\(locale)\""]
        }

        app.launchArguments += ["-FASTLANE_SNAPSHOT", "YES", "-ui_testing"]

        if let launchArguments = readCacheFile(named: "snapshot-launch_arguments.txt") {
            app.launchArguments += splitArguments(launchArguments)
        }
    }

    static func capture(_ name: String, timeWaitingForIdle timeout: TimeInterval) {
        guard app != nil, let screenshotsDirectory else {
            XCTFail("Snapshot helper is not configured.")
            return
        }

        if timeout > 0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: min(timeout, 1)))
        }

        if waitForAnimations {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.8))
        }

        let screenshot = XCUIScreen.main.screenshot()
        guard let imageData = screenshot.image.pngData() else {
            XCTFail("Unable to render screenshot image data.")
            return
        }

        let deviceName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?
            .replacingOccurrences(
                of: #"Clone [0-9]+ of "#,
                with: "",
                options: .regularExpression
            ) ?? "Simulator"

        let outputURL = screenshotsDirectory.appendingPathComponent("\(deviceName)-\(name).png")
        do {
            try FileManager.default.createDirectory(
                at: screenshotsDirectory,
                withIntermediateDirectories: true
            )
            try imageData.write(to: outputURL, options: .atomic)
        } catch {
            XCTFail("Failed to write snapshot \(name): \(error.localizedDescription)")
        }
    }

    private static var screenshotsDirectory: URL? {
        cacheDirectory?.appendingPathComponent("screenshots", isDirectory: true)
    }

    private static var cacheDirectory: URL? {
        guard let simulatorHostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else {
            return nil
        }
        return URL(fileURLWithPath: simulatorHostHome)
            .appendingPathComponent("Library/Caches/tools.fastlane", isDirectory: true)
    }

    private static func readCacheFile(named name: String) -> String? {
        guard let cacheDirectory else {
            return nil
        }
        return try? String(
            contentsOf: cacheDirectory.appendingPathComponent(name),
            encoding: .utf8
        )
    }

    private static func splitArguments(_ string: String) -> [String] {
        let pattern = #"(\".+?\"|\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return string.split(separator: " ").map(String.init)
        }
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: string.count))
        return matches.map { match in
            (string as NSString).substring(with: match.range)
        }
    }
}

// Please don't remove the lines below
// They are used to detect outdated configuration files
// SnapshotHelperVersion [1.30]
