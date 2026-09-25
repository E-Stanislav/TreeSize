import SwiftUI

/// Интерактивная treemap-визуализация (ТЗ 2.1.2): клик по папке — drill-down,
/// клик по файлу — выбор, hover — подсветка
struct TreemapView: View {
    let directory: FileNode
    let selected: FileNode?
    let onTap: (FileNode) -> Void

    @State private var hovered: FileNode?

    var body: some View {
        GeometryReader { geo in
            let slices = TreemapLayout.flatten(node: directory, in: CGRect(origin: .zero, size: geo.size))
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Canvas { context, _ in
                    draw(slices: slices, in: &context)
                }
            }
            .clipShape(Rectangle())
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    if let node = hitTest(value.location, slices: slices) {
                        onTap(node)
                    }
                }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hovered = hitTest(location, slices: slices)
                case .ended:
                    hovered = nil
                }
            }
        }
    }

    private func draw(slices: [TreeMapSlice], in context: inout GraphicsContext) {
        for (index, slice) in slices.enumerated() {
            let node = slice.node
            let rect = slice.rect
            let isHovered = hovered?.id == node.id
            let isSelected = selected?.id == node.id

            let path = Path(rect)
            context.fill(path, with: .color(node.category.color(variant: index / 3 + slice.depth)))

            if rect.width > 34 && rect.height > 18 {
                let nameText: Text = Text(node.name)
                    .font(.system(size: min(11, rect.height * 0.28), weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                context.draw(nameText, in: rect.insetBy(dx: 4, dy: 3))

                if rect.height > 34 {
                    let sizeText: Text = Text(formatBytes(node.size))
                        .font(.system(size: 10))
                        .foregroundColor(.black.opacity(0.6))
                    context.draw(sizeText, in: CGRect(
                        x: rect.minX + 4, y: rect.minY + 3 + min(15, rect.height * 0.3),
                        width: rect.width - 8, height: 12
                    ))
                }
            }

            if isHovered || isSelected {
                context.stroke(
                    path,
                    with: .color(isSelected ? .yellow : .white),
                    lineWidth: isSelected ? 2.5 : 1.5
                )
            } else {
                context.stroke(path, with: .color(.black.opacity(0.18)), lineWidth: 0.5)
            }
        }
    }

    /// Самый глубокий (мелкий по площади) блок, содержащий точку
    private func hitTest(_ point: CGPoint, slices: [TreeMapSlice]) -> FileNode? {
        var best: TreeMapSlice?
        for slice in slices where slice.rect.contains(point) {
            if best == nil || slice.rect.width * slice.rect.height < best!.rect.width * best!.rect.height {
                best = slice
            }
        }
        return best?.node
    }
}
