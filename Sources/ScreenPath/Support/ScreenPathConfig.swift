import AppKit
import Foundation

enum ScreenPathConfig {
    static let appName = "ScreenPath"
    static let version = "0.4"
    static let maxRecent = 9
    static let recentPreviewCount = 8
    static let maxLogEntries = 25
    static let directoryRefreshInterval: TimeInterval = 10
    static let logPath = ("~/Library/Application Support/ScreenPath/paths.log" as NSString).expandingTildeInPath
    static let dragPreviewMenuWidth: CGFloat = 320
    static let compactGridColumns = 2
    static let compactGridSpacing: CGFloat = 8
    static let compactGridPadding: CGFloat = 4
    static let compactTileHeight: CGFloat = 102
    static let copyHoverDelay: TimeInterval = 0.5
}
