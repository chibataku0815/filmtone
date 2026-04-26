import Foundation

/// App-only conformance bridging ``FilmtoneExportSession`` (declared in
/// `FilmtoneExportSession.swift`, App target only — pulls AVFoundation,
/// CoreImage, AVAssetWriter, CIContext) to the lightweight
/// ``ExportCancelable`` protocol that the shared
/// ``ExportCancelController`` actor uses.
///
/// Living in its own file (instead of being added to FilmtoneExportSession.swift)
/// keeps the bridge surface obvious and avoids re-touching the 1500+ line export
/// session source for every protocol surface evolution.
extension FilmtoneExportSession: ExportCancelable {}
