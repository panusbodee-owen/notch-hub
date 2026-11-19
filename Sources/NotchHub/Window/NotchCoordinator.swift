import AppKit
import Combine
import Foundation
import NotchHubCore
import SwiftUI

@MainActor
final class NotchCoordinator: ObservableObject {
    @Published var displayState: NotchDisplayState = .closed
    @Published var isContentVisible: Bool = false
    @Published var selectedTab: NotchTab = .home
    @Published var isDropTargeted: Bool = false
    @Published var showMirror: Bool = false
    @Published var isPinnedOpen: Bool = false
    @Published var isResizing: Bool = false
    @Published var isEditingHomeGadgets: Bool = false
    @Published var isAddingQuickApp: Bool = false
    @Published var isEditingQuickApps: Bool = false
    @Published var newQuickAppName: String = ""
    @Published var newQuickAppTarget: String = ""
    @Published var newQuickAppKind: QuickAppKind = .url
    @Published var selectedAIFilter: String = "All"
    @Published var lastCopiedID: UUID?
    @Published var lastCopiedCaptureID: UUID?
    @Published var currentTime: Date = Date()

    let settingsStore: SettingsStore
    let shelfStore: FileShelfStore
    let screenshotStore: ScreenshotTrayStore
    let quickAppStore: QuickAppStore
    let clipboardStore: ClipboardStore
    let timerStore: FocusTimerStore
    let activityStore: LiveActivityStore
    let mediaService: MediaService
    let systemService: SystemStatusService
    let clipboardMonitor: ClipboardMonitor
    let screenshotMonitor: ScreenshotMonitor
    let aiDiscovery: AIDiscoveryService

    private var activityServer: LiveActivityServer?
    private var panel: NotchPanel?
    private var statusItem: NSStatusItem?
    private var hoverTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var transitionStageTask: Task<Void, Never>?
    private var focusTickTimer: Timer?
    private var globalPointerMonitor: Any?
    private var localPointerMonitor: Any?
    private var isPointerInsideNotch: Bool = false
    private var cancellables = Set<AnyCancellable>()

    init(inMemoryOnly: Bool = false) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("NotchHub", isDirectory: true)

        let sStore = SettingsStore(storageURL: inMemoryOnly ? nil : appSupport.appendingPathComponent("settings.json"))
        self.settingsStore = sStore
        self.shelfStore = FileShelfStore(storageURL: inMemoryOnly ? nil : appSupport.appendingPathComponent("shelf.json"))
        let capStore = ScreenshotTrayStore(
            storageURL: inMemoryOnly ? nil : appSupport.appendingPathComponent("captures.json"),
            maxItems: sStore.settings.maxScreenshots
        )
        self.screenshotStore = capStore

        let quickAppsFile = appSupport.appendingPathComponent("quick_apps.json")
        let isFirstQuickAppSetup = !inMemoryOnly && !FileManager.default.fileExists(atPath: quickAppsFile.path)
        self.quickAppStore = QuickAppStore(
            storageURL: inMemoryOnly ? nil : quickAppsFile,
            defaultItems: Self.discoverDefaultQuickApps()
        )
        if isFirstQuickAppSetup && !sStore.settings.homeGadgets.contains(.quickApps) {
            sStore.settings.homeGadgets.insert(.quickApps, at: 0)
        }

