import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Link(
                "Filmtone Help",
                destination: URL(string: "https://chibatakumi.com/filmtone")!
            )
        }
    }
}
