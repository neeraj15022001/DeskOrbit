import AppKit
import SwiftUI
import AppIntents

public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public static let shared = AppDelegate()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var mainWindowController: NSWindowController?
    private let manager = DeviceManager.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        // Open Dashboard window automatically on launch
        openDashboardWindow()

        // Notify macOS system that DeskOrbit app shortcuts and intents are ready
        if #available(macOS 14.0, *) {
            DeskOrbitShortcutsProvider.updateAppShortcutParameters()
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openDashboardWindow()
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            if let image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "DeskOrbit")?.withSymbolConfiguration(config) {
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
                contentRect: NSRect(x: 0, y: 0, width: 920, height: 630),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "DeskOrbit Dashboard"
            window.titlebarAppearsTransparent = true
            window.minSize = NSSize(width: 780, height: 500)
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