        self.clipboardStore = ClipboardStore(maxEntries: 18)
        self.timerStore = FocusTimerStore()
        self.activityStore = LiveActivityStore()
        self.mediaService = MediaService()
        self.systemService = SystemStatusService()
        self.clipboardMonitor = ClipboardMonitor(store: clipboardStore)
        self.screenshotMonitor = ScreenshotMonitor(
            store: capStore,
            capturesDir: appSupport.appendingPathComponent("Captures", isDirectory: true)
        )
        self.aiDiscovery = AIDiscoveryService()
    }

    func start() {
        setupWindow()
        setupStatusBarItem()
        setupScreenObserver()
        setupPointerMonitors()

        mediaService.start()
        systemService.start()
        clipboardMonitor.start()
        screenshotMonitor.start()
        aiDiscovery.start()

        focusTickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
                self?.timerStore.tick()
                self?.syncRestingStateIfNotExpanded()
            }
        }

        // Start loopback Live Activity HTTP API
        let port = settingsStore.settings.apiPort
        let server = LiveActivityServer(store: activityStore, port: port) { [weak self] in
            Task { @MainActor in
                self?.syncRestingStateIfNotExpanded()
            }
        }
        server.start()
        self.activityServer = server

        // Observe state changes that affect compact wings
        mediaService.$track
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncRestingStateIfNotExpanded() }
            .store(in: &cancellables)

        activityStore.$activities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncRestingStateIfNotExpanded() }
            .store(in: &cancellables)

        settingsStore.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.syncRestingStateIfNotExpanded()
                self.updatePanelHitTesting(mouseLocation: NSEvent.mouseLocation)
            }
            .store(in: &cancellables)

        syncRestingStateIfNotExpanded()
    }

    func shutdown() {
        mediaService.stop()
        systemService.stop()
        clipboardMonitor.stop()
        screenshotMonitor.stop()
        aiDiscovery.stop()
        activityServer?.stop()
        focusTickTimer?.invalidate()
        hoverTask?.cancel()
        collapseTask?.cancel()
        transitionStageTask?.cancel()
        if let globalPointerMonitor {
            NSEvent.removeMonitor(globalPointerMonitor)
        }
        if let localPointerMonitor {
            NSEvent.removeMonitor(localPointerMonitor)
        }
    }

    func toggleHomeGadget(_ kind: HomeGadgetKind) {
        var list = settingsStore.settings.homeGadgets
        if let idx = list.firstIndex(of: kind) {
            list.remove(at: idx)
        } else {
            if kind.isFullWidth {
                list.insert(kind, at: 0)
            } else {
                list.append(kind)
            }
        }
        settingsStore.settings.homeGadgets = list
    }

    func moveHomeGadget(_ kind: HomeGadgetKind, offset: Int) {
        var list = settingsStore.settings.homeGadgets
        guard let idx = list.firstIndex(of: kind) else { return }
        let target = idx + offset
        guard target >= 0 && target < list.count else { return }
        list.swapAt(idx, target)
        settingsStore.settings.homeGadgets = list
    }

    func triggerQuickCapture() {
        screenshotMonitor.captureInteractiveRegion(
            beforeCapture: { [weak self] in
                guard let self else { return }
                self.isPinnedOpen = false
                self.transition(to: self.shouldShowCompactWings ? .compact : .closed)
            },
            afterCapture: { [weak self] captured in
                guard let self, captured else { return }
                if !self.settingsStore.settings.homeGadgets.contains(.captures) {
                    self.settingsStore.settings.homeGadgets.insert(.captures, at: 0)
                }
                self.openTab(.home)
            }
        )
    }

    func copyScreenshot(_ item: ScreenshotItem) {
        screenshotMonitor.copyImageToPasteboard(item)
        lastCopiedCaptureID = item.id
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            if self?.lastCopiedCaptureID == item.id {
                self?.lastCopiedCaptureID = nil
            }
        }
    }

    var l10n: L10n {
        L10n(settingsStore.settings.language)
    }

    var currentGeometry: NotchGeometry {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let metrics = ScreenMetrics(
            frame: screen?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982),
            topSafeAreaInset: screen?.safeAreaInsets.top ?? 0,
            auxTopLeftWidth: screen?.auxiliaryTopLeftArea?.width,
            auxTopRightWidth: screen?.auxiliaryTopRightArea?.width
        )
        let s = settingsStore.settings
        return NotchGeometry(
            metrics: metrics,
            preferredExpandedWidth: CGFloat(s.expandedWidth),
            preferredExpandedHeight: CGFloat(s.expandedHeight),
            preferredCompactWingExtra: CGFloat(s.compactWingExtraWidth)
        )
    }

    private var resizeStartSize: CGSize?

    func beginResizeIfNeeded() {
        if resizeStartSize == nil {
            isResizing = true
            resizeStartSize = CGSize(
                width: settingsStore.settings.expandedWidth,
                height: settingsStore.settings.expandedHeight
            )
        }
    }

    func updateResize(translation: CGSize) {
        beginResizeIfNeeded()
        guard let start = resizeStartSize else { return }
        let nextW = min(1100.0, max(460.0, Double(start.width) + Double(translation.width) * 2.0))
        let nextH = min(560.0, max(220.0, Double(start.height) + Double(translation.height)))
        settingsStore.settings.expandedWidth = round(nextW)
        settingsStore.settings.expandedHeight = round(nextH)
    }

    func endResize() {
        resizeStartSize = nil
        isResizing = false
        updatePanelHitTesting(mouseLocation: NSEvent.mouseLocation)
    }

    func applySizePreset(width: Double, height: Double) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
            settingsStore.settings.expandedWidth = width
            settingsStore.settings.expandedHeight = height
        }
        updatePanelHitTesting(mouseLocation: NSEvent.mouseLocation)
    }

    var shouldShowCompactWings: Bool {
        guard settingsStore.settings.showCompactWings else { return false }
        let hasMedia = settingsStore.settings.enableMedia && mediaService.track.isPlaying
        let hasTimer = settingsStore.settings.enableTimer && timerStore.isRunning
        let hasAI = settingsStore.settings.enableAIHub && activityStore.primaryActivity != nil
        return hasMedia || hasTimer || hasAI
    }

    func syncRestingStateIfNotExpanded() {
        guard displayState != .expanded else { return }
        let target: NotchDisplayState = shouldShowCompactWings ? .compact : .closed
        if displayState != target {
            transition(to: target)
        }
    }

    var shouldStayExpanded: Bool {
        isPinnedOpen || isDropTargeted || isResizing || isAddingQuickApp || isEditingHomeGadgets || isEditingQuickApps
    }

    func handleHoverChanged(_ hovering: Bool) {
        guard hovering != isPointerInsideNotch else { return }
        isPointerInsideNotch = hovering
        hoverTask?.cancel()
        collapseTask?.cancel()

        if hovering {
            guard settingsStore.settings.hoverExpandEnabled else { return }
            if displayState == .expanded { return }
            let delayNs = UInt64(max(0.05, settingsStore.settings.hoverDelaySeconds) * 1_000_000_000)
            hoverTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: delayNs)
                guard !Task.isCancelled else { return }
                self?.transition(to: .expanded)
            }
        } else {
            guard !shouldStayExpanded else { return }
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 240_000_000)
                guard !Task.isCancelled else { return }
                guard let self, !self.isPointerInsideNotch, !self.shouldStayExpanded else { return }
                self.showMirror = false
                self.transition(to: self.shouldShowCompactWings ? .compact : .closed)
            }
        }
    }

    func toggleExpanded() {
        hoverTask?.cancel()
        collapseTask?.cancel()
        if displayState == .expanded {
            isPinnedOpen = false
            isAddingQuickApp = false
            isEditingHomeGadgets = false
            isEditingQuickApps = false
            showMirror = false
            transition(to: shouldShowCompactWings ? .compact : .closed)
        } else {
            transition(to: .expanded)
        }
    }

    func openTab(_ tab: NotchTab) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            selectedTab = tab
        }
        transition(to: .expanded)
    }

    /// Choreographed 2-stage 120Hz GPU SwiftUI spring transition (ZERO NSWindow.setFrame stutter!).
    func transition(to state: NotchDisplayState) {
        transitionStageTask?.cancel()

        if state == .expanded {
            panel?.ignoresMouseEvents = false
            panel?.orderFrontRegardless()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.78, blendDuration: 0.10)) {
                displayState = .expanded
            }
            transitionStageTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 35_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.22)) {
                        self?.isContentVisible = true
                    }
                }
            }
        } else {
            if displayState == .expanded {
                withAnimation(.easeOut(duration: 0.11)) {
                    isContentVisible = false
                }
                transitionStageTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 55_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let self else { return }
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86, blendDuration: 0.08)) {
                            self.displayState = state
                        }
                        self.updatePanelHitTesting(mouseLocation: NSEvent.mouseLocation)
                    }
                }
            } else {
                isContentVisible = false
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.08)) {
                    displayState = state
                }
                updatePanelHitTesting(mouseLocation: NSEvent.mouseLocation)
            }
        }
    }

    func updatePanelHitTesting(mouseLocation: NSPoint) {
        guard let panel else { return }
        if isResizing || isDropTargeted {
            panel.ignoresMouseEvents = false
            return
        }
        let hitMargin: CGFloat = displayState == .expanded ? 14 : 6
        let activeRect = currentGeometry.activeScreenRect(for: displayState, extraMargin: hitMargin)
        let inside = activeRect.contains(mouseLocation)
        panel.ignoresMouseEvents = !inside
    }

    func injectDemoActivity() {
        activityStore.upsert(
            LiveActivity(
                id: "demo-yt-mcp",
                source: "yt-creative-mcp",
                state: .running,
                title: "Analyzing YouTube Edit",
                detail: "Detecting cuts, 124 BPM & zoom keyframes...",
                progress: 0.68
            )
        )
        activityStore.upsert(
            LiveActivity(
                id: "demo-agent",
                source: "Antigravity",
                state: .waitingApproval,
                title: "Ready to apply FilmCraft plan",
                detail: "18 cuts + 4 zoom punch-ins queued",
                progress: nil
            )
        )
        openTab(.ai)
    }

    func launchApp(named appPath: String) {
        let url = URL(fileURLWithPath: appPath)
        guard FileManager.default.fileExists(atPath: appPath) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func launchQuickApp(_ item: QuickAppItem) {
        switch item.kind {
        case .app:
            let url = URL(fileURLWithPath: item.target)
            if FileManager.default.fileExists(atPath: url.path) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        case .folder:
            let expanded = (item.target as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            NSWorkspace.shared.open(url)
        case .url:
            var raw = item.target.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.contains("://") {
                raw = "http://\(raw)"
            }
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
            }
        case .command:
            let escaped = item.target
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            tell application "Terminal"
                activate
                do script "\(escaped)"
            end tell
            """
            Task.detached(priority: .userInitiated) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                proc.arguments = ["-e", script]
                try? proc.run()
            }
        }
    }

    func isQuickAppRunning(_ item: QuickAppItem) -> Bool {
        guard item.kind == .app else { return false }
        let targetStd = URL(fileURLWithPath: item.target).standardizedFileURL.path
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleURL?.standardizedFileURL.path == targetStd
        }
    }

    func pickQuickAppsWithOpenPanel() {
        isPinnedOpen = true
        let panel = NSOpenPanel()
        panel.title = "Add App or Project Folder to NotchHub"
        panel.prompt = "Add to Notch"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            for url in panel.urls {
                addQuickAppFromURL(url)
            }
        }
        isPinnedOpen = false
        openTab(.home)
    }

    func addQuickAppFromURL(_ url: URL) {
        let path = url.standardizedFileURL.path
        let isApp = url.pathExtension.lowercased() == "app"
        let cleanName = isApp
            ? url.deletingPathExtension().lastPathComponent
            : url.lastPathComponent
        quickAppStore.add(
            QuickAppItem(
                name: cleanName,
                kind: isApp ? .app : .folder,
                target: path
            )
        )
    }

    func addCustomQuickApp() {
        let name = newQuickAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = newQuickAppTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !target.isEmpty else { return }

        quickAppStore.add(
            QuickAppItem(
                name: name,
                kind: newQuickAppKind,
                target: target
            )
        )
        newQuickAppName = ""
        newQuickAppTarget = ""
        isAddingQuickApp = false
    }

    private static func discoverDefaultQuickApps() -> [QuickAppItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates: [(name: String, kind: QuickAppKind, path: String)] = [
            ("Antigravity", .app, "/Applications/Antigravity.app"),
            ("FilmCraft", .app, "/Applications/FilmCraft.app"),
            ("EffectCraft", .app, "/Applications/EffectCraft.app"),
            ("Blender", .app, "\(home)/Applications/Blender.app"),
            ("Blender", .app, "/Applications/Blender.app"),
            ("Claude", .app, "/Applications/Claude.app"),
            ("ChatGPT", .app, "/Applications/ChatGPT.app"),
            ("Salab", .app, "\(home)/Applications/Salab.app"),
            ("AI-Team", .folder, "\(home)/Desktop/AI-Team-Projects")
        ]
        var seen = Set<String>()
        var out: [QuickAppItem] = []
        for c in candidates {
            if !seen.contains(c.name), FileManager.default.fileExists(atPath: c.path) {
                seen.insert(c.name)
                out.append(QuickAppItem(name: c.name, kind: c.kind, target: c.path))
            }
        }
        return out
    }

    private func setupWindow() {
        let canvas = currentGeometry.canvasFrame
        let panel = NotchPanel(contentRect: canvas)
        let rootView = NotchRootView(coordinator: self)
        let hosting = PassthroughHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: canvas.size)
        hosting.autoresizingMask = [.width, .height]
        hosting.shouldAcceptHit = { [weak self] pointInView in
            guard let self, let panel = self.panel else { return false }
            if self.isResizing || self.isDropTargeted { return true }
            let screenPoint = NSPoint(
                x: panel.frame.minX + pointInView.x,
                y: panel.frame.minY + pointInView.y
            )
            let rect = self.currentGeometry.activeScreenRect(
                for: self.displayState,
                extraMargin: self.displayState == .expanded ? 12 : 4
            )
            return rect.contains(screenPoint)
        }
        panel.contentView = hosting
        panel.orderFrontRegardless()
        self.panel = panel
        updatePanelHitTesting(mouseLocation: NSEvent.mouseLocation)
    }

    private func setupScreenObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.panel?.setFrame(self.currentGeometry.canvasFrame, display: true)
                self.updatePanelHitTesting(mouseLocation: NSEvent.mouseLocation)
            }
        }
    }

    private func setupPointerMonitors() {
        globalPointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            Task { @MainActor in
                self?.processPointerEvent(isDragging: event.type == .leftMouseDragged)
            }
        }
        localPointerMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            Task { @MainActor in
                self?.processPointerEvent(isDragging: event.type == .leftMouseDragged)
            }
            return event
        }
    }

    private func processPointerEvent(isDragging: Bool) {
        let loc = NSEvent.mouseLocation
        let geo = currentGeometry

        // Auto-open File Drop Shelf when dragging anything into the top-center hot zone
        if isDragging && settingsStore.settings.enableShelf && geo.activationHotZone.contains(loc) {
            panel?.ignoresMouseEvents = false
            if displayState != .expanded {
                selectedTab = .shelf
                transition(to: .expanded)
            }
            return
        }

        // Hysteresis cushion: wider exit boundary when expanded so edge clicks never collapse accidentally
        let enterRect = geo.activeScreenRect(for: displayState, extraMargin: displayState == .expanded ? 22 : 4)
        let inside = enterRect.contains(loc)
        updatePanelHitTesting(mouseLocation: loc)
        handleHoverChanged(inside)
    }

    private func setupStatusBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = item.button {
            btn.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "NotchHub")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle NotchHub", action: #selector(menuToggleNotch), keyEquivalent: "n").target = self
        menu.addItem(withTitle: "Cap Screen -> Recent 5", action: #selector(menuQuickCap), keyEquivalent: "4").target = self
        menu.addItem(withTitle: "Open File Shelf", action: #selector(menuOpenShelf), keyEquivalent: "s").target = self
        menu.addItem(withTitle: "Open AI & Jobs Hub", action: #selector(menuOpenAI), keyEquivalent: "a").target = self
        menu.addItem(withTitle: "Trigger Demo AI Activity", action: #selector(menuDemoAI), keyEquivalent: "d").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings...", action: #selector(menuOpenSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit NotchHub", action: #selector(menuQuit), keyEquivalent: "q").target = self
        item.menu = menu
        self.statusItem = item
    }

    @objc private func menuToggleNotch() { toggleExpanded() }
    @objc private func menuQuickCap() { triggerQuickCapture() }
    @objc private func menuOpenShelf() { openTab(.shelf) }
    @objc private func menuOpenAI() { openTab(.ai) }
    @objc private func menuDemoAI() { injectDemoActivity() }
    @objc private func menuOpenSettings() { openTab(.settings) }
    @objc private func menuQuit() {
        shutdown()
        NSApp.terminate(nil)
    }
}
