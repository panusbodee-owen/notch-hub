import AppKit
import Darwin
import Foundation
import NotchHubCore

@MainActor
final class AIDiscoveryService: ObservableObject {
    @Published private(set) var items: [DiscoveredAIItem] = []
    @Published private(set) var lastScannedAt: Date?
    @Published private(set) var isScanning: Bool = false

    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    var desktopApps: [DiscoveredAIItem] { items.filter { $0.category == .desktopApp } }
    var cliTools: [DiscoveredAIItem] { items.filter { $0.category == .cli } }
    var apis: [DiscoveredAIItem] { items.filter { $0.category == .api } }

    func refresh() {
        guard !isScanning else { return }
        isScanning = true

        let runningAppPaths = Set(
            NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.path }
        )
        let runningAppNames = Set(
            NSWorkspace.shared.runningApplications.compactMap { $0.localizedName?.lowercased() }
        )

        Task.detached(priority: .utility) {
            let discovered = Self.scanAll(
                runningAppPaths: runningAppPaths,
                runningAppNames: runningAppNames
            )
            await MainActor.run { [weak self] in
                self?.items = discovered
                self?.lastScannedAt = Date()
                self?.isScanning = false
            }
        }
    }

    func activate(_ item: DiscoveredAIItem, copyFallback: (String) -> Void) {
        switch item.category {
        case .desktopApp:
            let url = URL(fileURLWithPath: item.targetPathOrURL)
            if FileManager.default.fileExists(atPath: url.path) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        case .cli:
            let cmd = item.launchCommand ?? item.targetPathOrURL
            launchInTerminal(cmd)
        case .api:
            if item.targetPathOrURL.hasPrefix("http://") || item.targetPathOrURL.hasPrefix("https://"),
               let url = URL(string: item.targetPathOrURL) {
                NSWorkspace.shared.open(url)
            } else {
                copyFallback(item.targetPathOrURL)
            }
        }
    }

    private func launchInTerminal(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            try? proc.run()
        }
    }

    // MARK: - Background Scanner

    nonisolated private static func scanAll(
        runningAppPaths: Set<String>,
        runningAppNames: Set<String>
    ) -> [DiscoveredAIItem] {
        var results: [DiscoveredAIItem] = []
        results.append(contentsOf: scanDesktopApps(runningPaths: runningAppPaths, runningNames: runningAppNames))
        results.append(contentsOf: scanCLIs())
        results.append(contentsOf: scanAPIsAndServices())
        return results
    }

    nonisolated private static func scanDesktopApps(
        runningPaths: Set<String>,
        runningNames: Set<String>
    ) -> [DiscoveredAIItem] {
        let knownApps: [(fileName: String, displayName: String, subtitle: String)] = [
            ("Antigravity.app", "Antigravity", "Google Agentic AI IDE"),
            ("Claude.app", "Claude", "Anthropic Desktop AI"),
            ("ChatGPT.app", "ChatGPT", "OpenAI Desktop AI"),
            ("Cursor.app", "Cursor", "AI Code Editor"),
            ("Windsurf.app", "Windsurf", "AI Code Editor"),
            ("Ollama.app", "Ollama", "Local LLM Runner"),
            ("LM Studio.app", "LM Studio", "Local LLM Workbench"),
            ("Jan.app", "Jan", "Local Open-Source AI"),
            ("Perplexity.app", "Perplexity", "AI Research Assistant"),
            ("Poe.app", "Poe", "Multi-Model AI Client"),
            ("Raycast.app", "Raycast", "Launcher + AI"),
            ("Zed.app", "Zed", "Editor + AI Assistant"),
            ("Trae.app", "Trae", "AI IDE"),
            ("Kiro.app", "Kiro", "Agentic IDE"),
            ("ComfyUI.app", "ComfyUI", "Node-based Image/Video AI"),
            ("DiffusionBee.app", "DiffusionBee", "Local Image Gen"),
            ("Draw Things.app", "Draw Things", "Local Diffusion Studio")
        ]

        let searchRoots = [
            "/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]

        var found: [DiscoveredAIItem] = []
        var seen = Set<String>()

        for root in searchRoots {
            for entry in knownApps {
                let fullPath = (root as NSString).appendingPathComponent(entry.fileName)
                guard !seen.contains(entry.displayName),
                      FileManager.default.fileExists(atPath: fullPath) else { continue }
                seen.insert(entry.displayName)
                let stdPath = URL(fileURLWithPath: fullPath).standardizedFileURL.path
                let isRunning = runningPaths.contains(stdPath) || runningNames.contains(entry.displayName.lowercased())
                found.append(
                    DiscoveredAIItem(
                        id: "app-\(entry.displayName.lowercased())",
                        name: entry.displayName,
                        category: .desktopApp,
                        status: isRunning ? .running : .installed,
                        subtitle: entry.subtitle,
                        targetPathOrURL: fullPath
                    )
                )
            }
        }

        // Sort Running apps first
        return found.sorted { lhs, rhs in
            if (lhs.status == .running) != (rhs.status == .running) {
                return lhs.status == .running
            }
            return lhs.name < rhs.name
        }
    }

    nonisolated private static func scanCLIs() -> [DiscoveredAIItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let binDirs = [
            "\(home)/.local/bin",
            "\(home)/.local/node/bin",
            "\(home)/.npm-global/bin",
            "\(home)/.cargo/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/Library/Python/3.11/bin",
            "\(home)/Library/Python/3.12/bin",
            "\(home)/Library/Python/3.9/bin"
        ]

        let knownCLIs: [(bin: String, name: String, subtitle: String, launch: String)] = [
            ("agy", "Antigravity CLI", "agy — Agentic CLI", "agy"),
            ("codex", "Codex CLI", "OpenAI Codex Terminal Agent", "codex"),
            ("claude", "Claude Code", "Anthropic Terminal Agent", "claude"),
            ("gemini", "Gemini CLI", "Google Gemini Terminal Agent", "gemini"),
            ("ollama", "Ollama CLI", "Local LLM Runner CLI", "ollama list"),
            ("agent-desktop", "Agent Desktop", "Desktop automation CLI", "agent-desktop --help"),
            ("aider", "Aider", "AI Pair Programming CLI", "aider"),
            ("opencode", "OpenCode", "Terminal AI Coding Agent", "opencode"),
            ("goose", "Goose", "Open-Source AI Agent CLI", "goose"),
            ("llm", "LLM CLI", "Simon Willison's LLM tool", "llm models"),
            ("sgpt", "ShellGPT", "Terminal GPT helper", "sgpt --help"),
            ("cursor", "Cursor CLI", "Open workspace in Cursor", "cursor --version"),
            ("graphify-mcp", "Graphify MCP", "Knowledge Graph MCP Server", "graphify --help")
        ]

        let activeProcessList = runningProcessNames()
        var found: [DiscoveredAIItem] = []
        var seen = Set<String>()

        for cli in knownCLIs {
            for dir in binDirs {
                let candidate = (dir as NSString).appendingPathComponent(cli.bin)
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    guard !seen.contains(cli.bin) else { break }
                    seen.insert(cli.bin)
                    let isRunning = activeProcessList.contains(cli.bin.lowercased())
                    found.append(
                        DiscoveredAIItem(
                            id: "cli-\(cli.bin)",
                            name: cli.name,
                            category: .cli,
                            status: isRunning ? .running : .installed,
                            subtitle: "\(cli.subtitle) (\(dir.replacingOccurrences(of: home, with: "~")))",
                            targetPathOrURL: candidate,
                            launchCommand: cli.launch
                        )
                    )
                    break
                }
            }
        }

        // Check custom yt-creative-mcp project we built in scratch!
        let ytMcpDir = "\(home)/.gemini/antigravity/scratch/yt-creative-mcp"
        if FileManager.default.fileExists(atPath: "\(ytMcpDir)/pyproject.toml") {
            found.append(
                DiscoveredAIItem(
                    id: "cli-yt-creative-mcp",
                    name: "yt-creative-mcp",
                    category: .cli,
                    status: .configured,
                    subtitle: "YouTube Edit Analyzer + FilmCraft/EffectCraft/Blender MCP",
                    targetPathOrURL: ytMcpDir,
                    launchCommand: "cd '\(ytMcpDir)' && uv run yt-creative-mcp"
                )
            )
        }

        return found.sorted { lhs, rhs in
            if (lhs.status == .running) != (rhs.status == .running) {
                return lhs.status == .running
            }
            return lhs.name < rhs.name
        }
    }

    nonisolated private static func scanAPIsAndServices() -> [DiscoveredAIItem] {
        var found: [DiscoveredAIItem] = []

        // 1. Live Local AI / Creative HTTP & TCP Endpoints
        let localEndpoints: [(id: String, name: String, port: UInt16, subtitle: String, url: String, showOffline: Bool)] = [
            ("api-ollama", "Ollama Local API", 11434, "Local LLM HTTP API", "http://127.0.0.1:11434", false),
            ("api-lmstudio", "LM Studio API", 1234, "OpenAI-compat Local Server", "http://127.0.0.1:1234/v1/models", false),
            ("api-jan", "Jan Local API", 1337, "Jan OpenAI-compat API", "http://127.0.0.1:1337", false),
            ("api-comfyui", "ComfyUI API", 8188, "Local Diffusion Workflow Server", "http://127.0.0.1:8188", false),
            ("api-sdwebui", "SD WebUI / Forge", 7860, "Stable Diffusion Local API", "http://127.0.0.1:7860", false),
            ("api-vllm", "Local LLM (8000)", 8000, "vLLM / FastAPI AI Server", "http://127.0.0.1:8000", false),
            ("api-filmcraft", "FilmCraft Control", 9876, "FilmCraft JSON-lines Bridge", "127.0.0.1:9876", false),
            ("api-effectcraft", "EffectCraft Control", 9877, "EffectCraft JSON-lines Bridge", "127.0.0.1:9877", false),
            ("api-blender", "Blender MCP Bridge", 9878, "Blender bpy Socket Bridge", "127.0.0.1:9878", false),
            ("api-notchhub", "NotchHub Live API", 47890, "Local AI & Render Activity Endpoint", "http://127.0.0.1:47890/health", true)
        ]

        for ep in localEndpoints {
            let online = isLocalPortOpen(port: ep.port)
            if online || ep.showOffline {
                found.append(
                    DiscoveredAIItem(
                        id: ep.id,
                        name: ep.name,
                        category: .api,
                        status: online ? .online : .configured,
                        subtitle: "\(ep.subtitle) (:\(ep.port))",
                        targetPathOrURL: ep.url
                    )
                )
            }
        }

        // 2. Cloud AI API Keys (Presence ONLY — never reads or displays actual secret values!)
        let keySpecs: [(keys: [String], provider: String, subtitle: String)] = [
            (["GEMINI_API_KEY", "GOOGLE_API_KEY"], "Google Gemini API", "API Key configured in env/shell"),
            (["OPENAI_API_KEY"], "OpenAI API", "API Key configured in env/shell"),
            (["ANTHROPIC_API_KEY"], "Anthropic Claude API", "API Key configured in env/shell"),
            (["OPENROUTER_API_KEY"], "OpenRouter API", "Multi-model router key configured"),
            (["GROQ_API_KEY"], "Groq API", "Fast inference key configured"),
            (["DEEPSEEK_API_KEY"], "DeepSeek API", "API Key configured in env/shell"),
            (["XAI_API_KEY"], "xAI (Grok) API", "API Key configured in env/shell"),
            (["MISTRAL_API_KEY"], "Mistral API", "API Key configured in env/shell"),
            (["PERPLEXITY_API_KEY"], "Perplexity API", "Search API key configured"),
            (["HF_TOKEN", "HUGGINGFACE_TOKEN"], "Hugging Face API", "HF Token configured in env/shell")
        ]

        let allKnownKeys = keySpecs.flatMap { $0.keys }
        var detectedKeys = Set<String>()

        // Check current process env (keys only)
        let procEnv = ProcessInfo.processInfo.environment
        for k in allKnownKeys {
            if let v = procEnv[k], !v.isEmpty {
                detectedKeys.insert(k)
            }
        }

        // Check user shell rc files safely (name presence only)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for rc in [".zshrc", ".zshenv", ".zprofile", ".bashrc", ".bash_profile"] {
            let path = "\(home)/\(rc)"
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                detectedKeys.formUnion(AIShellKeyScanner.detectKnownAPIKeyNames(in: content, knownKeys: allKnownKeys))
            }
        }

        var seenProviders = Set<String>()
        for spec in keySpecs {
            let matched = spec.keys.filter { detectedKeys.contains($0) }
            if !matched.isEmpty {
                seenProviders.insert(spec.provider)
                found.append(
                    DiscoveredAIItem(
                        id: "api-key-\(spec.provider.lowercased().replacingOccurrences(of: " ", with: "-"))",
                        name: spec.provider,
                        category: .api,
                        status: .configured,
                        subtitle: "\(matched.joined(separator: ", ")) set",
                        targetPathOrURL: matched.first ?? spec.provider
                    )
                )
            }
        }

        // 3. Provider Auth / Config Folders (shows authenticated local AI ecosystems)
        let configAuthDirs: [(path: String, name: String, subtitle: String)] = [
            ("\(home)/.gemini/antigravity", "Antigravity Auth / MCP", "Authenticated session & MCPs (~/.gemini)"),
            ("\(home)/.codex", "OpenAI Codex Auth", "Codex CLI config (~/.codex)"),
            ("\(home)/.claude", "Claude Code Auth", "Claude CLI config (~/.claude)"),
            ("\(home)/.ollama", "Ollama Models Store", "Local model weights (~/.ollama)"),
            ("\(home)/.config/github-copilot", "GitHub Copilot Auth", "Copilot CLI/IDE auth")
        ]

        for cfg in configAuthDirs {
            if FileManager.default.fileExists(atPath: cfg.path), !seenProviders.contains(cfg.name) {
                found.append(
                    DiscoveredAIItem(
                        id: "api-cfg-\(cfg.name.lowercased().replacingOccurrences(of: " ", with: "-"))",
                        name: cfg.name,
                        category: .api,
                        status: .configured,
                        subtitle: cfg.subtitle,
                        targetPathOrURL: cfg.path
                    )
                )
            }
        }

        return found.sorted { lhs, rhs in
            if (lhs.status == .online) != (rhs.status == .online) {
                return lhs.status == .online
            }
            return lhs.name < rhs.name
        }
    }

    nonisolated private static func isLocalPortOpen(port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        // Non-blocking connect with 150ms select timeout
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if res == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let pollRes = poll(&pfd, 1, 150)
        guard pollRes > 0, (pfd.revents & Int16(POLLOUT)) != 0 else { return false }

        var err: Int32 = 0
        var errLen = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &errLen)
        return err == 0
    }

    nonisolated private static func runningProcessNames() -> Set<String> {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-Ao", "comm="]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            var names = Set<String>()
            for line in output.components(separatedBy: .newlines) {
                let base = URL(fileURLWithPath: line.trimmingCharacters(in: .whitespaces)).lastPathComponent.lowercased()
                if !base.isEmpty { names.insert(base) }
            }
            return names
        } catch {
            return []
        }
    }
}
