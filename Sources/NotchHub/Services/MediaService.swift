import AppKit
import Foundation
import NotchHubCore

@MainActor
final class MediaService: ObservableObject {
    @Published var track = MediaTrackInfo()
    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let runningBundles = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        let hasSpotify = runningBundles.contains("com.spotify.client")
        let hasMusic = runningBundles.contains("com.apple.Music")

        guard hasSpotify || hasMusic else {
            if track.isPlaying || !track.appName.isEmpty {
                track = MediaTrackInfo()
            }
            return
        }

        Task.detached(priority: .utility) {
            var info: MediaTrackInfo?
            if hasSpotify {
                info = Self.queryPlayer(appName: "Spotify")
            }
            if (info == nil || info?.isPlaying == false), hasMusic {
                if let musicInfo = Self.queryPlayer(appName: "Music") {
                    if musicInfo.isPlaying || info == nil {
                        info = musicInfo
                    }
                }
            }
            let resolved = info ?? MediaTrackInfo()
            await MainActor.run { [weak self] in
                self?.track = resolved
            }
        }
    }

    func playPause() {
        let target = activeTargetApp()
        Task.detached(priority: .userInitiated) {
            Self.runScript("tell application \"\(target)\" to playpause")
            try? await Task.sleep(nanoseconds: 180_000_000)
            await MainActor.run { [weak self] in self?.refresh() }
        }
    }

    func nextTrack() {
        let target = activeTargetApp()
        Task.detached(priority: .userInitiated) {
            Self.runScript("tell application \"\(target)\" to next track")
            try? await Task.sleep(nanoseconds: 180_000_000)
            await MainActor.run { [weak self] in self?.refresh() }
        }
    }

    func previousTrack() {
        let target = activeTargetApp()
        Task.detached(priority: .userInitiated) {
            Self.runScript("tell application \"\(target)\" to previous track")
            try? await Task.sleep(nanoseconds: 180_000_000)
            await MainActor.run { [weak self] in self?.refresh() }
        }
    }

    private func activeTargetApp() -> String {
        if !track.appName.isEmpty { return track.appName }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        if running.contains("com.spotify.client") { return "Spotify" }
        return "Music"
    }

    nonisolated private static func queryPlayer(appName: String) -> MediaTrackInfo? {
        let script = """
        tell application "\(appName)"
            if it is running then
                set st to (player state as string)
                if st is "playing" or st is "paused" then
                    set tName to name of current track
                    set tArtist to artist of current track
                    return st & "|||" & tName & "|||" & tArtist
                end if
            end if
        end tell
        """
        let output = runScript(script).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 3 else { return nil }
        return MediaTrackInfo(
            appName: appName,
            title: parts[1].isEmpty ? "Unknown Track" : parts[1],
            artist: parts[2],
            isPlaying: parts[0].lowercased() == "playing"
        )
    }

    @discardableResult
    nonisolated private static func runScript(_ script: String) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
