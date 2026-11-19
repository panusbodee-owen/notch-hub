import AppKit
import NotchHubCore
import SwiftUI

struct SettingsWidgetView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var launchAtLogin: LaunchAtLoginService

    init(coordinator: NotchCoordinator) {
        self.coordinator = coordinator
        self.settingsStore = coordinator.settingsStore
        self.launchAtLogin = coordinator.launchAtLogin
    }

    private var l10n: L10n { coordinator.l10n }
    private var palette: NotchThemePalette {
        NotchThemePalette.palette(for: settingsStore.settings.theme)
    }

    private var sections: [(id: String, title: String, icon: String)] {
        [
            ("general", l10n.settingsGeneral, "gearshape.fill"),
            ("layout", l10n.settingsLayout, "rectangle.arrowtriangle.2.outward"),
            ("modules", l10n.settingsModules, "square.grid.2x2.fill"),
            ("about", l10n.settingsAbout, "network")
        ]
    }

    private let presets: [(label: String, subtitle: String, w: Double, h: Double)] = [
        ("S", "580 × 320", 580, 320),
        ("M", "700 × 440", 700, 440),
        ("L", "840 × 480", 840, 480),
        ("XL", "980 × 520", 980, 520)
    ]

    var body: some View {
        VStack(spacing: 10) {
            // Segmented Top Navigation Bar
            HStack(spacing: 6) {
                ForEach(sections, id: \.id) { sec in
                    let active = coordinator.selectedSettingsSection == sec.id
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                            coordinator.selectedSettingsSection = sec.id
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: sec.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(sec.title)
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5.5)
                        .background(
                            active ? palette.accent.opacity(0.22) : Color.white.opacity(0.05),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(
                                active ? palette.accent.opacity(0.65) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                        )
                        .foregroundStyle(active ? .white : .white.opacity(0.62))
                    }
                    .buttonStyle(NotchSpringButtonStyle(pressedScale: 0.95))
                }
                Spacer()
            }

            // Section Body
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    switch coordinator.selectedSettingsSection {
                    case "layout":
                        layoutSection
                    case "modules":
                        modulesSection
                    case "about":
                        aboutSection
                    default:
                        generalSection
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - 1. General (Launch at Login, Theme & Accent, Language, Hover Feel)

    private var generalSection: some View {
        VStack(spacing: 10) {
            // Apple-style Theme & Accent Picker Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    iconBadge(
                        systemName: "paintpalette.fill",
                        gradient: [palette.accent, palette.accentSecondary]
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(l10n.themeLabel)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(l10n.themeSubtitle)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()

                    // Apple macOS-style accent color dots
                    HStack(spacing: 9) {
                        ForEach(NotchTheme.allCases) { theme in
                            let themePal = NotchThemePalette.palette(for: theme)
                            let selected = settingsStore.settings.theme == theme
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                                    settingsStore.settings.theme = theme
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [themePal.accent, themePal.accentSecondary],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 20, height: 20)
                                        .shadow(color: selected ? themePal.accent.opacity(0.85) : .clear, radius: 5)
                                    if selected {
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: 2)
                                            .frame(width: 24, height: 24)
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 5.5, height: 5.5)
                                    }
                                }
                                .frame(width: 24, height: 24)
                            }
                            .buttonStyle(NotchSpringButtonStyle(pressedScale: 0.86))
                            .help(theme.displayName)
                        }
                    }

                    Text(settingsStore.settings.theme.displayName)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(palette.accent.opacity(0.18), in: Capsule())
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(11)
            .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.cardBorder, lineWidth: 1))

            // Startup & Language Row
            HStack(spacing: 10) {
                // Launch at Login Card
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 9) {
                        iconBadge(
                            systemName: "power",
                            gradient: launchAtLogin.isEnabled
                                ? [Color(red: 0.16, green: 0.88, blue: 0.50), Color(red: 0.08, green: 0.58, blue: 0.40)]
                                : [Color.white.opacity(0.18), Color.white.opacity(0.08)]
                        )
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(l10n.launchAtLoginTitle)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(launchAtLogin.statusDescription)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(launchAtLogin.isEnabled ? Color(red: 0.24, green: 0.94, blue: 0.56) : .white.opacity(0.45))
                        }
                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { launchAtLogin.isEnabled },
                                set: { launchAtLogin.setEnabled($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Color(red: 0.22, green: 0.90, blue: 0.52))
                    }

                    Text(l10n.launchAtLoginSubtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
                .padding(11)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15).stroke(
                        launchAtLogin.isEnabled ? Color.green.opacity(0.35) : palette.cardBorder,
                        lineWidth: 1
                    )
                )

                // Language Selector Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        iconBadge(
                            systemName: "globe",
                            gradient: [palette.accent, Color.blue.opacity(0.75)]
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(l10n.languageLabel)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Instant live UI switching")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        ForEach(AppLanguage.allCases) { lang in
                            let selected = settingsStore.settings.language == lang
                            Button {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                                    settingsStore.settings.language = lang
                                }
                            } label: {
                                Text(lang.displayName)
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(
                                        selected ? palette.accent : Color.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 9)
                                    )
                                    .foregroundStyle(selected ? .black : .white.opacity(0.82))
                            }
                            .buttonStyle(NotchSpringButtonStyle(pressedScale: 0.94))
                        }
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.cardBorder, lineWidth: 1))
            }

            // Interaction & Hover Feel Card
            VStack(spacing: 9) {
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        iconBadge(
                            systemName: "cursorarrow.motionlines",
                            gradient: [Color.purple.opacity(0.85), Color.indigo.opacity(0.75)]
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Expand on Hover")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Auto-open when pointer rests on notch")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        Spacer()
                        Toggle("", isOn: $settingsStore.settings.hoverExpandEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(palette.accent)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 28).overlay(Color.white.opacity(0.1))

                    HStack(spacing: 8) {
                        iconBadge(
                            systemName: "waveform.path.ecg",
                            gradient: [Color.orange.opacity(0.85), Color.pink.opacity(0.75)]
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Compact Wings")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Show live music, AI & timer beside notch")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        Spacer()
                        Toggle("", isOn: $settingsStore.settings.showCompactWings)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(palette.accent)
                    }
                    .frame(maxWidth: .infinity)
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack(spacing: 10) {
                    Text("Hover Delay")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                    Slider(value: $settingsStore.settings.hoverDelaySeconds, in: 0.08...0.50, step: 0.02)
                        .controlSize(.mini)
                        .tint(palette.accent)
                    Text(String(format: "%.0f ms", settingsStore.settings.hoverDelaySeconds * 1000))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.09), in: Capsule())
                        .foregroundStyle(palette.accent)
                        .frame(width: 62, alignment: .center)
                }
            }
            .padding(11)
            .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - 2. Size & Motion

    private var layoutSection: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quick Size Presets")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                    Text("Or drag bottom-right corner ↖↘ anytime")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.45))
                }

                HStack(spacing: 8) {
                    ForEach(presets, id: \.label) { preset in
                        let active = Int(settingsStore.settings.expandedWidth) == Int(preset.w) &&
                            Int(settingsStore.settings.expandedHeight) == Int(preset.h)
                        Button {
                            coordinator.applySizePreset(width: preset.w, height: preset.h)
                        } label: {
                            VStack(spacing: 3) {
                                Text(preset.label)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(active ? palette.accent : .white)
                                Text(preset.subtitle)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(active ? palette.accent.opacity(0.9) : .white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                active ? palette.accent.opacity(0.16) : Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 11)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 11).stroke(
                                    active ? palette.accent.opacity(0.70) : Color.white.opacity(0.08),
                                    lineWidth: active ? 1.2 : 1
                                )
                            )
                        }
                        .buttonStyle(NotchSpringButtonStyle(pressedScale: 0.95))
                    }
                }
            }
            .padding(12)
            .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.cardBorder, lineWidth: 1))

            VStack(spacing: 9) {
                dimensionSliderRow(
                    title: "Expanded Width",
                    valueText: "\(Int(settingsStore.settings.expandedWidth)) px",
                    value: $settingsStore.settings.expandedWidth,
                    range: 460...1100,
                    step: 10
                )
                dimensionSliderRow(
                    title: "Expanded Height",
                    valueText: "\(Int(settingsStore.settings.expandedHeight)) px",
                    value: $settingsStore.settings.expandedHeight,
                    range: 220...560,
                    step: 10
                )
                dimensionSliderRow(
                    title: "Compact Wings Extra Width",
                    valueText: "+\(Int(settingsStore.settings.compactWingExtraWidth)) px",
                    value: $settingsStore.settings.compactWingExtraWidth,
                    range: 80...320,
                    step: 10
                )
            }
            .padding(12)
            .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - 3. Modular Widgets Grid

    private var modulesSection: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 9),
                GridItem(.flexible(), spacing: 9)
            ],
            spacing: 9
        ) {
            moduleToggleCard(
                title: "Media Controls",
                subtitle: "Spotify / Apple Music + Waveform",
                icon: "waveform",
                gradient: [Color.green.opacity(0.85), Color.teal.opacity(0.75)],
                isOn: $settingsStore.settings.enableMedia
            )
            moduleToggleCard(
                title: "File Drop Shelf",
                subtitle: "Drag files to top-center notch",
                icon: "tray.and.arrow.down.fill",
                gradient: [Color.blue.opacity(0.85), Color.cyan.opacity(0.75)],
                isOn: $settingsStore.settings.enableShelf
            )
            moduleToggleCard(
                title: "AI & Render Hub",
                subtitle: "AI Radar & Live Activity API",
                icon: "cpu.fill",
                gradient: [Color.purple.opacity(0.85), Color.indigo.opacity(0.75)],
                isOn: $settingsStore.settings.enableAIHub
            )
            moduleToggleCard(
                title: "Clipboard History",
                subtitle: "Pinned text & prompt snippets",
                icon: "doc.on.clipboard.fill",
                gradient: [Color.yellow.opacity(0.85), Color.orange.opacity(0.75)],
                isOn: $settingsStore.settings.enableClipboard
            )
            moduleToggleCard(
                title: "Focus Timer",
                subtitle: "Pomodoro presets & countdown",
                icon: "timer",
                gradient: [Color.orange.opacity(0.90), Color.red.opacity(0.75)],
                isOn: $settingsStore.settings.enableTimer
            )
            moduleToggleCard(
                title: "System HUD",
                subtitle: "Battery, CPU rings & Volume",
                icon: "gauge.medium",
                gradient: [palette.accent, Color.mint.opacity(0.75)],
                isOn: $settingsStore.settings.enableSystemHUD
            )
        }
    }

    // MARK: - 4. API & About (with Real App Logo!)

    private var aboutSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                appLogoImage
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("NotchHub")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.4.0")")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(palette.accent.opacity(0.20), in: Capsule())
                            .foregroundStyle(palette.accent)
                    }
                    Text("Native SwiftUI macOS Dynamic Island • Apple Silicon")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/panusbodee-owen/notch-hub") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.11), in: Capsule())
                .foregroundStyle(.white)
                .buttonStyle(NotchSpringButtonStyle())
            }
            .padding(12)
            .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.cardBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Loopback Live Activity API", systemImage: "bolt.horizontal.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Spacer()
                    Text("127.0.0.1:\(settingsStore.settings.apiPort)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                Text("POST http://127.0.0.1:\(settingsStore.settings.apiPort)/v1/activity")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 8) {
                    Button("Copy Endpoint") {
                        coordinator.clipboardMonitor.copyToPasteboard(
                            "http://127.0.0.1:\(settingsStore.settings.apiPort)/v1/activity"
                        )
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1), in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(NotchSpringButtonStyle())

                    Button("Send Demo Activity") {
                        coordinator.injectDemoActivity()
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.accent.opacity(0.22), in: Capsule())
                    .foregroundStyle(palette.accent)
                    .buttonStyle(NotchSpringButtonStyle())

                    Spacer()
                }
            }
            .padding(12)
            .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var appLogoImage: some View {
        if let iconImg = NSApp.applicationIconImage {
            Image(nsImage: iconImg)
                .resizable()
                .scaledToFit()
        } else {
            iconBadge(
                systemName: "rectangle.topthird.inset.filled",
                gradient: [palette.accent, palette.accentSecondary]
            )
        }
    }

    private func iconBadge(systemName: String, gradient: [Color]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func moduleToggleCard(
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color],
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 9) {
            iconBadge(systemName: icon, gradient: gradient)
            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(palette.accent)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13).stroke(
                isOn.wrappedValue ? palette.cardBorder : Color.white.opacity(0.05),
                lineWidth: 1
            )
        )
    }

    private func dimensionSliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 145, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .controlSize(.mini)
                .tint(palette.accent)
            Text(valueText)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(palette.accent)
                .frame(width: 68, alignment: .center)
        }
    }
}
