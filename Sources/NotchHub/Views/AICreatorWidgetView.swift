import NotchHubCore
import SwiftUI

private let aiCardFill = Color(red: 0.085, green: 0.088, blue: 0.102)
private let aiCardBorder = Color.white.opacity(0.10)

struct AICreatorWidgetView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var activities: LiveActivityStore
    @ObservedObject var aiDiscovery: AIDiscoveryService

    init(coordinator: NotchCoordinator) {
        self.coordinator = coordinator
        self.activities = coordinator.activityStore
        self.aiDiscovery = coordinator.aiDiscovery
    }

    private var palette: NotchThemePalette {
        NotchThemePalette.palette(for: coordinator.settingsStore.settings.theme)
    }

    private var creativeApps: [(name: String, path: String, icon: String, accent: Color)] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let blenderPath = FileManager.default.fileExists(atPath: "/Applications/Blender.app")
            ? "/Applications/Blender.app"
            : "\(home)/Applications/Blender.app"
        return [
            ("FilmCraft", "/Applications/FilmCraft.app", "film.fill", .purple),
            ("EffectCraft", "/Applications/EffectCraft.app", "wand.and.stars", .cyan),
            ("Blender", blenderPath, "cube.transparent.fill", .orange)
        ]
    }

    private var filters: [(id: String, label: String, count: Int)] {
        [
            ("All", "All AIs", aiDiscovery.items.count),
            ("Desktop", "Desktop", aiDiscovery.desktopApps.count),
            ("CLI", "CLI", aiDiscovery.cliTools.count),
            ("API", "API", aiDiscovery.apis.count),
            ("Jobs", "Live Jobs", activities.activities.count)
        ]
    }

    private var filteredItems: [DiscoveredAIItem] {
        switch coordinator.selectedAIFilter {
        case "Desktop": return aiDiscovery.desktopApps
        case "CLI": return aiDiscovery.cliTools
        case "API": return aiDiscovery.apis
        default: return aiDiscovery.items
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Top Filter Strip + Rescan + Demo Job
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(filters, id: \.id) { f in
                            let selected = coordinator.selectedAIFilter == f.id
                            Button {
                                coordinator.selectedAIFilter = f.id
                            } label: {
                                HStack(spacing: 5) {
                                    Text(f.label)
                                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                    Text("\(f.count)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.white.opacity(selected ? 0.22 : 0.12), in: Capsule())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    selected ? Color.white.opacity(0.18) : Color.clear,
                                    in: Capsule()
                                )
                                .foregroundStyle(selected ? .white : .white.opacity(0.65))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 4)

                Button {
                    aiDiscovery.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(aiDiscovery.isScanning ? .cyan : .white.opacity(0.75))
                        .padding(6)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Rescan AI Apps, CLIs, and APIs on this Mac")

                Button("Demo Job") {
                    coordinator.injectDemoActivity()
                    coordinator.selectedAIFilter = "All"
                }
                .font(.system(size: 9.5, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.09), in: Capsule())
                .foregroundStyle(.white.opacity(0.8))
                .buttonStyle(.plain)
            }

            // Main Content: Live Jobs OR Discovered AIs + Live Progress Card
            if coordinator.selectedAIFilter == "Jobs" {
                jobsSection
            } else {
                discoveredAISection
            }

            Divider().overlay(Color.white.opacity(0.08))

            // Creative App Quick Launch Bar
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                ForEach(creativeApps, id: \.name) { app in
                    let installed = FileManager.default.fileExists(atPath: app.path)
                    Button {
                        coordinator.launchApp(named: app.path)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: app.icon)
                                .font(.system(size: 10.5))
                                .foregroundStyle(installed ? app.accent : .white.opacity(0.45))
                            Text(app.name)
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(installed ? .white : .white.opacity(0.45))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(aiCardFill, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(installed ? 0.14 : 0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!installed)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var discoveredAISection: some View {
        Group {
            if filteredItems.isEmpty && activities.activities.isEmpty {
                VStack(spacing: 5) {
                    Text(aiDiscovery.isScanning ? "Scanning this Mac for AI tools..." : "No AI tools found in this category")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Click the refresh icon to rescan Desktop Apps, CLI binaries, and local/cloud APIs.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(aiCardFill, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 9),
                            GridItem(.flexible(), spacing: 9)
                        ],
                        spacing: 9
                    ) {
                        ForEach(filteredItems) { item in
                            discoveredRow(item)
                        }
                        if coordinator.selectedAIFilter == "All", let liveJob = activities.primaryActivity {
                            liveProgressTile(liveJob)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func discoveredRow(_ item: DiscoveredAIItem) -> some View {
        let dotColor = statusColor(item.status)
        let isGlowing = item.status == .running || item.status == .online || item.status == .configured
        return Button {
            aiDiscovery.activate(item) { text in
                coordinator.clipboardMonitor.copyToPasteboard(text)
            }
        } label: {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 5) {
                        Text(item.name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("(\(item.status.rawValue))")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }

                    Text(item.subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: isGlowing ? dotColor.opacity(0.95) : .clear, radius: 5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("\(actionLabel(for: item)) \(item.name) — \(item.targetPathOrURL)")
    }

    private func liveProgressTile(_ act: LiveActivity) -> some View {
        let pct = Int((act.progress ?? 0.5) * 100)
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(act.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(palette.accent)
                        .frame(width: max(8, proxy.size.width * CGFloat(act.progress ?? 0.5)))
                        .shadow(color: palette.accent.opacity(0.85), radius: 5)
                }
            }
            .frame(height: 5.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.accent.opacity(0.45), lineWidth: 1))
    }

    private var jobsSection: some View {
        Group {
            if activities.activities.isEmpty {
                VStack(spacing: 5) {
                    Text("No active AI or Render jobs")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("POST http://127.0.0.1:\(coordinator.settingsStore.settings.apiPort)/v1/activity to stream live progress")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.65))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(aiCardFill, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 7) {
                        ForEach(activities.activities) { act in
                            activityRow(act)
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ act: LiveActivity) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(colorForActivity(act.state))
                    .frame(width: 7, height: 7)
                    .shadow(color: colorForActivity(act.state).opacity(0.85), radius: 4)
                Text(act.source)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(colorForActivity(act.state))
                Text(act.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if let p = act.progress {
                    Text("\(Int(p * 100))%")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                } else {
                    Text(act.state.label)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(colorForActivity(act.state))
                }
                Button {
                    activities.remove(id: act.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }

            if !act.detail.isEmpty {
                Text(act.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            if let p = act.progress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Capsule()
                            .fill(colorForActivity(act.state))
                            .frame(width: max(8, proxy.size.width * CGFloat(p)))
                            .shadow(color: colorForActivity(act.state).opacity(0.75), radius: 4)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(aiCardFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(aiCardBorder, lineWidth: 1))
    }

    private func statusColor(_ status: AIRunStatus) -> Color {
        switch status {
        case .running: return Color(red: 0.20, green: 0.92, blue: 0.48)
        case .online: return Color(red: 0.16, green: 0.88, blue: 0.72)
        case .configured: return Color(red: 0.16, green: 0.85, blue: 0.98)
        case .installed: return Color.white.opacity(0.48)
        }
    }

    private func actionLabel(for item: DiscoveredAIItem) -> String {
        switch item.category {
        case .desktopApp: return item.status == .running ? "Focus" : "Open"
        case .cli: return "Run"
        case .api: return item.targetPathOrURL.hasPrefix("http") ? "Open" : "Copy"
        }
    }
}
