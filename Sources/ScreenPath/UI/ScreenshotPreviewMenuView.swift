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
    private var isHoveringPreview = false {
        didSet {
            if oldValue != isHoveringPreview { needsDisplay = true }
        }
    }

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
        copyButton.toolTip = "Copy screenshot path"
        addSubview(copyButton)
        toolTip = "Click to open image · Drag to share"

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let borderPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        (isHoveringPreview ? NSColor.controlAccentColor : .quaternaryLabelColor).setStroke()
        borderPath.lineWidth = 1
        borderPath.stroke()

        let previewRect = centeredPreviewRect()
        image.draw(in: previewRect, from: .zero, operation: .sourceOver, fraction: 1)

        if isHoveringPreview && previewInteractionRect.height >= 26 {
            let hint = NSAttributedString(string: "Click to open", attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.white
            ])
            let size = hint.size()
            let pill = NSRect(x: (bounds.width - size.width - 12) / 2,
                              y: 6, width: size.width + 12, height: size.height + 6)
            NSColor.black.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 5, yRadius: 5).fill()
            hint.draw(at: NSPoint(x: pill.minX + 6, y: pill.minY + 3))
        }
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
        isHoveringPreview = false

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

    private var previewInteractionRect: NSRect {
        NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - style.topInset))
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(previewInteractionRect, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard previewInteractionRect.contains(location), let trackingWindow = window else {
            super.mouseDown(with: event)
            return
        }

        var gesture = ScreenshotPreviewGesture(start: location)
        // Custom menu views track the press themselves so a click does not start a drag.
        while window === trackingWindow {
            guard let next = NSApp.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp, .keyDown],
                until: Date().addingTimeInterval(0.1), inMode: .eventTracking, dequeue: true
            ) else { continue }
            if next.type == .keyDown {
                if next.keyCode == 53 { return } // Escape cancels the press.
                continue
            }
            let point = convert(next.locationInWindow, from: nil)
            switch gesture.update(at: point, released: next.type == .leftMouseUp,
                                  insidePreview: previewInteractionRect.contains(point)) {
            case .waiting:
                continue
            case .open:
                openImage()
                return
            case .drag:
                let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
                draggingItem.setDraggingFrame(centeredPreviewRect(), contents: image)
                beginDraggingSession(with: [draggingItem], event: next, source: self)
                return
            case .cancelled:
                return
            }
        }
    }

    private func openImage() {
        var rootMenu = enclosingMenuItem?.menu
        while let parent = rootMenu?.supermenu { rootMenu = parent }
        rootMenu?.cancelTracking()
        let url = fileURL
        // Let menu tracking finish before activating the default image application.
        DispatchQueue.main.async {
            guard NSWorkspace.shared.open(url) else {
                let alert = NSAlert()
                alert.messageText = "Couldn’t open screenshot"
                alert.informativeText = "The file “\(url.lastPathComponent)” may have been moved or deleted, or no app is available to open it."
                alert.alertStyle = .warning
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
                return
            }
        }
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
        isHoveringPreview = previewInteractionRect.contains(pointer)
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

/// A small amount of pointer movement is still a click; a drag can never open the file.
struct ScreenshotPreviewGesture {
    enum Action { case waiting, open, drag, cancelled }

    let start: NSPoint
    private var finished = false

    mutating func update(at point: NSPoint, released: Bool, insidePreview: Bool) -> Action {
        guard !finished else { return .cancelled }
        let distance = hypot(point.x - start.x, point.y - start.y)
        if distance >= 4 {
            finished = true
            return released ? .cancelled : .drag
        }
        if released {
            finished = true
            return insidePreview ? .open : .cancelled
        }
        return .waiting
    }
}
