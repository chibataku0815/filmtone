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

    func testCaptureProcessVideoRefreshRegression() throws {
        let app = launch(scene: .processVideo)
        waitForAppToSettle(app)

        let openAdjustmentsButton = app.buttons["filmtone.adjust.open"]
        reveal(openAdjustmentsButton, in: app)
        XCTAssertTrue(openAdjustmentsButton.waitForExistence(timeout: 5))
        openAdjustmentsButton.tap()

        let strengthSheet = app.otherElements["filmtone.sheet.strength"]
        XCTAssertTrue(strengthSheet.waitForExistence(timeout: 5))

        let advancedButton = app.buttons["filmtone.sheet.advanced"]
        reveal(advancedButton, in: app, maxSwipes: 2)
        XCTAssertTrue(advancedButton.waitForExistence(timeout: 5))
        advancedButton.tap()
        pauseForLayout()

        let processSlider = app.sliders["filmtone.sheet.slider.param.compressionAmount"]
        reveal(processSlider, in: app, maxSwipes: 2)
        XCTAssertTrue(processSlider.waitForExistence(timeout: 5))

        processSlider.adjust(toNormalizedSliderPosition: 0.82)
        waitForLivePreviewReady(in: app)

        processSlider.adjust(toNormalizedSliderPosition: 0.28)
        waitForRefreshToSettle(in: app)

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
        snapshot("04_camera_profile_route", timeWaitingForIdle: 0)
        app.terminate()
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

    private func launch(scene: SnapshotScene) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app, waitForAnimations: false)
        app.launchArguments += ["-filmtoneSnapshot", scene.rawValue]
        app.launch()
        return app
    }

    private func waitForAppToSettle(_ app: XCUIApplication) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        pauseForLayout(1.0)
    }

    private func waitForLivePreviewReady(in app: XCUIApplication) {
        let videoPreview = app.otherElements["filmtone.sheet.preview.video"]
        let originalCompare = app.buttons["filmtone.sheet.preview.compare.original"]

        XCTAssertTrue(videoPreview.waitForExistence(timeout: 15))
        XCTAssertTrue(originalCompare.waitForExistence(timeout: 15))
        waitForRefreshToSettle(in: app)
    }

    private func waitForRefreshToSettle(in app: XCUIApplication) {
        let loadingIndicator = app.otherElements["filmtone.sheet.preview.loading"]
        if loadingIndicator.waitForExistence(timeout: 2) {
            XCTAssertTrue(waitForElementToDisappear(loadingIndicator, timeout: 20))
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

    private func pauseForLayout(_ duration: TimeInterval = 0.4) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: duration))
    }
}
