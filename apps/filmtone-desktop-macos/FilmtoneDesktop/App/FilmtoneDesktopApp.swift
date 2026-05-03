import SwiftUI

@main
struct FilmtoneDesktopApp: App {
    var body: some Scene {
        WindowGroup("Filmtone Desktop") {
            RootWindowView()
        }
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands()
        }
    }
}
