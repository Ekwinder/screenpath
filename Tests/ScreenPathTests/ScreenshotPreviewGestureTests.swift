import AppKit
import Testing
@testable import ScreenPath

@Test func clickOpensDespiteSmallPointerMovement() {
    var gesture = ScreenshotPreviewGesture(start: NSPoint(x: 10, y: 10))
    #expect(gesture.update(at: NSPoint(x: 11, y: 11), released: false, insidePreview: true) == .waiting)
    #expect(gesture.update(at: NSPoint(x: 12, y: 11), released: true, insidePreview: true) == .open)
    #expect(gesture.update(at: NSPoint(x: 12, y: 11), released: true, insidePreview: true) == .cancelled)
}

@Test func dragDoesNotOpenEvenIfReleasedAtStartingPoint() {
    var gesture = ScreenshotPreviewGesture(start: .zero)
    #expect(gesture.update(at: NSPoint(x: 8, y: 0), released: false, insidePreview: true) == .drag)
    #expect(gesture.update(at: .zero, released: true, insidePreview: true) == .cancelled)
}

@Test func releaseOutsidePreviewDoesNotOpen() {
    var gesture = ScreenshotPreviewGesture(start: .zero)
    #expect(gesture.update(at: NSPoint(x: -1, y: 0), released: true, insidePreview: false) == .cancelled)
}

@Test func largeMovementOnReleaseDoesNotAccidentallyOpen() {
    var gesture = ScreenshotPreviewGesture(start: .zero)
    #expect(gesture.update(at: NSPoint(x: 12, y: 0), released: true, insidePreview: true) == .cancelled)
}
