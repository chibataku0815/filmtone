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
    let onboardingNext: String
    let onboardingSkip: String
    let onboardingPickMedia: String
    let onboardingChooseTitle: String
    let onboardingChooseBody: String
    let onboardingShapeTitle: String
    let onboardingShapeBody: String
    let onboardingFinishTitle: String
    let onboardingFinishBody: String
    /// 4th onboarding slide added in v1.3 (Item 3 follow-up): teaches the
    /// reuse loop — Saved LUTs / Saved Looks / source-swap survival.
    let onboardingReuseTitle: String
    let onboardingReuseBody: String
    let helpLutTitle: String
    let helpLutBody: String
    let helpLutCameraLut: String
    let helpLutLookLut: String
    /// Tertiary help-sheet section (v1.3): explains that imported LUTs and
    /// saved Looks live in the local library and survive source swaps. Sits
    /// alongside the camera-LUT / look-LUT explanations on the same ⓘ sheet.
    let helpLutSavedLibrary: String
    let helpLutAccessibilityLabel: String
    let helpDismiss: String
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
    let advancedMotionLabel: String
    let advancedToneLabel: String
    let advancedPresetNoneLabel: String
    let advancedPresetDefaultLabel: String
    let advancedPresetStrongLabel: String
    let advancedPresetPrintLabel: String
    let advancedPresetPushLabel: String
    let advancedPresetVividLabel: String
    let advancedPresetPunchLabel: String
    let advancedPresetCustomLabel: String
    let advancedToneStandardLabel: String
    let advancedToneAiryLabel: String
    let advancedToneSunsetLabel: String
    let advancedToneDepthLabel: String
    let paramLabels: [String: String]
    let resetLabel: String
    let exportSectionTitle: String
    let exportIdle: String
    let exportRunning: String
    let exportWritingHint: String
    let exportStart: String
    let exportAndSave: String
    let exportSavingToPhotos: String
    let exportDisabled: String
    let saveToPhotos: String
    let saveToPhotosDone: String
    let unsavedExportPrompt: String
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
    /// v1.3 Camera Profiles Phase D — built-in source profile catalog labels.
    let cameraAppleLog: String
    let cameraAppleLog2: String
    let cameraVLog: String
    let cameraSLog3: String
    let cameraRec709: String
    let cameraCustom: String
    let cameraImport: String
    let inputLutAmountLabel: String
    let lookLabel: String
    let lookFilmtone: String
    let lookCustom: String
    let lookImport: String
    let lookLutAmountLabel: String
    let clearLut: String
    let lutImportError: String
    let lutParseError: String
    let lookLutParseError: String
    let exportStagePreflight: String
    let exportStageReading: String
    let exportStageRendering: String
    let exportStageWriting: String
    let exportStageCompleted: String
    let saveStateSaved: String
    let saveStateFailed: String
    let presetCategoryBase: String
    let presetCategoryCamera: String
    let presetCategoryLook: String
    let genericPickSourceError: String
    let genericImportLutError: String
    let genericImportLookLutError: String
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
    // MARK: - LUT library + Saved Looks (Item 3, v1.3 candidate)
    let librarySavedLutsTitle: String
    let librarySavedLooksTitle: String
    let librarySavedLooksEmpty: String
    let libraryApplyAction: String
    let libraryRenameAction: String
    let libraryDeleteAction: String
    let libraryFavoriteAction: String
    let libraryUnfavoriteAction: String
    let libraryQuotaExceeded: String
    let libraryLutMissingOnApply: String
    let lookSaveCurrentMenu: String
    let lookSavedToastFormat: String
    let lookAppliedToastFormat: String
    let savedLookSheetCreateTitle: String
    let savedLookSheetRenameTitle: String
    let savedLookSheetCreateHeadline: String
    let savedLookSheetRenameHeadline: String
    let savedLookSheetBody: String
    let savedLookNamePlaceholder: String
    let savedLookSheetSave: String
    let savedLookSheetRename: String
    let savedLookSheetCancel: String

    // MARK: - Built-in Filmtone Looks (Item 2, v1.3 candidate)
    let builtInLookFilmtoneSignature: String
    let builtInLookCleanBase: String
    let builtInLookAmberGlow: String
    let builtInLookSoftBlue: String
    let builtInLookNightSoft: String
    /// Caption-style badge that marks a chip as a built-in catalog
    /// entry. Same text in ja and en since "FILMTONE" is the brand
    /// glyph rather than a translatable label.
    let builtInBadgeLabel: String
}

