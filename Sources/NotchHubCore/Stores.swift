import Foundation

@MainActor
public final class FileShelfStore: ObservableObject {
    @Published public private(set) var items: [ShelfItem] = []
    private let storageURL: URL?

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        load()
    }

    public func add(filePaths: [String]) {
        for raw in filePaths {
            let clean = URL(fileURLWithPath: raw).standardizedFileURL.path
            guard !clean.isEmpty else { continue }
            if let existingIdx = items.firstIndex(where: { $0.filePath == clean }) {
                let existing = items.remove(at: existingIdx)
                items.insert(existing, at: 0)
            } else {
                items.insert(ShelfItem(filePath: clean), at: 0)
            }
        }
        if items.count > 30 {
            items = Array(items.prefix(30))
        }
        save()
    }

    public func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func clear() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let url = storageURL, let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) {
            items = decoded
        }
    }

    private func save() {
        guard let url = storageURL else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let encoded = try? JSONEncoder().encode(items) {
            try? encoded.write(to: url, options: .atomic)
        }
    }
}

@MainActor
public final class ClipboardStore: ObservableObject {
    @Published public private(set) var entries: [ClipboardEntry] = []
    public let maxEntries: Int

    public init(maxEntries: Int = 18) {
        self.maxEntries = maxEntries
    }

    public func record(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = entries.firstIndex(where: { $0.content == trimmed }) {
            var existing = entries.remove(at: idx)
            existing.createdAt = Date()
            entries.insert(existing, at: 0)
        } else {
            entries.insert(ClipboardEntry(content: trimmed), at: 0)
        }
        trim()
    }

    public func togglePin(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].pinned.toggle()
        sortPinnedFirst()
    }

    public func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public func clearUnpinned() {
        entries.removeAll { !$0.pinned }
    }

    private func sortPinnedFirst() {
        entries.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func trim() {
        sortPinnedFirst()
        while entries.count > maxEntries {
            if let lastUnpinned = entries.lastIndex(where: { !$0.pinned }) {
                entries.remove(at: lastUnpinned)
            } else {
                entries.removeLast()
            }
        }
    }
}

@MainActor
public final class FocusTimerStore: ObservableObject {
    @Published public var totalSeconds: Int = 25 * 60
    @Published public var remainingSeconds: Int = 25 * 60
    @Published public var isRunning: Bool = false
    @Published public var label: String = "Focus"

    public init() {}

    public func setPreset(minutes: Int, label: String = "Focus") {
        let secs = max(60, minutes * 60)
        self.totalSeconds = secs
        self.remainingSeconds = secs
        self.label = label
        self.isRunning = false
    }

    public func toggle() {
        if remainingSeconds <= 0 {
            remainingSeconds = totalSeconds
        }
        isRunning.toggle()
    }

    public func reset() {
        isRunning = false
        remainingSeconds = totalSeconds
    }

    public func tick() {
        guard isRunning else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }
        if remainingSeconds == 0 {
            isRunning = false
        }
    }

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    public var formattedRemaining: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

@MainActor
public final class LiveActivityStore: ObservableObject {
    @Published public private(set) var activities: [LiveActivity] = []

    public init() {}

    public func upsert(_ activity: LiveActivity) {
        var updated = activity
        updated.updatedAt = Date()
        if let idx = activities.firstIndex(where: { $0.id == updated.id }) {
            activities[idx] = updated
        } else {
            activities.insert(updated, at: 0)
        }
        activities.sort { $0.updatedAt > $1.updatedAt }
    }

    public func remove(id: String) {
        activities.removeAll { $0.id == id }
    }

    public func clearAll() {
        activities.removeAll()
    }

    /// Returns the highest-priority activity to display in Compact Notch Wings.
    public var primaryActivity: LiveActivity? {
        if let waiting = activities.first(where: { $0.state == .waitingApproval }) {
            return waiting
        }
        if let active = activities.first(where: { $0.state == .running || $0.state == .thinking }) {
            return active
        }
        if let err = activities.first(where: { $0.state == .error }) {
            return err
        }
        return activities.first
    }
}

