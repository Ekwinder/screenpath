import AppKit

func makeStatusBarIcon() -> NSImage? {
    let imageSize = NSSize(width: 16, height: 16)

    let image = NSImage(size: imageSize, flipped: false) { bounds in
        NSColor.clear.setFill()
        bounds.fill()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let boundary = NSBezierPath(
            roundedRect: NSRect(x: 4.0, y: 3.0, width: 10.0, height: 10.0),
            xRadius: 2.4,
            yRadius: 2.4
        )
        boundary.lineWidth = 1.15
        boundary.lineCapStyle = .round
        boundary.lineJoinStyle = .round
        boundary.stroke()

        let lens = NSBezierPath(ovalIn: NSRect(x: 7.1, y: 6.1, width: 3.8, height: 3.8))
        lens.fill()

        return true
    }

    image.isTemplate = true
    return image
}
