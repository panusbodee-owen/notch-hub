import Foundation
import ServiceManagement

/// Manages macOS Launch at Login cleanly for both notarized and ad-hoc signed builds.
/// Prefers Apple's `SMAppService.mainApp` and automatically falls back to a standard
/// user LaunchAgent plist (`~/Library/LaunchAgents/local.notchhub.app.plist`) if needed.
@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var statusDescription: String = ""

    private let agentLabel = "local.notchhub.app"

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        let smEnabled = SMAppService.mainApp.status == .enabled
        let plistExists = FileManager.default.fileExists(atPath: launchAgentURL.path)
        isEnabled = smEnabled || plistExists
        if smEnabled {
            statusDescription = "Login Item (macOS)"
        } else if plistExists {
            statusDescription = "LaunchAgent (Active)"
        } else {
            statusDescription = "Off"
        }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            enable()
        } else {
            disable()
        }
        refreshStatus()
    }

    private func enable() {
        // 1. Try native SMAppService first (shows directly in System Settings -> Login Items)
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
            if SMAppService.mainApp.status == .enabled {
                // Clean up fallback plist if native registration succeeded
                try? FileManager.default.removeItem(at: launchAgentURL)
                return
            }
        } catch {
            // Fall through to standard LaunchAgent plist for ad-hoc signed builds
        }

        // 2. Reliable user LaunchAgent fallback
        let appBundlePath = resolvedAppPath()
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": ["/usr/bin/open", "-a", appBundlePath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        do {
            try FileManager.default.createDirectory(
                at: launchAgentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: launchAgentURL, options: .atomic)
        } catch {
            // Ignore write error gracefully
        }
    }

    private func disable() {
        try? SMAppService.mainApp.unregister()
        try? FileManager.default.removeItem(at: launchAgentURL)
    }

    private func resolvedAppPath() -> String {
        let appsPath = "/Applications/NotchHub.app"
        if FileManager.default.fileExists(atPath: appsPath) {
            return appsPath
        }
        return Bundle.main.bundlePath
    }
}
