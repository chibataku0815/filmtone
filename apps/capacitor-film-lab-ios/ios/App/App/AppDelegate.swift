import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var store: FilmtoneEditorStore?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        runFilmtoneSmokeIfRequested()
        #endif

        do {
            if try FilmtoneHelpAssetGenerator.runIfRequested() {
                exit(0)
            }
            let snapshotScene = FilmtoneSnapshotScene.current
            // Snapshot mode and onboarding-reset both want a clean library so
            // fixtures stay deterministic. We construct the actor first so we
            // can call `clear()` synchronously on the scratch state before
            // the editor store attempts a load.
            let libraryStore = try? LibraryStoreActor()
            if snapshotScene != nil {
                FilmtonePersistence.clear()
                UIView.setAnimationsEnabled(false)
                if let libraryStore {
                    Task { await libraryStore.clear() }
                }
            } else if ProcessInfo.processInfo.arguments.contains(FilmtoneOnboardingLaunchArguments.reset) {
                FilmtonePersistence.clear()
                if let libraryStore {
                    Task { await libraryStore.clear() }
                }
            }
            let facade = try FilmtoneEditorFacade()
            let store = FilmtoneEditorStore(facade: facade, libraryStore: libraryStore)
            if let snapshotScene {
                store.applySnapshotScene(snapshotScene)
            } else if ProcessInfo.processInfo.arguments.contains(FilmtoneOnboardingLaunchArguments.seedRestoredSource) {
                store.applySnapshotScene(.hero)
            }
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = FilmtoneRootHostingController(store: store)
            window.makeKeyAndVisible()
            self.window = window
            self.store = store
        } catch {
            fatalError("Failed to bootstrap Filmtone native runtime: \(error.localizedDescription)")
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Task { @MainActor [weak self] in
            self?.store?.reclaimCacheForBackground()
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        FilmtoneInterfaceOrientationLock.currentMask
    }

    #if DEBUG
    /// V2 capture / Gyroflow lane smoke dispatcher. Selects at most one
    /// smoke per Debug launch via the `FILMTONE_SMOKE_LANE` environment
    /// variable so M1 / M2-B / M3 / M4 / M5 / M6 evidence stays mutually
    /// exclusive (M3 in particular must be motion-only — no
    /// AVCaptureSession may be running on the device while it records).
    /// Default (env var unset) runs nothing, so day-to-day Xcode Debug
    /// launches stay clean.
    ///
    /// Trigger from devicectl with the JSON-dictionary form:
    ///   xcrun devicectl device process launch --device <udid> \
    ///     --environment-variables '{"FILMTONE_SMOKE_LANE":"m6","FILMTONE_M6_STABILIZATION_MODE":"cinematicExtended"}' \
    ///     com.chibatakumi.film.lab.ios
    /// Fallback if the JSON form fails to propagate:
    ///   DEVICECTL_CHILD_FILMTONE_SMOKE_LANE=m6 \
    ///   DEVICECTL_CHILD_FILMTONE_M6_STABILIZATION_MODE=cinematicExtended \
    ///   xcrun devicectl …
    private func runFilmtoneSmokeIfRequested() {
        let lane = ProcessInfo.processInfo.environment["FILMTONE_SMOKE_LANE"]?
            .lowercased()
        switch lane {
        case "m1":
            runM1CapabilityProbeOnLaunch()
        case "m2b":
            runM2BCoexistenceSmokeOnLaunch()
        case "m3":
            runM3MotionOnlySmokeOnLaunch()
        case "m4":
            runM4CombinedTimingSmokeOnLaunch()
        case "m5":
            runM5GcsvSmokeOnLaunch()
        case "m6":
            runM6StabilizationSmokeOnLaunch()
        case .some(let other):
            NSLog("[FilmtoneSmoke] FILMTONE_SMOKE_LANE=%@ unrecognised; no smoke runs.", other)
        case .none:
            break
        }
    }

    /// V2 capture / Gyroflow lane M1: writes the capability probe JSON
    /// once per Debug launch (synchronously) so a single Xcode Run on a
    /// real device produces the artifact that M1 Done Conditions require.
    /// Synchronous so the artifact exists before the SwiftUI bootstrap
    /// runs and before the app can be suspended by an out-of-foreground
    /// devicectl launch.
    private func runM1CapabilityProbeOnLaunch() {
        do {
            let result = try FilmtoneCaptureCapabilityProbe.run()
            NSLog("[FilmtoneM1Probe] capability JSON written: %@", result.fileURL.path)
        } catch {
            NSLog("[FilmtoneM1Probe] capability probe failed: %@", error.localizedDescription)
        }
    }

    /// V2 capture / Gyroflow lane M2-B: Path C dual-output coexistence
    /// smoke. Drives one AVCaptureSession with AVCaptureMovieFileOutput
    /// (ProRes 422 HQ Apple Log 2 master) and AVCaptureVideoDataOutput
    /// (timing / diagnostics side-band) attached together.
    /// Writes m2b-master.mov, m2b-coexistence-smoke.json, and
    /// m2b-debug.log to Library/Caches/Filmtone/captures/.
    private func runM2BCoexistenceSmokeOnLaunch() {
        NSLog("[FilmtoneM2BSmoke] starting Path C dual-output coexistence smoke (async)…")
        FilmtoneCaptureWriter.runSmoke(duration: 6.0) { result in
            switch result {
            case .success(let output):
                NSLog("[FilmtoneM2BSmoke] OK mov=%@", output.movURL.path)
                NSLog("[FilmtoneM2BSmoke] OK json=%@", output.jsonURL.path)
            case .failure(let error):
                NSLog("[FilmtoneM2BSmoke] FAIL: %@", error.localizedDescription)
            }
        }
    }

    /// V2 capture / Gyroflow lane M3: motion-only Core Motion smoke. No
    /// AVCaptureSession is started. Raw startGyroUpdates /
    /// startAccelerometerUpdates only — fused startDeviceMotionUpdates is
    /// not called (Gyroflow data must be raw per strategy). Writes
    /// m3-motion-only-smoke.json and m3-debug.log to
    /// Library/Caches/Filmtone/captures/.
    private func runM3MotionOnlySmokeOnLaunch() {
        NSLog("[FilmtoneM3Smoke] starting motion-only smoke (async)…")
        FilmtoneMotionRecorder.runSmoke(duration: 10.0) { result in
            switch result {
            case .success(let output):
                NSLog("[FilmtoneM3Smoke] OK json=%@", output.jsonURL.path)
                NSLog("[FilmtoneM3Smoke] OK log=%@", output.debugLogURL.path)
            case .failure(let error):
                NSLog("[FilmtoneM3Smoke] FAIL: %@", error.localizedDescription)
            }
        }
    }

    /// V2 capture / Gyroflow lane M4: combined timing smoke. One
    /// AVCaptureSession (M2-B Path C ProRes 422 HQ Apple Log 2 master +
    /// VDO timing side-band) runs simultaneously with raw Core Motion
    /// gyro + accelerometer. Records a `mach_absolute_time` /
    /// `systemUptime` anchor pair captured at session start so M5 can
    /// map video PTS to Core Motion `CMLogItem.timestamp` without
    /// guessing. Writes m4-master.mov, m4-combined-timing-smoke.json,
    /// and m4-debug.log to Library/Caches/Filmtone/captures/.
    private func runM4CombinedTimingSmokeOnLaunch() {
        NSLog("[FilmtoneM4Smoke] starting combined timing smoke (async)…")
        FilmtoneCombinedTimingSmoke.runSmoke(duration: 30.0, motionMargin: 1.0) { result in
            switch result {
            case .success(let output):
                NSLog("[FilmtoneM4Smoke] OK mov=%@", output.movURL.path)
                NSLog("[FilmtoneM4Smoke] OK json=%@", output.jsonURL.path)
                NSLog("[FilmtoneM4Smoke] OK log=%@", output.debugLogURL.path)
            case .failure(let error):
                NSLog("[FilmtoneM4Smoke] FAIL: %@", error.localizedDescription)
            }
        }
    }

    /// V2 capture / Gyroflow lane M5-A: Gyroflow `.gcsv` proof smoke.
    /// Forks M4's combined-timing scaffolding and adds Strategy C
    /// resampling onto the gyro timeline plus a `m5-package-<UUID>/`
    /// directory containing {`m5-master.mov`, `m5-motion.gcsv`,
    /// `m5-combined-timing.json`, `m5-debug.log`}. Run-local sync
    /// offsets (computed from THIS run's anchors) are recorded as
    /// the M5-B Gyroflow sync seeds — M4 offsets serve only as the
    /// `±200ms` drift gate.
    private func runM5GcsvSmokeOnLaunch() {
        NSLog("[FilmtoneM5Smoke] starting gcsv proof smoke (async)…")
        FilmtoneGcsvSmoke.runSmoke(duration: 30.0, motionMargin: 1.0) { result in
            switch result {
            case .success(let output):
                NSLog("[FilmtoneM5Smoke] OK package=%@", output.packageDirURL.path)
                NSLog("[FilmtoneM5Smoke] OK mov=%@", output.movURL.path)
                NSLog("[FilmtoneM5Smoke] OK gcsv=%@", output.gcsvURL.path)
                NSLog("[FilmtoneM5Smoke] OK json=%@", output.jsonURL.path)
                NSLog("[FilmtoneM5Smoke] OK log=%@", output.debugLogURL.path)
            case .failure(let error):
                NSLog("[FilmtoneM5Smoke] FAIL: %@", error.localizedDescription)
            }
        }
    }

    /// V2 capture / Gyroflow lane M6: AVFoundation stabilization smoke.
    /// Forks M5-A's `.gcsv` scaffolding and ONLY changes stabilization
    /// wiring + diagnostics. Reads `FILMTONE_M6_STABILIZATION_MODE`
    /// (off|standard|cinematic|cinematicExtended|previewOptimized|
    /// cinematicExtendedEnhanced|auto). Default unset = `.off` (M5-A
    /// baseline parity). Probes per-format supported modes, applies the
    /// requested mode to the MovieFileOutput connection, and re-reads
    /// `activeVideoStabilizationMode` after `didStartRecordingTo` so
    /// AVFoundation's resolution is observable. Stop Conditions: env
    /// requested non-`.off` but active resolved to `.off`; or Apple
    /// Log 2 silently downgraded after stabilization engaged. Writes
    /// m6-master.mov / m6-motion.gcsv / m6-combined-timing.json /
    /// m6-debug.log to Library/Caches/Filmtone/captures/m6-package-<UUID>/.
    private func runM6StabilizationSmokeOnLaunch() {
        NSLog("[FilmtoneM6Smoke] starting stabilization smoke (async)…")
        FilmtoneStabilizationSmoke.runSmoke(duration: 30.0, motionMargin: 1.0) { result in
            switch result {
            case .success(let output):
                NSLog("[FilmtoneM6Smoke] OK package=%@", output.packageDirURL.path)
                NSLog("[FilmtoneM6Smoke] OK mov=%@", output.movURL.path)
                NSLog("[FilmtoneM6Smoke] OK gcsv=%@", output.gcsvURL.path)
                NSLog("[FilmtoneM6Smoke] OK json=%@", output.jsonURL.path)
                NSLog("[FilmtoneM6Smoke] OK log=%@", output.debugLogURL.path)
            case .failure(let error):
                NSLog("[FilmtoneM6Smoke] FAIL: %@", error.localizedDescription)
            }
        }
    }
    #endif

}
