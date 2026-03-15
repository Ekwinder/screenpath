import AppKit
import Foundation

@MainActor
final class ScreenshotWatcher: NSObject {
    let logPath: String
    var onChange: (() -> Void)?

    private(set) var watchDirectory: String
    private(set) var recentPaths: [String] = []
    private(set) var latestPath: String?
    private(set) var hasDirectoryAccess: Bool = true

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

        refreshDirectoryAccessState()
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
        if refreshDirectoryAccessState() {
            onChange?()
        }
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

    @discardableResult
    private func refreshDirectoryAccessState() -> Bool {
        let previous = hasDirectoryAccess
        do {
            _ = try fileManager.contentsOfDirectory(atPath: watchDirectory)
            hasDirectoryAccess = true
        } catch {
            hasDirectoryAccess = false
            knownFiles.removeAll()
            recentPaths.removeAll()
            latestPath = nil
        }
        return previous != hasDirectoryAccess
    }

    private func refreshWatchDirectoryIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastDirectoryRefresh) >= directoryRefreshInterval else { return }
        lastDirectoryRefresh = now

        let resolved = Self.resolveScreenshotDirectory()
        guard resolved != watchDirectory else { return }

        watchDirectory = resolved
        refreshDirectoryAccessState()
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
