import AppKit
import NotchHubCore
import SwiftUI
import UniformTypeIdentifiers

/// Subtle tactile spring feedback on buttons inside NotchHub.
struct NotchSpringButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

/// Authentic macOS Dynamic Notch silhouette with animatable concave top ears and rounded bottom corners.
struct NotchShellShape: Shape {
    var bottomRadius: CGFloat
    var topRadius: CGFloat
    var earRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(bottomRadius, AnimatablePair(topRadius, earRadius)) }
        set {
            bottomRadius = newValue.first
            topRadius = newValue.second.first
            earRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let ear = min(earRadius, rect.width / 8, rect.height / 2)
        let br = min(bottomRadius, (rect.width - ear * 2) / 2, rect.height / 2)

        if ear > 0.5 {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - ear, y: rect.minY + ear),
                control: CGPoint(x: rect.maxX - ear, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - ear, y: rect.maxY - br))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - ear - br, y: rect.maxY),
                control: CGPoint(x: rect.maxX - ear, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + ear + br, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + ear, y: rect.maxY - br),
                control: CGPoint(x: rect.minX + ear, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + ear, y: rect.minY + ear))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.minY),
                control: CGPoint(x: rect.minX + ear, y: rect.minY)
            )
            path.closeSubpath()
            return path
        }

        let tr = min(topRadius, rect.height / 2, rect.width / 2)
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
    @ObservedObject var settingsStore: SettingsStore
    var forceConcaveEars: Bool? = nil
    var isShowcaseMode: Bool = false

    init(
        coordinator: NotchCoordinator,
        forceConcaveEars: Bool? = nil,
        isShowcaseMode: Bool = false
    ) {
        self.coordinator = coordinator
        self.settingsStore = coordinator.settingsStore
        self.forceConcaveEars = forceConcaveEars
        self.isShowcaseMode = isShowcaseMode
    }

    private var hasHardwareNotch: Bool {
        forceConcaveEars ?? coordinator.currentGeometry.metrics.hasHardwareNotch
    }

    private var earRadius: CGFloat {
        guard hasHardwareNotch else { return 0 }
        switch coordinator.displayState {
        case .closed: return 8
        case .compact: return 11
        case .expanded: return 15
        }
    }

    private var bottomRadius: CGFloat {
        switch coordinator.displayState {
        case .closed: return hasHardwareNotch ? 12 : 14
        case .compact: return 16
        case .expanded: return 26
        }
    }

    private var topRadius: CGFloat {
        hasHardwareNotch ? 0 : (coordinator.displayState == .expanded ? 20 : 14)
    }

    private var shellShape: NotchShellShape {
        NotchShellShape(bottomRadius: bottomRadius, topRadius: topRadius, earRadius: earRadius)
    }

    private var pillSize: CGSize {
        coordinator.currentGeometry.panelSize(for: coordinator.displayState)
    }

    private var effectiveContentVisible: Bool {
        isShowcaseMode ? (coordinator.displayState == .expanded) : coordinator.isContentVisible
    }

    var body: some View {
        if isShowcaseMode {
            notchPillBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.dark)
        } else {
            ZStack(alignment: .top) {
                Color.clear
                notchPillBody
                    .frame(width: pillSize.width, height: pillSize.height)
                    .padding(.top, hasHardwareNotch ? 0 : 4)
                    .animation(
                        coordinator.isResizing
                            ? nil
                            : .spring(response: 0.36, dampingFraction: 0.80, blendDuration: 0.10),
                        value: pillSize
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .preferredColorScheme(.dark)
        }
    }

    private var palette: NotchThemePalette {
        NotchThemePalette.palette(for: settingsStore.settings.theme)
    }

    private var notchPillBody: some View {
        ZStack(alignment: .top) {
            shellShape
                .fill(palette.shellFill)
                .overlay(
                    shellShape
                        .stroke(
                            coordinator.isDropTargeted
                                ? palette.accent.opacity(0.95)
                                : (coordinator.displayState == .expanded ? palette.shellGlowBorder : Color.white.opacity(0.08)),
                            lineWidth: coordinator.isDropTargeted ? 2.0 : 1.0
                        )
                )
                .shadow(
                    color: Color.black.opacity(coordinator.displayState == .expanded ? 0.62 : 0.28),
                    radius: coordinator.displayState == .expanded ? 20 : 6,
                    x: 0,
                    y: coordinator.displayState == .expanded ? 8 : 3
                )

            Group {
                switch coordinator.displayState {
                case .closed:
                    closedView
                        .transition(.opacity)
                case .compact:
                    compactWingsView
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                case .expanded:
                    ZStack(alignment: .bottomTrailing) {
                        expandedView
                            .opacity(effectiveContentVisible ? 1 : 0)
                            .scaleEffect(effectiveContentVisible ? 1.0 : 0.95, anchor: .top)
                            .blur(radius: effectiveContentVisible ? 0 : 2.5)
                        resizeGrip
                            .opacity(effectiveContentVisible ? 1 : 0)
                    }
                }
            }
            .padding(.horizontal, earRadius > 0 ? earRadius : 0)
            .clipShape(shellShape)
        }
        .contentShape(shellShape)
        .onTapGesture {
            if coordinator.displayState != .expanded {
                coordinator.toggleExpanded()
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $coordinator.isDropTargeted) { providers in
            handleFileDrop(providers)
        }
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
            HStack(spacing: 6) {
                if let primary = coordinator.activityStore.primaryActivity, settingsStore.settings.enableAIHub {
                    Circle()
                        .fill(colorForActivity(primary.state))
                        .frame(width: 7, height: 7)
                        .shadow(color: colorForActivity(primary.state).opacity(0.9), radius: 4)
                    Text(primary.source)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                } else if coordinator.mediaService.track.isPlaying, settingsStore.settings.enableMedia {
                    Image(systemName: "waveform")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.green)
                    Text(coordinator.mediaService.track.title)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: max(108, CGFloat(settingsStore.settings.compactWingExtraWidth) * 0.58), alignment: .leading)
            .padding(.leading, 12)

            Spacer()

            HStack(spacing: 6) {
                if let primary = coordinator.activityStore.primaryActivity,
                   let progress = primary.progress,
                   settingsStore.settings.enableAIHub {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.16), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 13, height: 13)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.accent)
                } else if coordinator.timerStore.isRunning, settingsStore.settings.enableTimer {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(coordinator.timerStore.formattedRemaining)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                } else if coordinator.mediaService.track.isPlaying {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: max(96, CGFloat(settingsStore.settings.compactWingExtraWidth) * 0.52), alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var expandedView: some View {
        VStack(spacing: 10) {
            // Top Header & Smooth Animated Tab Strip
            HStack(spacing: 6) {
                ForEach(visibleTabs) { tab in
                    let isSelected = coordinator.selectedTab == tab
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
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
                                    .shadow(color: colorForActivity(coordinator.activityStore.primaryActivity?.state ?? .running).opacity(0.8), radius: 3)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            isSelected ? palette.accent.opacity(0.22) : Color.clear,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(isSelected ? palette.accent.opacity(0.50) : Color.clear, lineWidth: 0.9)
                        )
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                    }
                    .buttonStyle(NotchSpringButtonStyle(pressedScale: 0.95))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
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
                        .background(Color.white.opacity(coordinator.showMirror ? 0.18 : 0.07), in: Circle())
                }
                .buttonStyle(NotchSpringButtonStyle())
                .help("Quick Camera Mirror")

                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        coordinator.isPinnedOpen.toggle()
                    }
                } label: {
                    Image(systemName: coordinator.isPinnedOpen ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundStyle(coordinator.isPinnedOpen ? .yellow : .white.opacity(0.65))
                        .padding(5)
                        .background(Color.white.opacity(coordinator.isPinnedOpen ? 0.18 : 0.07), in: Circle())
                }
                .buttonStyle(NotchSpringButtonStyle())
                .help("Keep Notch Expanded")

                Button {
                    coordinator.toggleExpanded()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(5)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(NotchSpringButtonStyle())
            }
            .padding(.top, 12)
            .padding(.horizontal, 14)

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.horizontal, 14)

            // Active Tab Content with crisp crossfade
            ZStack {
                switch coordinator.selectedTab {
                case .home:
                    HomeWidgetView(coordinator: coordinator)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                case .shelf:
                    ShelfWidgetView(coordinator: coordinator)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                case .ai:
                    AICreatorWidgetView(coordinator: coordinator)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                case .clipboard:
                    ClipboardWidgetView(coordinator: coordinator)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                case .settings:
                    SettingsWidgetView(coordinator: coordinator)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .animation(.easeOut(duration: 0.18), value: coordinator.selectedTab)
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
        let s = settingsStore.settings
        var tabs: [NotchTab] = [.home]
        if s.enableShelf { tabs.append(.shelf) }
        if s.enableAIHub { tabs.append(.ai) }
        if s.enableClipboard { tabs.append(.clipboard) }
        tabs.append(.settings)
        return tabs
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard settingsStore.settings.enableShelf else { return false }
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
