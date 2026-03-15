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

        var showsPersistentCopyLabel: Bool {
            switch self {
            case .large:
                return true
            case .compact:
                return false
            }
        }
    }

    private let fileURL: URL
    private let image: NSImage
    private let style: Style
    private let copyButton: NSButton
    private let hoverLabel = NSTextField(labelWithString: "Copy Path")
    private var hoverPollTimer: Timer?
    private var hoverStartTime: Date?
    private var isHoveringCopyButton = false

    init(frame frameRect: NSRect, fileURL: URL, image: NSImage, style: Style) {
        self.fileURL = fileURL
        self.image = image
        self.style = style
        self.copyButton = NSButton(title: ">_", target: nil, action: nil)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        copyButton.target = self
        copyButton.action = #selector(copyPath)
        copyButton.isBordered = false
        copyButton.bezelStyle = .inline
        copyButton.font = NSFont.monospacedSystemFont(ofSize: style.copyButtonFontSize, weight: .semibold)
        copyButton.contentTintColor = .secondaryLabelColor
        addSubview(copyButton)

        hoverLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        hoverLabel.textColor = .secondaryLabelColor
        hoverLabel.isHidden = !style.showsPersistentCopyLabel
        addSubview(hoverLabel)
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
        let buttonSize = NSSize(width: 28, height: 18)
        copyButton.frame = NSRect(
            x: bounds.width - buttonSize.width - 6,
            y: bounds.height - buttonSize.height - 4,
            width: buttonSize.width,
            height: buttonSize.height
        )

        hoverLabel.sizeToFit()
        hoverLabel.frame = NSRect(
            x: copyButton.frame.minX - hoverLabel.frame.width + 2,
            y: copyButton.frame.minY + ((copyButton.frame.height - hoverLabel.frame.height) / 2),
            width: hoverLabel.frame.width,
            height: hoverLabel.frame.height
        )
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if style.showsPersistentCopyLabel {
            hoverPollTimer?.invalidate()
            hoverPollTimer = nil
            hoverLabel.isHidden = false
            return
        }

        if window == nil {
            hoverPollTimer?.invalidate()
            hoverPollTimer = nil
            return
        }

        if hoverPollTimer == nil {
            let timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkHoverState), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            hoverPollTimer = timer
        }
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

    @objc private func checkHoverState() {
        guard !style.showsPersistentCopyLabel else {
            hoverLabel.isHidden = false
            return
        }

        guard let window else { return }
        let pointerInWindow = window.mouseLocationOutsideOfEventStream
        let pointerInView = convert(pointerInWindow, from: nil)
        let isHovered = copyButton.frame.contains(pointerInView)

        if isHovered {
            if !isHoveringCopyButton {
                isHoveringCopyButton = true
                hoverStartTime = Date()
                hoverLabel.isHidden = true
            } else if let hoverStartTime,
                      Date().timeIntervalSince(hoverStartTime) >= ScreenPathConfig.copyHoverDelay {
                hoverLabel.isHidden = false
            }
            return
        }

        isHoveringCopyButton = false
        hoverStartTime = nil
        hoverLabel.isHidden = true
    }

    @objc private func copyPath() {
        hoverLabel.isHidden = !style.showsPersistentCopyLabel
        isHoveringCopyButton = false
        hoverStartTime = nil
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fileURL.path, forType: .string)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }
}
