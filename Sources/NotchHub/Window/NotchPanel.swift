import AppKit
import Foundation
import SwiftUI

/// Custom NSHostingView that rejects hit-testing outside the active visible Notch pill,
/// allowing 100% native click-through across the fixed-canvas transparent NSPanel.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    var shouldAcceptHit: ((NSPoint) -> Bool)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let shouldAcceptHit, !shouldAcceptHit(point) {
            return nil
        }
        return super.hitTest(point)
    }
}

final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
