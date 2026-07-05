//
//  IconSwitchingMonitor.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 05/07/26.
//

import AppKit

@MainActor
final class IconSwitchingMonitor {
    static let shared = IconSwitchingMonitor()

    private var appURL: URL?
    private var lightIcon: NSImage?
    private var darkIcon: NSImage?
    private var isEnabled = false
    private var refreshesDockAutomatically = false
    private var notificationObserver: NSObjectProtocol?

    private init() {
        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyIconForCurrentAppearance()
            }
        }
    }

    func updateConfiguration(
        appURL: URL?,
        lightIcon: NSImage?,
        darkIcon: NSImage?,
        refreshesDockAutomatically: Bool
    ) {
        self.appURL = appURL
        self.lightIcon = lightIcon
        self.darkIcon = darkIcon
        self.refreshesDockAutomatically = refreshesDockAutomatically
    }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func applyIconForCurrentAppearance() {
        guard isEnabled, let appURL else {
            return
        }

        let path = appURL.path(percentEncoded: false)
        guard NSWorkspace.shared.setIcon(iconForCurrentAppearance(), forFile: path, options: []) else {
            return
        }

        NSWorkspace.shared.noteFileSystemChanged(path)

        if refreshesDockAutomatically {
            refreshDock()
        }
    }

    private func iconForCurrentAppearance() -> NSImage? {
        isSystemDarkMode ? darkIcon : lightIcon
    }

    private var isSystemDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    @discardableResult
    private func refreshDock() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
