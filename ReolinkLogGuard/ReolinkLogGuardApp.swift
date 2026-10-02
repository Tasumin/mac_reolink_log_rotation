import SwiftUI

@main
struct ReolinkLogGuardApp: App {
    @StateObject private var manager = LogGuardManager()

    var body: some Scene {
        WindowGroup("Reolink LogGuard") {
            ContentView()
                .environmentObject(manager)
                .frame(minWidth: 620, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Status") { manager.refresh() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
