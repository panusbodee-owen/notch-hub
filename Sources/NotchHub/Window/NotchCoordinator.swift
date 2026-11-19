import AppKit
import Combine
import Foundation
import NotchHubCore
import SwiftUI

@MainActor
final class NotchCoordinator: ObservableObject {
    @Published var displayState: NotchDisplayState = .closed
    @Published var selectedTab: NotchTab = .home
    @Published var isDropTargeted: Bool = false
    @Published var showMirror: Bool = false
    @Published var isPinnedOpen: Bool = false
    @Published var isResizing: Bool = false
    @Published var isEditingHomeGadgets: Bool = false
    @Published var selectedAIFilter: String = "All"
    @Published var lastCopiedID: UUID?
    @Published var lastCopiedCaptureID: UUID?
    @Published var currentTime: Date = Date()

    let settingsStore: SettingsStore
    let shelfStore: FileShelfStore
    let screenshotStore: ScreenshotTrayStore
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
    private var focusTickTimer: Timer?
    private var dragMonitor: Any?
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
        setupDragMonitor()

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
                self.applyCurrentFrame(animated: !self.isResizing)
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
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
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

    func applyCurrentFrame(animated: Bool = true) {
        guard let panel else { return }
        let targetFrame = currentGeometry.panelFrame(for: displayState)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
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
        // Symmetrical width resize (dragging right edge by dx expands total width by 2*dx)
        let nextW = min(1100.0, max(460.0, Double(start.width) + Double(translation.width) * 2.0))
        let nextH = min(540.0, max(220.0, Double(start.height) + Double(translation.height)))
        settingsStore.settings.expandedWidth = round(nextW)
        settingsStore.settings.expandedHeight = round(nextH)
        applyCurrentFrame(animated: false)
    }

    func endResize() {
        resizeStartSize = nil
        isResizing = false
    }

    func applySizePreset(width: Double, height: Double) {
        settingsStore.settings.expandedWidth = width
        settingsStore.settings.expandedHeight = height
        applyCurrentFrame(animated: true)
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

    func handleHoverChanged(_ hovering: Bool) {
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
            guard !isPinnedOpen && !isDropTargeted && !isResizing else { return }
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard !Task.isCancelled else { return }
                guard let self, !self.isPinnedOpen, !self.isDropTargeted, !self.isResizing else { return }
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
            showMirror = false
            transition(to: shouldShowCompactWings ? .compact : .closed)
        } else {
            transition(to: .expanded)
        }
    }

    func openTab(_ tab: NotchTab) {
        selectedTab = tab
        transition(to: .expanded)
    }

    func transition(to state: NotchDisplayState) {
        let targetFrame = currentGeometry.panelFrame(for: state)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
            displayState = state
        }
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
        panel.orderFrontRegardless()
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

    private func setupWindow() {
        let frame = currentGeometry.panelFrame(for: .closed)
        let panel = NotchPanel(contentRect: frame)
        let rootView = NotchRootView(coordinator: self)
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func setupScreenObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let targetFrame = self.currentGeometry.panelFrame(for: self.displayState)
                self.panel?.setFrame(targetFrame, display: true)
            }
        }
    }

    private func setupDragMonitor() {
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.settingsStore.settings.enableShelf else { return }
                let loc = NSEvent.mouseLocation
                if self.currentGeometry.activationHotZone.contains(loc), self.displayState != .expanded {
                    self.selectedTab = .shelf
                    self.transition(to: .expanded)
                }
            }
        }
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
