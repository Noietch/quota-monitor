import AppKit
import SwiftUI

@main
struct QuotaMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = MonitorStore()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "号池额度")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 590)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MonitorView(store: store))
        self.popover = popover

        if ProcessInfo.processInfo.arguments.contains("--preview") {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 590),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "号池额度"
            window.contentViewController = NSHostingController(rootView: MonitorView(store: store))
            window.center()
            window.makeKeyAndOrderFront(nil)
            previewWindow = window
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        store.onStatusChanged = { [weak self] in
            self?.updateStatusItem()
        }
        updateStatusItem()
        store.startMonitoring()
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        if let summary = store.snapshot?.summary {
            button.title = "\(summary.usableNow)/\(summary.supported)"
            button.toolTip = "号池可用 \(summary.usableNow)，支持查询 \(summary.supported)"
        } else {
            button.title = store.isRefreshing ? "…" : "--"
            button.toolTip = store.errorMessage ?? "号池额度"
        }
    }
}
