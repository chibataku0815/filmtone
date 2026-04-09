import Capacitor
import Foundation
import UIKit

@objc(FilmtoneMediaPlugin)
final class FilmtoneMediaPlugin: CAPPlugin, CAPBridgedPlugin {
    let identifier = "FilmtoneMediaPlugin"
    let jsName = "FilmtoneMedia"
    let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "pickSource", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pickLutFile", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "probeSource", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "runExport", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "saveToPhotos", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "shareOutput", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cancelExport", returnType: CAPPluginReturnPromise),
    ]

    private var cacheStore: CacheStore?
    private var assetPickerService: AssetPickerService?
    private let sourceProbeService = SourceProbeService()
    private let photoLibraryService = PhotoLibraryService()
    private var currentExportSession: FilmtoneExportSession?
    private var currentExportTask: Task<Void, Never>?
    private var memoryWarningCount = 0
    private var idleTimerDisabledBeforeExport = false
    private var exportIdleTimerActive = false
    private let photoSaveLock = NSLock()
    private var inFlightPhotoSaveURI: String?
    private var lastSavedPhotoURI: String?

    override func load() {
        super.load()
        do {
            let cacheStore = try CacheStore()
            self.cacheStore = cacheStore
            self.assetPickerService = AssetPickerService(cacheStore: cacheStore)
        } catch {
            CAPLog.print("FilmtoneMediaPlugin cache init failed:", error.localizedDescription)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleMemoryWarning() {
        memoryWarningCount += 1
    }

    @objc func pickSource(_ call: CAPPluginCall) {
        guard let viewController = bridge?.viewController else {
            reject(call, with: FilmtoneMediaError.bridgeUnavailable)
            return
        }
        guard let assetPickerService else {
            reject(call, with: FilmtoneMediaError.cacheFailed("Cache store is unavailable."))
            return
        }

        Task { @MainActor in
            do {
                if let source = try await assetPickerService.pickSource(presenting: viewController) {
                    call.resolve(with: source)
                } else {
                    call.resolve()
                }
            } catch {
                reject(call, with: error)
            }
        }
    }

    @objc func pickLutFile(_ call: CAPPluginCall) {
        guard let viewController = bridge?.viewController else {
            reject(call, with: FilmtoneMediaError.bridgeUnavailable)
            return
        }
        guard let assetPickerService else {
            reject(call, with: FilmtoneMediaError.cacheFailed("Cache store is unavailable."))
            return
        }

        Task { @MainActor in
            do {
                if let file = try await assetPickerService.pickLutFile(presenting: viewController) {
                    call.resolve(with: file)
                } else {
                    call.resolve()
                }
            } catch {
                reject(call, with: error)
            }
        }
    }

    @objc func probeSource(_ call: CAPPluginCall) {
        do {
            let options = try call.decode(UriOptions.self)
            let sourceURL = try resolveFileURL(options.uri)
            let fallback = SourceInfoDTO(
                uri: sourceURL.absoluteString,
                filename: sourceURL.lastPathComponent,
                kind: inferKind(from: sourceURL),
                mimeType: nil
            )
            let probe = try sourceProbeService.probeSource(at: sourceURL, fallback: fallback)
            call.resolve(with: probe)
        } catch {
            reject(call, with: error)
        }
    }

    @objc func runExport(_ call: CAPPluginCall) {
        guard currentExportTask == nil else {
            reject(call, with: FilmtoneMediaError.exportBusy)
            return
        }
        guard let cacheStore else {
            reject(call, with: FilmtoneMediaError.cacheFailed("Cache store is unavailable."))
            return
        }

        do {
            let request = try call.decode(Phase0ExportRequestDTO.self)
            let sourceURL = try resolveFileURL(request.sourceUri)
            let thermalStateAtStart = ProcessInfo.processInfo.thermalState.filmtoneLabel
            let memoryWarningsAtStart = memoryWarningCount
            let exportSession = try FilmtoneExportSession(
                request: request,
                sourceURL: sourceURL,
                cacheStore: cacheStore
            )
            currentExportSession = exportSession
            DispatchQueue.main.async {
                self.beginForegroundExportActivity()
            }

            currentExportTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                do {
                    var exportResult = try exportSession.run { progress in
                        let payload: [String: Any] = [
                            "stage": progress.stage.rawValue,
                            "progress": progress.progress,
                            "currentFrame": progress.currentFrame as Any,
                            "totalFrames": progress.totalFrames as Any,
                            "message": progress.message as Any,
                        ]
                        DispatchQueue.main.async {
                            self.notifyListeners("exportProgress", data: payload)
                        }
                    }

                    let benchmarkRecord = self.makeBenchmarkRecord(
                        request: request,
                        result: exportResult,
                        thermalStateAtStart: thermalStateAtStart,
                        memoryWarningsAtStart: memoryWarningsAtStart
                    )
                    exportResult = Phase0ExportResultDTO(
                        outputUri: exportResult.outputUri,
                        elapsedMs: exportResult.elapsedMs,
                        outputWidth: exportResult.outputWidth,
                        outputHeight: exportResult.outputHeight,
                        outputFps: exportResult.outputFps,
                        fileSizeBytes: exportResult.fileSizeBytes,
                        realtimeRatio: exportResult.realtimeRatio,
                        audioPreserved: exportResult.audioPreserved,
                        benchmarkRecord: benchmarkRecord
                    )

                    await MainActor.run {
                        self.currentExportSession = nil
                        self.currentExportTask = nil
                        self.endForegroundExportActivity()
                        call.resolve(with: exportResult)
                    }
                } catch {
                    let benchmarkRecord = self.makeFailureBenchmarkRecord(
                        request: request,
                        thermalStateAtStart: thermalStateAtStart,
                        memoryWarningsAtStart: memoryWarningsAtStart,
                        error: error
                    )
                    await MainActor.run {
                        self.currentExportSession = nil
                        self.currentExportTask = nil
                        self.endForegroundExportActivity()
                        self.notifyListeners("exportProgress", data: [
                            "stage": Phase0ExportStage.completed.rawValue,
                            "progress": 1,
                            "message": "Export failed",
                            "errorCode": (error as? FilmtoneMediaError)?.code as Any,
                            "benchmarkRecord": [
                                "deviceModel": benchmarkRecord.deviceModel,
                                "iosVersion": benchmarkRecord.iosVersion,
                                "elapsedMs": benchmarkRecord.elapsedMs,
                                "thermalState": benchmarkRecord.thermalState as Any,
                                "memoryWarningCount": benchmarkRecord.memoryWarningCount as Any,
                                "errorCode": benchmarkRecord.errorCode as Any,
                            ],
                        ])
                        self.reject(call, with: error)
                    }
                }
            }
        } catch {
            reject(call, with: error)
        }
    }

    @objc func saveToPhotos(_ call: CAPPluginCall) {
        Task {
            do {
                let options = try call.decode(UriOptions.self)
                let fileURL = try resolveFileURL(options.uri)
                let photoSaveURI = fileURL.standardizedFileURL.absoluteString

                switch beginPhotoSave(for: photoSaveURI) {
                case .ready:
                    break
                case .alreadyInFlight:
                    reject(call, with: FilmtoneMediaError.saveFailed("Save to Photos is already in progress for this output."))
                    return
                case .alreadySaved:
                    reject(call, with: FilmtoneMediaError.saveFailed("This output was already saved to Photos."))
                    return
                }

                do {
                    _ = try await photoLibraryService.saveToPhotos(fileURL: fileURL)
                    finishPhotoSave(for: photoSaveURI, succeeded: true)
                    call.resolve()
                } catch {
                    finishPhotoSave(for: photoSaveURI, succeeded: false)
                    reject(call, with: error)
                }
            } catch {
                reject(call, with: error)
            }
        }
    }

    @objc func shareOutput(_ call: CAPPluginCall) {
        guard let viewController = bridge?.viewController else {
            reject(call, with: FilmtoneMediaError.bridgeUnavailable)
            return
        }

        Task { @MainActor in
            do {
                let options = try call.decode(ShareOptions.self)
                let fileURL = try resolveFileURL(options.uri)
                let shareSheetService = ShareSheetService()
                _ = try await shareSheetService.share(
                    fileURL: fileURL,
                    title: options.title,
                    text: options.text,
                    presenting: viewController
                )
                call.resolve()
            } catch {
                reject(call, with: error)
            }
        }
    }

    @objc func cancelExport(_ call: CAPPluginCall) {
        currentExportSession?.cancel()
        currentExportTask?.cancel()
        currentExportSession = nil
        currentExportTask = nil
        DispatchQueue.main.async {
            self.endForegroundExportActivity()
        }
        call.resolve()
    }

    private func reject(_ call: CAPPluginCall, with error: Error) {
        if let mediaError = error as? FilmtoneMediaError {
            call.reject(mediaError.localizedDescription, mediaError.code, error)
            return
        }
        call.reject(error.localizedDescription, "FILMTONE_NATIVE_ERROR", error)
    }

    private func resolveFileURL(_ uri: String) throws -> URL {
        if let fileURL = URL(string: uri), fileURL.isFileURL {
            return fileURL
        }

        if let webURL = URL(string: uri), let localURL = bridge?.localURL(fromWebURL: webURL) {
            return localURL
        }

        if FileManager.default.fileExists(atPath: uri) {
            return URL(fileURLWithPath: uri)
        }

        throw FilmtoneMediaError.invalidURL("The file URL '\(uri)' is invalid or inaccessible.")
    }

    private func inferKind(from url: URL) -> FilmtoneSourceKind {
        let extensionLower = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "heic", "heif", "webp"].contains(extensionLower) {
            return .image
        }
        return .video
    }

    private func beginPhotoSave(for uri: String) -> PhotoSaveGuardState {
        photoSaveLock.lock()
        defer { photoSaveLock.unlock() }

        if inFlightPhotoSaveURI == uri {
            return .alreadyInFlight
        }
        if lastSavedPhotoURI == uri {
            return .alreadySaved
        }

        inFlightPhotoSaveURI = uri
        return .ready
    }

    private func finishPhotoSave(for uri: String, succeeded: Bool) {
        photoSaveLock.lock()
        defer { photoSaveLock.unlock() }

        if inFlightPhotoSaveURI == uri {
            inFlightPhotoSaveURI = nil
        }
        if succeeded {
            lastSavedPhotoURI = uri
        }
    }

    @MainActor
    private func beginForegroundExportActivity() {
        guard !exportIdleTimerActive else {
            return
        }
        idleTimerDisabledBeforeExport = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        exportIdleTimerActive = true
    }

    @MainActor
    private func endForegroundExportActivity() {
        guard exportIdleTimerActive else {
            return
        }
        UIApplication.shared.isIdleTimerDisabled = idleTimerDisabledBeforeExport
        exportIdleTimerActive = false
    }

    private func makeBenchmarkRecord(
        request: Phase0ExportRequestDTO,
        result: Phase0ExportResultDTO,
        thermalStateAtStart: String,
        memoryWarningsAtStart: Int
    ) -> Phase0ExportBenchmarkRecordDTO {
        let sourceResolution: String?
        if let width = request.sourceProbe?.width, let height = request.sourceProbe?.height {
            sourceResolution = "\(width)x\(height)"
        } else {
            sourceResolution = nil
        }

        return Phase0ExportBenchmarkRecordDTO(
            deviceModel: UIDevice.current.filmtoneModelIdentifier,
            iosVersion: UIDevice.current.systemVersion,
            sourceCodec: request.sourceProbe?.codec,
            sourceResolution: sourceResolution,
            sourceDurationSec: request.sourceProbe?.durationSec,
            outputFileSizeBytes: result.fileSizeBytes,
            elapsedMs: result.elapsedMs,
            realtimeRatio: result.realtimeRatio,
            thermalState: "\(thermalStateAtStart)->\(ProcessInfo.processInfo.thermalState.filmtoneLabel)",
            memoryWarningCount: max(memoryWarningCount - memoryWarningsAtStart, 0),
            permissionResult: "save-not-run",
            errorCode: nil
        )
    }

    private func makeFailureBenchmarkRecord(
        request: Phase0ExportRequestDTO,
        thermalStateAtStart: String,
        memoryWarningsAtStart: Int,
        error: Error
    ) -> Phase0ExportBenchmarkRecordDTO {
        let sourceResolution: String?
        if let width = request.sourceProbe?.width, let height = request.sourceProbe?.height {
            sourceResolution = "\(width)x\(height)"
        } else {
            sourceResolution = nil
        }

        return Phase0ExportBenchmarkRecordDTO(
            deviceModel: UIDevice.current.filmtoneModelIdentifier,
            iosVersion: UIDevice.current.systemVersion,
            sourceCodec: request.sourceProbe?.codec,
            sourceResolution: sourceResolution,
            sourceDurationSec: request.sourceProbe?.durationSec,
            outputFileSizeBytes: nil,
            elapsedMs: 0,
            realtimeRatio: nil,
            thermalState: "\(thermalStateAtStart)->\(ProcessInfo.processInfo.thermalState.filmtoneLabel)",
            memoryWarningCount: max(memoryWarningCount - memoryWarningsAtStart, 0),
            permissionResult: nil,
            errorCode: (error as? FilmtoneMediaError)?.code ?? "FILMTONE_NATIVE_ERROR"
        )
    }
}

private enum PhotoSaveGuardState {
    case ready
    case alreadyInFlight
    case alreadySaved
}

private struct UriOptions: Decodable {
    let uri: String
}

private struct ShareOptions: Decodable {
    let uri: String
    let title: String?
    let text: String?
}
