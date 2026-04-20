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
        CAPPluginMethod(name: "renderPreviewFrame", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "runExport", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "saveToPhotos", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "shareOutput", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cancelExport", returnType: CAPPluginReturnPromise),
    ]

    private var assetPickerService: AssetPickerService?
    private var runtime: FilmtoneMediaRuntime?
    private var currentExportSession: FilmtoneExportSession?
    private var currentExportTask: Task<Void, Never>?
    private var memoryWarningCount = 0
    private let photoSaveLock = NSLock()
    private var inFlightPhotoSaveURI: String?
    private var lastSavedPhotoURI: String?

    override func load() {
        super.load()
        do {
            let cacheStore = try CacheStore()
            self.assetPickerService = AssetPickerService(cacheStore: cacheStore)
            self.runtime = FilmtoneMediaRuntime(
                cacheStore: cacheStore,
                memoryWarningCounter: { [weak self] in self?.memoryWarningCount ?? 0 },
                invalidFileURLError: { uri in
                    FilmtoneMediaError.invalidURL("The file URL '\(uri)' is invalid or inaccessible.")
                }
            )
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
                if let source = try await assetPickerService.pickSource(
                    presenting: viewController,
                    route: .photoLibrary
                ) {
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
        guard let runtime else {
            reject(call, with: FilmtoneMediaError.cacheFailed("Cache store is unavailable."))
            return
        }

        do {
            let options = try call.decode(UriOptions.self)
            let sourceURL = try resolveFileURL(options.uri)
            let fallback = SourceInfoDTO(
                uri: sourceURL.absoluteString,
                filename: sourceURL.lastPathComponent,
                kind: inferKind(from: sourceURL),
                mimeType: nil
            )
            let probe = try runtime.probeSource(fallback, sourceURL: sourceURL)
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
        guard let runtime else {
            reject(call, with: FilmtoneMediaError.cacheFailed("Cache store is unavailable."))
            return
        }

        do {
            let request = try call.decode(Phase0ExportRequestDTO.self)
            let sourceURL = try resolveFileURL(request.sourceUri)
            let benchmarkCollector = runtime.makeBenchmarkCollector(request: request)
            let exportSession = try runtime.makeExportSession(
                request: request,
                sourceURL: sourceURL
            )
            currentExportSession = exportSession

            currentExportTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                do {
                    let exportResult = try await runtime.runExport(
                        request: request,
                        sourceURL: sourceURL,
                        session: exportSession,
                        collector: benchmarkCollector
                    ) { progress in
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

                    await MainActor.run {
                        self.currentExportSession = nil
                        self.currentExportTask = nil
                        call.resolve(with: exportResult)
                    }
                } catch {
                    let benchmarkRecord = runtime.makeFailureBenchmarkRecord(
                        collector: benchmarkCollector,
                        error: error
                    )
                    await MainActor.run {
                        self.currentExportSession = nil
                        self.currentExportTask = nil
                        self.notifyListeners("exportProgress", data: [
                            "stage": Phase0ExportStage.completed.rawValue,
                            "progress": 1,
                            "message": "Export failed",
                            "errorCode": (error as? FilmtoneMediaError)?.code as Any,
                            "benchmarkRecord": [
                                "appVersion": benchmarkRecord.appVersion,
                                "buildNumber": benchmarkRecord.buildNumber,
                                "deviceModel": benchmarkRecord.deviceModel,
                                "iosVersion": benchmarkRecord.iosVersion,
                                "elapsedMs": benchmarkRecord.elapsedMs,
                                "thermalState": benchmarkRecord.thermalState as Any,
                                "memoryWarningCount": benchmarkRecord.memoryWarningCount as Any,
                                "errorDomain": benchmarkRecord.errorDomain as Any,
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

    @objc func renderPreviewFrame(_ call: CAPPluginCall) {
        guard let runtime else {
            reject(call, with: FilmtoneMediaError.cacheFailed("Cache store is unavailable."))
            return
        }

        Task {
            do {
                let request = try call.decode(Phase0ExportRequestDTO.self)
                let sourceURL = try resolveFileURL(request.sourceUri)
                let result = try await runtime.renderPreview(
                    request: request,
                    sourceURL: sourceURL
                )
                call.resolve(with: result)
            } catch {
                reject(call, with: error)
            }
        }
    }

    @objc func saveToPhotos(_ call: CAPPluginCall) {
        guard let runtime else {
            reject(call, with: FilmtoneMediaError.cacheFailed("Cache store is unavailable."))
            return
        }

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
                    try await runtime.saveToPhotos(fileURL: fileURL)
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
        guard let runtime else {
            reject(call, with: FilmtoneMediaError.cacheFailed("Cache store is unavailable."))
            return
        }
        guard let viewController = bridge?.viewController else {
            reject(call, with: FilmtoneMediaError.bridgeUnavailable)
            return
        }

        Task { @MainActor in
            do {
                let options = try call.decode(ShareOptions.self)
                let fileURL = try resolveFileURL(options.uri)
                try await runtime.shareOutput(
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
        if let webURL = URL(string: uri), let localURL = bridge?.localURL(fromWebURL: webURL) {
            return localURL
        }

        guard let runtime else {
            throw FilmtoneMediaError.cacheFailed("Cache store is unavailable.")
        }
        return try runtime.resolveFileURL(uri)
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
