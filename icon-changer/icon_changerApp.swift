//
//  icon_changerApp.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 04/07/26.
//

import AppKit
import SwiftUI

@main
struct icon_changerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var isMenuBarModeEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationIcon()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarModeChanged(_:)),
            name: .iconChangerMenuBarModeChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeVisible(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func menuBarModeChanged(_ notification: Notification) {
        guard let isEnabled = notification.object as? Bool else {
            return
        }

        isMenuBarModeEnabled = isEnabled

        if isEnabled {
            installStatusItem()
            NSApp.setActivationPolicy(.accessory)
        } else {
            removeStatusItem()
            NSApp.setActivationPolicy(.regular)
            showMainWindow()
        }
    }

    @objc private func windowDidBecomeVisible(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        window.delegate = self
    }

    private func installStatusItem() {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = menuBarIcon()
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Abrir Icon Changer", action: #selector(openMainAppFromMenuBar), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Encerrar", action: #selector(quitFromMenuBar), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu

        statusItem = item
    }

    private func removeStatusItem() {
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    @objc private func openMainAppFromMenuBar() {
        showMainWindow()
    }

    @objc private func quitFromMenuBar() {
        NSApp.terminate(nil)
    }

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)

        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.canBecomeKey || $0.isMiniaturized }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            return
        }

        NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
    }

    private func configureApplicationIcon() {
        if let appIcon = bundledAppIcon() {
            NSApp.applicationIconImage = appIcon
        }
    }

    private func menuBarIcon() -> NSImage? {
        guard let sourceImage = bundledAppIcon() ?? NSApp.applicationIconImage else {
            return NSImage(systemSymbolName: "paintbrush.pointed", accessibilityDescription: "Icon Changer")
        }

        let image = sourceImage.copy() as? NSImage
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = false
        return image
    }

    private func bundledAppIcon() -> NSImage? {
        if let appIcon = NSImage(named: "AppIcon") {
            return appIcon
        }

        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
            return nil
        }

        return NSImage(contentsOf: iconURL)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isMenuBarModeEnabled else {
            return true
        }

        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }
}

extension Notification.Name {
    static let iconChangerMenuBarModeChanged = Notification.Name("iconChangerMenuBarModeChanged")
}
