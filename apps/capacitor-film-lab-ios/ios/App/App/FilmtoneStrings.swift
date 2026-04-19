import Foundation

struct FilmtoneStrings {
    let appName: String
    let sourceEmpty: String
    let pickSource: String
    let repickSource: String
    let probePending: String
    let previewRendering: String
    let previewSheetHint: String
    let compareLabel: String
    let compareHint: String
    let presetTitle: String
    let strengthLabel: String
    let adjustLabel: String
    let quickHint: String
    let quickFilmCharacter: String
    let quickEra: String
    let quickDynamics: String
    let advancedParamsLabel: String
    let advancedParamsHint: String
    let advancedAdjustmentsActive: String
    let advancedBasicLabel: String
    let advancedOpticsLabel: String
    let advancedGlowLabel: String
    let advancedGrainLabel: String
    let advancedToneLabel: String
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
    let cameraImport: String
    let clearLut: String
    let lutImportError: String
    let lutParseError: String
}

extension FilmtoneStrings {
    func paramLabel(for key: String) -> String {
        paramLabels[key] ?? key
    }
}

enum FilmtoneStringsCatalog {
    static var current: FilmtoneStrings {
        let localeCode = Locale.current.language.languageCode?.identifier ?? Locale.current.identifier
        return localeCode.hasPrefix("ja") ? .ja : .en
    }
}

private extension FilmtoneStrings {
    static let en = FilmtoneStrings(
        appName: "Filmtone",
        sourceEmpty: "Pick a video to begin.",
        pickSource: "Pick video",
        repickSource: "Replace video",
        probePending: "Inspecting video…",
        previewRendering: "Generating preview…",
        previewSheetHint: "Preview updates through the native render path.",
        compareLabel: "Original",
        compareHint: "Press and hold the preview to compare.",
        presetTitle: "Film Presets",
        strengthLabel: "Strength",
        adjustLabel: "Adjust",
        quickHint: "Three quick axes to shape the look.",
        quickFilmCharacter: "Exposure",
        quickEra: "Contrast",
        quickDynamics: "Saturation",
        advancedParamsLabel: "Advanced Params",
        advancedParamsHint: "Fine-tune the optical mix directly.",
        advancedAdjustmentsActive: "Advanced tuning active.",
        advancedBasicLabel: "Basic",
        advancedOpticsLabel: "Optics",
        advancedGlowLabel: "Glow",
        advancedGrainLabel: "Grain",
        advancedToneLabel: "Tone / Process",
        paramLabels: [
            "exposure": "Exposure",
            "contrast": "Contrast",
            "saturation": "Saturation",
            "temperature": "Temperature",
            "tint": "Tint",
            "fade": "Fade",
            "rgbShift": "RGB Shift",
            "lensSoftness": "Lens Softness",
            "vignette": "Vignette",
            "bloomThreshold": "Bloom Threshold",
            "bloomStrength": "Bloom Strength",
            "bloomRadius": "Bloom Radius",
            "bloomSoftKnee": "Bloom Soft Knee",
            "halationIntensity": "Halation Intensity",
            "halationSpread": "Halation Spread",
            "halationHue": "Halation Hue",
            "halationThreshold": "Halation Threshold",
            "halationRadius": "Halation Radius",
            "halationSoftKnee": "Halation Soft Knee",
            "diffusion": "Diffusion",
            "grainIntensity": "Grain Intensity",
            "grainSize": "Grain Size",
            "grainRadialMix": "Grain Radial Mix",
            "compressionAmount": "Compression Amount",
            "compressionRange": "Compression Range",
        ],
        resetLabel: "Reset",
        exportSectionTitle: "Export",
        exportIdle: "Ready to export.",
        exportRunning: "Exporting…",
        exportWritingHint: "Finalizing. Long clips may take a moment.",
        exportStart: "Export",
        exportDisabled: "This video can't be exported. See the source notes above.",
        saveToPhotos: "Save to Photos",
        saveToPhotosDone: "Saved to Photos.",
        shareOutput: "Share",
        resultTitle: "Last export",
        metricsElapsed: "Elapsed",
        metricsOutput: "Output",
        metricsFileSize: "File size",
        metricsSaveToPhotos: "Save to Photos",
        noticePrefix: "Note",
        errorPrefix: "Error",
        doneLabel: "Done",
        cameraLabel: "Camera",
        cameraDescription: "Translate log footage before the look. Phase 1 supports Auto or one imported .cube.",
        cameraAuto: "Auto",
        cameraImport: "Import .cube",
        clearLut: "Clear",
        lutImportError: "Camera profile import failed",
        lutParseError: "Camera profile .cube could not be parsed"
    )

