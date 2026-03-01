import AppKit
import Foundation

enum ScreenPathConfig {
    static let appName = "ScreenPath"
    static let version = "0.2"
    static let maxRecent = 10
    static let inlineRecentCount = 3
    static let maxLogEntries = 25
    static let directoryRefreshInterval: TimeInterval = 10
    static let fileScanInterval: TimeInterval = 1.5
    static let logPath = ("~/Library/Application Support/ScreenPath/paths.log" as NSString).expandingTildeInPath
    static let dragPreviewMenuWidth: CGFloat = 320
}

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
            directoryRefreshInterval: ScreenPathConfig.directoryRefreshInterval,
            fileScanInterval: ScreenPathConfig.fileScanInterval
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

    private func addLatestSection() {
        let latestLabel = watcher.latestPath.map { compactPathLabel($0, maxLength: 28) } ?? "No screenshot available"
        let latestItem = NSMenuItem(title: "Copy Latest Path: \(latestLabel)", action: #selector(copyLatestPath), keyEquivalent: "")
        latestItem.target = self
        latestItem.toolTip = watcher.latestPath
        latestItem.isEnabled = watcher.latestPath != nil
        menu.addItem(latestItem)

        for item in makeDragLatestMenuItems() {
            menu.addItem(item)
        }

        menu.addItem(.separator())
    }

    private func makeDragLatestMenuItems() -> [NSMenuItem] {
        let headerItem = NSMenuItem(title: "Drag Latest Screenshot", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false

        guard let latest = watcher.latestPath,
              FileManager.default.fileExists(atPath: latest),
              let image = NSImage(contentsOfFile: latest) else {
            let unavailableItem = NSMenuItem(title: "No screenshot available", action: nil, keyEquivalent: "")
            unavailableItem.isEnabled = false
            return [headerItem, unavailableItem]
        }

        let previewSize = dragPreviewViewSize(for: image, menuWidth: ScreenPathConfig.dragPreviewMenuWidth)
        let previewItem = NSMenuItem()
        previewItem.view = DraggableScreenshotMenuView(
            frame: NSRect(origin: .zero, size: previewSize),
            fileURL: URL(fileURLWithPath: latest),
            image: image
        )
        return [headerItem, previewItem]
    }

    private func dragPreviewViewSize(for image: NSImage, menuWidth: CGFloat) -> NSSize {
        let maxWidth: CGFloat = 220
        let maxHeight: CGFloat = 220
        let headerHeight: CGFloat = 22
        let imageSize = image.size

        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: maxWidth, height: 160)
        }

        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height, 1.0)
        let drawHeight = imageSize.height * scale
        return NSSize(width: menuWidth, height: drawHeight + headerHeight + 8)
    }

    private func makeRecentScreenshotMenuItem(path: String) -> NSMenuItem {
        let title = (path as NSString).lastPathComponent
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let copyItem = NSMenuItem(title: "Copy Path", action: #selector(copyRecentPath(_:)), keyEquivalent: "")
        copyItem.target = self
        copyItem.representedObject = path
        submenu.addItem(copyItem)

        submenu.addItem(.separator())

        guard FileManager.default.fileExists(atPath: path),
              let image = NSImage(contentsOfFile: path) else {
            let unavailable = NSMenuItem(title: "Screenshot unavailable", action: nil, keyEquivalent: "")
            unavailable.isEnabled = false
            submenu.addItem(unavailable)
            item.submenu = submenu
            return item
        }

        let previewSize = dragPreviewViewSize(for: image, menuWidth: ScreenPathConfig.dragPreviewMenuWidth)
        let previewItem = NSMenuItem()
        previewItem.view = DraggableScreenshotMenuView(
            frame: NSRect(origin: .zero, size: previewSize),
            fileURL: URL(fileURLWithPath: path),
            image: image
        )
        submenu.addItem(previewItem)
        item.submenu = submenu
        return item
    }

    private func addRecentsSection() {
        if watcher.recentPaths.isEmpty {
            let emptyRecent = NSMenuItem(title: "Recent: none yet", action: nil, keyEquivalent: "")
            emptyRecent.isEnabled = false
            menu.addItem(emptyRecent)
            menu.addItem(.separator())
            return
        }

        let header = NSMenuItem(title: "Recent screenshots:", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let inlineRecents = Array(watcher.recentPaths.prefix(ScreenPathConfig.inlineRecentCount))
        for path in inlineRecents {
            menu.addItem(makeRecentScreenshotMenuItem(path: path))
        }

        if watcher.recentPaths.count > ScreenPathConfig.inlineRecentCount {
            let moreMenu = NSMenu()
            let overflowRecents = watcher.recentPaths.dropFirst(ScreenPathConfig.inlineRecentCount)
            for path in overflowRecents {
                let item = NSMenuItem(
                    title: (path as NSString).lastPathComponent,
                    action: #selector(copyRecentPath(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = path
                moreMenu.addItem(item)
            }

            let moreItem = NSMenuItem(title: "See More...", action: nil, keyEquivalent: "")
            moreItem.submenu = moreMenu
            menu.addItem(moreItem)
        }

        menu.addItem(.separator())
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
        revealItem.isEnabled = watcher.latestPath != nil
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

    @objc private func copyLatestPath() {
        guard let latest = validatedLatestPath() else { return }
        copyToClipboard(latest)
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

    @objc private func copyRecentPath(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        copyToClipboard(path)
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

    private func makeStatusBarIcon() -> NSImage? {
        let imageSize = NSSize(width: 16, height: 16)

        let image = NSImage(size: imageSize, flipped: false) { bounds in
            NSColor.clear.setFill()
            bounds.fill()

            NSColor.black.setStroke()
            NSColor.black.setFill()

            let boundary = NSBezierPath(roundedRect: NSRect(x: 4.0, y: 4.0, width: 10.0, height: 10.0), xRadius: 2.4, yRadius: 2.4)
            boundary.lineWidth = 1.15
            boundary.lineCapStyle = .round
            boundary.lineJoinStyle = .round
            boundary.stroke()

            let lens = NSBezierPath(ovalIn: NSRect(x: 7.1, y: 7.1, width: 3.8, height: 3.8))
            lens.fill()

            return true
        }

        image.isTemplate = true
        return image
    }

    private func pasteClipboardToFrontApp() -> Bool {
        let script = "tell application \"System Events\" to keystroke \"v\" using command down"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func copyToClipboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}

let app = NSApplication.shared
let delegate = ScreenPathApp()
app.delegate = delegate
app.run()

@MainActor
final class ScreenshotWatcher: NSObject {
    let logPath: String
    var onChange: (() -> Void)?

    private(set) var watchDirectory: String
    private(set) var recentPaths: [String] = []
    private(set) var latestPath: String?

    private let maxRecent: Int
    private let maxLogEntries: Int
    private let directoryRefreshInterval: TimeInterval
    private let fileScanInterval: TimeInterval

    private var knownFiles: Set<String> = []
    private var timer: Timer?
    private var lastDirectoryRefresh: Date = .distantPast
    private let fileManager = FileManager.default

    init(
        logPath: String,
        maxRecent: Int,
        maxLogEntries: Int,
        directoryRefreshInterval: TimeInterval,
        fileScanInterval: TimeInterval
    ) {
        self.watchDirectory = Self.resolveScreenshotDirectory()
        self.logPath = logPath
        self.maxRecent = maxRecent
        self.maxLogEntries = maxLogEntries
        self.directoryRefreshInterval = directoryRefreshInterval
        self.fileScanInterval = fileScanInterval
        super.init()

        seedKnownFiles()
        bootstrapRecentFromDisk()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: fileScanInterval,
            target: self,
            selector: #selector(onTimer),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func onTimer() {
        refreshWatchDirectoryIfNeeded()
        pruneDeletedScreenshots()
        scanForNewScreenshots()
    }

    private func seedKnownFiles() {
        knownFiles = Set(Self.listImageFiles(in: watchDirectory))
    }

    private func bootstrapRecentFromDisk() {
        let recent = Self.listImageFilesWithDates(in: watchDirectory)
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .map { $0.path }

        recentPaths = Array(recent.prefix(maxRecent))
        latestPath = recentPaths.first
    }

    private func refreshWatchDirectoryIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastDirectoryRefresh) >= directoryRefreshInterval else { return }
        lastDirectoryRefresh = now

        let resolved = Self.resolveScreenshotDirectory()
        guard resolved != watchDirectory else { return }

        watchDirectory = resolved
        knownFiles = Set(Self.listImageFiles(in: watchDirectory))
        pruneInMemoryStateAgainstCurrentDirectory()
        onChange?()
    }

    private func pruneDeletedScreenshots() {
        let current = Set(Self.listImageFiles(in: watchDirectory))
        let removedPaths = knownFiles.subtracting(current)
        guard !removedPaths.isEmpty else { return }

        knownFiles = current
        pruneInMemoryStateAgainstCurrentDirectory()
        onChange?()
    }

    private func pruneInMemoryStateAgainstCurrentDirectory() {
        recentPaths = recentPaths.filter { knownFiles.contains($0) }
        latestPath = latestPath.flatMap { knownFiles.contains($0) ? $0 : nil }
        if latestPath == nil {
            latestPath = recentPaths.first
        }
    }

    private func scanForNewScreenshots() {
        let current = Set(Self.listImageFiles(in: watchDirectory))
        let newPaths = current.subtracting(knownFiles)
            .sorted { Self.lastModified(at: $0) < Self.lastModified(at: $1) }
        guard !newPaths.isEmpty else { return }

        for path in newPaths {
            knownFiles.insert(path)
            latestPath = path
            recentPaths.removeAll { $0 == path }
            recentPaths.insert(path, at: 0)
            if recentPaths.count > maxRecent {
                recentPaths.removeLast(recentPaths.count - maxRecent)
            }
            appendToLog(path: path)
        }

        onChange?()
    }

    private func appendToLog(path: String) {
        let logDir = (logPath as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: logDir) {
            try? fileManager.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: logPath) {
            fileManager.createFile(atPath: logPath, contents: nil)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let line = "\(formatter.string(from: Date()))\t\(path)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                // Ignore transient write failures.
            }
        }

        trimLogIfNeeded()
    }

    private func trimLogIfNeeded() {
        guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else { return }

        var lines = content.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > maxLogEntries else { return }

        lines = Array(lines.suffix(maxLogEntries))
        let trimmed = lines.joined(separator: "\n") + "\n"
        try? trimmed.write(toFile: logPath, atomically: true, encoding: .utf8)
    }

    private static func resolveScreenshotDirectory() -> String {
        let defaultsPath = ("~/Library/Preferences/com.apple.screencapture.plist" as NSString)
            .expandingTildeInPath

        if
            let dict = NSDictionary(contentsOfFile: defaultsPath),
            let location = dict["location"] as? String
        {
            return (location as NSString).expandingTildeInPath
        }

        return ("~/Desktop" as NSString).expandingTildeInPath
    }

    private static func listImageFiles(in directory: String) -> [String] {
        listImageFilesWithDates(in: directory).map { $0.path }
    }

    private static func listImageFilesWithDates(in directory: String) -> [(path: String, modifiedAt: Date)] {
        let validExts = Set(["png", "jpg", "jpeg", "heic", "tiff"])
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return []
        }

        return items.compactMap { name in
            let path = (directory as NSString).appendingPathComponent(name)
            let ext = (name as NSString).pathExtension.lowercased()
            guard validExts.contains(ext) else { return nil }
            guard isLikelyMacScreenshotFileName(name) else { return nil }

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
                return nil
            }

            return (path, lastModified(at: path))
        }
    }

    private static func isLikelyMacScreenshotFileName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("screenshot ") || lower.hasPrefix("screen shot ")
    }

    private static func lastModified(at path: String) -> Date {
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: path),
            let modified = attrs[.modificationDate] as? Date
        else {
            return .distantPast
        }
        return modified
    }
}


@MainActor
final class DraggableScreenshotMenuView: NSView, NSDraggingSource {
    private let fileURL: URL
    private let image: NSImage

    init(frame frameRect: NSRect, fileURL: URL, image: NSImage) {
        self.fileURL = fileURL
        self.image = image
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let instruction = "Drag this image into another app"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let instructionRect = NSRect(x: 4, y: bounds.height - 20, width: bounds.width - 8, height: 14)
        instruction.draw(in: instructionRect, withAttributes: attrs)

        let previewRect = centeredPreviewRect()
        image.draw(in: previewRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    override func mouseDown(with event: NSEvent) {
        let previewRect = centeredPreviewRect()
        let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        draggingItem.setDraggingFrame(previewRect, contents: image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    private func centeredPreviewRect() -> NSRect {
        let availableWidth = bounds.width - 4
        let availableHeight = bounds.height - 24
        let scale = min(availableWidth / image.size.width, availableHeight / image.size.height, 1.0)
        let drawWidth = image.size.width * scale
        let drawHeight = image.size.height * scale
        let originX = (bounds.width - drawWidth) / 2
        let originY = 4 + ((availableHeight - drawHeight) / 2)
        return NSRect(x: originX, y: originY, width: drawWidth, height: drawHeight)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }
}