@MainActor
public final class ScreenshotTrayStore: ObservableObject {
    @Published public private(set) var items: [ScreenshotItem] = []
    public var maxItems: Int
    private let storageURL: URL?

    public init(storageURL: URL? = nil, maxItems: Int = 5) {
        self.storageURL = storageURL
        self.maxItems = max(1, maxItems)
        load()
    }

    public func add(filePath: String, source: String = "screen", isManagedFile: Bool = false) {
        let clean = URL(fileURLWithPath: filePath).standardizedFileURL.path
        guard !clean.isEmpty else { return }

        if let existingIdx = items.firstIndex(where: { $0.filePath == clean }) {
            var existing = items.remove(at: existingIdx)
            existing.capturedAt = Date()
            items.insert(existing, at: 0)
        } else {
            items.insert(
                ScreenshotItem(
                    filePath: clean,
                    source: source,
                    isManagedFile: isManagedFile
                ),
                at: 0
            )
        }
        trim()
        save()
    }

    public func remove(id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            let removed = items.remove(at: idx)
            if removed.isManagedFile {
                try? FileManager.default.removeItem(atPath: removed.filePath)
            }
            save()
        }
    }

    public func clear() {
        for item in items where item.isManagedFile {
            try? FileManager.default.removeItem(atPath: item.filePath)
        }
        items.removeAll()
        save()
    }

    public func pruneMissingFiles() {
        let before = items.count
        items.removeAll { !FileManager.default.fileExists(atPath: $0.filePath) }
        if items.count != before {
            save()
        }
    }

    private func trim() {
        while items.count > maxItems {
            let evicted = items.removeLast()
            if evicted.isManagedFile {
                try? FileManager.default.removeItem(atPath: evicted.filePath)
            }
        }
    }

    private func load() {
        guard let url = storageURL, let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([ScreenshotItem].self, from: data) {
            items = decoded.filter { FileManager.default.fileExists(atPath: $0.filePath) }
            trim()
        }
    }

    private func save() {
        guard let url = storageURL else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let encoded = try? JSONEncoder().encode(items) {
            try? encoded.write(to: url, options: .atomic)
        }
    }
}

@MainActor
public final class QuickAppStore: ObservableObject {
    @Published public private(set) var items: [QuickAppItem] = []
    private let storageURL: URL?

    public init(storageURL: URL? = nil, defaultItems: [QuickAppItem] = []) {
        self.storageURL = storageURL
        if !load(), !defaultItems.isEmpty {
            self.items = defaultItems
            save()
        }
    }

    public func add(_ item: QuickAppItem) {
        let trimmedTarget = item.target.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty, !trimmedName.isEmpty else { return }

        if let existingIdx = items.firstIndex(where: { $0.target == trimmedTarget && $0.kind == item.kind }) {
            items[existingIdx].name = trimmedName
        } else {
            items.append(
                QuickAppItem(
                    id: item.id,
                    name: trimmedName,
                    kind: item.kind,
                    target: trimmedTarget,
                    iconSymbol: item.iconSymbol
                )
            )
        }
        save()
    }

    public func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func move(id: UUID, offset: Int) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let target = idx + offset
        guard target >= 0 && target < items.count else { return }
        items.swapAt(idx, target)
        save()
    }

    public func replaceAll(_ newItems: [QuickAppItem]) {
        items = newItems
        save()
    }

    @discardableResult
    private func load() -> Bool {
        guard let url = storageURL, let data = try? Data(contentsOf: url) else { return false }
        if let decoded = try? JSONDecoder().decode([QuickAppItem].self, from: data) {
            items = decoded
            return true
        }
        return false
    }

    private func save() {
        guard let url = storageURL else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let encoded = try? JSONEncoder().encode(items) {
            try? encoded.write(to: url, options: .atomic)
        }
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    @Published public var settings: NotchSettings {
        didSet { save() }
    }
    private let storageURL: URL?

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        if let url = storageURL,
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(NotchSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = NotchSettings()
        }
    }

    private func save() {
        guard let url = storageURL else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let encoded = try? JSONEncoder().encode(settings) {
            try? encoded.write(to: url, options: .atomic)
        }
    }
}
