import AppKit
import NotchHubCore
import SwiftUI
import UniformTypeIdentifiers

private let gadgetCardFill = Color(red: 0.085, green: 0.088, blue: 0.102)
private let gadgetCardBorder = Color.white.opacity(0.095)

private struct CircularGaugeRing: View {
    let progress: Double
    let tint: Color
    let iconName: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 3.2)
            Circle()
                .trim(from: 0, to: CGFloat(min(1.0, max(0.02, progress))))
                .stroke(tint, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let iconName {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(width: 28, height: 28)
    }
}

private struct AudioWaveformBars: View {
    let isPlaying: Bool
    let phase: Int

    private let baseHeights: [CGFloat] = [
        0.25, 0.45, 0.35, 0.72, 0.90, 0.55, 0.40, 0.85, 1.0, 0.68,
        0.52, 0.92, 0.78, 0.44, 0.62, 0.84, 0.48, 0.36, 0.54, 0.28, 0.20
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<baseHeights.count, id: \.self) { idx in
                let raw = baseHeights[(idx + (isPlaying ? phase : 0)) % baseHeights.count]
                let factor: CGFloat = isPlaying ? raw : max(0.18, raw * 0.42)
                let isHighlight = isPlaying && idx >= 2 && idx <= 15
                Capsule()
                    .fill(
                        isHighlight
                            ? LinearGradient(
                                colors: [Color(red: 0.28, green: 0.95, blue: 0.55), Color(red: 0.12, green: 0.78, blue: 0.45)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.28), Color.white.opacity(0.18)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .frame(width: 2.8, height: max(4, 22 * factor))
                    .shadow(color: isHighlight ? Color.green.opacity(0.45) : .clear, radius: 3)
            }
        }
        .frame(height: 22)
    }
}

