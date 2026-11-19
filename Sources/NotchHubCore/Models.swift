import Foundation

public enum NotchDisplayState: String, Codable, Equatable, Sendable {
    case closed
    case compact
    case expanded
}

public enum NotchTab: String, CaseIterable, Identifiable, Codable, Sendable {
    case home = "Home"
    case shelf = "Shelf"
    case ai = "AI & Jobs"
    case clipboard = "Clips"
    case settings = "Settings"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .home: return "sparkles"
        case .shelf: return "tray.and.arrow.down.fill"
        case .ai: return "cpu.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

public enum ActivityState: String, Codable, Equatable, Sendable {
    case idle
    case thinking
    case running
    case waitingApproval = "waiting_approval"
    case done
    case error

    public var label: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking"
        case .running: return "Running"
        case .waitingApproval: return "Needs Input"
        case .done: return "Done"
        case .error: return "Error"
        }
    }
}

public struct LiveActivity: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var source: String
    public var state: ActivityState
    public var title: String
    public var detail: String
    public var progress: Double?
    public var updatedAt: Date

    public init(
        id: String,
        source: String,
        state: ActivityState,
        title: String,
        detail: String = "",
        progress: Double? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.state = state
        self.title = title
        self.detail = detail
        self.progress = progress.map { min(1.0, max(0.0, $0)) }
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, source, state, title, detail, progress, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? "agent"
        self.state = try c.decodeIfPresent(ActivityState.self, forKey: .state) ?? .running
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Working..."
        self.detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        if let p = try c.decodeIfPresent(Double.self, forKey: .progress) {
            self.progress = min(1.0, max(0.0, p))
        } else {
            self.progress = nil
        }
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

public struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var filePath: String
    public var displayName: String
    public var addedAt: Date

    public init(id: UUID = UUID(), filePath: String, displayName: String? = nil, addedAt: Date = Date()) {
        self.id = id
        self.filePath = filePath
        self.displayName = displayName ?? URL(fileURLWithPath: filePath).lastPathComponent
        self.addedAt = addedAt
    }

    public var url: URL { URL(fileURLWithPath: filePath) }
}

public struct ClipboardEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var content: String
    public var pinned: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), content: String, pinned: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.pinned = pinned
        self.createdAt = createdAt
    }
}

public struct MediaTrackInfo: Equatable, Sendable {
    public var appName: String
    public var title: String
    public var artist: String
    public var isPlaying: Bool

    public init(appName: String = "", title: String = "Nothing Playing", artist: String = "", isPlaying: Bool = false) {
        self.appName = appName
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
    }
}

public struct SystemSnapshot: Equatable, Sendable {
    public var batteryPercent: Int
    public var isCharging: Bool
    public var cpuUsagePercent: Double
    public var memoryUsedGB: Double
    public var memoryTotalGB: Double
    public var volumePercent: Int
    public var isMuted: Bool

    public init(
        batteryPercent: Int = 100,
        isCharging: Bool = false,
        cpuUsagePercent: Double = 0,
        memoryUsedGB: Double = 0,
        memoryTotalGB: Double = 16,
        volumePercent: Int = 50,
        isMuted: Bool = false
    ) {
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.cpuUsagePercent = cpuUsagePercent
        self.memoryUsedGB = memoryUsedGB
        self.memoryTotalGB = memoryTotalGB
        self.volumePercent = volumePercent
        self.isMuted = isMuted
    }
}

public enum HomeGadgetKind: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case captures
    case aiRadar
    case media
    case ai
    case timer
    case system
    case notes
    case clock

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .captures: return "Captures (5)"
        case .aiRadar: return "My AIs"
        case .media: return "Media"
        case .ai: return "AI Jobs"
        case .timer: return "Timer"
        case .system: return "System HUD"
        case .notes: return "Quick Note"
        case .clock: return "Clock"
        }
    }

    public var symbolName: String {
        switch self {
        case .captures: return "camera.viewfinder"
        case .aiRadar: return "brain.head.profile"
        case .media: return "music.note"
        case .ai: return "cpu.fill"
        case .timer: return "timer"
        case .system: return "gauge.medium"
        case .notes: return "note.text"
        case .clock: return "clock.fill"
        }
    }

    public var isFullWidth: Bool {
        self == .captures
    }
}

public enum AICategory: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case desktopApp = "Desktop"
    case cli = "CLI"
    case api = "API"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .desktopApp: return "macwindow"
        case .cli: return "terminal.fill"
        case .api: return "network"
        }
    }
}

public enum AIRunStatus: String, Codable, Equatable, Sendable {
    case running = "Running"
    case online = "Online"
    case configured = "Ready"
    case installed = "Installed"
}

