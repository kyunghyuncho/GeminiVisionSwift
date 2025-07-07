import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private var menu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            self.window = window
            window.orderOut(nil)
        }
        
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        menu = NSMenu()
        let captureItem = NSMenuItem(title: "Capture Screen", action: #selector(captureAndShowWindow), keyEquivalent: "s")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(captureItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.macro.circle", accessibilityDescription: "Open GeminiVisionSwift")
            button.action = #selector(statusBarButtonAction)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc func statusBarButtonAction() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Use a Task to call our new async function
            Task {
                await toggleWindow()
            }
        }
    }

    /// Shows or hides the window on left-click.
    @objc func toggleWindow() async {
        if window.isVisible && NSApp.isActive {
            NSApp.hide(nil)
        } else {
            await showWindow()
        }
    }
    
    /// Shows the window and triggers a capture (for the menu item).
    @objc func captureAndShowWindow() {
        Task {
            await showWindow()
            NotificationCenter.default.post(name: .captureScreen, object: nil)
        }
    }
    
    /// Helper function to bring the window to the front.
    private func showWindow() async {
        // Change to a normal app
        NSApp.setActivationPolicy(.regular)
        
        // ** THE FIX: Add a tiny delay to allow the system to process the policy change **
        try? await Task.sleep(for: .milliseconds(50))
        
        // Now, activate and show the window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    /// This is called when the user clicks on another app.
    func applicationDidResignActive(_ notification: Notification) {
        if window.isVisible {
            window.orderOut(nil)
        }
        NSApp.setActivationPolicy(.accessory)
    }

    /// Prevents the app from terminating when the last window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