struct HomeWidgetView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var media: MediaService
    @ObservedObject var system: SystemStatusService
    @ObservedObject var timer: FocusTimerStore
    @ObservedObject var activities: LiveActivityStore
    @ObservedObject var captures: ScreenshotTrayStore
    @ObservedObject var aiDiscovery: AIDiscoveryService
    @ObservedObject var quickApps: QuickAppStore

    init(coordinator: NotchCoordinator) {
        self.coordinator = coordinator
        self.settingsStore = coordinator.settingsStore
        self.media = coordinator.mediaService
        self.system = coordinator.systemService
        self.timer = coordinator.timerStore
        self.activities = coordinator.activityStore
        self.captures = coordinator.screenshotStore
        self.aiDiscovery = coordinator.aiDiscovery
        self.quickApps = coordinator.quickAppStore
    }

    private var l10n: L10n {
        L10n(settingsStore.settings.language)
    }

    private var activeGadgets: [HomeGadgetKind] {
        settingsStore.settings.homeGadgets
    }

    private var gridGadgets: [HomeGadgetKind] {
        activeGadgets.filter { !$0.isFullWidth }
    }

    private var wavePhase: Int {
        Int(coordinator.currentTime.timeIntervalSinceReferenceDate) % 21
    }

    var body: some View {
        VStack(spacing: 8) {
            // Compact Home Toolbar: Quick Cap + Customize Gadgets
            HStack(spacing: 8) {
                Button {
                    coordinator.triggerQuickCapture()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 10, weight: .bold))
                        Text(l10n.capScreen)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.cyan.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 0.8))
                    .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .help("Capture screen region directly into your 5-shot tray")

                Text(l10n.capHint)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        coordinator.isEditingHomeGadgets.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: coordinator.isEditingHomeGadgets ? "checkmark" : "plus.square.on.square")
                            .font(.system(size: 10, weight: .bold))
                        Text(coordinator.isEditingHomeGadgets ? l10n.done : l10n.gadgets)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        coordinator.isEditingHomeGadgets ? Color.green.opacity(0.24) : Color.white.opacity(0.09),
                        in: Capsule()
                    )
                    .foregroundStyle(coordinator.isEditingHomeGadgets ? .green : .white.opacity(0.88))
                }
                .buttonStyle(.plain)
            }

            // Inline Gadget Picker Bar
            if coordinator.isEditingHomeGadgets {
                gadgetCustomizerBar
            }

            if coordinator.showMirror {
                mirrorCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        if activeGadgets.contains(.quickApps) {
                            quickAppsStripGadget
                        }
                        if activeGadgets.contains(.captures) {
                            capturesStripGadget
                        }

                        if !gridGadgets.isEmpty {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ],
                                spacing: 10
                            ) {
                                ForEach(gridGadgets) { gadget in
                                    gadgetCard(for: gadget)
                                }
                            }
                        }

                        if activeGadgets.isEmpty {
                            VStack(spacing: 6) {
                                Text("No gadgets on Home")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.65))
                                Text("Click 'Gadgets' above to add Captures, My AIs, Media, Timer, Notes, Clock, or HUD.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Gadget Picker & Reorder Strip

    private var gadgetCustomizerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HomeGadgetKind.allCases) { kind in
                    let isOn = activeGadgets.contains(kind)
                    HStack(spacing: 4) {
                        Button {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                                coordinator.toggleHomeGadget(kind)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(isOn ? .cyan : .white.opacity(0.5))
                                Text(l10n.gadgetName(kind))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(isOn ? .white : .white.opacity(0.6))
                            }
                        }
                        .buttonStyle(.plain)

                        if isOn && !kind.isFullWidth {
                            Button {
                                coordinator.moveHomeGadget(kind, offset: -1)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)

                            Button {
                                coordinator.moveHomeGadget(kind, offset: 1)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        isOn ? Color.cyan.opacity(0.16) : Color.white.opacity(0.06),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(isOn ? Color.cyan.opacity(0.45) : Color.clear, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Quick Apps Dock & Add App Gadget

    private var quickAppsStripGadget: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Label(l10n.quickAppsTitle, systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()

                if !quickApps.items.isEmpty {
                    Button(coordinator.isEditingQuickApps ? l10n.done : "Edit") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            coordinator.isEditingQuickApps.toggle()
                        }
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(coordinator.isEditingQuickApps ? .green : .white.opacity(0.55))
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        coordinator.isAddingQuickApp.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: coordinator.isAddingQuickApp ? "xmark" : "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text(l10n.addApp)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.24), in: Capsule())
                    .overlay(Capsule().stroke(Color.purple.opacity(0.55), lineWidth: 0.8))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            // Inline Add App / Project / URL / Command panel
            if coordinator.isAddingQuickApp {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Button {
                            coordinator.pickQuickAppsWithOpenPanel()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 10))
                                Text(l10n.pickFromMac)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(Color.cyan.opacity(0.22), in: Capsule())
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.55), lineWidth: 0.8))
                            .foregroundStyle(.cyan)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        ForEach([QuickAppKind.url, QuickAppKind.command, QuickAppKind.folder], id: \.id) { kind in
                            let selected = coordinator.newQuickAppKind == kind
                            Button(kind.rawValue.uppercased()) {
                                coordinator.newQuickAppKind = kind
                            }
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(selected ? Color.white.opacity(0.22) : Color.white.opacity(0.06), in: Capsule())
                            .foregroundStyle(selected ? .white : .white.opacity(0.55))
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 6) {
                        TextField("Name (e.g. AI Power Ranger)", text: $coordinator.newQuickAppName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                            .frame(maxWidth: 185)

                        TextField(
                            coordinator.newQuickAppKind == .url
                                ? "http://localhost:3000"
                                : (coordinator.newQuickAppKind == .command ? "cd ~/project && npm run dev" : "~/Desktop/MyProject"),
                            text: $coordinator.newQuickAppTarget
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 0.8))

                        Button(l10n.addCustomAction) {
                            coordinator.addCustomQuickApp()
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }

            // Horizontal Dock of Quick Apps
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickApps.items) { item in
                        quickAppTile(item)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(11)
        .background(gadgetCardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gadgetCardBorder, lineWidth: 1))
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleQuickAppDrop(providers)
        }
    }

    private func quickAppTile(_ item: QuickAppItem) -> some View {
        let running = coordinator.isQuickAppRunning(item)
        return ZStack(alignment: .topTrailing) {
            Button {
                coordinator.launchQuickApp(item)
            } label: {
                VStack(spacing: 4) {
                    ZStack(alignment: .bottomTrailing) {
                        if item.kind == .app || item.kind == .folder {
                            let expanded = (item.target as NSString).expandingTildeInPath
                            Image(nsImage: NSWorkspace.shared.icon(forFile: expanded))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: item.kind == .url
                                                ? [Color.cyan.opacity(0.45), Color.blue.opacity(0.35)]
                                                : [Color.purple.opacity(0.50), Color.indigo.opacity(0.38)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 30, height: 30)
                                Image(systemName: item.iconSymbol ?? item.kind.symbolName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }

                        if running {
                            Circle()
                                .fill(Color(red: 0.22, green: 0.94, blue: 0.54))
                                .frame(width: 6.5, height: 6.5)
                                .shadow(color: .green.opacity(0.9), radius: 3)
                        }
                    }

                    Text(item.name)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(width: 68, height: 54)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(running ? Color.green.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 0.9)
                )
            }
            .buttonStyle(.plain)
            .help("\(item.name) — \(item.target)")

            if coordinator.isEditingQuickApps {
                HStack(spacing: 1) {
                    Button {
                        quickApps.move(id: item.id, offset: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Color.black.opacity(0.75), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        quickApps.remove(id: item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Color.red.opacity(0.85), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(2)
            }
        }
    }

    private func handleQuickAppDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var resolvedURL: URL?
                    if let data = item as? Data {
                        resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let url = item as? URL {
                        resolvedURL = url
                    }
                    if let url = resolvedURL {
                        Task { @MainActor in
                            coordinator.addQuickAppFromURL(url)
                        }
                    }
                }
            }
        }
        return handled
    }

    // MARK: - 5-Slot Recent Captures Gadget

    private var capturesStripGadget: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(l10n.recentCaptures)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                Text("(\(captures.items.count)/\(captures.maxItems))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                Text("•  \(l10n.captureDragHint)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)

                Spacer()

                if !captures.items.isEmpty {
                    Button(l10n.clear) {
                        captures.clear()
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.8))
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<captures.maxItems, id: \.self) { slotIdx in
                    if slotIdx < captures.items.count {
                        captureThumbnailCard(captures.items[slotIdx])
                    } else {
                        emptyCaptureSlot(index: slotIdx + 1)
                    }
                }
            }
        }
        .padding(11)
        .background(gadgetCardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gadgetCardBorder, lineWidth: 1))
    }

    private func captureThumbnailCard(_ item: ScreenshotItem) -> some View {
        let isCopied = coordinator.lastCopiedCaptureID == item.id
        return ZStack(alignment: .topTrailing) {
            Button {
                coordinator.copyScreenshot(item)
            } label: {
                ZStack(alignment: .bottomLeading) {
                    if let nsImg = NSImage(contentsOfFile: item.filePath) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 66)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(maxWidth: .infinity)
                            .frame(height: 66)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.white.opacity(0.4))
                            )
                    }

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 66)

                    HStack(spacing: 3) {
                        Text(isCopied ? l10n.copied : item.displayName)
                            .font(.system(size: 8.5, weight: isCopied ? .bold : .medium))
                            .foregroundStyle(isCopied ? .green : .white.opacity(0.9))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCopied ? Color.green : Color.white.opacity(0.16), lineWidth: isCopied ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)
            .help("Click to copy image • Drag out to drop into any app/file")

            HStack(spacing: 2) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.white)
                        .padding(3.5)
                        .background(Color.black.opacity(0.68), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Button {
                    captures.remove(id: item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3.5)
                        .background(Color.black.opacity(0.68), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Remove from tray")
            }
            .padding(4)
        }
        .frame(maxWidth: .infinity)
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }

    private func emptyCaptureSlot(index: Int) -> some View {
        Button {
            coordinator.triggerQuickCapture()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.24))
                Text("Cap \(index)")
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.11), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .help("Click to capture screenshot into slot \(index)")
    }

    // MARK: - Modular 2-Column Gadgets

    @ViewBuilder
    private func gadgetCard(for kind: HomeGadgetKind) -> some View {
        switch kind {
        case .captures, .quickApps:
            EmptyView()
        case .aiRadar:
            aiRadarCard
        case .media:
            mediaCard
        case .ai:
            aiMiniCard
        case .timer:
            timerCard
        case .system:
            systemHUDCard
        case .notes:
            scratchpadCard
        case .clock:
            clockCard
        }
    }

    /// 2x2 Glowing AI Pill Grid (matching the clean neon-border aesthetic)
    private var aiRadarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l10n.aiOnThisMac)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Spacer()
                Button {
                    coordinator.selectedTab = .ai
                    coordinator.selectedAIFilter = "All"
                } label: {
                    Text("\(aiDiscovery.desktopApps.count)A • \(aiDiscovery.cliTools.count)C • \(aiDiscovery.apis.count)P")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.9))
                }
                .buttonStyle(.plain)
            }

            let topAIs = Array(aiDiscovery.items.prefix(4))
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 7),
                    GridItem(.flexible(), spacing: 7)
                ],
                spacing: 7
            ) {
                ForEach(topAIs) { item in
                    let isLive = item.status == .running || item.status == .online
                    let accent: Color = isLive ? Color(red: 0.25, green: 0.92, blue: 0.56) : Color(red: 0.18, green: 0.85, blue: 0.96)
                    Button {
                        aiDiscovery.activate(item) { text in
                            coordinator.clipboardMonitor.copyToPasteboard(text)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(item.name)
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.94))
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Circle()
                                .fill(accent)
                                .frame(width: 6, height: 6)
                                .shadow(color: accent.opacity(0.9), radius: 3)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(accent.opacity(0.11), in: Capsule())
                        .overlay(Capsule().stroke(accent.opacity(0.65), lineWidth: 1.1))
                        .shadow(color: accent.opacity(0.22), radius: 5)
                    }
                    .buttonStyle(.plain)
                    .help("\(item.category.rawValue): \(item.subtitle)")
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(gadgetCardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gadgetCardBorder, lineWidth: 1))
    }

    /// Now Playing with Animated Green Waveform
    private var mediaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Now Playing")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Spacer()
                HStack(spacing: 10) {
                    Button { media.previousTrack() } label: {
                        Image(systemName: "backward.fill").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    Button { media.playPause() } label: {
                        Image(systemName: media.track.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    Button { media.nextTrack() } label: {
                        Image(systemName: "forward.fill").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white.opacity(0.78))
            }

            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: media.track.isPlaying
                                    ? [Color(red: 0.14, green: 0.65, blue: 0.50), Color(red: 0.08, green: 0.30, blue: 0.36)]
                                    : [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: media.track.isPlaying ? "music.note" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(media.track.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(media.track.artist.isEmpty ? (media.track.appName.isEmpty ? "Spotify / Apple Music" : media.track.appName) : media.track.artist)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer()
            }

            AudioWaveformBars(isPlaying: media.track.isPlaying, phase: wavePhase)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(gadgetCardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gadgetCardBorder, lineWidth: 1))
    }

    /// Big Crisp Focus Timer + Vibrant Orange Play Circle
    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Focus Timer")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Spacer()
                HStack(spacing: 4) {
                    ForEach([5, 15, 25], id: \.self) { mins in
                        Button("\(mins)m") {
                            timer.setPreset(minutes: mins)
                        }
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.09), in: Capsule())
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.78))
                    }
                    Button {
                        timer.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(4)
                            .background(Color.white.opacity(0.08), in: Circle())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .center) {
                Text(timer.formattedRemaining)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button {
                    timer.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.96, green: 0.42, blue: 0.14))
                            .frame(width: 38, height: 38)
                            .shadow(color: Color.orange.opacity(0.45), radius: 8)
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: timer.isRunning ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(gadgetCardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gadgetCardBorder, lineWidth: 1))
    }

    /// System HUD with Circular Battery & CPU Gauge Rings + Capsule Volume Bar
    private var systemHUDCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("System HUD")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Spacer()
                Text(String(format: "%.1f / %.0f GB", system.snapshot.memoryUsedGB, system.snapshot.memoryTotalGB))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))
            }

            HStack(spacing: 14) {
                HStack(spacing: 8) {
                    CircularGaugeRing(
                        progress: Double(system.snapshot.batteryPercent) / 100.0,
                        tint: system.snapshot.isCharging ? Color(red: 0.25, green: 0.92, blue: 0.56) : .white.opacity(0.88),
                        iconName: system.snapshot.isCharging ? "bolt.fill" : "battery.75"
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Battery")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.55))
                        Text("\(system.snapshot.batteryPercent)%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 8) {
                    CircularGaugeRing(
                        progress: system.snapshot.cpuUsagePercent / 100.0,
                        tint: Color.cyan.opacity(0.9),
                        iconName: nil
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("CPU")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(String(format: "%.0f%%", system.snapshot.cpuUsagePercent))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(system.snapshot.volumePercent) },
                        set: { system.setVolume(Int($0)) }
                    ),
                    in: 0...100
                )
                .controlSize(.mini)
                .tint(.white)

                Button {
                    system.toggleMute()
                } label: {
                    Image(systemName: system.snapshot.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(system.snapshot.isMuted ? .red : .white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(gadgetCardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gadgetCardBorder, lineWidth: 1))
    }

    private var aiMiniCard: some View {
        Button {
            coordinator.selectedTab = .ai
            coordinator.selectedAIFilter = "Jobs"
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Text("AI & Render Jobs")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                    Spacer()
                    if let primary = activities.primaryActivity {
                        Text(primary.state.label)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorForActivity(primary.state).opacity(0.25), in: Capsule())
                            .foregroundStyle(colorForActivity(primary.state))
                    } else {
                        Text("API :\(settingsStore.settings.apiPort)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

                if let primary = activities.primaryActivity {
                    Text(primary.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let prog = primary.progress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.14))
                                Capsule()
                                    .fill(Color.cyan)
                                    .frame(width: max(6, proxy.size.width * CGFloat(prog)))
                                    .shadow(color: .cyan.opacity(0.7), radius: 4)
                            }
                        }
                        .frame(height: 5)
                    } else if !primary.detail.isEmpty {
                        Text(primary.detail)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                } else {
                    Text("Ready for Antigravity, MCP & Render jobs")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
            .background(gadgetCardFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(gadgetCardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var scratchpadCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(l10n.quickNote, systemImage: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.yellow.opacity(0.9))
                Spacer()
                if !settingsStore.settings.scratchpadText.isEmpty {
                    Button("Copy") {
                        coordinator.clipboardMonitor.copyToPasteboard(settingsStore.settings.scratchpadText)
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .buttonStyle(.plain)
                }
            }
            TextEditor(text: $settingsStore.settings.scratchpadText)
                .font(.system(size: 10.5))
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white.opacity(0.9))
                .frame(height: 58)
                .padding(4)
                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(gadgetCardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gadgetCardBorder, lineWidth: 1))
    }

    private var clockCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(l10n.clockTitle, systemImage: "clock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.indigo)
                Spacer()
                Text(formattedDate(coordinator.currentTime))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Text(formattedTime(coordinator.currentTime))
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            HStack(spacing: 10) {
                Text("UTC \(formattedTZ(coordinator.currentTime, id: "UTC"))")
                Text("TYO \(formattedTZ(coordinator.currentTime, id: "Asia/Tokyo"))")
            }
            .font(.system(size: 9.5, design: .monospaced))
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(gadgetCardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gadgetCardBorder, lineWidth: 1))
    }

    private var mirrorCard: some View {
        ZStack(alignment: .topTrailing) {
            CameraMirrorPreview()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button {
                coordinator.showMirror = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
        )
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }

    private func formattedTZ(_ date: Date, id: String) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: id)
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
