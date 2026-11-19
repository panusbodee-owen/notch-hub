import AppKit
import NotchHubCore
import SwiftUI
import UniformTypeIdentifiers

struct NotchShellShape: Shape {
    var bottomRadius: CGFloat
    var topRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, topRadius) }
        set {
            bottomRadius = newValue.first
            topRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tr = min(topRadius, rect.height / 2, rect.width / 2)
        let br = min(bottomRadius, rect.height / 2, rect.width / 2)

        path.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - br, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - br),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))
        if tr > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + tr, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }
        path.closeSubpath()
        return path
    }
}

struct NotchRootView: View {
    @ObservedObject var coordinator: NotchCoordinator

    private var hasHardwareNotch: Bool {
        coordinator.currentGeometry.metrics.hasHardwareNotch
    }

    private var bottomRadius: CGFloat {
        switch coordinator.displayState {
        case .closed: return hasHardwareNotch ? 12 : 14
        case .compact: return 16
        case .expanded: return 24
        }
    }

    private var topRadius: CGFloat {
        hasHardwareNotch ? 0 : (coordinator.displayState == .expanded ? 18 : 14)
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShellShape(bottomRadius: bottomRadius, topRadius: topRadius)
                .fill(Color.black)
                .overlay(
                    NotchShellShape(bottomRadius: bottomRadius, topRadius: topRadius)
                        .stroke(
                            coordinator.isDropTargeted
                                ? Color.accentColor.opacity(0.95)
                                : Color.white.opacity(coordinator.displayState == .expanded ? 0.14 : 0.06),
                            lineWidth: coordinator.isDropTargeted ? 2.0 : 1.0
                        )
                )
                .shadow(
                    color: Color.black.opacity(coordinator.displayState == .expanded ? 0.55 : 0.25),
                    radius: coordinator.displayState == .expanded ? 18 : 6,
                    x: 0,
                    y: 4
                )

            Group {
                switch coordinator.displayState {
                case .closed:
                    closedView
                case .compact:
                    compactWingsView
                case .expanded:
                    ZStack(alignment: .bottomTrailing) {
                        expandedView
                        resizeGrip
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            coordinator.handleHoverChanged(hovering)
        }
        .onTapGesture {
            if coordinator.displayState != .expanded {
                coordinator.toggleExpanded()
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $coordinator.isDropTargeted) { providers in
            handleFileDrop(providers)
        }
        .preferredColorScheme(.dark)
    }

    private var closedView: some View {
        HStack(spacing: 6) {
            if !hasHardwareNotch {
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 5, height: 5)
                Text("NotchHub")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compactWingsView: some View {
        HStack {
            // Left Wing: AI Activity or Music indicator
            HStack(spacing: 5) {
                if let primary = coordinator.activityStore.primaryActivity, coordinator.settingsStore.settings.enableAIHub {
                    Circle()
                        .fill(colorForActivity(primary.state))
                        .frame(width: 7, height: 7)
                    Text(primary.source)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                } else if coordinator.mediaService.track.isPlaying, coordinator.settingsStore.settings.enableMedia {
                    Image(systemName: "waveform")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                    Text(coordinator.mediaService.track.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: max(96, CGFloat(coordinator.settingsStore.settings.compactWingExtraWidth) * 0.55), alignment: .leading)
            .padding(.leading, 12)

            Spacer()

            // Right Wing: Progress %, Timer, or Battery
            HStack(spacing: 5) {
                if let primary = coordinator.activityStore.primaryActivity,
                   let progress = primary.progress,
                   coordinator.settingsStore.settings.enableAIHub {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                } else if coordinator.timerStore.isRunning, coordinator.settingsStore.settings.enableTimer {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(coordinator.timerStore.formattedRemaining)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                } else if coordinator.mediaService.track.isPlaying {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: max(88, CGFloat(coordinator.settingsStore.settings.compactWingExtraWidth) * 0.50), alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var expandedView: some View {
        VStack(spacing: 10) {
            // Top Header & Tab Strip
            HStack(spacing: 6) {
                ForEach(visibleTabs) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            coordinator.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.symbolName)
                                .font(.system(size: 10, weight: .semibold))
                            Text(coordinator.l10n.tabTitle(tab))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                            if tab == .shelf && !coordinator.shelfStore.items.isEmpty {
                                Text("\(coordinator.shelfStore.items.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.16), in: Capsule())
                            }
                            if tab == .ai && !coordinator.activityStore.activities.isEmpty {
                                Circle()
                                    .fill(colorForActivity(coordinator.activityStore.primaryActivity?.state ?? .running))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            coordinator.selectedTab == tab
                                ? Color.white.opacity(0.16)
                                : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(coordinator.selectedTab == tab ? .white : .white.opacity(0.62))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Quick Camera Mirror button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        coordinator.showMirror.toggle()
                        if coordinator.showMirror {
                            coordinator.selectedTab = .home
                        }
                    }
                } label: {
                    Image(systemName: coordinator.showMirror ? "camera.fill" : "camera")
                        .font(.system(size: 11))
                        .foregroundStyle(coordinator.showMirror ? .cyan : .white.opacity(0.65))
                        .padding(5)
                        .background(Color.white.opacity(coordinator.showMirror ? 0.18 : 0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Quick Camera Mirror")

                // Pin open toggle
                Button {
                    coordinator.isPinnedOpen.toggle()
                } label: {
                    Image(systemName: coordinator.isPinnedOpen ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundStyle(coordinator.isPinnedOpen ? .yellow : .white.opacity(0.65))
                        .padding(5)
                        .background(Color.white.opacity(coordinator.isPinnedOpen ? 0.18 : 0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Keep Notch Expanded")

                // Close button
                Button {
                    coordinator.toggleExpanded()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(5)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, hasHardwareNotch ? 10 : 12)
            .padding(.horizontal, 14)

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.horizontal, 14)

            // Active Tab Content
            Group {
                switch coordinator.selectedTab {
                case .home:
                    HomeWidgetView(coordinator: coordinator)
                case .shelf:
                    ShelfWidgetView(coordinator: coordinator)
                case .ai:
                    AICreatorWidgetView(coordinator: coordinator)
                case .clipboard:
                    ClipboardWidgetView(coordinator: coordinator)
                case .settings:
                    SettingsWidgetView(coordinator: coordinator)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var resizeGrip: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(coordinator.isResizing ? .cyan : .white.opacity(0.35))
            .padding(7)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        coordinator.updateResize(translation: value.translation)
                    }
                    .onEnded { _ in
                        coordinator.endResize()
                    }
            )
            .help("Drag corner to resize NotchHub")
    }

    private var visibleTabs: [NotchTab] {
        let s = coordinator.settingsStore.settings
        var tabs: [NotchTab] = [.home]
        if s.enableShelf { tabs.append(.shelf) }
        if s.enableAIHub { tabs.append(.ai) }
        if s.enableClipboard { tabs.append(.clipboard) }
        tabs.append(.settings)
        return tabs
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard coordinator.settingsStore.settings.enableShelf else { return false }
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
                    if let path = resolvedURL?.path {
                        Task { @MainActor in
                            coordinator.shelfStore.add(filePaths: [path])
                            coordinator.selectedTab = .shelf
                        }
                    }
                }
            }
        }
        return handled
    }
}

func colorForActivity(_ state: ActivityState) -> Color {
    switch state {
    case .idle: return .gray
    case .thinking: return .purple
    case .running: return .cyan
    case .waitingApproval: return .orange
    case .done: return .green
    case .error: return .red
    }
}
