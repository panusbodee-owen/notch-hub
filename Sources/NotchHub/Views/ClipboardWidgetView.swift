import NotchHubCore
import SwiftUI

struct ClipboardWidgetView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var store: ClipboardStore

    init(coordinator: NotchCoordinator) {
        self.coordinator = coordinator
        self.store = coordinator.clipboardStore
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Clipboard & Prompt Snippets", systemImage: "doc.on.clipboard.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if !store.entries.isEmpty {
                    Button("Clear Unpinned") {
                        store.clearUnpinned()
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .buttonStyle(.plain)
                }
            }

            if store.entries.isEmpty {
                VStack(spacing: 4) {
                    Text("Clipboard history is empty")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    Text("Copy any text, URL, or AI prompt — it appears here automatically.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(store.entries) { entry in
                            HStack(spacing: 8) {
                                Button {
                                    coordinator.clipboardMonitor.copyToPasteboard(entry.content)
                                    coordinator.lastCopiedID = entry.id
                                    Task {
                                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                                        if coordinator.lastCopiedID == entry.id {
                                            coordinator.lastCopiedID = nil
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(entry.content.replacingOccurrences(of: "\n", with: " "))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.9))
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if coordinator.lastCopiedID == entry.id {
                                            Text("Copied")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                Button {
                                    store.togglePin(id: entry.id)
                                } label: {
                                    Image(systemName: entry.pinned ? "pin.fill" : "pin")
                                        .font(.system(size: 10))
                                        .foregroundStyle(entry.pinned ? .yellow : .white.opacity(0.4))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    store.remove(id: entry.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }
            }
        }
    }
}
