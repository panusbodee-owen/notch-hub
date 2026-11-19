import AppKit
import NotchHubCore
import SwiftUI

struct ShelfWidgetView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var shelf: FileShelfStore

    init(coordinator: NotchCoordinator) {
        self.coordinator = coordinator
        self.shelf = coordinator.shelfStore
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("File Drop Shelf", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("ลากไฟล์มาวางพัก หรือลากออกไปใส่ FilmCraft / EffectCraft / Finder")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                Spacer()
                if !shelf.items.isEmpty {
                    Button("Clear") {
                        shelf.clear()
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.85))
                    .buttonStyle(.plain)
                }
            }

            if shelf.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(coordinator.isDropTargeted ? .cyan : .white.opacity(0.4))
                    Text("Drop files, clips, or images here")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("Tip: Drag any file to the top center of your screen to auto-open this shelf.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            coordinator.isDropTargeted ? Color.cyan : Color.white.opacity(0.14),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(shelf.items) { item in
                            shelfItemCard(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func shelfItemCard(_ item: ShelfItem) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.filePath))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .padding(.top, 8)

                Button {
                    shelf.remove(id: item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            .frame(maxWidth: .infinity)

            Text(item.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Button {
                    coordinator.clipboardMonitor.copyToPasteboard(item.filePath)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Copy File Path")
            }
            .foregroundStyle(.white.opacity(0.65))
            .padding(.bottom, 6)
        }
        .frame(width: 104, height: 126)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }
}
