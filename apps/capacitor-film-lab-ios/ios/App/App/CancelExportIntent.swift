import AppIntents
import Foundation

/// Live Activity Cancel button intent.
///
/// Compiled into both the App target and the FilmtoneExportActivity Widget Extension.
/// At runtime, `LiveActivityIntent.perform()` always executes inside the host app
/// process (Apple docs: AppIntents → LiveActivityIntent). Therefore this file can
/// freely call `ExportCancelController.shared` because that actor — also a
/// shared-target file — runs in the App process when the intent fires.
///
/// Locked-device behavior: Apple Widget interactivity docs note that interactive
/// elements in Live Activities require Face ID / passcode authentication when the
/// device is locked. Filmtone's release note must state this explicitly so users
/// don't perceive the button as broken.
@available(iOS 17.0, *)
public struct CancelExportIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "書き出しをキャンセル"
    public static var description = IntentDescription(
        "Cancels the current Filmtone export from the Lock Screen / Dynamic Island.",
        categoryName: "Export"
    )

    /// Cancel must not foreground the app — it just cancels in-place.
    public static var openAppWhenRun: Bool = false

    public init() {}

    /// Runs in the host App process (per Apple's `LiveActivityIntent` contract,
    /// not in the Widget Extension). Race-free cancel is centralized in
    /// `ExportCancelController` (3-way: WebView UI / LiveActivity / bgExpiration).
    public func perform() async throws -> some IntentResult {
        await ExportCancelController.shared.cancel(reason: .userViaLiveActivity)
        return .result()
    }
}
