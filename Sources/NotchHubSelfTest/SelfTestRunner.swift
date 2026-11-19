import CoreGraphics
import Foundation
import NotchHubCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@MainActor
func runAllTests() throws {
    // 1. Notched display geometry
    let notched = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        topSafeAreaInset: 38,
        auxTopLeftWidth: 650,
        auxTopRightWidth: 650
    )
    let geo = NotchGeometry(metrics: notched)
    check(notched.hasHardwareNotch, "notched screen should detect hardware notch")
    let closed = geo.panelFrame(for: .closed)
    check(closed.maxY == 982, "closed notch frame should sit flush at top")
    check(closed.height == 38, "closed notch height should match safeAreaInset")
    let compact = geo.panelFrame(for: .compact)
    check(compact.width > closed.width, "compact wings must be wider than closed notch")
    let expanded = geo.panelFrame(for: .expanded)
    check(expanded.width == 680 && expanded.height == 360 && expanded.maxY == 982, "expanded frame dimensions mismatch")

    // Custom adjustable dimensions + clamping
    let customGeo = NotchGeometry(
        metrics: notched,
        preferredExpandedWidth: 920,
        preferredExpandedHeight: 420,
        preferredCompactWingExtra: 240
    )
    let customExpanded = customGeo.panelFrame(for: .expanded)
    check(customExpanded.width == 920 && customExpanded.height == 420, "custom adjustable expanded size mismatch")
    check(customGeo.panelFrame(for: .compact).width > compact.width, "custom compact wing extra width mismatch")
    print("[PASS] testNotchGeometryOnNotchedDisplay")

    // 2. Non-notched external display geometry
    let external = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), topSafeAreaInset: 0)
    let extGeo = NotchGeometry(metrics: external)
    check(!external.hasHardwareNotch, "external screen should not detect hardware notch")
    check(extGeo.panelFrame(for: .closed).maxY == 1076, "external screen pill should have 4pt top offset")
    print("[PASS] testNotchGeometryOnExternalNonNotchDisplay")

    // 3. FileShelf deduplication & persistence
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("notchhub_test_\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tmp) }
    let shelf = FileShelfStore(storageURL: tmp)
    shelf.add(filePaths: ["/tmp/clip1.mp4", "/tmp/clip2.mp4", "/tmp/clip1.mp4"])
    check(shelf.items.count == 2, "duplicate files must deduplicate")
    check(shelf.items.first?.displayName == "clip1.mp4", "re-added item should bubble to front")
    let reloaded = FileShelfStore(storageURL: tmp)
    check(reloaded.items.count == 2, "shelf items must persist to disk")
    print("[PASS] testFileShelfDeduplicationAndPersistence")

    // 4. Clipboard pinning & cap
    let clips = ClipboardStore(maxEntries: 3)
    clips.record("first")
    clips.record("second")
    clips.togglePin(id: clips.entries.last!.id)
    clips.record("third")
    clips.record("fourth")
    check(clips.entries.count == 3, "clipboard store must respect maxEntries")
    check(clips.entries.contains(where: { $0.content == "first" && $0.pinned }), "pinned entry must not be evicted")
    print("[PASS] testClipboardPinningAndMaxEntries")

    // 5. LiveActivity priority & FocusTimer countdown
    let acts = LiveActivityStore()
    acts.upsert(LiveActivity(id: "1", source: "FilmCraft", state: .running, title: "Rendering", progress: 0.4))
    acts.upsert(LiveActivity(id: "2", source: "Antigravity", state: .waitingApproval, title: "Approve edit"))
    check(acts.primaryActivity?.id == "2", "waitingApproval should take highest priority")

    let timer = FocusTimerStore()
    timer.setPreset(minutes: 5)
    check(timer.formattedRemaining == "05:00", "preset 5m formatting mismatch")
    timer.toggle()
    timer.tick()
    check(timer.formattedRemaining == "04:59", "tick should decrement 1 second")
    print("[PASS] testLiveActivityPriorityAndFocusTimer")

    // 6. Local HTTP request parsing & JSON decode
    let body = #"{"id":"job1","source":"yt-creative-mcp","state":"running","title":"Analyzing","progress":0.5}"#
    let raw = "POST /v1/activity HTTP/1.1\r\nHost: 127.0.0.1:47890\r\nContent-Type: application/json\r\n\r\n\(body)"
    guard let parsed = LocalHTTPProtocol.parse(rawData: Data(raw.utf8)) else {
        check(false, "HTTP parser returned nil")
        return
    }
    check(parsed.method == "POST" && parsed.path == "/v1/activity", "HTTP method/path mismatch")
    let decoded = try JSONDecoder().decode(LiveActivity.self, from: parsed.body)
    check(decoded.id == "job1" && decoded.progress == 0.5, "LiveActivity JSON decode mismatch")
    print("[PASS] testLocalHTTPProtocolParsing")

    // 7. ScreenshotTrayStore max-5 cap & HomeGadgets persistence
    let capDir = FileManager.default.temporaryDirectory.appendingPathComponent("notchhub_caps_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: capDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: capDir) }
    let capJSON = capDir.appendingPathComponent("captures.json")
    let capStore = ScreenshotTrayStore(storageURL: capJSON, maxItems: 5)
    for i in 1...7 {
        let f = capDir.appendingPathComponent("shot_\(i).png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: f)
        capStore.add(filePath: f.path, source: "screen", isManagedFile: false)
    }
    check(capStore.items.count == 5, "screenshot tray must keep only latest 5 items")
    check(capStore.items.first?.displayName == "shot_7.png", "newest screenshot must be first")
    check(capStore.items.last?.displayName == "shot_3.png", "oldest kept screenshot must be shot_3")

    let reloadedCaps = ScreenshotTrayStore(storageURL: capJSON, maxItems: 5)
    check(reloadedCaps.items.count == 5, "screenshot tray must persist across launches")
    print("[PASS] testScreenshotTrayMax5AndPersistence")

    // 8. AIShellKeyScanner detects key names safely without exposing secret values
    let sampleRC = """
    # comment
    export OPENAI_API_KEY="sk-test-12345"
    export GEMINI_API_KEY=AIzaFakeKey
    # export ANTHROPIC_API_KEY="commented-out"
    export GROQ_API_KEY=""
    """
    let detected = AIShellKeyScanner.detectKnownAPIKeyNames(
        in: sampleRC,
        knownKeys: ["OPENAI_API_KEY", "GEMINI_API_KEY", "ANTHROPIC_API_KEY", "GROQ_API_KEY"]
    )
    check(detected == Set(["OPENAI_API_KEY", "GEMINI_API_KEY"]), "shell key scanner mismatch: \(detected)")
    print("[PASS] testAIShellKeyScanner")

    // 9. Localization (EN / TH / JA)
    check(L10n(.en).tabTitle(.home) == "Home", "EN tab title mismatch")
    check(L10n(.th).tabTitle(.home) == "หน้าหลัก", "TH tab title mismatch")
    check(L10n(.ja).tabTitle(.home) == "ホーム", "JA tab title mismatch")
    print("[PASS] testThreeLanguageLocalization")

    print("\nAll 9 NotchHubCore self-tests passed!")
}

@main
@MainActor
struct SelfTestEntry {
    static func main() {
        do {
            try runAllTests()
        } catch {
            fputs("ERROR: \(error)\n", stderr)
            exit(1)
        }
    }
}
