import SwiftUI

/// Топ-100 самых больших файлов (ТЗ 2.1.3, US-1) — карточный список
struct TopFilesView: View {
    let files: [FileNode]
    let onSelect: (FileNode) -> Void
    let onTrash: (FileNode) -> Void

    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 10)]

    var body: some View {
        Group {
            if files.isEmpty {
                ContentUnavailableView(
                    "Нет данных",
                    systemImage: "flame",
                    description: Text("Сначала просканируйте диск")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(files.prefix(100).enumerated()), id: \.element.id) { index, file in
                            FileCard(
                                file: file,
                                rank: index + 1,
                                maxSize: files.first?.size ?? 1,
                                onSelect: onSelect,
                                onTrash: onTrash
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

private struct FileCard: View {
    let file: FileNode
    let rank: Int
    let maxSize: Int64
    let onSelect: (FileNode) -> Void
    let onTrash: (FileNode) -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 22, alignment: .trailing)

                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                    .resizable()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(file.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(file.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatBytes(file.size))
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                    Chip(text: file.category.displayName, color: categoryColor)
                }
            }

            // Полоса относительного размера
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quinary)
                    Capsule()
                        .fill(categoryColor.opacity(0.75))
                        .frame(width: max(3, geo.size.width * CGFloat(file.size) / CGFloat(max(maxSize, 1))))
                }
            }
            .frame(height: 4)

            HStack {
                Button {
                    onSelect(file)
                } label: {
                    Label("Показать в Finder", systemImage: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.link)

                Spacer()

                Button {
                    onTrash(file)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .help("Переместить в корзину")
            }
            .opacity(isHovered ? 1 : 0.55)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHovered ? AnyShapeStyle(Color.accentColor.opacity(0.4)) : AnyShapeStyle(.quaternary), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.012 : 1)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var categoryColor: Color {
        file.category.color(variant: 0)
    }
}
