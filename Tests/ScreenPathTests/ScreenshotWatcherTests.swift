import Foundation
import Testing
@testable import ScreenPath

@Test @MainActor
func selectedFolderPersistsAndRejectsInvalidChanges() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let first = root.appendingPathComponent("First")
    let second = root.appendingPathComponent("Second")
    let suite = "ScreenPathTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
    for folder in [first, second] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    let firstImage = first.appendingPathComponent("Screenshot first.png")
    let secondImage = second.appendingPathComponent("Screenshot second.png")
    try Data().write(to: firstImage)
    try Data().write(to: secondImage)
    func makeWatcher() -> ScreenshotWatcher {
        ScreenshotWatcher(logPath: root.appendingPathComponent("paths.log").path,
                          maxRecent: 9, maxLogEntries: 25,
                          directoryRefreshInterval: 10, defaults: defaults)
    }
    let watcher = makeWatcher()
    try watcher.chooseDirectory(first)
    #expect(watcher.latestPath == firstImage.path)
    try watcher.chooseDirectory(second)
    #expect(watcher.recentPaths == [secondImage.path])
    #expect(watcher.usesCustomDirectory)
    let restored = makeWatcher()
    #expect(restored.watchDirectory == second.path)
    #expect(restored.latestPath == secondImage.path)
    #expect(throws: (any Error).self) {
        try watcher.chooseDirectory(root.appendingPathComponent("Missing"))
    }
    #expect(watcher.watchDirectory == second.path)
    #expect(watcher.latestPath == secondImage.path)
    #expect(makeWatcher().watchDirectory == second.path)
    let newImage = second.appendingPathComponent("Screenshot new.png")
    try Data().write(to: first.appendingPathComponent("Screenshot ignored.png"))
    try Data().write(to: newImage)
    for _ in 0..<40 {
        if watcher.latestPath == newImage.path { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(watcher.latestPath == newImage.path)
    #expect(watcher.recentPaths.allSatisfy { $0.hasPrefix(second.path + "/") })
    watcher.useSystemScreenshotDirectory()
    #expect(!watcher.usesCustomDirectory)
    #expect(makeWatcher().watchDirectory == watcher.watchDirectory)
}
