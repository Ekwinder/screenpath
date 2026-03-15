import AppKit
import Foundation

@MainActor
final class ScreenshotGridMenuView: NSView {
    struct Entry {
        let fileURL: URL
        let image: NSImage
    }

    private let entries: [Entry]
    private let menuWidth: CGFloat

    init(frame frameRect: NSRect, entries: [Entry], menuWidth: CGFloat) {
        self.entries = entries
        self.menuWidth = menuWidth
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        buildTiles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let tileWidth = Self.tileWidth(for: menuWidth)
        let tileHeight = ScreenPathConfig.compactTileHeight
        let spacing = ScreenPathConfig.compactGridSpacing
        let padding = ScreenPathConfig.compactGridPadding

        for (index, view) in subviews.enumerated() {
            let row = index / ScreenPathConfig.compactGridColumns
            let column = index % ScreenPathConfig.compactGridColumns
            let x = padding + CGFloat(column) * (tileWidth + spacing)
            let y = bounds.height - padding - tileHeight - CGFloat(row) * (tileHeight + spacing)
            view.frame = NSRect(x: x, y: y, width: tileWidth, height: tileHeight)
        }
    }

    static func size(for entryCount: Int, menuWidth: CGFloat) -> NSSize {
        let rows = Int(ceil(Double(entryCount) / Double(ScreenPathConfig.compactGridColumns)))
        let height =
            ScreenPathConfig.compactGridPadding * 2 +
            CGFloat(rows) * ScreenPathConfig.compactTileHeight +
            CGFloat(max(rows - 1, 0)) * ScreenPathConfig.compactGridSpacing
        return NSSize(width: menuWidth, height: height)
    }

    private static func tileWidth(for menuWidth: CGFloat) -> CGFloat {
        let totalSpacing = ScreenPathConfig.compactGridSpacing * CGFloat(ScreenPathConfig.compactGridColumns - 1)
        let totalPadding = ScreenPathConfig.compactGridPadding * 2
        return (menuWidth - totalSpacing - totalPadding) / CGFloat(ScreenPathConfig.compactGridColumns)
    }

    private func buildTiles() {
        for entry in entries {
            let tile = ScreenshotPreviewMenuView(
                frame: .zero,
                fileURL: entry.fileURL,
                image: entry.image,
                style: .compact
            )
            addSubview(tile)
        }
    }
}
