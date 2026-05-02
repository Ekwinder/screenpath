import AppKit

private enum WarningMenuLabelMetrics {
    static let horizontalInset: CGFloat = 20
    static let verticalInset: CGFloat = 4
    static var font: NSFont { NSFont.systemFont(ofSize: 13, weight: .semibold) }
}

@MainActor
final class WarningMenuLabelView: NSView {
    private let text: String
    private let color: NSColor

    static func preferredHeight(for text: String, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: WarningMenuLabelMetrics.font
        ]
        let insetWidth = max(width - (WarningMenuLabelMetrics.horizontalInset * 2), 1)
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: insetWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return ceil(rect.height) + (WarningMenuLabelMetrics.verticalInset * 2)
    }

    init(frame frameRect: NSRect, text: String, color: NSColor) {
        self.text = text
        self.color = color
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

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: WarningMenuLabelMetrics.font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        let rect = bounds.insetBy(
            dx: WarningMenuLabelMetrics.horizontalInset,
            dy: WarningMenuLabelMetrics.verticalInset
        )
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}
