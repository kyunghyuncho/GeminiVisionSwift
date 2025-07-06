import SwiftUI

@main
struct GeminiVisionSwiftApp: App {
    // Add this line to link your AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("View") {
                Button("Increase Font Size") {
                    NotificationCenter.default.post(name: .increaseFontSize, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    NotificationCenter.default.post(name: .decreaseFontSize, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
            }
        }
    }
}
