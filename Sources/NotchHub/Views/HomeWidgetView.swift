import AppKit
import NotchHubCore
import SwiftUI

struct HomeWidgetView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var media: MediaService
    @ObservedObject var system: SystemStatusService
    @ObservedObject var timer: FocusTimerStore
    @ObservedObject var activities: LiveActivityStore
    @ObservedObject var captures: ScreenshotTrayStore
    @ObservedObject var aiDiscovery: AIDiscoveryService

    init(coordinator: NotchCoordinator) {
        self.coordinator = coordinator
        self.settingsStore = coordinator.settingsStore
        self.media = coordinator.mediaService
        self.system = coordinator.systemService
        self.timer = coordinator.timerStore
        self.activities = coordinator.activityStore
        self.captures = coordinator.screenshotStore
        self.aiDiscovery = coordinator.aiDiscovery
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
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.22), in: Capsule())
                    .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .help("Capture screen region directly into your 5-shot tray")

                Text(l10n.capHint)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.45))
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
                    .padding(.vertical, 3)
                    .background(
                        coordinator.isEditingHomeGadgets ? Color.green.opacity(0.28) : Color.white.opacity(0.1),
                        in: Capsule()
                    )
                    .foregroundStyle(coordinator.isEditingHomeGadgets ? .green : .white.opacity(0.88))
                }
                .buttonStyle(.plain)
            }

            // Inline Gadget Picker Bar (Add / Remove Gadgets on Home)
            if coordinator.isEditingHomeGadgets {
                gadgetCustomizerBar
            }

            if coordinator.showMirror {
                mirrorCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 9) {
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
                                Text("Click 'Gadgets' above to add Captures, Media, Timer, Notes, Clock, or HUD.")
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

    // MARK: - 5-Slot Recent Captures Gadget

    private var capturesStripGadget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(l10n.recentCaptures) (\(captures.items.count)/\(captures.maxItems))", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text(l10n.captureDragHint)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.45))
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
        .padding(9)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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
                            .frame(height: 68)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(maxWidth: .infinity)
                            .frame(height: 68)
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
                    .frame(height: 68)

                    HStack(spacing: 3) {
                        Text(isCopied ? l10n.copied : item.displayName)
                            .font(.system(size: 8.5, weight: isCopied ? .bold : .medium))
                            .foregroundStyle(isCopied ? .green : .white.opacity(0.9))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 5)
                    .padding(.bottom, 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(isCopied ? Color.green : Color.white.opacity(0.14), lineWidth: isCopied ? 1.5 : 1)
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
                        .padding(3)
                        .background(Color.black.opacity(0.65), in: Circle())
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
                        .background(Color.black.opacity(0.65), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Remove from tray")
            }
            .padding(3)
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
                    .foregroundStyle(.white.opacity(0.25))
                Text("Cap \(index)")
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .help("Click to capture screenshot into slot \(index)")
    }

    // MARK: - Modular 2-Column Gadgets

    @ViewBuilder
    private func gadgetCard(for kind: HomeGadgetKind) -> some View {
        switch kind {
        case .captures:
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

    private var aiRadarCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(l10n.aiOnThisMac, systemImage: "brain.head.profile")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.purple)
                Spacer()
                Button {
                    coordinator.selectedTab = .ai
                    coordinator.selectedAIFilter = "All"
                } label: {
                    Text("\(aiDiscovery.desktopApps.count) App • \(aiDiscovery.cliTools.count) CLI • \(aiDiscovery.apis.count) API")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(aiDiscovery.items.prefix(6)) { item in
                        Button {
                            aiDiscovery.activate(item) { text in
                                coordinator.clipboardMonitor.copyToPasteboard(text)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill((item.status == .running || item.status == .online) ? Color.green : Color.cyan.opacity(0.7))
                                    .frame(width: 5, height: 5)
                                Text(item.name)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.09), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("\(item.category.rawValue): \(item.subtitle)")
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var mediaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: media.track.isPlaying ? [.green.opacity(0.7), .teal.opacity(0.6)] : [.gray.opacity(0.35), .gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: media.track.isPlaying ? "waveform" : "music.note")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(media.track.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(media.track.artist.isEmpty ? (media.track.appName.isEmpty ? "Spotify / Music" : media.track.appName) : media.track.artist)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                Spacer()
                Button { media.previousTrack() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)

                Button { media.playPause() } label: {
                    Image(systemName: media.track.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button { media.nextTrack() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Text(timer.formattedRemaining)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    timer.toggle()
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .padding(6)
                        .background(Color.orange.opacity(0.85), in: Circle())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Button {
                    timer.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(6)
                        .background(Color.white.opacity(0.1), in: Circle())
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                ForEach([5, 15, 25], id: \.self) { mins in
                    Button("\(mins)m") {
                        timer.setPreset(minutes: mins)
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.09), in: Capsule())
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var aiMiniCard: some View {
        Button {
            coordinator.selectedTab = .ai
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Text("AI & Render Hub")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
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
                        ProgressView(value: prog)
                            .tint(.cyan)
                            .controlSize(.small)
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
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var systemHUDCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("\(system.snapshot.batteryPercent)%", systemImage: system.snapshot.isCharging ? "battery.100.bolt" : "battery.75")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(system.snapshot.isCharging ? .green : .white.opacity(0.85))

                Label(String(format: "CPU %.0f%%", system.snapshot.cpuUsagePercent), systemImage: "gauge.medium")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                Text(String(format: "%.1f/%.0fG", system.snapshot.memoryUsedGB, system.snapshot.memoryTotalGB))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 8) {
                Button {
                    system.toggleMute()
                } label: {
                    Image(systemName: system.snapshot.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(system.snapshot.isMuted ? .red : .white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Slider(
                    value: Binding(
                        get: { Double(system.snapshot.volumePercent) },
                        set: { system.setVolume(Int($0)) }
                    ),
                    in: 0...100
                )
                .controlSize(.mini)
                .tint(.white)

                Text("\(system.snapshot.volumePercent)%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var scratchpadCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("Quick Note", systemImage: "note.text")
                    .font(.system(size: 10.5, weight: .semibold))
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
                .frame(height: 46)
                .padding(4)
                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var clockCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("Clock", systemImage: "clock.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.indigo)
                Spacer()
                Text(formattedDate(coordinator.currentTime))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Text(formattedTime(coordinator.currentTime))
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            HStack(spacing: 10) {
                Text("UTC \(formattedTZ(coordinator.currentTime, id: "UTC"))")
                Text("TYO \(formattedTZ(coordinator.currentTime, id: "Asia/Tokyo"))")
            }
            .font(.system(size: 9.5, design: .monospaced))
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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
