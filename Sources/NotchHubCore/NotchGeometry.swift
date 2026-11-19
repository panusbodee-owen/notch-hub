import CoreGraphics
import Foundation

public struct ScreenMetrics: Equatable, Sendable {
    public var frame: CGRect
    public var topSafeAreaInset: CGFloat
    public var auxTopLeftWidth: CGFloat?
    public var auxTopRightWidth: CGFloat?

    public init(
        frame: CGRect,
        topSafeAreaInset: CGFloat = 0,
        auxTopLeftWidth: CGFloat? = nil,
        auxTopRightWidth: CGFloat? = nil
    ) {
        self.frame = frame
        self.topSafeAreaInset = topSafeAreaInset
        self.auxTopLeftWidth = auxTopLeftWidth
        self.auxTopRightWidth = auxTopRightWidth
    }

    public var hasHardwareNotch: Bool {
        topSafeAreaInset > 0
    }
}

public struct NotchGeometry: Sendable {
    public let metrics: ScreenMetrics
    public let preferredExpandedWidth: CGFloat
    public let preferredExpandedHeight: CGFloat
    public let preferredCompactWingExtra: CGFloat

    public init(
        metrics: ScreenMetrics,
        preferredExpandedWidth: CGFloat = 700,
        preferredExpandedHeight: CGFloat = 440,
        preferredCompactWingExtra: CGFloat = 180
    ) {
        self.metrics = metrics
        self.preferredExpandedWidth = preferredExpandedWidth
        self.preferredExpandedHeight = preferredExpandedHeight
        self.preferredCompactWingExtra = preferredCompactWingExtra
    }

    /// Hardware notch width (computed from auxiliary menu bar areas when present, otherwise standard fallback).
    public var closedWidth: CGFloat {
        if let leftW = metrics.auxTopLeftWidth, let rightW = metrics.auxTopRightWidth {
            let computed = metrics.frame.width - leftW - rightW
            if computed > 100 && computed < 380 {
                return computed + 12
            }
        }
        return metrics.hasHardwareNotch ? 204 : 186
    }

    public var closedHeight: CGFloat {
        if metrics.hasHardwareNotch {
            return max(32, metrics.topSafeAreaInset)
        }
        return 28
    }

    public var compactWidth: CGFloat {
        let extra = min(max(preferredCompactWingExtra, 80), 320)
        return min(closedWidth + extra, metrics.frame.width - 40)
    }

    public var compactHeight: CGFloat {
        max(closedHeight, 34)
    }

    public var expandedWidth: CGFloat {
        let clamped = min(max(preferredExpandedWidth, 460), 1100)
        return min(clamped, metrics.frame.width - 32)
    }

    public var expandedHeight: CGFloat {
        let clamped = min(max(preferredExpandedHeight, 220), 540)
        return min(clamped, metrics.frame.height - 80)
    }

    public func panelSize(for state: NotchDisplayState) -> CGSize {
        switch state {
        case .closed:
            return CGSize(width: closedWidth, height: closedHeight)
        case .compact:
            return CGSize(width: compactWidth, height: compactHeight)
        case .expanded:
            return CGSize(width: expandedWidth, height: expandedHeight)
        }
    }

    /// Top-centered window frame anchored flush to the top of the display (or slight offset on non-notch displays).
    public func panelFrame(for state: NotchDisplayState) -> CGRect {
        let size = panelSize(for: state)
        let x = metrics.frame.minX + (metrics.frame.width - size.width) / 2.0
        let topOffset: CGFloat = metrics.hasHardwareNotch ? 0.0 : 4.0
        let y = metrics.frame.maxY - size.height - topOffset
        return CGRect(x: round(x), y: round(y), width: round(size.width), height: round(size.height))
    }

    /// Fixed transparent canvas frame used by the borderless NSPanel so SwiftUI can
    /// morph the notch silhouette purely on the GPU at 120Hz without NSWindow.setFrame stutter.
    public var canvasFrame: CGRect {
        let maxW = min(1160, metrics.frame.width)
        let maxH = min(620, metrics.frame.height - 40)
        let x = metrics.frame.minX + (metrics.frame.width - maxW) / 2.0
        let y = metrics.frame.maxY - maxH
        return CGRect(x: round(x), y: round(y), width: round(maxW), height: round(maxH))
    }

    /// Top-centered screen rect of the visible notch pill for a given state (plus optional hit-test margin).
    public func activeScreenRect(for state: NotchDisplayState, extraMargin: CGFloat = 0) -> CGRect {
        let base = panelFrame(for: state)
        guard extraMargin > 0 else { return base }
        return CGRect(
            x: base.minX - extraMargin,
            y: base.minY - extraMargin,
            width: base.width + extraMargin * 2,
            height: base.height + extraMargin // keep top anchored cleanly
        )
    }

    /// A forgiving top-center hot zone used to detect drag-to-notch or pointer arrival.
    public var activationHotZone: CGRect {
        let width = max(compactWidth, 280)
        let height = max(closedHeight + 10, 44)
        let x = metrics.frame.minX + (metrics.frame.width - width) / 2.0
        let y = metrics.frame.maxY - height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
