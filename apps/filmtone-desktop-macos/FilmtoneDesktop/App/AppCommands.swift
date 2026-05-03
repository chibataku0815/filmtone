import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Link(
                "Filmtone Native Desktop v2 (Phase 0)",
                destination: URL(string: "https://chibatakumi.com/filmtone")!
            )
        }
    }
}
