import Foundation

func filmtoneLocalized(
    _ key: String,
    defaultValue: String,
    comment: String
) -> String {
    NSLocalizedString(
        key,
        tableName: nil,
        bundle: .main,
        value: defaultValue,
        comment: comment
    )
}

func filmtoneLocalizedFormat(
    _ key: String,
    defaultValue: String,
    arguments: [CVarArg],
    comment: String
) -> String {
    let format = filmtoneLocalized(key, defaultValue: defaultValue, comment: comment)
    return String(format: format, locale: Locale.current, arguments: arguments)
}

func filmtoneLocalizedNumber(
    _ value: Double,
    maximumFractionDigits: Int
) -> String {
    let formatter = NumberFormatter()
    formatter.locale = .current
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = maximumFractionDigits
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

struct FilmtoneStrings {
    let locale: Locale
    let appName: String
    let sourceEmpty: String
    let pickSource: String
    let repickSource: String
    let sourcePickerTitle: String
    let pickFromPhotoLibrary: String
    let pickFromFiles: String
    let probePending: String
    let sourceLoadImportingTitle: String
    let sourceLoadProbingTitle: String
    let sourceLoadImportingMessage: String
    let sourceLoadImportingFromFilesMessage: String
    let sourceLoadDownloadingFromCloudMessage: String
    let previewRendering: String
    let previewEmptyEyebrow: String
    let previewEmptyHint: String
    let compareLabel: String
    let compareHint: String
    let previewGradedLabel: String
    let previewExpandLabel: String
    let presetTitle: String
    let strengthLabel: String
    let adjustLabel: String
    let adjustOpenLabel: String
    let quickFilmCharacter: String
    let quickEra: String
    let quickDynamics: String
    let advancedParamsLabel: String
    let advancedParamsHint: String
    let advancedAdjustmentsActive: String
    let advancedBasicLabel: String
    let advancedProcessLabel: String
    let advancedOpticsLabel: String
    let advancedGlowLabel: String
    let advancedGrainLabel: String
    let advancedToneLabel: String
    let advancedPresetNoneLabel: String
    let advancedPresetDefaultLabel: String
    let advancedPresetStrongLabel: String
    let advancedPresetCustomLabel: String
    let paramLabels: [String: String]
    let resetLabel: String
    let exportSectionTitle: String
    let exportIdle: String
    let exportRunning: String
    let exportWritingHint: String
    let exportStart: String
    let exportDisabled: String
    let saveToPhotos: String
    let saveToPhotosDone: String
    let shareOutput: String
    let resultTitle: String
    let metricsElapsed: String
    let metricsOutput: String
    let metricsFileSize: String
    let metricsSaveToPhotos: String
    let noticePrefix: String
    let errorPrefix: String
    let doneLabel: String
    let cameraLabel: String
    let cameraDescription: String
    let cameraAuto: String
    let cameraAutoAppleLogDetected: String
    let cameraAutoAppleLog2Detected: String
    let cameraCustom: String
    let cameraImport: String
    let clearLut: String
    let lutImportError: String
    let lutParseError: String
    let exportStagePreflight: String
    let exportStageReading: String
    let exportStageRendering: String
    let exportStageWriting: String
    let exportStageCompleted: String
    let saveStateSaved: String
    let saveStateFailed: String
    let presetCategoryFilmStock: String
    let presetCategoryLook: String
    let presetCategoryUtility: String
    let genericPickSourceError: String
    let genericImportLutError: String
    let genericExportError: String
    let genericSaveToPhotosError: String
    let genericShareError: String
    let genericPreviewError: String
    // MARK: - HDR policy notice (T1 v1.1)
    let hdrNoticeTitle: String
    let hdrNoticeBodyPq: String
    let hdrNoticeBodyHlg: String
    let hdrNoticeBodyWideGamutUnknown: String
    // MARK: - Camera optics label (T5 v1.1)
    let opticsSourceMetadata: String
    let opticsSourceAssumed: String
    let opticsSourceAccessibilityMetadata: String
    let opticsSourceAccessibilityAssumed: String
    let opticsHfovFormat: String
    let opticsSeparator: String
    let opticsMetricLabel: String
    // MARK: - Toast UX (T1 v1.1 portrait optics + toast fix)
    let toastSaveSuccess: String
    let toastExportComplete: String
    let toastShareFailed: String
}

extension FilmtoneStrings {
    init(locale: Locale = .current) {
        self.locale = locale
        let prefersJapanese = locale.language.languageCode?.identifier.hasPrefix("ja") == true
        appName = filmtoneLocalized(
            "filmtone.app_name",
            defaultValue: "Filmtone",
            comment: "App name shown in the UI."
        )
        sourceEmpty = filmtoneLocalized(
            "filmtone.source.empty",
            defaultValue: "Pick a photo or video to begin.",
            comment: "Empty state message shown before any media is selected."
        )
        pickSource = filmtoneLocalized(
            "filmtone.source.pick",
            defaultValue: "Pick media",
            comment: "Primary action to pick source media."
        )
        repickSource = filmtoneLocalized(
            "filmtone.source.repick",
            defaultValue: "Replace media",
            comment: "Action to replace selected source media."
        )
        sourcePickerTitle = filmtoneLocalized(
            "filmtone.source.picker_title",
            defaultValue: "Choose Source",
            comment: "Title shown in the source picker confirmation dialog."
        )
        pickFromPhotoLibrary = filmtoneLocalized(
            "filmtone.source.photo_library",
            defaultValue: "Photo Library",
            comment: "Source picker option for the photo library."
        )
        pickFromFiles = filmtoneLocalized(
            "filmtone.source.files",
            defaultValue: "Files",
            comment: "Source picker option for the Files app."
        )
        probePending = filmtoneLocalized(
            "filmtone.source.inspecting",
            defaultValue: "Inspecting media…",
            comment: "Notice shown while the app probes the selected source."
        )
        sourceLoadImportingTitle = filmtoneLocalized(
            "filmtone.source.load_title.importing",
            defaultValue: prefersJapanese ? "読み込み中" : "Loading",
            comment: "Title shown while the selected media is still being imported."
        )
        sourceLoadProbingTitle = filmtoneLocalized(
            "filmtone.source.load_title.probing",
            defaultValue: prefersJapanese ? "素材を確認中" : "Inspecting",
            comment: "Title shown while the selected media is being probed."
        )
        sourceLoadImportingMessage = filmtoneLocalized(
            "filmtone.source.load_message.importing",
            defaultValue: prefersJapanese ? "選択した素材を読み込んでいます…" : "Loading the selected media…",
            comment: "Message shown while the selected media is being imported."
        )
        sourceLoadImportingFromFilesMessage = filmtoneLocalized(
            "filmtone.source.load_message.importing_files",
            defaultValue: prefersJapanese ? "ファイルを読み込んでいます…" : "Importing the selected file…",
            comment: "Message shown while importing media from Files."
        )
        sourceLoadDownloadingFromCloudMessage = filmtoneLocalized(
            "filmtone.source.load_message.cloud",
            defaultValue: prefersJapanese ? "iCloud から取得しています…" : "Downloading from iCloud…",
            comment: "Message shown while the selected media is downloading from iCloud."
        )
        previewRendering = filmtoneLocalized(
            "filmtone.preview.rendering",
            defaultValue: "Generating preview…",
            comment: "Notice shown while the app renders a preview."
        )
        previewEmptyEyebrow = filmtoneLocalized(
            "filmtone.preview.empty_eyebrow",
            defaultValue: "Quick Preview",
            comment: "Eyebrow shown above the preview empty state."
        )
        previewEmptyHint = filmtoneLocalized(
            "filmtone.preview.empty_hint",
            defaultValue: "Looks render here as you grade.",
            comment: "Hint shown in the preview empty state."
        )
        compareLabel = filmtoneLocalized(
            "filmtone.preview.compare_label",
            defaultValue: "Original",
            comment: "Badge shown while comparing with the original."
        )
        compareHint = filmtoneLocalized(
            "filmtone.preview.compare_hint",
            defaultValue: "Press and hold the preview to compare.",
            comment: "Hint that explains compare interaction."
        )
        previewGradedLabel = filmtoneLocalized(
            "filmtone.preview.graded_label",
            defaultValue: "Graded",
            comment: "Label for the graded video preview mode."
        )
        previewExpandLabel = filmtoneLocalized(
            "filmtone.preview.expand",
            defaultValue: "Full Screen",
            comment: "Action label to open the video preview in full screen."
        )
        presetTitle = filmtoneLocalized(
            "filmtone.preset.title",
            defaultValue: "Film Presets",
            comment: "Section title for presets."
        )
        strengthLabel = filmtoneLocalized(
            "filmtone.adjustment.strength",
            defaultValue: "Strength",
            comment: "Label for the strength control."
        )
        adjustLabel = filmtoneLocalized(
            "filmtone.adjustment.title",
            defaultValue: "Adjust",
            comment: "Section title for adjustments."
        )
        adjustOpenLabel = filmtoneLocalized(
            "filmtone.adjustment.open",
            defaultValue: "Fine Tune",
            comment: "Title for the button that opens detailed look controls."
        )
        quickFilmCharacter = filmtoneLocalized(
            "filmtone.quick.exposure",
            defaultValue: "Exposure",
            comment: "Quick adjustment axis label."
        )
        quickEra = filmtoneLocalized(
            "filmtone.quick.contrast",
            defaultValue: "Contrast",
            comment: "Quick adjustment axis label."
        )
        quickDynamics = filmtoneLocalized(
            "filmtone.quick.saturation",
            defaultValue: "Saturation",
            comment: "Quick adjustment axis label."
        )
        advancedParamsLabel = filmtoneLocalized(
            "filmtone.advanced.title",
            defaultValue: "Advanced Params",
            comment: "Section title for advanced parameters."
        )
        advancedParamsHint = filmtoneLocalized(
            "filmtone.advanced.hint",
            defaultValue: "Fine-tune the optical mix directly.",
            comment: "Hint shown when no advanced params are overridden."
        )
        advancedAdjustmentsActive = filmtoneLocalized(
            "filmtone.advanced.active",
            defaultValue: "Advanced tuning active.",
            comment: "Summary text shown when advanced adjustments are active."
        )
        advancedBasicLabel = filmtoneLocalized(
            "filmtone.advanced.group.basic",
            defaultValue: "Basic",
            comment: "Group title for basic advanced params."
        )
        advancedProcessLabel = filmtoneLocalized(
            "filmtone.advanced.group.process",
            defaultValue: prefersJapanese ? "プロセス" : "Process",
            comment: "Group title for process advanced params."
        )
        advancedOpticsLabel = filmtoneLocalized(
            "filmtone.advanced.group.optics",
            defaultValue: "Optics",
            comment: "Group title for optics advanced params."
        )
        advancedGlowLabel = filmtoneLocalized(
            "filmtone.advanced.group.glow",
            defaultValue: "Glow",
            comment: "Group title for glow advanced params."
        )
        advancedGrainLabel = filmtoneLocalized(
            "filmtone.advanced.group.grain",
            defaultValue: "Grain",
            comment: "Group title for grain advanced params."
        )
        advancedToneLabel = filmtoneLocalized(
            "filmtone.advanced.group.tone_only",
            defaultValue: prefersJapanese ? "階調" : "Tone",
            comment: "Group title for tone advanced params."
        )
        advancedPresetNoneLabel = filmtoneLocalized(
            "filmtone.advanced.preset.none",
            defaultValue: "None",
            comment: "Compact preset chip that clears an advanced parameter group effect."
        )
        advancedPresetDefaultLabel = filmtoneLocalized(
            "filmtone.advanced.preset.default",
            defaultValue: "Default",
            comment: "Compact preset chip that applies the standard advanced parameter group recipe."
        )
        advancedPresetStrongLabel = filmtoneLocalized(
            "filmtone.advanced.preset.strong",
            defaultValue: "Strong",
            comment: "Compact preset chip that applies a stronger advanced parameter group recipe."
        )
        advancedPresetCustomLabel = filmtoneLocalized(
            "filmtone.advanced.preset.custom",
            defaultValue: "Custom",
            comment: "Compact status label shown when an advanced parameter group has manual overrides."
        )
        paramLabels = [
            "exposure": filmtoneLocalized("filmtone.param.exposure", defaultValue: "Exposure", comment: "Advanced parameter label."),
            "contrast": filmtoneLocalized("filmtone.param.contrast", defaultValue: "Contrast", comment: "Advanced parameter label."),
            "saturation": filmtoneLocalized("filmtone.param.saturation", defaultValue: "Saturation", comment: "Advanced parameter label."),
            "temperature": filmtoneLocalized("filmtone.param.temperature", defaultValue: "Temperature", comment: "Advanced parameter label."),
            "tint": filmtoneLocalized("filmtone.param.tint", defaultValue: "Tint", comment: "Advanced parameter label."),
            "fade": filmtoneLocalized("filmtone.param.fade", defaultValue: "Fade", comment: "Advanced parameter label."),
            "rgbShift": filmtoneLocalized("filmtone.param.rgb_shift", defaultValue: "Color fringing", comment: "Advanced parameter label."),
            "lensSoftness": filmtoneLocalized("filmtone.param.lens_softness", defaultValue: "Lens softness", comment: "Advanced parameter label."),
            "vignette": filmtoneLocalized("filmtone.param.vignette", defaultValue: "Vignette", comment: "Advanced parameter label."),
            "bloomThreshold": filmtoneLocalized("filmtone.param.bloom_threshold", defaultValue: "Bloom Threshold", comment: "Advanced parameter label."),
            "bloomStrength": filmtoneLocalized("filmtone.param.bloom_strength", defaultValue: "Bloom Strength", comment: "Advanced parameter label."),
            "bloomRadius": filmtoneLocalized("filmtone.param.bloom_radius", defaultValue: "Bloom Radius", comment: "Advanced parameter label."),
            "bloomSoftKnee": filmtoneLocalized("filmtone.param.bloom_soft_knee", defaultValue: "Bloom Soft Knee", comment: "Advanced parameter label."),
            "halationIntensity": filmtoneLocalized("filmtone.param.halation_intensity", defaultValue: "Halation Intensity", comment: "Advanced parameter label."),
            "halationSpread": filmtoneLocalized("filmtone.param.halation_spread", defaultValue: "Halation Spread", comment: "Advanced parameter label."),
            "halationHue": filmtoneLocalized("filmtone.param.halation_hue", defaultValue: "Halation Hue", comment: "Advanced parameter label."),
            "halationThreshold": filmtoneLocalized("filmtone.param.halation_threshold", defaultValue: "Halation Threshold", comment: "Advanced parameter label."),
            "halationRadius": filmtoneLocalized("filmtone.param.halation_radius", defaultValue: "Halation Radius", comment: "Advanced parameter label."),
            "halationSoftKnee": filmtoneLocalized("filmtone.param.halation_soft_knee", defaultValue: "Halation Soft Knee", comment: "Advanced parameter label."),
            "diffusion": filmtoneLocalized("filmtone.param.diffusion", defaultValue: "Diffusion", comment: "Advanced parameter label."),
            "grainIntensity": filmtoneLocalized("filmtone.param.grain_intensity", defaultValue: "Grain Strength", comment: "Advanced parameter label."),
            "grainSize": filmtoneLocalized("filmtone.param.grain_size", defaultValue: "Grain Size", comment: "Advanced parameter label."),
            "grainRadialMix": filmtoneLocalized("filmtone.param.grain_radial_mix", defaultValue: "Grain edge emphasis", comment: "Advanced parameter label."),
            "compressionAmount": filmtoneLocalized("filmtone.param.compression_amount", defaultValue: "Highlight softness", comment: "Advanced parameter label."),
            "compressionRange": filmtoneLocalized("filmtone.param.compression_range", defaultValue: "Tone span", comment: "Advanced parameter label."),
            "printContrast": filmtoneLocalized("filmtone.param.print_contrast", defaultValue: "Print Contrast", comment: "Advanced parameter label."),
            "cyan": filmtoneLocalized("filmtone.param.cyan", defaultValue: "Cyan", comment: "Advanced parameter label."),
            "magenta": filmtoneLocalized("filmtone.param.magenta", defaultValue: "Magenta", comment: "Advanced parameter label."),
            "yellow": filmtoneLocalized("filmtone.param.yellow", defaultValue: "Yellow", comment: "Advanced parameter label."),
        ]
        resetLabel = filmtoneLocalized(
            "filmtone.action.reset",
            defaultValue: "Reset",
            comment: "Action label to reset adjustments."
        )
        exportSectionTitle = filmtoneLocalized(
            "filmtone.export.title",
            defaultValue: "Export",
            comment: "Section title for export."
        )
        exportIdle = filmtoneLocalized(
            "filmtone.export.ready",
            defaultValue: "Ready to export.",
            comment: "Status shown before export starts."
        )
        exportRunning = filmtoneLocalized(
            "filmtone.export.running",
            defaultValue: "Exporting…",
            comment: "Status shown while export runs."
        )
        exportWritingHint = filmtoneLocalized(
            "filmtone.export.writing_hint",
            defaultValue: "Finalizing. Larger photos or videos may take a moment.",
            comment: "Hint shown during the writing stage."
        )
        exportStart = filmtoneLocalized(
            "filmtone.export.start",
            defaultValue: "Export",
            comment: "Primary export action."
        )
        exportDisabled = filmtoneLocalized(
            "filmtone.export.disabled",
            defaultValue: "This source can't be exported. See the source notes above.",
            comment: "Message shown when the current source fails export validation."
        )
        saveToPhotos = filmtoneLocalized(
            "filmtone.export.save_to_photos",
            defaultValue: "Save to Photos",
            comment: "Action to save the output to Photos."
        )
        saveToPhotosDone = filmtoneLocalized(
            "filmtone.export.save_to_photos_done",
            defaultValue: "Saved to Photos.",
            comment: "Notice shown when saving to Photos succeeds."
        )
        shareOutput = filmtoneLocalized(
            "filmtone.export.share",
            defaultValue: "Share",
            comment: "Action to share the exported output."
        )
        resultTitle = filmtoneLocalized(
            "filmtone.export.last_result",
            defaultValue: "Last export",
            comment: "Title shown for the latest export result."
        )
        metricsElapsed = filmtoneLocalized(
            "filmtone.metric.elapsed",
            defaultValue: "Elapsed",
            comment: "Metric label for elapsed time."
        )
        metricsOutput = filmtoneLocalized(
            "filmtone.metric.output",
            defaultValue: "Output",
            comment: "Metric label for output resolution."
        )
        metricsFileSize = filmtoneLocalized(
            "filmtone.metric.file_size",
            defaultValue: "File size",
            comment: "Metric label for file size."
        )
        metricsSaveToPhotos = filmtoneLocalized(
            "filmtone.metric.save_to_photos",
            defaultValue: "Save to Photos",
            comment: "Metric label for save-to-Photos state."
        )
        noticePrefix = filmtoneLocalized(
            "filmtone.message.note",
            defaultValue: "Note",
            comment: "Prefix used for informational message panels."
        )
        errorPrefix = filmtoneLocalized(
            "filmtone.message.error",
            defaultValue: "Error",
            comment: "Prefix used for error message panels."
        )
        doneLabel = filmtoneLocalized(
            "filmtone.action.done",
            defaultValue: "Done",
            comment: "Action label to close a sheet."
        )
        cameraLabel = filmtoneLocalized(
            "filmtone.camera.title",
            defaultValue: "Camera",
            comment: "Label for the camera profile control."
        )
        cameraDescription = filmtoneLocalized(
            "filmtone.camera.description",
            defaultValue: "Normalize log source media before the look. Phase 1 supports Auto or one imported .cube.",
            comment: "Description shown for camera profile behavior."
        )
        cameraAuto = filmtoneLocalized(
            "filmtone.camera.auto",
            defaultValue: "Auto",
            comment: "Default camera profile state."
        )
        cameraAutoAppleLogDetected = filmtoneLocalized(
            "filmtone.camera.auto_apple_log_detected",
            defaultValue: "Auto -> Apple Log detected",
            comment: "Camera profile state when Apple Log is automatically detected."
        )
        cameraAutoAppleLog2Detected = filmtoneLocalized(
            "filmtone.camera.auto_apple_log2_detected",
            defaultValue: "Auto -> Apple Log 2 detected",
            comment: "Camera profile state when Apple Log 2 is automatically detected."
        )
        cameraCustom = filmtoneLocalized(
            "filmtone.camera.custom",
            defaultValue: "Custom",
            comment: "Camera profile state when a custom input LUT is selected."
        )
        cameraImport = filmtoneLocalized(
            "filmtone.camera.import",
            defaultValue: "Import .cube",
            comment: "Action label to import a camera .cube."
        )
        clearLut = filmtoneLocalized(
            "filmtone.camera.clear",
            defaultValue: "Clear",
            comment: "Action label to clear the imported LUT."
        )
        lutImportError = filmtoneLocalized(
            "filmtone.lut.import_error",
            defaultValue: "Camera profile import failed",
            comment: "Error prefix for LUT import problems."
        )
        lutParseError = filmtoneLocalized(
            "filmtone.lut.parse_error",
            defaultValue: "Camera profile .cube could not be parsed",
            comment: "Error shown when parsing a LUT file fails."
        )
        exportStagePreflight = filmtoneLocalized(
            "filmtone.export.stage.preflight",
            defaultValue: "Preparing",
            comment: "Label for the export preflight stage."
        )
        exportStageReading = filmtoneLocalized(
            "filmtone.export.stage.reading",
            defaultValue: "Reading",
            comment: "Label for the export reading stage."
        )
        exportStageRendering = filmtoneLocalized(
            "filmtone.export.stage.rendering",
            defaultValue: "Rendering",
            comment: "Label for the export rendering stage."
        )
        exportStageWriting = filmtoneLocalized(
            "filmtone.export.stage.writing",
            defaultValue: "Writing",
            comment: "Label for the export writing stage."
        )
        exportStageCompleted = filmtoneLocalized(
            "filmtone.export.stage.completed",
            defaultValue: "Completed",
            comment: "Label for the export completed stage."
        )
        saveStateSaved = filmtoneLocalized(
            "filmtone.export.save_state.saved",
            defaultValue: "Saved",
            comment: "State badge shown after Save to Photos succeeds."
        )
        saveStateFailed = filmtoneLocalized(
            "filmtone.export.save_state.failed",
            defaultValue: "Failed",
            comment: "State badge shown after Save to Photos fails."
        )
        presetCategoryFilmStock = filmtoneLocalized(
            "filmtone.preset.category.film_stock",
            defaultValue: "Film",
            comment: "Preset category label for film stock presets."
        )
        presetCategoryLook = filmtoneLocalized(
            "filmtone.preset.category.look",
            defaultValue: "Look",
            comment: "Preset category label for look presets."
        )
        presetCategoryUtility = filmtoneLocalized(
            "filmtone.preset.category.utility",
            defaultValue: "Utility",
            comment: "Preset category label for utility presets."
        )
        genericPickSourceError = filmtoneLocalized(
            "filmtone.error.generic.pick_source",
            defaultValue: "Media selection couldn't be completed.",
            comment: "Fallback error for source picking."
        )
        genericImportLutError = filmtoneLocalized(
            "filmtone.error.generic.import_lut",
            defaultValue: "The camera profile couldn't be imported.",
            comment: "Fallback error for LUT import."
        )
        genericExportError = filmtoneLocalized(
            "filmtone.error.generic.export",
            defaultValue: "Export couldn't be completed.",
            comment: "Fallback error for export."
        )
        genericSaveToPhotosError = filmtoneLocalized(
            "filmtone.error.generic.save_to_photos",
            defaultValue: "Saving to Photos couldn't be completed.",
            comment: "Fallback error for saving to Photos."
        )
        genericShareError = filmtoneLocalized(
            "filmtone.error.generic.share",
            defaultValue: "Sharing couldn't be completed.",
            comment: "Fallback error for sharing."
        )
        genericPreviewError = filmtoneLocalized(
            "filmtone.error.generic.preview",
            defaultValue: "Preview couldn't be generated.",
            comment: "Fallback error for preview rendering."
        )
        // MARK: HDR policy notice (v1.1)
        // Per terminology SSoT §5.1 / §5.2, all three body variants share the same
        // generic end-user copy. v1.2 candidate: collapse to single body key.
        let hdrGenericBody = prefersJapanese
            ? "この環境では、HDR動画を標準のSDR動画として正確に変換できない場合があります。書き出しは続行できますが、他のアプリで見ると明るさや色が元動画と違って見えることがあります。正確な色で書き出したい場合は、カメラアプリや編集アプリでSDR動画に変換してから読み込んでください。"
            : "This environment may not be able to convert HDR video into a standard SDR video accurately. You can continue exporting, but brightness or color may look different in other apps. For color-critical exports, convert the clip to SDR in your camera app or editor before importing it."
        hdrNoticeTitle = filmtoneLocalized(
            "filmtone.hdr.notice.title",
            defaultValue: prefersJapanese ? "HDR動画を読み込みました" : "HDR video loaded",
            comment: "Title for the inline HDR preparation policy notice."
        )
        hdrNoticeBodyPq = filmtoneLocalized(
            "filmtone.hdr.notice.body.pq",
            defaultValue: hdrGenericBody,
            comment: "Body text shown when a PQ HDR source is loaded."
        )
        hdrNoticeBodyHlg = filmtoneLocalized(
            "filmtone.hdr.notice.body.hlg",
            defaultValue: hdrGenericBody,
            comment: "Body text shown when an HLG HDR source is loaded."
        )
        hdrNoticeBodyWideGamutUnknown = filmtoneLocalized(
            "filmtone.hdr.notice.body.wideGamutUnknown",
            defaultValue: hdrGenericBody,
            comment: "Body text shown when the source is wide-gamut but transfer is unknown."
        )
        // MARK: Camera optics label (v1.1)
        opticsSourceMetadata = filmtoneLocalized(
            "filmtone.optics.source.metadata",
            defaultValue: prefersJapanese ? "メタデータ" : "metadata",
            comment: "Trailing tag shown on camera optics label when values came from source metadata."
        )
        opticsSourceAssumed = filmtoneLocalized(
            "filmtone.optics.source.assumed",
            defaultValue: prefersJapanese ? "推定" : "assumed",
            comment: "Trailing tag shown on camera optics label when values were inferred from defaults."
        )
        opticsSourceAccessibilityMetadata = filmtoneLocalized(
            "filmtone.optics.source.accessibility.metadata",
            defaultValue: prefersJapanese ? "メタデータから取得" : "from camera metadata",
            comment: "VoiceOver phrasing for metadata-sourced optics."
        )
        opticsSourceAccessibilityAssumed = filmtoneLocalized(
            "filmtone.optics.source.accessibility.assumed",
            defaultValue: prefersJapanese ? "既定値で推定" : "assumed defaults",
            comment: "VoiceOver phrasing for assumed optics."
        )
        opticsHfovFormat = filmtoneLocalized(
            "filmtone.optics.label.hfov",
            defaultValue: "HFOV %@°",
            comment: "Format string for horizontal field of view (degree sign literal)."
        )
        opticsSeparator = filmtoneLocalized(
            "filmtone.optics.label.separator",
            defaultValue: "・",
            comment: "Separator used between metadata segments in the optics label."
        )
        opticsMetricLabel = filmtoneLocalized(
            "filmtone.metric.optics",
            defaultValue: prefersJapanese ? "光学系" : "Optics",
            comment: "Metric card label shown above the camera optics detail in the export panel."
        )
        toastSaveSuccess = filmtoneLocalized(
            "filmtone.toast.save.success",
            defaultValue: prefersJapanese ? "写真に保存しました" : "Saved to Photos",
            comment: "Toast shown when Save to Photos succeeds. Auto-dismisses after a short delay."
        )
        toastExportComplete = filmtoneLocalized(
            "filmtone.toast.export.complete",
            defaultValue: prefersJapanese ? "書き出し完了" : "Export complete",
            comment: "Toast shown when an export run finishes successfully."
        )
        toastShareFailed = filmtoneLocalized(
            "filmtone.toast.share.failed",
            defaultValue: prefersJapanese ? "共有に失敗しました" : "Share failed — try again",
            comment: "Toast shown when sharing the exported file fails."
        )
    }

    func paramLabel(for key: String) -> String {
        paramLabels[key] ?? key
    }

    var usesJapaneseTypography: Bool {
        locale.language.languageCode?.identifier.hasPrefix("ja") == true
    }

    func stageLabel(for stage: Phase0ExportStage) -> String {
        switch stage {
        case .preflight:
            return exportStagePreflight
        case .reading:
            return exportStageReading
        case .rendering:
            return exportStageRendering
        case .writing:
            return exportStageWriting
        case .completed:
            return exportStageCompleted
        }
    }

    func sourceLoadTitle(for stage: FilmtoneSourceLoadState.Stage) -> String {
        switch stage {
        case .importing:
            return sourceLoadImportingTitle
        case .probing:
            return sourceLoadProbingTitle
        }
    }

    func sourceImportMessage(
        for phase: FilmtoneSourceImportProgressPhase,
        route: FilmtoneSourcePickerRoute
    ) -> String {
        switch phase {
        case .importing:
            switch route {
            case .photoLibrary:
                return sourceLoadImportingMessage
            case .files:
                return sourceLoadImportingFromFilesMessage
            }
        case .downloadingFromCloud:
            return sourceLoadDownloadingFromCloudMessage
        }
    }

    func saveStateLabel(_ state: FilmtoneSaveToPhotosState) -> String {
        switch state {
        case .notRun:
            return "—"
        case .saved:
            return saveStateSaved
        case .failed:
            return saveStateFailed
        }
    }

    func categoryLabel(for category: FilmtonePresetCategory) -> String {
        switch category {
        case .filmStock:
            return presetCategoryFilmStock
        case .look:
            return presetCategoryLook
        case .utility:
            return presetCategoryUtility
        }
    }

    func byteLabel(_ fileSizeBytes: Int?) -> String {
        guard let fileSizeBytes else {
            return "—"
        }
        return ByteCountFormatter.string(
            fromByteCount: Int64(fileSizeBytes),
            countStyle: .file
        )
    }

    func elapsedLabel(_ elapsedMs: Int) -> String {
        compactDurationLabel(Double(elapsedMs) / 1000)
    }

    func outputSummaryLabel(width: Int, height: Int, fps: Int) -> String {
        filmtoneLocalizedFormat(
            "filmtone.metric.output_value",
            defaultValue: "%1$@×%2$@ @ %3$@ fps",
            arguments: [
                String(width),
                String(height),
                filmtoneLocalizedNumber(Double(fps), maximumFractionDigits: 0)
            ],
            comment: "Formatted output metric that shows resolution and frame rate."
        )
    }

    func compactDurationLabel(_ durationSec: Double) -> String {
        let roundedTenth = (durationSec * 10).rounded() / 10
        if roundedTenth < 60 {
            let seconds = filmtoneLocalizedNumber(roundedTenth, maximumFractionDigits: 1)
            return filmtoneLocalizedFormat(
                "filmtone.duration.seconds",
                defaultValue: "%@s",
                arguments: [seconds],
                comment: "Duration string for a value in seconds."
            )
        }

        let totalSeconds = Int(durationSec.rounded())
        let minutes = String(totalSeconds / 60)
        let seconds = String(totalSeconds % 60)
        return filmtoneLocalizedFormat(
            "filmtone.duration.minutes_seconds",
            defaultValue: "%1$@m %2$@s",
            arguments: [minutes, seconds],
            comment: "Duration string for values in minutes and seconds."
        )
    }

    func userMessage(for error: Error, context: FilmtoneUserErrorContext) -> String {
        if let mediaError = error as? FilmtoneMediaError {
            return mediaError.userFacingMessage(strings: self, context: context)
        }

        if let requestError = error as? FilmtoneRequestBuildError {
            return requestError.localizedDescription
        }

        switch context {
        case .pickSource:
            return genericPickSourceError
        case .importLut:
            return genericImportLutError
        case .export:
            return genericExportError
        case .saveToPhotos:
            return genericSaveToPhotosError
        case .share:
            return genericShareError
        case .preview:
            return genericPreviewError
        }
    }
}

enum FilmtoneStringsCatalog {
    static var current: FilmtoneStrings {
        FilmtoneStrings(locale: .current)
    }
}

enum FilmtoneUserErrorContext {
    case pickSource
    case importLut
    case export
    case saveToPhotos
    case share
    case preview
}

extension FilmtoneMediaError {
    func userFacingMessage(strings: FilmtoneStrings, context: FilmtoneUserErrorContext) -> String {
        switch self {
        case .bridgeUnavailable,
             .exportBusy,
             .exportCancelled,
             .depthUnsupportedForVideoSource,
             .depthUnsupportedFormat:
            return localizedDescription
        case .invalidURL(let message),
             .missingSource(let message),
             .unsupportedSource(let message),
             .permissionDenied(let message),
             .pickerUnavailable(let message):
            return message
        case .exportFailed:
            switch context {
            case .preview:
                return strings.genericPreviewError
            default:
                return strings.genericExportError
            }
        case .saveFailed:
            return strings.genericSaveToPhotosError
        case .shareFailed:
            return strings.genericShareError
        case .cacheFailed:
            switch context {
            case .pickSource:
                return strings.genericPickSourceError
            case .importLut:
                return strings.genericImportLutError
            case .export:
                return strings.genericExportError
            case .saveToPhotos:
                return strings.genericSaveToPhotosError
            case .share:
                return strings.genericShareError
            case .preview:
                return strings.genericPreviewError
            }
        }
    }
}