public struct DiscoveredAIItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: AICategory
    public var status: AIRunStatus
    public var subtitle: String
    public var targetPathOrURL: String
    public var launchCommand: String?

    public init(
        id: String,
        name: String,
        category: AICategory,
        status: AIRunStatus,
        subtitle: String,
        targetPathOrURL: String,
        launchCommand: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.status = status
        self.subtitle = subtitle
        self.targetPathOrURL = targetPathOrURL
        self.launchCommand = launchCommand
    }
}

public enum AIShellKeyScanner {
    /// Safely extract ONLY known AI API environment variable NAMES (never values) from shell config text.
    public static func detectKnownAPIKeyNames(in shellText: String, knownKeys: [String]) -> Set<String> {
        var found = Set<String>()
        for rawLine in shellText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            for key in knownKeys {
                if line.hasPrefix("export \(key)=") || line.hasPrefix("\(key)=") {
                    // Check that right-hand side is non-empty
                    if let eq = line.firstIndex(of: "=") {
                        let rhs = line[line.index(after: eq)...]
                            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'\t"))
                        if !rhs.isEmpty {
                            found.insert(key)
                        }
                    }
                }
            }
        }
        return found
    }
}

public struct ScreenshotItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var filePath: String
    public var displayName: String
    public var source: String
    public var isManagedFile: Bool
    public var capturedAt: Date

    public init(
        id: UUID = UUID(),
        filePath: String,
        displayName: String? = nil,
        source: String = "screen",
        isManagedFile: Bool = false,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.filePath = filePath
        self.displayName = displayName ?? URL(fileURLWithPath: filePath).lastPathComponent
        self.source = source
        self.isManagedFile = isManagedFile
        self.capturedAt = capturedAt
    }

    public var url: URL { URL(fileURLWithPath: filePath) }
}

public struct NotchSettings: Codable, Equatable, Sendable {
    public var enableMedia: Bool = true
    public var enableShelf: Bool = true
    public var enableAIHub: Bool = true
    public var enableClipboard: Bool = true
    public var enableTimer: Bool = true
    public var enableSystemHUD: Bool = true
    public var hoverExpandEnabled: Bool = true
    public var hoverDelaySeconds: Double = 0.18
    public var apiPort: UInt16 = 47890
    public var showCompactWings: Bool = true
    public var expandedWidth: Double = 680
    public var expandedHeight: Double = 360
    public var compactWingExtraWidth: Double = 160
    public var homeGadgets: [HomeGadgetKind] = [.captures, .aiRadar, .media, .timer, .system]
    public var maxScreenshots: Int = 5
    public var scratchpadText: String = ""

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enableMedia = try c.decodeIfPresent(Bool.self, forKey: .enableMedia) ?? true
        self.enableShelf = try c.decodeIfPresent(Bool.self, forKey: .enableShelf) ?? true
        self.enableAIHub = try c.decodeIfPresent(Bool.self, forKey: .enableAIHub) ?? true
        self.enableClipboard = try c.decodeIfPresent(Bool.self, forKey: .enableClipboard) ?? true
        self.enableTimer = try c.decodeIfPresent(Bool.self, forKey: .enableTimer) ?? true
        self.enableSystemHUD = try c.decodeIfPresent(Bool.self, forKey: .enableSystemHUD) ?? true
        self.hoverExpandEnabled = try c.decodeIfPresent(Bool.self, forKey: .hoverExpandEnabled) ?? true
        self.hoverDelaySeconds = try c.decodeIfPresent(Double.self, forKey: .hoverDelaySeconds) ?? 0.18
        self.apiPort = try c.decodeIfPresent(UInt16.self, forKey: .apiPort) ?? 47890
        self.showCompactWings = try c.decodeIfPresent(Bool.self, forKey: .showCompactWings) ?? true
        self.expandedWidth = try c.decodeIfPresent(Double.self, forKey: .expandedWidth) ?? 680
        self.expandedHeight = try c.decodeIfPresent(Double.self, forKey: .expandedHeight) ?? 360
        self.compactWingExtraWidth = try c.decodeIfPresent(Double.self, forKey: .compactWingExtraWidth) ?? 160
        self.homeGadgets = try c.decodeIfPresent([HomeGadgetKind].self, forKey: .homeGadgets)
            ?? [.captures, .aiRadar, .media, .timer, .system]
        self.maxScreenshots = try c.decodeIfPresent(Int.self, forKey: .maxScreenshots) ?? 5
        self.scratchpadText = try c.decodeIfPresent(String.self, forKey: .scratchpadText) ?? ""
    }
}