    static let ja = FilmtoneStrings(
        appName: "Filmtone",
        sourceEmpty: "動画を選んでください。",
        pickSource: "動画を選ぶ",
        repickSource: "動画を差し替える",
        probePending: "動画を確認しています…",
        previewRendering: "プレビューを生成しています…",
        previewSheetHint: "プレビューは native の render path をそのまま反映します。",
        compareLabel: "オリジナル",
        compareHint: "プレビューを長押しで比較します。",
        presetTitle: "フィルムプリセット",
        strengthLabel: "強さ",
        adjustLabel: "調整",
        quickHint: "3 軸で素早くルックを整えます。",
        quickFilmCharacter: "明るさ",
        quickEra: "コントラスト",
        quickDynamics: "彩度",
        advancedParamsLabel: "詳細パラメータ",
        advancedParamsHint: "光学系の効きを直接微調整します。",
        advancedAdjustmentsActive: "詳細調整を適用中。",
        advancedBasicLabel: "基本",
        advancedOpticsLabel: "光学",
        advancedGlowLabel: "グロー",
        advancedGrainLabel: "グレイン",
        advancedToneLabel: "階調 / プロセス",
        paramLabels: [
            "exposure": "露出",
            "contrast": "コントラスト",
            "saturation": "彩度",
            "temperature": "色温度",
            "tint": "ティント",
            "fade": "フェード",
            "rgbShift": "RGB シフト",
            "lensSoftness": "レンズソフト",
            "vignette": "周辺減光",
            "bloomThreshold": "ブルームしきい値",
            "bloomStrength": "ブルーム量",
            "bloomRadius": "ブルーム半径",
            "bloomSoftKnee": "ブルームソフトニー",
            "halationIntensity": "ハレーション量",
            "halationSpread": "ハレーション広がり",
            "halationHue": "ハレーション色相",
            "halationThreshold": "ハレーションしきい値",
            "halationRadius": "ハレーション半径",
            "halationSoftKnee": "ハレーションソフトニー",
            "diffusion": "ディフュージョン",
            "grainIntensity": "グレイン量",
            "grainSize": "グレイン粒径",
            "grainRadialMix": "グレイン周辺ミックス",
            "compressionAmount": "圧縮量",
            "compressionRange": "圧縮レンジ",
        ],
        resetLabel: "リセット",
        exportSectionTitle: "書き出し",
        exportIdle: "書き出しの準備ができています。",
        exportRunning: "書き出し中…",
        exportWritingHint: "出力を仕上げ中です。長尺の場合少し時間がかかります。",
        exportStart: "書き出す",
        exportDisabled: "この動画は書き出せません。素材の注意事項を確認してください。",
        saveToPhotos: "写真へ保存",
        saveToPhotosDone: "写真への保存が完了しました。",
        shareOutput: "共有",
        resultTitle: "直近の書き出し",
        metricsElapsed: "経過時間",
        metricsOutput: "出力",
        metricsFileSize: "ファイルサイズ",
        metricsSaveToPhotos: "写真への保存",
        noticePrefix: "補足",
        errorPrefix: "エラー",
        doneLabel: "完了",
        cameraLabel: "カメラ",
        cameraDescription: "ルック適用前に log 動画を変換します。Phase 1 はオートまたは 1 本の .cube 読み込みに絞ります。",
        cameraAuto: "オート",
        cameraImport: ".cube を読み込む",
        clearLut: "外す",
        lutImportError: "カメラプロファイルの読み込みに失敗しました",
        lutParseError: "カメラプロファイルの .cube を解釈できませんでした"
    )
}
