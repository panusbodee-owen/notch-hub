import NotchHubCore
import SwiftUI

struct SettingsWidgetView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var settingsStore: SettingsStore

    init(coordinator: NotchCoordinator) {
        self.coordinator = coordinator
        self.settingsStore = coordinator.settingsStore
    }

    private let presets: [(label: String, w: Double, h: Double)] = [
        ("S", 580, 320),
        ("M", 700, 440),
        ("L", 840, 480),
        ("XL", 980, 520)
    ]

    var body: some View {
        HStack(spacing: 14) {
            // Left: Language Switcher + Modular Widget Toggles
            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.l10n.languageLabel)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: 4) {
                    ForEach(AppLanguage.allCases) { lang in
                        let selected = settingsStore.settings.language == lang
                        Button(lang.displayName) {
                            settingsStore.settings.language = lang
                        }
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            selected ? Color.cyan.opacity(0.85) : Color.white.opacity(0.1),
                            in: Capsule()
                        )
                        .foregroundStyle(selected ? .black : .white.opacity(0.85))
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 2)

                Text(coordinator.l10n.modularWidgets)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))

                Toggle("Media Controls", isOn: $settingsStore.settings.enableMedia)
                Toggle("File Drop Shelf", isOn: $settingsStore.settings.enableShelf)
                Toggle("AI & Render Hub", isOn: $settingsStore.settings.enableAIHub)
                Toggle("Clipboard History", isOn: $settingsStore.settings.enableClipboard)
                Toggle("Focus Timer", isOn: $settingsStore.settings.enableTimer)
                Toggle("System HUD", isOn: $settingsStore.settings.enableSystemHUD)

                Spacer()

                HStack(spacing: 4) {
                    Text("API:")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("127.0.0.1:\(settingsStore.settings.apiPort)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.system(size: 11))
            .frame(maxWidth: 185, alignment: .leading)

            Divider().overlay(Color.white.opacity(0.1))

            // Right: Size & Behavior Controls (live resize!)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(coordinator.l10n.notchSizeLayout)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(presets, id: \.label) { preset in
                                let isActive = Int(settingsStore.settings.expandedWidth) == Int(preset.w) &&
                                    Int(settingsStore.settings.expandedHeight) == Int(preset.h)
                                Button(preset.label) {
                                    coordinator.applySizePreset(width: preset.w, height: preset.h)
                                }
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    isActive ? Color.cyan.opacity(0.85) : Color.white.opacity(0.1),
                                    in: Capsule()
                                )
                                .foregroundStyle(isActive ? .black : .white)
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Expanded Width")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text("\(Int(settingsStore.settings.expandedWidth)) px")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                        Slider(value: $settingsStore.settings.expandedWidth, in: 460...1100, step: 10)
                            .controlSize(.mini)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Expanded Height")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text("\(Int(settingsStore.settings.expandedHeight)) px")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                        Slider(value: $settingsStore.settings.expandedHeight, in: 220...540, step: 10)
                            .controlSize(.mini)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Compact Wings Width")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text("+\(Int(settingsStore.settings.compactWingExtraWidth)) px")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Slider(value: $settingsStore.settings.compactWingExtraWidth, in: 80...320, step: 10)
                            .controlSize(.mini)
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    HStack(spacing: 12) {
                        Toggle("Hover Expand", isOn: $settingsStore.settings.hoverExpandEnabled)
                        Toggle("Compact Wings", isOn: $settingsStore.settings.showCompactWings)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Hover Delay")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text(String(format: "%.0f ms", settingsStore.settings.hoverDelaySeconds * 1000))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Slider(value: $settingsStore.settings.hoverDelaySeconds, in: 0.08...0.50, step: 0.02)
                            .controlSize(.mini)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}
