import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var store: FilmtoneEditorStore?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do {
            let snapshotScene = FilmtoneSnapshotScene.current
            if snapshotScene != nil {
                FilmtonePersistence.clear()
                UIView.setAnimationsEnabled(false)
            }
            let facade = try FilmtoneEditorFacade()
            let store = FilmtoneEditorStore(facade: facade)
            if let snapshotScene {
                store.applySnapshotScene(snapshotScene)
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

}
