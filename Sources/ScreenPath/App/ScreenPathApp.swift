import AppKit
import Foundation

@MainActor
final class ScreenPathApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var watcher: ScreenshotWatcher!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        watcher = ScreenshotWatcher(
            logPath: ScreenPathConfig.logPath,
            maxRecent: ScreenPathConfig.maxRecent,
            maxLogEntries: ScreenPathConfig.maxLogEntries,
            directoryRefreshInterval: ScreenPathConfig.directoryRefreshInterval
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let icon = makeStatusBarIcon() {
                button.image = icon
                button.imageScaling = .scaleProportionallyUpOrDown
            } else {
                button.title = ScreenPathConfig.appName
            }
        }

        menu = NSMenu()
        statusItem.menu = menu
        rebuildMenu()

        watcher.onChange = { [weak self] in
            self?.rebuildMenu()
        }
        watcher.start()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addWatchingSection()
        addAccessSectionIfNeeded()
        addLatestSection()
        addRecentsSection()
        addOptionsSection()
        addQuitItem()
    }

    private func addWatchingSection() {
        let folderLabel = compactPathLabel(watcher.watchDirectory, maxLength: 24)
        let item = NSMenuItem(title: "Watching: \(folderLabel)", action: nil, keyEquivalent: "")
        item.toolTip = watcher.watchDirectory
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addAccessSectionIfNeeded() {
        guard !watcher.hasDirectoryAccess else { return }

        let warningItem = NSMenuItem(title: "Folder access required", action: nil, keyEquivalent: "")
        warningItem.isEnabled = false
        menu.addItem(warningItem)

        let detailText = "Grant access to the screenshot folder in System Settings"
        let detailHeight = WarningMenuLabelView.preferredHeight(
            for: detailText,
            width: ScreenPathConfig.dragPreviewMenuWidth
        )
        let detailItem = NSMenuItem()
        detailItem.view = WarningMenuLabelView(
            frame: NSRect(x: 0, y: 0, width: ScreenPathConfig.dragPreviewMenuWidth, height: detailHeight),
            text: detailText,
            color: .systemRed
        )
        menu.addItem(detailItem)

        let openSettingsItem = NSMenuItem(title: "Open Files & Folders Settings", action: #selector(openFilesAndFoldersSettings), keyEquivalent: "")
        openSettingsItem.target = self
        menu.addItem(openSettingsItem)

        menu.addItem(.separator())
    }

    private func addLatestSection() {
        let latestHeader = NSMenuItem(title: "Latest screenshot", action: nil, keyEquivalent: "")
        latestHeader.isEnabled = false
        menu.addItem(latestHeader)
        menu.addItem(makeLatestPreviewMenuItem())
        menu.addItem(.separator())
    }

    private func makeLatestPreviewMenuItem() -> NSMenuItem {
        guard let latest = watcher.latestPath,
              FileManager.default.fileExists(atPath: latest),
              let image = NSImage(contentsOfFile: latest) else {
            let unavailableItem = NSMenuItem(title: "No screenshot available", action: nil, keyEquivalent: "")
            unavailableItem.isEnabled = false
            return unavailableItem
        }

        let previewSize = latestPreviewViewSize(for: image, menuWidth: ScreenPathConfig.dragPreviewMenuWidth)
        let previewItem = NSMenuItem()
        previewItem.view = ScreenshotPreviewMenuView(
            frame: NSRect(origin: .zero, size: previewSize),
            fileURL: URL(fileURLWithPath: latest),
            image: image,
            style: .large
        )
        return previewItem
    }

    private func latestPreviewViewSize(for image: NSImage, menuWidth: CGFloat) -> NSSize {
        let maxWidth: CGFloat = 220
        let maxHeight: CGFloat = 220
        let topInset: CGFloat = ScreenshotPreviewMenuView.Style.large.topInset
        let bottomInset: CGFloat = ScreenshotPreviewMenuView.Style.large.bottomInset
        let imageSize = image.size

        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: menuWidth, height: 160)
        }

        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height, 1.0)
        let drawHeight = imageSize.height * scale
        return NSSize(width: menuWidth, height: drawHeight + topInset + bottomInset)
    }

    private func addRecentsSection() {
        let recentPaths = Array(watcher.recentPaths.dropFirst())

        if recentPaths.isEmpty {
            let emptyRecent = NSMenuItem(title: "Recent: none yet", action: nil, keyEquivalent: "")
            emptyRecent.isEnabled = false
            menu.addItem(emptyRecent)
            menu.addItem(.separator())
            return
        }

        let gridEntries = recentPaths.compactMap(Self.makeGridEntry)

        if gridEntries.isEmpty {
            let emptyRecent = NSMenuItem(title: "No recent screenshots available", action: nil, keyEquivalent: "")
            emptyRecent.isEnabled = false
            menu.addItem(emptyRecent)
            menu.addItem(.separator())
            return
        }

        let recentEntries = Array(gridEntries.prefix(ScreenPathConfig.recentPreviewCount))
        let recentsMenu = NSMenu()
        recentsMenu.addItem(makeGridMenuItem(entries: recentEntries))

        let recentsItem = NSMenuItem(title: "Recent screenshots", action: nil, keyEquivalent: "")
        recentsItem.submenu = recentsMenu
        menu.addItem(recentsItem)

        menu.addItem(.separator())
    }

    private func makeGridMenuItem(entries: [ScreenshotGridMenuView.Entry]) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = ScreenshotGridMenuView(
            frame: NSRect(
                origin: .zero,
                size: ScreenshotGridMenuView.size(
                    for: entries.count,
                    menuWidth: ScreenPathConfig.dragPreviewMenuWidth
                )
            ),
            entries: entries,
            menuWidth: ScreenPathConfig.dragPreviewMenuWidth
        )
        return item
    }

    private static func makeGridEntry(for path: String) -> ScreenshotGridMenuView.Entry? {
        guard FileManager.default.fileExists(atPath: path),
              let image = NSImage(contentsOfFile: path) else {
            return nil
        }

        return ScreenshotGridMenuView.Entry(
            fileURL: URL(fileURLWithPath: path),
            image: image
        )
    }

    private func addOptionsSection() {
        let optionsMenu = NSMenu()

        let openLogItem = NSMenuItem(title: "Open paths.log", action: #selector(openLogFile), keyEquivalent: "")
        openLogItem.target = self
        optionsMenu.addItem(openLogItem)

        let revealItem = NSMenuItem(
            title: "Reveal Latest in Finder",
            action: #selector(revealLatestInFinder),
            keyEquivalent: ""
        )
        revealItem.target = self
        revealItem.isEnabled = watcher.hasDirectoryAccess && watcher.latestPath != nil
        optionsMenu.addItem(revealItem)

        optionsMenu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About \(ScreenPathConfig.appName)", action: nil, keyEquivalent: "")
        aboutItem.isEnabled = false
        optionsMenu.addItem(aboutItem)

        let versionItem = NSMenuItem(title: "Version: \(ScreenPathConfig.version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        optionsMenu.addItem(versionItem)

        let optionsItem = NSMenuItem(title: "Options", action: nil, keyEquivalent: "")
        optionsItem.submenu = optionsMenu
        menu.addItem(optionsItem)
    }

    private func addQuitItem() {
        let quitItem = NSMenuItem(title: "Quit \(ScreenPathConfig.appName)", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func revealLatestInFinder() {
        guard let latest = validatedLatestPath() else { return }

        if NSWorkspace.shared.selectFile(latest, inFileViewerRootedAtPath: "") {
            return
        }

        let parent = (latest as NSString).deletingLastPathComponent
        if !parent.isEmpty {
            NSWorkspace.shared.open(URL(fileURLWithPath: parent))
        } else {
            playErrorSound()
        }
    }

    @objc private func openLogFile() {
        NSWorkspace.shared.open(URL(fileURLWithPath: watcher.logPath))
    }

    @objc private func openFilesAndFoldersSettings() {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"),
            URL(string: "x-apple.systempreferences:com.apple.Settings.PrivacySecurity")
        ].compactMap { $0 }

        for url in urls where NSWorkspace.shared.open(url) {
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func playErrorSound() {
        if let sound = NSSound(named: "Sosumi") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func validatedLatestPath() -> String? {
        guard let latest = watcher.latestPath else {
            playErrorSound()
            return nil
        }

        guard FileManager.default.fileExists(atPath: latest) else {
            playErrorSound()
            return nil
        }

        return latest
    }

    private func compactPathLabel(_ path: String, maxLength: Int) -> String {
        let fileName = (path as NSString).lastPathComponent
        if fileName.count <= maxLength { return fileName }
        if maxLength <= 1 { return String(fileName.prefix(maxLength)) }
        return String(fileName.prefix(maxLength - 1)) + "…"
    }
}
