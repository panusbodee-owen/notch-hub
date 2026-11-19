import NotchHubCore
import SwiftUI

struct AICreatorWidgetView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var activities: LiveActivityStore
    @ObservedObject var aiDiscovery: AIDiscoveryService

    init(coordinator: NotchCoordinator) {
        self.coordinator = coordinator
        self.activities = coordinator.activityStore
        self.aiDiscovery = coordinator.aiDiscovery
    }

    private let creativeApps: [(name: String, path: String, icon: String, accent: Color)] = [
        ("FilmCraft", "/Applications/FilmCraft.app", "film.fill", .purple),
        ("EffectCraft", "/Applications/EffectCraft.app", "wand.and.stars", .cyan),
        ("Blender", "/Applications/Blender.app", "cube.transparent.fill", .orange)
    ]

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
        VStack(spacing: 8) {
            // Top Filter Strip + Rescan + Demo Job
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(filters, id: \.id) { f in
                            let selected = coordinator.selectedAIFilter == f.id
                            Button {
                                coordinator.selectedAIFilter = f.id
                            } label: {
                                HStack(spacing: 4) {
                                    Text(f.label)
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    Text("\(f.count)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.black.opacity(selected ? 0.25 : 0.35), in: Capsule())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    selected ? Color.cyan.opacity(0.85) : Color.white.opacity(0.08),
                                    in: Capsule()
                                )
                                .foregroundStyle(selected ? .black : .white.opacity(0.85))
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
                        .padding(5)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Rescan AI Apps, CLIs, and APIs on this Mac")

                Button("Demo Job") {
                    coordinator.injectDemoActivity()
                    coordinator.selectedAIFilter = "Jobs"
                }
                .font(.system(size: 9.5, weight: .semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.09), in: Capsule())
                .foregroundStyle(.white.opacity(0.8))
                .buttonStyle(.plain)
            }

            // Main Content: Live Jobs OR Discovered AIs (Desktop / CLI / API)
            if coordinator.selectedAIFilter == "Jobs" {
                jobsSection
            } else {
                discoveredAISection
            }

            // Creative App Quick Launch Bar
            HStack(spacing: 8) {
                Text("Creative Apps:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                ForEach(creativeApps, id: \.name) { app in
                    let installed = FileManager.default.fileExists(atPath: app.path)
                    Button {
                        coordinator.launchApp(named: app.path)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: app.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(installed ? app.accent : .gray)
                            Text(app.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(installed ? .white : .white.opacity(0.35))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(installed ? 0.09 : 0.03), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!installed)
                }

                Spacer()

                Text("API :\(coordinator.settingsStore.settings.apiPort)")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.7))
            }
        }
    }

    private var discoveredAISection: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 5) {
                    Text(aiDiscovery.isScanning ? "Scanning this Mac for AI tools..." : "No AI tools found in this category")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Click the refresh icon to rescan Desktop Apps, CLI binaries, and local/cloud APIs.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 7
                    ) {
                        ForEach(filteredItems) { item in
                            discoveredRow(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func discoveredRow(_ item: DiscoveredAIItem) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(categoryColor(item.category).opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: item.category.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(categoryColor(item.category))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Circle()
                        .fill(statusColor(item.status))
                        .frame(width: 6, height: 6)

                    Text(item.status.rawValue)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(statusColor(item.status))
                }

                Text(item.subtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            Button {
                aiDiscovery.activate(item) { text in
                    coordinator.clipboardMonitor.copyToPasteboard(text)
                }
            } label: {
                Text(actionLabel(for: item))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))
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
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(activities.activities) { act in
                            activityRow(act)
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ act: LiveActivity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(colorForActivity(act.state))
                    .frame(width: 7, height: 7)
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
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                } else {
                    Text(act.state.label)
                        .font(.system(size: 9, weight: .bold))
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
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            if let p = act.progress {
                ProgressView(value: p)
                    .tint(colorForActivity(act.state))
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func categoryColor(_ cat: AICategory) -> Color {
        switch cat {
        case .desktopApp: return .purple
        case .cli: return .green
        case .api: return .cyan
        }
    }

    private func statusColor(_ status: AIRunStatus) -> Color {
        switch status {
        case .running, .online: return .green
        case .configured: return .cyan
        case .installed: return .white.opacity(0.45)
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
