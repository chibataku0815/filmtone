import CoreGraphics
import XCTest

private enum SnapshotScene: String {
    case hero
    case presets
    case quick
    case camera
    case export
    case processVideo
    case sourceImportLoading
    case sourceProbeLoading
}

@MainActor
final class FilmtoneSnapshotsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureAppStoreScreenshots() throws {
        captureHero()
        capturePresetRow()
        captureQuickControls()
        captureCameraProfile()
        captureExportFlow()
        captureSourceImportLoading()
        captureSourceProbeLoading()
    }

    func testPresetCatalogDisplaysFourIosPresets() throws {
        let app = launch(scene: .presets)
        waitForAppToSettle(app)

        let presetCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "filmtone.preset.card.")
        )
        XCTAssertEqual(presetCards.count, 4)

        for presetName in ["reset", "iphone", "softBlue", "amberGlow"] {
            XCTAssertTrue(app.buttons["filmtone.preset.card.\(presetName)"].exists)
        }

        for legacyPresetName in ["portra", "pro400h", "superia400", "gold200", "cinestill800t", "velvia50", "ektar100", "cinematic", "bw"] {
            XCTAssertFalse(app.buttons["filmtone.preset.card.\(legacyPresetName)"].exists)
        }

        app.terminate()
    }

    func testPresetDefaultRestoresCustomizedActivePreset() throws {
        let app = launch(scene: .presets)
        waitForAppToSettle(app)

        let activePresetCard = app.buttons["filmtone.preset.card.amberGlow"]
        XCTAssertTrue(activePresetCard.waitForExistence(timeout: 5))
        XCTAssertEqual(activePresetCard.value as? String, "Selected")

        let defaultButton = app.descendants(matching: .any)["filmtone.preset.default"]
        XCTAssertTrue(defaultButton.waitForExistence(timeout: 5))
        XCTAssertTrue(defaultButton.isEnabled)
        defaultButton.tap()

        XCTAssertTrue(activePresetCard.waitForExistence(timeout: 5))
        XCTAssertEqual(activePresetCard.value as? String, "Selected")
        XCTAssertTrue(waitForElementToDisappear(defaultButton, timeout: 5))

        app.terminate()
    }

    func testCameraProfileShowsInputAndCreativeLutControls() throws {
        let app = launch(scene: .camera)
        waitForAppToSettle(app)
        app.swipeUp()
        pauseForLayout()
        assertDualLutMenus(in: app)
        app.terminate()
    }

    func testExportSaveCtaVisibleWithoutScrolling() throws {
        let app = launch(scene: .export)
        waitForAppToSettle(app)

        let prompt = app.descendants(matching: .any)["filmtone.export.unsavedPrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["filmtone.export.unsavedPrompt.save"].exists)

        app.terminate()
    }

    func testOnboardingAppearsOnFirstLaunch() throws {
        let app = launch(extraArguments: ["-filmtoneResetOnboarding"])
        waitForAppToSettle(app)

        XCTAssertTrue(onboardingFirstPage(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["filmtone.onboarding.next"].exists)

        app.terminate()
    }

    func testOnboardingSkipDoesNotShowAgain() throws {
        let app = launch(extraArguments: ["-filmtoneResetOnboarding"])
        waitForAppToSettle(app)

        let onboarding = onboardingFirstPage(in: app)
        XCTAssertTrue(onboarding.waitForExistence(timeout: 5))
        app.buttons["filmtone.onboarding.skip"].tap()
        XCTAssertTrue(waitForElementToDisappear(onboarding, timeout: 5))
        app.terminate()

        let relaunched = launch()
        waitForAppToSettle(relaunched)
        XCTAssertFalse(onboardingFirstPage(in: relaunched).waitForExistence(timeout: 2))
        relaunched.terminate()
    }

    func testOnboardingPickMediaOpensSourcePickerDialog() throws {
        let app = launch(extraArguments: ["-filmtoneResetOnboarding"])
        waitForAppToSettle(app)

        XCTAssertTrue(onboardingFirstPage(in: app).waitForExistence(timeout: 5))
        tapOnboardingNext(in: app)
        tapOnboardingNext(in: app)

        let pickMedia = app.buttons["filmtone.onboarding.pickMedia"]
        XCTAssertTrue(pickMedia.waitForExistence(timeout: 5))
        pickMedia.tap()

        XCTAssertTrue(waitForAnyElement([
            app.buttons["filmtone.source.photoLibrary"],
            app.buttons["Photo Library"],
            app.buttons["フォトライブラリ"],
        ], timeout: 5))
        XCTAssertTrue(waitForAnyElement([
            app.buttons["filmtone.source.files"],
            app.buttons["Files"],
            app.buttons["ファイル"],
        ], timeout: 2))

        app.terminate()
    }

    func testOnboardingDoesNotAppearForSnapshotScene() throws {
        let app = launch(
            scene: .hero,
            extraArguments: ["-filmtoneResetOnboarding", "-filmtoneForceOnboarding"]
        )
        waitForAppToSettle(app)

        XCTAssertFalse(onboardingFirstPage(in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["filmtone.root.scroll"].exists)

        app.terminate()
    }

    func testOnboardingDoesNotAppearWhenSourceIsAlreadyRestored() throws {
        let app = launch(
            extraArguments: [
                "-filmtoneResetOnboarding",
                "-filmtoneForceOnboarding",
                "-filmtoneSeedRestoredSource",
            ]
        )
        waitForAppToSettle(app)

        XCTAssertFalse(onboardingFirstPage(in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["filmtone.root.scroll"].exists)

        app.terminate()
    }

    func testCameraProfileLutHelpOpensAndDismisses() throws {
        let app = launch(scene: .camera)
        waitForAppToSettle(app)
        app.swipeUp()
        pauseForLayout()

        let helpButton = app.descendants(matching: .any)["filmtone.help.lut.button"]
        reveal(helpButton, in: app, maxSwipes: 4)
        XCTAssertTrue(helpButton.waitForExistence(timeout: 5))
        helpButton.tap()
        pauseForLayout()

        let helpTitle = app.descendants(matching: .any)["filmtone.help.sheet.title"]
        XCTAssertTrue(helpTitle.waitForExistence(timeout: 5))

        let helpBody = app.descendants(matching: .any)["filmtone.help.sheet.body"]
        XCTAssertTrue(helpBody.waitForExistence(timeout: 2))

        let dismissButton = app.descendants(matching: .any)["filmtone.help.sheet.dismiss"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 2))
        dismissButton.tap()

        XCTAssertTrue(waitForElementToDisappear(helpTitle, timeout: 5))

        app.terminate()
    }

    func testCaptureProcessVideoRefreshRegression() throws {
        let app = launch(scene: .processVideo)
        waitForAppToSettle(app)

        let openAdjustmentsButton = app.descendants(matching: .any)["filmtone.adjust.open"]
        reveal(openAdjustmentsButton, in: app)
        XCTAssertTrue(openAdjustmentsButton.waitForExistence(timeout: 5))
        openAdjustmentsButton.tap()

        let strengthSheet = app.descendants(matching: .any)["filmtone.sheet.strength"]
        XCTAssertTrue(strengthSheet.waitForExistence(timeout: 5))

        let advancedButton = app.buttons["filmtone.sheet.advanced"]
        reveal(advancedButton, in: app, maxSwipes: 2)
        XCTAssertTrue(advancedButton.waitForExistence(timeout: 5))
        advancedButton.tap()
        pauseForLayout()

        let toneStandardButton = app.buttons["filmtone.sheet.advanced.group.process.standard"]
        let toneAiryButton = app.buttons["filmtone.sheet.advanced.group.process.airy"]
        let toneSunsetButton = app.buttons["filmtone.sheet.advanced.group.process.sunset"]
        let toneDepthButton = app.buttons["filmtone.sheet.advanced.group.process.depth"]
        reveal(toneSunsetButton, in: app, maxSwipes: 2)
        XCTAssertTrue(toneStandardButton.waitForExistence(timeout: 5))
        XCTAssertTrue(toneAiryButton.waitForExistence(timeout: 5))
        XCTAssertTrue(toneSunsetButton.waitForExistence(timeout: 5))
        XCTAssertTrue(toneDepthButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["filmtone.sheet.advanced.group.process.none"].exists)
        XCTAssertFalse(app.buttons["filmtone.sheet.advanced.group.process.default"].exists)
        XCTAssertFalse(app.buttons["filmtone.sheet.advanced.group.process.strong"].exists)
        toneSunsetButton.tap()
        let compareSlider = waitForSheetCompareReady(in: app)
        dragCompareSlider(compareSlider, to: 0.74)
        let retainedCompareValue = compareSliderValue(compareSlider)
        XCTAssertNotEqual(retainedCompareValue, "58%")
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)

        let processGroupButton = app.buttons["filmtone.sheet.advanced.group.process"]
        reveal(processGroupButton, in: app, maxSwipes: 2)
        XCTAssertTrue(processGroupButton.waitForExistence(timeout: 5))
        processGroupButton.tap()
        pauseForLayout()
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)

        let processSlider = app.sliders["filmtone.sheet.slider.param.compressionAmount"]
        reveal(processSlider, in: app, maxSwipes: 2)
        XCTAssertTrue(processSlider.waitForExistence(timeout: 5))

        processSlider.adjust(toNormalizedSliderPosition: 0.82)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)
        pauseForLayout(0.25)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)
        waitForSheetCompareReady(in: app)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)

        reveal(processSlider, in: app, maxSwipes: 3)
        processSlider.adjust(toNormalizedSliderPosition: 0.28)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)
        pauseForLayout(0.25)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)
        waitForSheetCompareReady(in: app)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)

        reveal(toneAiryButton, in: app, maxSwipes: 3)
        XCTAssertTrue(toneAiryButton.waitForExistence(timeout: 5))
        toneAiryButton.tap()
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)
        pauseForLayout(0.25)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)
        waitForSheetCompareReady(in: app)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)

        reveal(toneStandardButton, in: app, maxSwipes: 3)
        XCTAssertTrue(toneStandardButton.waitForExistence(timeout: 5))
        toneStandardButton.tap()
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)
        pauseForLayout(0.25)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)
        waitForSheetCompareReady(in: app)
        assertSheetPreviewRetained(in: app, expectedCompareValue: retainedCompareValue)

        pauseForLayout(0.6)
        snapshot("06_live_video_process_refresh", timeWaitingForIdle: 0)
        app.terminate()
    }

    private func captureHero() {
        let app = launch(scene: .hero)
        waitForAppToSettle(app)
        snapshot("01_source_loaded_preview", timeWaitingForIdle: 0)
        app.terminate()
    }

    private func capturePresetRow() {
        let app = launch(scene: .presets)
        waitForAppToSettle(app)
        snapshot("02_preset_row", timeWaitingForIdle: 0)
        app.terminate()
    }

    private func captureQuickControls() {
        let app = launch(scene: .quick)
        waitForAppToSettle(app)
        pauseForLayout()
        snapshot("03_strength_quick_controls", timeWaitingForIdle: 0)
        app.terminate()
    }

    private func captureCameraProfile() {
        let app = launch(scene: .camera)
        waitForAppToSettle(app)
        app.swipeUp()
        pauseForLayout()
        assertDualLutMenus(in: app)
        snapshot("04_camera_profile_route", timeWaitingForIdle: 0)
        app.terminate()
    }

    private func assertDualLutMenus(in app: XCUIApplication) {
        let inputLutMenu = app.descendants(matching: .any)["filmtone.lut.input.menu"]
        let creativeLutMenu = app.descendants(matching: .any)["filmtone.lut.creative.menu"]
        let inputIntensitySlider = app.descendants(matching: .any)["filmtone.lut.input.intensity.slider"]
        let creativeIntensitySlider = app.descendants(matching: .any)["filmtone.lut.creative.intensity.slider"]
        reveal(inputLutMenu, in: app, maxSwipes: 2)
        XCTAssertTrue(inputLutMenu.waitForExistence(timeout: 5))
        XCTAssertTrue(creativeLutMenu.waitForExistence(timeout: 5))
        XCTAssertTrue(inputIntensitySlider.waitForExistence(timeout: 5))
        XCTAssertTrue(creativeIntensitySlider.waitForExistence(timeout: 5))
    }

    private func captureExportFlow() {
        let app = launch(scene: .export)
        waitForAppToSettle(app)
        app.swipeUp()
        app.swipeUp()
        pauseForLayout()
        snapshot("05_export_save_share", timeWaitingForIdle: 0)
        app.terminate()
    }

    private func captureSourceImportLoading() {
        let app = launch(scene: .sourceImportLoading)
        waitForAppToSettle(app)
        assertSourceLoadBanner(in: app, expectsProgress: true)
        snapshot("07_source_import_loading", timeWaitingForIdle: 0)
        app.terminate()
    }

    private func captureSourceProbeLoading() {
        let app = launch(scene: .sourceProbeLoading)
        waitForAppToSettle(app)
        assertSourceLoadBanner(in: app, expectsProgress: false)
        snapshot("08_source_probe_loading", timeWaitingForIdle: 0)
        app.terminate()
    }

    private func launch(scene: SnapshotScene, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app, waitForAnimations: false)
        app.launchArguments += ["-filmtoneSnapshot", scene.rawValue]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app, waitForAnimations: false)
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    private func onboardingFirstPage(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["filmtone.onboarding.page.0"]
    }

    private func waitForAppToSettle(_ app: XCUIApplication) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        pauseForLayout(1.0)
    }

    @discardableResult
    private func waitForSheetCompareReady(in app: XCUIApplication) -> XCUIElement {
        let compareSlider = app.descendants(matching: .any)["filmtone.sheet.preview.compare.slider"]

        XCTAssertTrue(compareSlider.waitForExistence(timeout: 20))
        revealAbove(compareSlider, in: app, maxSwipes: 4)
        waitForRefreshToSettle(in: app)
        XCTAssertTrue(compareSlider.exists)
        return compareSlider
    }

    private func waitForRefreshToSettle(in app: XCUIApplication) {
        let loadingIndicator = app.otherElements["filmtone.sheet.preview.loading"]
        XCTAssertFalse(loadingIndicator.waitForExistence(timeout: 0.5))

        let refreshIndicator = app.otherElements["filmtone.sheet.preview.refreshing"]
        if refreshIndicator.waitForExistence(timeout: 1) {
            XCTAssertTrue(waitForElementToDisappear(refreshIndicator, timeout: 20))
        } else {
            pauseForLayout(1.2)
        }
    }

    private func assertSourceLoadBanner(
        in app: XCUIApplication,
        expectsProgress: Bool
    ) {
        let banner = app.descendants(matching: .any)["filmtone.banner.sourceLoad"]
        let label = app.descendants(matching: .any)["filmtone.banner.sourceLoad.label"]
        let progress = app.descendants(matching: .any)["filmtone.banner.sourceLoad.progress"]

        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        if expectsProgress {
            XCTAssertTrue(progress.waitForExistence(timeout: 10))
        } else {
            XCTAssertFalse(progress.waitForExistence(timeout: 2))
        }
    }

    private func waitForElementToDisappear(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForAnyElement(
        _ elements: [XCUIElement],
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if elements.contains(where: { $0.exists }) {
                return true
            }
            pauseForLayout(0.1)
        }
        return elements.contains(where: { $0.exists })
    }

    private func tapOnboardingNext(in app: XCUIApplication) {
        let next = app.buttons["filmtone.onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        pauseForLayout(0.35)
    }

    private func assertSheetPreviewRetained(
        in app: XCUIApplication,
        expectedCompareValue: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let compareSlider = app.descendants(matching: .any)["filmtone.sheet.preview.compare.slider"]
        let loadingIndicator = app.otherElements["filmtone.sheet.preview.loading"]

        XCTAssertTrue(compareSlider.exists, "Compare preview disappeared during refresh.", file: file, line: line)
        XCTAssertEqual(
            compareSliderValue(compareSlider),
            expectedCompareValue,
            "Compare reveal position reset, which indicates the preview was remounted.",
            file: file,
            line: line
        )
        XCTAssertFalse(
            loadingIndicator.exists,
            "Large sheet preview loading indicator appeared during retained-preview refresh.",
            file: file,
            line: line
        )
    }

    private func dragCompareSlider(_ compareSlider: XCUIElement, to normalizedPosition: CGFloat) {
        let position = min(max(normalizedPosition, 0.05), 0.95)
        let start = compareSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = compareSlider.coordinate(withNormalizedOffset: CGVector(dx: position, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        pauseForLayout(0.2)
    }

    private func compareSliderValue(_ compareSlider: XCUIElement) -> String {
        compareSlider.value as? String ?? ""
    }

    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 4
    ) {
        var swipeCount = 0
        while swipeCount < maxSwipes && (!element.exists || !element.isHittable) {
            app.swipeUp()
            pauseForLayout(0.25)
            swipeCount += 1
        }
    }

    private func revealAbove(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 4
    ) {
        var swipeCount = 0
        while swipeCount < maxSwipes && (!element.exists || !element.isHittable) {
            app.swipeDown()
            pauseForLayout(0.25)
            swipeCount += 1
        }
    }

    private func pauseForLayout(_ duration: TimeInterval = 0.4) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: duration))
    }
}
