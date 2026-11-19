import AppKit
import CoreGraphics
import Foundation
import NotchHubCore
import SwiftUI

@MainActor
enum ScreenshotExporter {
    static func exportAll(to outputDirPath: String) {
        let outDir = URL(fileURLWithPath: outputDirPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let tmpSamplesDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("notchhub_samples_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpSamplesDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpSamplesDir) }

        let sampleImages = generateSampleCaptureThumbnails(in: tmpSamplesDir)

        // 1. Hero Banner — Real Home Dashboard
        let homeCoord = makeShowcaseCoordinator(
            displayState: .expanded,
            tab: .home,
            sampleCaptures: sampleImages
        )
        let heroView = macOSDesktopBackdrop(width: 1120, height: 630, showMenuBar: true) {
            NotchRootView(coordinator: homeCoord, forceConcaveEars: true, isShowcaseMode: true)
                .frame(width: 740, height: 555)
        }
        renderToPNG(heroView, to: outDir.appendingPathComponent("hero-banner.png"), scale: 2.0)

        // 2. AI Radar & Live Jobs — Real AI Tab
        let aiCoord = makeShowcaseCoordinator(
            displayState: .expanded,
            tab: .ai,
            sampleCaptures: sampleImages
        )
        aiCoord.selectedAIFilter = "All"
        let aiView = macOSDesktopBackdrop(width: 1120, height: 630, showMenuBar: true) {
            NotchRootView(coordinator: aiCoord, forceConcaveEars: true, isShowcaseMode: true)
                .frame(width: 720, height: 400)
        }
        renderToPNG(aiView, to: outDir.appendingPathComponent("ai-radar.png"), scale: 2.0)

        // 3. 3-State Dynamic Notch Comparison (Closed / Compact Wings / Expanded Shelf)
        let closedCoord = makeShowcaseCoordinator(displayState: .closed, tab: .home, sampleCaptures: sampleImages)
        let compactCoord = makeShowcaseCoordinator(displayState: .compact, tab: .home, sampleCaptures: sampleImages)
        let shelfCoord = makeShowcaseCoordinator(displayState: .expanded, tab: .shelf, sampleCaptures: sampleImages)
        shelfCoord.shelfStore.add(filePaths: Array(sampleImages.prefix(4)))

        let statesView = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.11, blue: 0.17),
                    Color(red: 0.05, green: 0.06, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 18) {
                Text("NotchHub — 3 Dynamic States (Actual App UI)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))

                stateStrip(label: "1. Closed — Blends cleanly into the MacBook hardware notch") {
                    NotchRootView(coordinator: closedCoord, forceConcaveEars: true, isShowcaseMode: true)
                        .frame(width: 214, height: 34)
                }

                stateStrip(label: "2. Compact Wings — Live AI / Render progress & Now Playing beside the notch") {
                    NotchRootView(coordinator: compactCoord, forceConcaveEars: true, isShowcaseMode: true)
                        .frame(width: 400, height: 36)
                }

                stateStrip(label: "3. Expanded Hub — File Drop Shelf, Gadgets, 5-Cap Tray & AI Radar") {
                    NotchRootView(coordinator: shelfCoord, forceConcaveEars: true, isShowcaseMode: true)
                        .frame(width: 700, height: 245)
                }
            }
            .padding(28)
        }
        .frame(width: 1120, height: 630)
        .preferredColorScheme(.dark)

        renderToPNG(statesView, to: outDir.appendingPathComponent("notch-states.png"), scale: 2.0)

        // 4. Polished Settings View (General: Launch at Login, Language, Hover Feel)
        let settingsCoord = makeShowcaseCoordinator(
            displayState: .expanded,
            tab: .settings,
            sampleCaptures: sampleImages
        )
        settingsCoord.selectedSettingsSection = "general"
        let settingsView = macOSDesktopBackdrop(width: 1120, height: 630, showMenuBar: true) {
            NotchRootView(coordinator: settingsCoord, forceConcaveEars: true, isShowcaseMode: true)
                .frame(width: 740, height: 460)
        }
        renderToPNG(settingsView, to: outDir.appendingPathComponent("settings.png"), scale: 2.0)

        print("Exported real SwiftUI screenshots to: \(outDir.path)")
    }

    private static func stateStrip<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Simulated macOS menu bar
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo").font(.system(size: 11))
                        Text("Finder").font(.system(size: 11, weight: .semibold))
                        Text("File").font(.system(size: 11))
                        Text("Edit").font(.system(size: 11))
                        Text("View").font(.system(size: 11))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "wifi").font(.system(size: 10))
                        Image(systemName: "battery.100").font(.system(size: 11))
                        Text("11:42").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 16)
                .frame(height: 28)
                .background(Color.black.opacity(0.35))

                content()
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom, 10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))

            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
        }
    }

    private static func macOSDesktopBackdrop<Content: View>(
        width: CGFloat,
        height: CGFloat,
        showMenuBar: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .top) {
            // Deep macOS midnight wallpaper gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.11, blue: 0.22),
                    Color(red: 0.05, green: 0.06, blue: 0.14),
                    Color(red: 0.09, green: 0.07, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.indigo.opacity(0.28), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 540
            )

            if showMenuBar {
                HStack {
                    HStack(spacing: 14) {
                        Image(systemName: "apple.logo").font(.system(size: 12))
                        Text("NotchHub").font(.system(size: 12, weight: .semibold))
                        Text("File").font(.system(size: 12))
                        Text("Edit").font(.system(size: 12))
                        Text("Window").font(.system(size: 12))
                    }
                    .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "wifi").font(.system(size: 11))
                        Image(systemName: "battery.100.bolt").font(.system(size: 12))
                        Text("Thu 11:42").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.82))
                }
                .padding(.horizontal, 20)
                .frame(height: 30)
                .background(Color.black.opacity(0.32))
            }

            content()
        }
        .frame(width: width, height: height)
        .preferredColorScheme(.dark)
    }

    private static func makeShowcaseCoordinator(
        displayState: NotchDisplayState,
        tab: NotchTab,
        sampleCaptures: [String]
    ) -> NotchCoordinator {
        let coord = NotchCoordinator(inMemoryOnly: true)
        coord.displayState = displayState
        coord.selectedTab = tab
        coord.settingsStore.settings.language = .en
        coord.settingsStore.settings.homeGadgets = [.quickApps, .captures, .aiRadar, .media, .timer, .system]
        coord.settingsStore.settings.expandedWidth = 720
        coord.settingsStore.settings.expandedHeight = 540

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        coord.quickAppStore.replaceAll([
            QuickAppItem(name: "AI Power Ranger", kind: .url, target: "http://localhost:3000", iconSymbol: "bolt.shield.fill"),
            QuickAppItem(name: "Antigravity", kind: .app, target: "/Applications/Antigravity.app"),
            QuickAppItem(name: "FilmCraft", kind: .app, target: "/Applications/FilmCraft.app"),
            QuickAppItem(name: "EffectCraft", kind: .app, target: "/Applications/EffectCraft.app"),
            QuickAppItem(name: "Blender", kind: .app, target: "\(homeDir)/Applications/Blender.app"),
            QuickAppItem(name: "Claude", kind: .app, target: "/Applications/Claude.app"),
            QuickAppItem(name: "ChatGPT", kind: .app, target: "/Applications/ChatGPT.app"),
            QuickAppItem(name: "AI-Team", kind: .folder, target: "\(homeDir)/Desktop/AI-Team-Projects")
        ])

        coord.mediaService.track = MediaTrackInfo(
            appName: "Spotify",
            title: "Midnight Focus Lo-Fi",
            artist: "Notch Beats",
            isPlaying: true
        )
        coord.systemService.snapshot = SystemSnapshot(
            batteryPercent: 94,
            isCharging: true,
            cpuUsagePercent: 18,
            memoryUsedGB: 10.4,
            memoryTotalGB: 24,
            volumePercent: 72,
            isMuted: false
        )
        coord.timerStore.setPreset(minutes: 25)

        coord.screenshotStore.clear()
        for path in sampleCaptures {
            coord.screenshotStore.add(filePath: path, source: "screen", isManagedFile: false)
        }

        coord.aiDiscovery.setItemsForShowcase([
            DiscoveredAIItem(id: "a1", name: "Antigravity", category: .desktopApp, status: .running, subtitle: "Google Agentic AI IDE", targetPathOrURL: "/Applications/Antigravity.app"),
            DiscoveredAIItem(id: "a2", name: "Claude", category: .desktopApp, status: .running, subtitle: "Anthropic Desktop AI", targetPathOrURL: "/Applications/Claude.app"),
            DiscoveredAIItem(id: "a3", name: "ChatGPT", category: .desktopApp, status: .installed, subtitle: "OpenAI Desktop AI", targetPathOrURL: "/Applications/ChatGPT.app"),
            DiscoveredAIItem(id: "c1", name: "Codex CLI", category: .cli, status: .configured, subtitle: "OpenAI Terminal Agent (~/.local/bin)", targetPathOrURL: "codex"),
            DiscoveredAIItem(id: "p1", name: "Ollama API", category: .api, status: .online, subtitle: "Local LLM HTTP API (:11434)", targetPathOrURL: "http://127.0.0.1:11434")
        ])

        coord.activityStore.upsert(
            LiveActivity(
                id: "yt-demo",
                source: "yt-creative-mcp",
                state: .running,
                title: "Analyzing YouTube Edit",
                detail: "Detecting cuts, 124 BPM & zoom keyframes",
                progress: 0.68
            )
        )
        return coord
    }

    private static func generateSampleCaptureThumbnails(in dir: URL) -> [String] {
        let specs: [(name: String, c1: NSColor, c2: NSColor, label: String)] = [
            ("Timeline_Edit.png", NSColor(red: 0.14, green: 0.17, blue: 0.28, alpha: 1), NSColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1), "FilmCraft Cut"),
            ("Shader_Node.png", NSColor(red: 0.18, green: 0.12, blue: 0.28, alpha: 1), NSColor(red: 0.08, green: 0.09, blue: 0.16, alpha: 1), "EffectCraft FX"),
            ("Notch_UI.png", NSColor(red: 0.10, green: 0.22, blue: 0.28, alpha: 1), NSColor(red: 0.06, green: 0.10, blue: 0.16, alpha: 1), "SwiftUI Spec"),
            ("Audio_BPM.png", NSColor(red: 0.09, green: 0.24, blue: 0.22, alpha: 1), NSColor(red: 0.06, green: 0.11, blue: 0.14, alpha: 1), "124 BPM Graph"),
            ("Terminal_CLI.png", NSColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 1), NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1), "MCP Output")
        ]

        var paths: [String] = []
        for (idx, s) in specs.enumerated() {
            let size = NSSize(width: 320, height: 200)
            let img = NSImage(size: size)
            img.lockFocus()
            let grad = NSGradient(starting: s.c1, ending: s.c2)
            grad?.draw(in: NSRect(origin: .zero, size: size), angle: -45)

            // Draw subtle mockup UI lines inside each thumbnail so it looks like a real screenshot
            NSColor.white.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: NSRect(x: 18, y: 148, width: 140, height: 14), xRadius: 4, yRadius: 4).fill()
            NSColor.cyan.withAlphaComponent(0.32).setFill()
            NSBezierPath(roundedRect: NSRect(x: 18, y: 118, width: CGFloat(160 + idx * 22), height: 10), xRadius: 3, yRadius: 3).fill()
            NSColor.white.withAlphaComponent(0.08).setFill()
            NSBezierPath(roundedRect: NSRect(x: 18, y: 30, width: 284, height: 74), xRadius: 8, yRadius: 8).fill()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.85)
            ]
            NSString(string: s.label).draw(at: NSPoint(x: 28, y: 60), withAttributes: attrs)
            img.unlockFocus()

            if let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                let fileURL = dir.appendingPathComponent(s.name)
                try? png.write(to: fileURL)
                paths.append(fileURL.path)
            }
        }
        return paths
    }

    private static func renderToPNG<V: View>(_ view: V, to url: URL, scale: CGFloat) {
        let size = NSSize(width: 1120, height: 630)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = true
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.wantsLayer = true
        window.contentView = hosting

        // Force full SwiftUI + AppKit layout pass
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let pixelW = Int(size.width * scale)
        let pixelH = Int(size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelW,
            pixelsHigh: pixelH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url, options: .atomic)
        }
        window.orderOut(nil)
    }
}
