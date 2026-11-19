import AppKit
import Foundation
import NotchHubCore

@MainActor
final class ScreenshotMonitor {
    private let store: ScreenshotTrayStore
    private let capturesDir: URL
    private var timer: Timer?
    private var knownFiles = Set<String>()
    private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount
    private var watchDirs: [URL] = []

    init(store: ScreenshotTrayStore, capturesDir: URL) {
        self.store = store
        self.capturesDir = capturesDir
        try? FileManager.default.createDirectory(at: capturesDir, withIntermediateDirectories: true)
    }

    func start() {
        watchDirs = resolveScreenshotDirectories()
        seedInitialSnapshot()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Copy both the image data (for Chat/Docs/Figma/Notion Cmd+V) and the file URL (for Finder/Apps).
    func copyImageToPasteboard(_ item: ScreenshotItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        var objects: [NSPasteboardWriting] = [item.url as NSURL]
        if let image = NSImage(contentsOf: item.url) {
            objects.insert(image, at: 0)
        }
        pb.writeObjects(objects)
        lastPasteboardChangeCount = pb.changeCount
    }

    /// Trigger macOS interactive region screenshot (`screencapture -i`) and store it in the 5-slot tray.
    func captureInteractiveRegion(
        beforeCapture: () -> Void,
        afterCapture: @escaping (Bool) -> Void
    ) {
        beforeCapture()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "Cap_\(formatter.string(from: Date())).png"
        let dest = capturesDir.appendingPathComponent(filename)

        Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            proc.arguments = ["-i", "-x", dest.path]
            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                await MainActor.run { afterCapture(false) }
                return
            }
            let exists = FileManager.default.fileExists(atPath: dest.path)
            await MainActor.run { [weak self] in
                if exists {
                    self?.knownFiles.insert(dest.standardizedFileURL.path)
                    self?.store.add(filePath: dest.path, source: "manual", isManagedFile: true)
                }
                afterCapture(exists)
            }
        }
    }

    private func resolveScreenshotDirectories() -> [URL] {
        var dirs: [URL] = []
        if let customPath = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                dirs.append(url)
            }
        }
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
        if !dirs.contains(desktop), FileManager.default.fileExists(atPath: desktop.path) {
            dirs.append(desktop)
        }
        return dirs
    }

    private func seedInitialSnapshot() {
        let fm = FileManager.default
        var candidates: [(path: String, date: Date)] = []

        for dir in watchDirs {
            guard let urls = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls {
                let path = url.standardizedFileURL.path
                knownFiles.insert(path)
                guard isLikelyScreenshotImage(url) else { continue }
                let vals = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                let dt = vals?.creationDate ?? vals?.contentModificationDate ?? .distantPast
                candidates.append((path, dt))
            }
        }

        // If the tray is empty on launch, pre-populate with up to latest 5 screenshots from Desktop/screenshot dir
        if store.items.isEmpty {
            let recent = candidates.sorted { $0.date > $1.date }.prefix(store.maxItems).reversed()
            for item in recent {
                store.add(filePath: item.path, source: "screen", isManagedFile: false)
            }
        }
        store.pruneMissingFiles()
    }

    private func poll() {
        checkScreenshotFolders()
        checkPasteboardForImage()
    }

    private func checkScreenshotFolders() {
        let fm = FileManager.default
        var newlyAdded: [(path: String, date: Date)] = []

        for dir in watchDirs {
            guard let urls = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.creationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls {
                let path = url.standardizedFileURL.path
                if knownFiles.contains(path) { continue }
                knownFiles.insert(path)
                guard isSupportedImageExtension(url) else { continue }
                let vals = try? url.resourceValues(forKeys: [.creationDateKey])
                newlyAdded.append((path, vals?.creationDate ?? Date()))
            }
        }

        for item in newlyAdded.sorted(by: { $0.date < $1.date }) {
            store.add(filePath: item.path, source: "screen", isManagedFile: false)
        }
    }

    private func checkPasteboardForImage() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = pb.changeCount

        // Ignore when user copied a file URL (e.g. from Finder or from our own shelf/tray)
        if let types = pb.types, types.contains(.fileURL) {
            return
        }

        var pngData = pb.data(forType: .png)
        if pngData == nil, let tiff = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff) {
            pngData = rep.representation(using: .png, properties: [:])
        }
        guard let data = pngData, data.count > 1024 else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let dest = capturesDir.appendingPathComponent("ClipCap_\(formatter.string(from: Date())).png")
        do {
            try data.write(to: dest, options: .atomic)
            knownFiles.insert(dest.standardizedFileURL.path)
            store.add(filePath: dest.path, source: "clipboard", isManagedFile: true)
        } catch {
            // Ignore write errors gracefully
        }
    }

    private func isSupportedImageExtension(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "webp", "heic"].contains(ext)
    }

    private func isLikelyScreenshotImage(_ url: URL) -> Bool {
        guard isSupportedImageExtension(url) else { return false }
        let name = url.lastPathComponent.lowercased()
        return name.contains("screenshot") ||
            name.contains("screen shot") ||
            name.contains("ภาพหน้าจอ") ||
            name.contains("cleanshot") ||
            name.hasPrefix("cap_") ||
            name.hasPrefix("clipcap_")
    }
}