extension FilmtoneStrings {
    /// Resolves a built-in Look's localized display name from its
    /// catalog slug. Returns nil for non-built-in slugs so callers can
    /// fall back to `entry.name` directly.
    func builtInLookName(for slug: String) -> String? {
        switch slug {
        case "filmtone-signature": return builtInLookFilmtoneSignature
        case "clean-base":         return builtInLookCleanBase
        case "amber-glow":         return builtInLookAmberGlow
        case "soft-blue":          return builtInLookSoftBlue
        case "night-soft":         return builtInLookNightSoft
        default:                   return nil
        }
    }

    /// Returns the display name for a Saved Look, picking the localized
    /// built-in name when the look is bundled and a slug match exists,
    /// or falling through to the user-stored `name`.
    func displayName(for look: SavedLookEntry) -> String {
        if look.bundled,
           let slug = look.bundledSlug,
           let localized = builtInLookName(for: slug) {
            return localized
        }
        return look.name
    }

    /// v1.3 Camera Profiles Phase D — resolves a built-in source-profile
    /// catalog id (e.g. "built-in:source-profile.panasonic-vlog") or its
    /// short slug suffix to the localized display name. Returns nil when
    /// the input is neither a known catalog id nor a known slug.
    func builtInSourceProfileName(for catalogIdOrSlug: String) -> String? {
        let prefix = "built-in:source-profile."
        let slug: String
        if catalogIdOrSlug.hasPrefix(prefix) {
            slug = String(catalogIdOrSlug.dropFirst(prefix.count))
        } else {
            slug = catalogIdOrSlug
        }
        switch slug {
        case "apple-log":      return cameraAppleLog
        case "apple-log-2":    return cameraAppleLog2
        case "panasonic-vlog": return cameraVLog
        case "sony-slog3":     return cameraSLog3
        case "rec709":         return cameraRec709
        default:               return nil
        }
    }
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
        onboardingNext = filmtoneLocalized(
            "filmtone.onboarding.next",
            defaultValue: prefersJapanese ? "次へ" : "Next",
            comment: "Primary onboarding action that advances to the next page."
        )
        onboardingSkip = filmtoneLocalized(
            "filmtone.onboarding.skip",
            defaultValue: prefersJapanese ? "スキップ" : "Skip",
            comment: "Secondary onboarding action that closes onboarding."
        )
        onboardingPickMedia = filmtoneLocalized(
            "filmtone.onboarding.pick_media",
            defaultValue: prefersJapanese ? "素材を選ぶ" : "Pick media",
            comment: "Final onboarding action that opens the existing source picker."
        )
        onboardingChooseTitle = filmtoneLocalized(
            "filmtone.onboarding.choose.title",
            defaultValue: prefersJapanese ? "写真や動画を選んで、すぐ映画調に" : "Choose a photo or video",
            comment: "Onboarding page title for choosing media."
        )
        onboardingChooseBody = filmtoneLocalized(
            "filmtone.onboarding.choose.body",
            defaultValue: prefersJapanese ? "自分の素材を読み込むと、映画調ルックのプレビューがすぐ始まります。" : "Load your own media and Filmtone starts a cinematic preview right away.",
            comment: "Onboarding page body for choosing media."
        )
        onboardingShapeTitle = filmtoneLocalized(
            "filmtone.onboarding.shape.title",
            defaultValue: prefersJapanese ? "質感まで作品に合わせて整える" : "Shape the film character",
            comment: "Onboarding page title for film character controls."
        )
        onboardingShapeBody = filmtoneLocalized(
            "filmtone.onboarding.shape.body",
            defaultValue: prefersJapanese ? "粒状感、グロー、トーン、動きの質感まで、作品に合わせて追い込めます。" : "Tune grain, glow, tone, and motion feel so the look fits the piece.",
            comment: "Onboarding page body for film character controls."
        )
        onboardingFinishTitle = filmtoneLocalized(
            "filmtone.onboarding.finish.title",
            defaultValue: prefersJapanese ? "LUTから書き出しまで完結" : "Finish with LUTs and export",
            comment: "Onboarding page title for LUT and export workflow."
        )
        onboardingFinishBody = filmtoneLocalized(
            "filmtone.onboarding.finish.body",
            defaultValue: prefersJapanese ? "色の方向をLUTで決めて、そのままiPhoneだけで書き出します。" : "Pick a color direction with a LUT, then export right on iPhone.",
            comment: "Onboarding page body for LUT and export workflow."
        )
        onboardingReuseTitle = filmtoneLocalized(
            "filmtone.onboarding.reuse.title",
            defaultValue: prefersJapanese
                ? "保存して、次の素材でも再利用"
                : "Save it. Reuse it on the next clip.",
            comment: "4th onboarding slide title (v1.3 Item 3): introduces the Saved LUTs / Saved Looks reuse loop."
        )
        onboardingReuseBody = filmtoneLocalized(
            "filmtone.onboarding.reuse.body",
            defaultValue: prefersJapanese
                ? "読み込んだLUTや作った Look は自動でライブラリに残ります。次の素材でもタップひとつで同じトーンを呼び出せます。"
                : "Imported LUTs and saved Looks stay in your library. Tap once to bring the same tone into your next clip.",
            comment: "4th onboarding slide body (v1.3 Item 3): explains saved-library reuse."
        )
        helpLutTitle = filmtoneLocalized(
            "filmtone.help.lut.title",
            defaultValue: prefersJapanese ? "LUTとは" : "What is a LUT?",
            comment: "Title shown in the LUT term help sheet."
        )
        helpLutBody = filmtoneLocalized(
            "filmtone.help.lut.body",
            defaultValue: prefersJapanese
                ? "色の雰囲気を一括で整えるデータです。カメラ素材の下準備や、仕上げの色づくりに使います。"
                : "A recipe that shapes colors at once. Use it to prepare footage or apply a finished look.",
            comment: "Body shown in the LUT term help sheet, explaining the umbrella concept."
        )
        helpLutCameraLut = filmtoneLocalized(
            "filmtone.help.lut.camera_lut",
            defaultValue: prefersJapanese
                ? "カメラLUT — カメラが記録した色を、Filmtoneが扱いやすい状態に整えます。"
                : "Camera LUT — Prepares the colors your camera recorded so Filmtone can work with them.",
            comment: "Sub-explanation of the camera-side LUT in the help sheet."
        )
        helpLutLookLut = filmtoneLocalized(
            "filmtone.help.lut.look_lut",
            defaultValue: prefersJapanese
                ? "ルックLUT — 仕上げの色や雰囲気を重ねます。作品のトーンを決める最後の一手です。"
                : "Look LUT — Layers the final mood and color palette onto your piece.",
            comment: "Sub-explanation of the look-side LUT in the help sheet."
        )
        helpLutSavedLibrary = filmtoneLocalized(
            "filmtone.help.lut.saved_library",
            defaultValue: prefersJapanese
                ? "保存したLUT / 保存したルック — 一度読み込んだLUTや調整した Look は自動でライブラリに残り、次の素材でも下のストリップからタップで再利用できます。"
                : "Saved LUTs / Saved Looks — Imported LUTs and adjusted Looks stay in your library. Tap a chip below to reapply them to the next clip.",
            comment: "Tertiary explanation introduced in v1.3 (Item 3): describes the saved-LUT / saved-Look library reuse loop."
        )
        helpLutAccessibilityLabel = filmtoneLocalized(
            "filmtone.help.lut.a11y",
            defaultValue: prefersJapanese ? "LUTの説明" : "About LUT",
            comment: "Accessibility label for the LUT term help button."
        )
        helpDismiss = filmtoneLocalized(
            "filmtone.help.dismiss",
            defaultValue: prefersJapanese ? "閉じる" : "Close",
            comment: "Action label that dismisses the term help sheet."
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
            defaultValue: prefersJapanese ? "階調" : "Tone",
            comment: "Group title for tone/process advanced params."
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
        advancedMotionLabel = filmtoneLocalized(
            "filmtone.advanced.group.motion",
            defaultValue: "Motion",
            comment: "Group title for motion advanced params."
        )
        advancedToneLabel = filmtoneLocalized(
            "filmtone.advanced.group.tone_only",
            defaultValue: prefersJapanese ? "階調" : "Tone",
            comment: "Group title for tone advanced params."
        )
        advancedPresetNoneLabel = filmtoneLocalized(
            "filmtone.advanced.preset.none",
            defaultValue: prefersJapanese ? "なし" : "None",
            comment: "Compact preset chip that clears an advanced parameter group effect."
        )
        advancedPresetDefaultLabel = filmtoneLocalized(
            "filmtone.advanced.preset.default",
            defaultValue: prefersJapanese ? "標準" : "Default",
            comment: "Compact preset chip that applies the standard advanced parameter group recipe."
        )
        advancedPresetStrongLabel = filmtoneLocalized(
            "filmtone.advanced.preset.strong",
            defaultValue: prefersJapanese ? "強め" : "Strong",
            comment: "Compact preset chip that applies a stronger advanced parameter group recipe."
        )
        advancedPresetPrintLabel = filmtoneLocalized(
            "filmtone.advanced.preset.print",
            defaultValue: prefersJapanese ? "階調" : "Tone",
            comment: "Compact preset chip that applies the tone/process advanced parameter recipe."
        )
        advancedPresetPushLabel = filmtoneLocalized(
            "filmtone.advanced.preset.push",
            defaultValue: "Push",
            comment: "Compact preset chip that applies the pushed-process advanced parameter recipe."
        )
        advancedPresetVividLabel = filmtoneLocalized(
            "filmtone.advanced.preset.vivid",
            defaultValue: "Vivid",
            comment: "Compact preset chip that applies the vivid tone advanced parameter recipe."
        )
        advancedPresetPunchLabel = filmtoneLocalized(
            "filmtone.advanced.preset.punch",
            defaultValue: "Punch",
            comment: "Compact preset chip that applies the punchy tone advanced parameter recipe."
        )
        advancedPresetCustomLabel = filmtoneLocalized(
            "filmtone.advanced.preset.custom",
            defaultValue: prefersJapanese ? "カスタム" : "Custom",
            comment: "Compact status label shown when an advanced parameter group has manual overrides."
        )
        advancedToneStandardLabel = filmtoneLocalized(
            "filmtone.advanced.tone.standard",
            defaultValue: prefersJapanese ? "標準" : "Standard",
            comment: "Tone recipe chip that clears tone overrides."
        )
        advancedToneAiryLabel = filmtoneLocalized(
            "filmtone.advanced.tone.airy",
            defaultValue: prefersJapanese ? "爽やか" : "Airy",
            comment: "Tone recipe chip for a cool airy tone."
        )
        advancedToneSunsetLabel = filmtoneLocalized(
            "filmtone.advanced.tone.sunset",
            defaultValue: prefersJapanese ? "夕景" : "Sunset",
            comment: "Tone recipe chip for a warm sunset tone."
        )
        advancedToneDepthLabel = filmtoneLocalized(
            "filmtone.advanced.tone.depth",
            defaultValue: prefersJapanese ? "深み" : "Depth",
            comment: "Tone recipe chip for neutral density and contrast."
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
            "shutterAngle": filmtoneLocalized("filmtone.param.shutter_angle", defaultValue: prefersJapanese ? "シャッターアングル" : "Shutter Angle", comment: "Advanced parameter label."),
            "trailIntensity": filmtoneLocalized("filmtone.param.trail_intensity", defaultValue: prefersJapanese ? "残像の長さ" : "Trail Length", comment: "Advanced parameter label."),
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
        exportAndSave = filmtoneLocalized(
            "filmtone.export.export_and_save",
            defaultValue: prefersJapanese ? "書き出して保存" : "Export & Save",
            comment: "Primary action that exports media and saves the result to Photos."
        )
        exportSavingToPhotos = filmtoneLocalized(
            "filmtone.export.saving_to_photos",
            defaultValue: prefersJapanese ? "写真へ保存中…" : "Saving to Photos…",
            comment: "Status shown after export finishes while the app is saving the output to Photos."
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
        unsavedExportPrompt = filmtoneLocalized(
            "filmtone.export.unsaved_prompt",
            defaultValue: prefersJapanese ? "書き出し完了。まだ写真には保存されていません。" : "Export complete. It has not been saved to Photos yet.",
            comment: "Bottom prompt shown when an exported result exists but has not been saved to Photos."
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
            defaultValue: "Normalize source media before the look. Creative LUTs stay separate.",
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
        cameraAppleLog = filmtoneLocalized(
            "filmtone.camera.apple_log",
            defaultValue: "Apple Log",
            comment: "Built-in camera source profile name (Apple Log)."
        )
        cameraAppleLog2 = filmtoneLocalized(
            "filmtone.camera.apple_log2",
            defaultValue: "Apple Log 2",
            comment: "Built-in camera source profile name (Apple Log 2)."
        )
        cameraVLog = filmtoneLocalized(
            "filmtone.camera.vlog",
            defaultValue: "V-Log",
            comment: "Built-in camera source profile name (Panasonic V-Log)."
        )
        cameraSLog3 = filmtoneLocalized(
            "filmtone.camera.slog3",
            defaultValue: "S-Log3",
            comment: "Built-in camera source profile name (Sony S-Log3)."
        )
        cameraRec709 = filmtoneLocalized(
            "filmtone.camera.rec709",
            defaultValue: "Rec.709",
            comment: "Built-in camera source profile name (Rec.709 passthrough)."
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
        inputLutAmountLabel = filmtoneLocalized(
            "filmtone.camera.input_lut_amount",
            defaultValue: prefersJapanese ? "カメラLUTの量" : "Camera LUT Amount",
            comment: "Label for the camera LUT amount slider (formerly Input LUT Amount)."
        )
        lookLabel = filmtoneLocalized(
            "filmtone.look.title",
            defaultValue: prefersJapanese ? "ルック" : "Look",
            comment: "Label for the creative look LUT control."
        )
        lookFilmtone = filmtoneLocalized(
            "filmtone.look.filmtone",
            defaultValue: "Filmtone",
            comment: "Default creative look state."
        )
        lookCustom = filmtoneLocalized(
            "filmtone.look.custom",
            defaultValue: prefersJapanese ? "カスタム" : "Custom",
            comment: "Creative look state when a custom LUT is selected."
        )
        lookImport = filmtoneLocalized(
            "filmtone.look.import",
            defaultValue: "Import .cube",
            comment: "Action label to import a creative look .cube."
        )
        lookLutAmountLabel = filmtoneLocalized(
            "filmtone.look.lut_amount",
            defaultValue: "Look LUT Amount",
            comment: "Label for the creative LUT amount slider."
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
        lookLutParseError = filmtoneLocalized(
            "filmtone.look.parse_error",
            defaultValue: "Look .cube could not be parsed",
            comment: "Error shown when parsing a creative look LUT file fails."
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
        presetCategoryBase = filmtoneLocalized(
            "filmtone.preset.category.base",
            defaultValue: "Base",
            comment: "Preset category label for the neutral base preset."
        )
        presetCategoryCamera = filmtoneLocalized(
            "filmtone.preset.category.camera",
            defaultValue: "Camera",
            comment: "Preset category label for camera-origin finishing presets."
        )
        presetCategoryLook = filmtoneLocalized(
            "filmtone.preset.category.look",
            defaultValue: "Look",
            comment: "Preset category label for look presets."
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
        genericImportLookLutError = filmtoneLocalized(
            "filmtone.error.generic.import_look_lut",
            defaultValue: "The look couldn't be imported.",
            comment: "Fallback error for creative look LUT import."
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
        librarySavedLutsTitle = filmtoneLocalized(
            "filmtone.library.saved_luts.title",
            defaultValue: prefersJapanese ? "保存したLUT" : "Saved LUTs",
            comment: "Section header above the horizontal imported-LUTs strip in the LUT card. Mirrors `Saved Looks` so the two reusable bins read symmetrically; sorted by lastUsedAt internally but the title does not surface the temporal frame because the v1.3 MVP has no `All` view to contrast against."
        )
        librarySavedLooksTitle = filmtoneLocalized(
            "filmtone.library.saved_looks.title",
            defaultValue: prefersJapanese ? "保存したルック" : "Saved Looks",
            comment: "Section header above the horizontal Saved Looks strip in the LUT card."
        )
        librarySavedLooksEmpty = filmtoneLocalized(
            "filmtone.library.saved_looks.empty",
            defaultValue: prefersJapanese
                ? "現在のグレードを Look として保存し、次のクリップでも同じトーンを再現できます。"
                : "Save your current grade as a Look to reuse the same tone on your next clip.",
            comment: "Empty-state copy shown under the Saved Looks header before the user has saved any looks."
        )
        libraryApplyAction = filmtoneLocalized(
            "filmtone.library.action.apply",
            defaultValue: prefersJapanese ? "適用" : "Apply",
            comment: "Context-menu action that applies a library entry to the current project."
        )
        libraryRenameAction = filmtoneLocalized(
            "filmtone.library.action.rename",
            defaultValue: prefersJapanese ? "名前を変更" : "Rename",
            comment: "Context-menu action that renames a library entry."
        )
        libraryDeleteAction = filmtoneLocalized(
            "filmtone.library.action.delete",
            defaultValue: prefersJapanese ? "削除" : "Delete",
            comment: "Context-menu action that deletes a library entry."
        )
        libraryFavoriteAction = filmtoneLocalized(
            "filmtone.library.action.favorite",
            defaultValue: prefersJapanese ? "お気に入りに追加" : "Mark Favorite",
            comment: "Context-menu action that flags a library entry as a favorite."
        )
        libraryUnfavoriteAction = filmtoneLocalized(
            "filmtone.library.action.unfavorite",
            defaultValue: prefersJapanese ? "お気に入り解除" : "Remove Favorite",
            comment: "Context-menu action that clears a library entry's favorite flag."
        )
        libraryQuotaExceeded = filmtoneLocalized(
            "filmtone.library.error.quota_exceeded",
            defaultValue: prefersJapanese
                ? "LUTライブラリが保存上限に達しました。古いLUTを削除してから読み込み直してください。"
                : "The LUT library is full. Delete some entries and try importing again.",
            comment: "User-facing message shown when an import would exceed the library subtree quota."
        )
        libraryLutMissingOnApply = filmtoneLocalized(
            "filmtone.library.error.lut_missing_on_apply",
            defaultValue: prefersJapanese
                ? "このLookに紐づくLUTが見つかりませんでした。LUTを再度読み込んでください。"
                : "The LUT linked to this Look is no longer in the library. Re-import it to restore the look.",
            comment: "Inline error shown when applying a Saved Look whose libraryRef points at a deleted LUT."
        )
        lookSaveCurrentMenu = filmtoneLocalized(
            "filmtone.look.menu.save_current",
            defaultValue: prefersJapanese ? "現在のLookを保存…" : "Save current Look…",
            comment: "Menu item under the Look row that opens the Save-current-Look sheet."
        )
        lookSavedToastFormat = filmtoneLocalized(
            "filmtone.look.toast.saved_format",
            defaultValue: prefersJapanese ? "Lookを保存しました：%@" : "Saved Look: %@",
            comment: "Toast format string shown after a Saved Look is created."
        )
        lookAppliedToastFormat = filmtoneLocalized(
            "filmtone.look.toast.applied_format",
            defaultValue: prefersJapanese ? "Lookを適用しました：%@" : "Applied Look: %@",
            comment: "Toast format string shown after a Saved Look is applied."
        )
        savedLookSheetCreateTitle = filmtoneLocalized(
            "filmtone.savedlook.sheet.create_title",
            defaultValue: prefersJapanese ? "Lookを保存" : "Save Look",
            comment: "Navigation title for the Save-current-Look sheet on the create path."
        )
        savedLookSheetRenameTitle = filmtoneLocalized(
            "filmtone.savedlook.sheet.rename_title",
            defaultValue: prefersJapanese ? "Lookの名前を変更" : "Rename Look",
            comment: "Navigation title for the Save-current-Look sheet on the rename path."
        )
        savedLookSheetCreateHeadline = filmtoneLocalized(
            "filmtone.savedlook.sheet.create_headline",
            defaultValue: prefersJapanese ? "現在のグレードを保存" : "Save the current grade",
            comment: "Headline shown above the name field on the create path."
        )
        savedLookSheetRenameHeadline = filmtoneLocalized(
            "filmtone.savedlook.sheet.rename_headline",
            defaultValue: prefersJapanese ? "新しい名前を入力" : "Enter a new name",
            comment: "Headline shown above the name field on the rename path."
        )
        savedLookSheetBody = filmtoneLocalized(
            "filmtone.savedlook.sheet.body",
            defaultValue: prefersJapanese
                ? "Lookには色味・調整・ルックLUTが含まれます。素材ごとのカメラLUTは別管理されます。"
                : "A Look bundles your tone, adjustments, and creative LUT. Source-side camera LUTs stay separate.",
            comment: "Supporting body shown above the name field on the Save-current-Look sheet."
        )
        savedLookNamePlaceholder = filmtoneLocalized(
            "filmtone.savedlook.sheet.placeholder",
            defaultValue: prefersJapanese ? "Look 名" : "Look name",
            comment: "Placeholder text inside the Saved-Look name field."
        )
        savedLookSheetSave = filmtoneLocalized(
            "filmtone.savedlook.sheet.save",
            defaultValue: prefersJapanese ? "保存" : "Save",
            comment: "Toolbar action that confirms creating a new Saved Look."
        )
        savedLookSheetRename = filmtoneLocalized(
            "filmtone.savedlook.sheet.rename",
            defaultValue: prefersJapanese ? "変更" : "Rename",
            comment: "Toolbar action that confirms renaming a Saved Look."
        )
        savedLookSheetCancel = filmtoneLocalized(
            "filmtone.savedlook.sheet.cancel",
            defaultValue: prefersJapanese ? "キャンセル" : "Cancel",
            comment: "Toolbar action that dismisses the Saved-Look sheet without saving."
        )
        // v1.3 Item 2: built-in Filmtone Look catalog (5 looks pinned at
        // the head of the chip strip). CD-signed-off names; refining
        // Night Soft's params on real low-light footage scheduled.
        builtInLookFilmtoneSignature = filmtoneLocalized(
            "filmtone.builtin_look.filmtone_signature",
            defaultValue: prefersJapanese ? "フィルムトーン" : "Filmtone Signature",
            comment: "Built-in Look name: the canonical Filmtone tone (iphone preset baseline)."
        )
        builtInLookCleanBase = filmtoneLocalized(
            "filmtone.builtin_look.clean_base",
            defaultValue: prefersJapanese ? "クリーンベース" : "Clean Base",
            comment: "Built-in Look name: minimal-tinting baseline (reset preset)."
        )
        builtInLookAmberGlow = filmtoneLocalized(
            "filmtone.builtin_look.amber_glow",
            defaultValue: prefersJapanese ? "アンバーグロー" : "Amber Glow",
            comment: "Built-in Look name: warm afternoon film-print mood (amberGlow preset)."
        )
        builtInLookSoftBlue = filmtoneLocalized(
            "filmtone.builtin_look.soft_blue",
            defaultValue: prefersJapanese ? "ソフトブルー" : "Soft Blue",
            comment: "Built-in Look name: airy desaturated cool tone (softBlue preset)."
        )
        builtInLookNightSoft = filmtoneLocalized(
            "filmtone.builtin_look.night_soft",
            defaultValue: prefersJapanese ? "ナイトソフト" : "Night Soft",
            comment: "Built-in Look name: low-light glow (softBlue + halation/bloom boost)."
        )
        builtInBadgeLabel = filmtoneLocalized(
            "filmtone.builtin_look.badge",
            defaultValue: "FILMTONE",
            comment: "Caption-style badge shown on built-in Filmtone Look chips. Same in ja/en."
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
        case .base:
            return presetCategoryBase
        case .camera:
            return presetCategoryCamera
        case .look:
            return presetCategoryLook
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
        case .importCreativeLut:
            return genericImportLookLutError
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
    case importCreativeLut
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
            case .importCreativeLut:
                return strings.genericImportLookLutError
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
