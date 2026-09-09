import AppKit
import Foundation

@MainActor
final class ScreenshotPreviewMenuView: NSView, NSDraggingSource {
    enum Style {
        case large
        case compact

        var topInset: CGFloat {
            switch self {
            case .large:
                return 28
            case .compact:
                return 24
            }
        }

        var bottomInset: CGFloat { 4 }

        var copyButtonFontSize: CGFloat {
            switch self {
            case .large:
                return 11
            case .compact:
                return 10
            }
        }

    }

    private let fileURL: URL
    private let image: NSImage
    private let style: Style
    private let copyButton: CopyPathButton
    private var hoverPollTimer: Timer?
    private var copiedUntil: Date?

    init(frame frameRect: NSRect, fileURL: URL, image: NSImage, style: Style) {
        self.fileURL = fileURL
        self.image = image
        self.style = style
        self.copyButton = CopyPathButton(title: "Copy Path >_", target: nil, action: nil)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        copyButton.target = self
        copyButton.action = #selector(copyPath)
        copyButton.isBordered = false
        copyButton.bezelStyle = .inline
        copyButton.font = NSFont.monospacedSystemFont(ofSize: style.copyButtonFontSize, weight: .semibold)
        copyButton.contentTintColor = .secondaryLabelColor
        copyButton.setAccessibilityLabel("Copy screenshot path")
        addSubview(copyButton)

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let borderPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        NSColor.quaternaryLabelColor.setStroke()
        borderPath.lineWidth = 1
        borderPath.stroke()

        let previewRect = centeredPreviewRect()
        image.draw(in: previewRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    override func layout() {
        super.layout()
        let buttonSize = NSSize(width: 90, height: 20)
        copyButton.frame = NSRect(
            x: bounds.width - buttonSize.width - 6,
            y: bounds.height - buttonSize.height - 3,
            width: buttonSize.width,
            height: buttonSize.height
        )
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hoverPollTimer?.invalidate()
        hoverPollTimer = nil
        copiedUntil = nil
        copyButton.title = "Copy Path >_"
        copyButton.isHovered = false

        guard window != nil else { return }
        // Menu tracking uses a nested run loop; keep feedback active in common modes.
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkHoverState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverPollTimer = timer
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard !copyButton.frame.contains(location) else {
            super.mouseDown(with: event)
            return
        }

        let previewRect = centeredPreviewRect()
        let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        draggingItem.setDraggingFrame(previewRect, contents: image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    private func centeredPreviewRect() -> NSRect {
        let availableWidth = bounds.width - 8
        let availableHeight = bounds.height - style.topInset - style.bottomInset - 4
        let scale = min(availableWidth / image.size.width, availableHeight / image.size.height, 1.0)
        let drawWidth = image.size.width * scale
        let drawHeight = image.size.height * scale
        let originX = (bounds.width - drawWidth) / 2
        let originY = style.bottomInset + ((availableHeight - drawHeight) / 2)
        return NSRect(x: originX, y: originY, width: drawWidth, height: drawHeight)
    }

    private func checkHoverState() {
        guard let window else { return }
        let pointer = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        copyButton.isHovered = copyButton.frame.contains(pointer)
        if let copiedUntil, Date() >= copiedUntil {
            self.copiedUntil = nil
            copyButton.title = "Copy Path >_"
        }
    }

    @objc private func copyPath() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(fileURL.path, forType: .string) else {
            copiedUntil = nil
            copyButton.title = "Copy failed"
            NSSound.beep()
            return
        }
        copyButton.title = "Copied!  ✓"
        copiedUntil = Date().addingTimeInterval(1.5)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }
}

/// One hit target for the label and icon, with feedback even inside an NSMenu.
@MainActor
private final class CopyPathButton: NSButton {
    var isHovered = false {
        didSet {
            if oldValue != isHovered { needsDisplay = true }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let active = isHovered || isHighlighted
        contentTintColor = active ? .controlAccentColor : .secondaryLabelColor
        if active {
            NSColor.controlAccentColor.withAlphaComponent(isHighlighted ? 0.28 : 0.14).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        }
        super.draw(dirtyRect)
    }
}
