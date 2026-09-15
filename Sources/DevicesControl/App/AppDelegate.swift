import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public static let shared = AppDelegate()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var mainWindowController: NSWindowController?
    private let manager = DeviceManager.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory (menu bar only, no dock icon by default)
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            if let image = NSImage(systemSymbolName: "macmini", accessibilityDescription: "DeskOrbit")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "🎛"
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 590, height: 450)
        pop.behavior = .transient

        let contentView = MenuBarView(
            manager: manager,
            onOpenDashboard: { [weak self] in
                self?.openDashboardWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        pop.contentViewController = NSHostingController(rootView: contentView)
        self.popover = pop
    }

    @objc public func togglePopover() {
        guard let button = statusItem?.button, let pop = popover else { return }

        if pop.isShown {
            pop.performClose(nil)
        } else {
            // Trigger refresh right before opening popover
            manager.refreshAll()
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }

    public func openDashboardWindow() {
        popover?.performClose(nil)

        // Elevate to regular app so it gets standard window focus and dock presence
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if mainWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "DeskOrbit Dashboard"
            window.minSize = NSSize(width: 750, height: 480)
            window.delegate = self
            window.contentView = NSHostingView(rootView: DashboardView(manager: manager))

            mainWindowController = NSWindowController(window: window)
        }

        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate
    public func windowWillClose(_ notification: Notification) {
        // When main window is closed, return to menu bar accessory mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
