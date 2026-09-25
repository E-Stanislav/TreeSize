import SwiftUI

/// Sunburst-диаграмма (ТЗ 2.1.2): кольца — уровни иерархии,
/// углы пропорциональны размерам. Клик по сектору — drill-down.
struct SunburstView: View {
    let directory: FileNode
    let selected: FileNode?
    let onTap: (FileNode) -> Void

    @State private var hovered: FileNode?

    private struct Segment {
        let node: FileNode
        let ring: Int
        let startAngle: Angle
        let endAngle: Angle
        let innerRadius: CGFloat
        let outerRadius: CGFloat
        let variant: Int
    }

    private static let ringWidth: CGFloat = 52
    private static let maxDepth = 4

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 4
            let ringWidth = min(Self.ringWidth, maxRadius / CGFloat(Self.maxDepth))
            let segments = Self.buildSegments(
                from: directory, ringWidth: ringWidth, maxRadius: maxRadius
            )
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Canvas { context, _ in
                    draw(segments: segments, center: center, in: &context)
                }
            }
            .clipShape(Rectangle())
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    if let node = hitTest(value.location, center: center, segments: segments) {
                        onTap(node)
                    }
                }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hovered = hitTest(location, center: center, segments: segments)
                case .ended:
                    hovered = nil
                }
            }
        }
    }

    // MARK: - Геометрия сегментов

    private static func buildSegments(
        from node: FileNode, ringWidth: CGFloat, maxRadius: CGFloat
    ) -> [Segment] {
        var segments: [Segment] = []
        let maxRings = max(1, Int(maxRadius / max(ringWidth, 1)))
        let depthLimit = min(Self.maxDepth, maxRings)

        func addChildren(_ parent: FileNode, ring: Int, start: Angle, end: Angle, variantBase: Int) {
            guard ring < depthLimit, end.radians > start.radians else { return }
            let total = parent.children.reduce(Int64(0)) { $0 + $1.size }
            guard total > 0 else { return }
            let sweep = end.radians - start.radians
            var current = start.radians
            for (index, child) in parent.children.enumerated() where child.size > 0 {
                let fraction = CGFloat(child.size) / CGFloat(total)
                let childSweep = sweep * fraction
                guard childSweep > 0.004 else { continue } // ~0.23°
                let segStart = Angle.radians(current)
                let segEnd = Angle.radians(current + childSweep)
                let inner = CGFloat(ring) * ringWidth
                segments.append(Segment(
                    node: child, ring: ring,
                    startAngle: segStart, endAngle: segEnd,
                    innerRadius: inner, outerRadius: inner + ringWidth - 1.5,
                    variant: variantBase + index
                ))
                if child.isDirectory {
                    addChildren(child, ring: ring + 1, start: segStart, end: segEnd, variantBase: variantBase + index)
                }
                current += childSweep
            }
        }

        addChildren(node, ring: 0, start: .degrees(-90), end: .degrees(270), variantBase: 0)
        return segments
    }

    // MARK: - Отрисовка

    private func draw(segments: [Segment], center: CGPoint, in context: inout GraphicsContext) {
        for segment in segments {
            var path = Path()
            path.addArc(
                center: center, radius: segment.outerRadius,
                startAngle: segment.startAngle, endAngle: segment.endAngle, clockwise: false
            )
            path.addArc(
                center: center, radius: segment.innerRadius,
                startAngle: segment.endAngle, endAngle: segment.startAngle, clockwise: true
            )
            path.closeSubpath()

            context.fill(
                path,
                with: .color(segment.node.category.color(variant: segment.variant / 3 + segment.ring))
            )

            let isHighlighted = hovered?.id == segment.node.id || selected?.id == segment.node.id
            if isHighlighted {
                context.stroke(path, with: .color(.yellow), lineWidth: 2)
            } else {
                context.stroke(path, with: .color(.black.opacity(0.15)), lineWidth: 0.5)
            }

            // Подпись на достаточно широких внешних сегментах
            let sweep = segment.endAngle.radians - segment.startAngle.radians
            let midRadius = (segment.innerRadius + segment.outerRadius) / 2
            if sweep * midRadius > 34, segment.outerRadius - segment.innerRadius > 16 {
                let midAngle = (segment.startAngle.radians + segment.endAngle.radians) / 2
                let position = CGPoint(
                    x: center.x + CGFloat(cos(midAngle)) * midRadius,
                    y: center.y + CGFloat(sin(midAngle)) * midRadius
                )
                let label: Text = Text(segment.node.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                context.draw(label, at: position)
            }
        }
    }

    private func hitTest(_ point: CGPoint, center: CGPoint, segments: [Segment]) -> FileNode? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }
        for segment in segments
        where distance >= segment.innerRadius && distance <= segment.outerRadius {
            var start = segment.startAngle.radians
            var end = segment.endAngle.radians
            if start < 0 { start += 2 * .pi; end += 2 * .pi }
            if angle >= start && angle <= end {
                return segment.node
            }
        }
        return nil
    }
}
