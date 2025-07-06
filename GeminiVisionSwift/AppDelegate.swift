import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private var menu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Find the main window to control its visibility
        if let window = NSApplication.shared.windows.first {
            self.window = window
            window.orderOut(nil)
        }
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Create the menu that we will show on right-click
        menu = NSMenu()
        let captureItem = NSMenuItem(title: "Capture Screen", action: #selector(captureAndShowWindow), keyEquivalent: "s")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(captureItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Configure the button in the status bar
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.macro.circle", accessibilityDescription: "Open GeminiVisionSwift")
            // Set a single action that will handle all click types
            button.action = #selector(statusBarButtonAction)
            // IMPORTANT: We need to send both left and right mouse events to the action.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    /// This function checks the event type and decides what to do.
    @objc func statusBarButtonAction() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            // For a right-click, show the menu programmatically.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil // Unset the menu to return control to left-click
        } else {
            // For a left-click, toggle the window.
            toggleWindow()
        }
    }

    /// Shows or hides the window on left-click.
    @objc func toggleWindow() {
        // If our window is visible AND our app is the one currently in focus...
        if window.isVisible && NSApp.isActive {
            // ...hide the entire app, which passes focus to the previous app.
            NSApp.hide(nil)
        } else {
            // ...otherwise, bring our app and its window to the front.
            showWindow()
        }
    }
    
    /// Shows the window and triggers a capture (for the menu item).
    @objc func captureAndShowWindow() {
        showWindow()
        NotificationCenter.default.post(name: .captureScreen, object: nil)
    }
    
    /// Helper function to bring the window to the front.
    private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Prevents the app from terminating when the last window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Hide the window when the user switches to another app
        if window.isVisible {
            window.orderOut(nil)
        }
    }
}
