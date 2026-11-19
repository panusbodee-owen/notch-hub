import AppKit
import Foundation
import NotchHubCore

@MainActor
final class ClipboardMonitor {
    private let store: ClipboardStore
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?

    init(store: ClipboardStore) {
        self.store = store
    }

    func start() {
        // Seed initial clipboard text if present
        if let initial = NSPasteboard.general.string(forType: .string) {
            store.record(initial)
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        lastChangeCount = pb.changeCount
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        if let str = pb.string(forType: .string) {
            store.record(str)
        }
    }
}
