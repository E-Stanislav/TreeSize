import Foundation
import CoreGraphics

/// Прямоугольник treemap, привязанный к узлу дерева
nonisolated struct TreeMapSlice {
    let node: FileNode
    let rect: CGRect
    let depth: Int
}

/// Squarified treemap layout (Bruls et al.) — ТЗ 2.1.2
nonisolated enum TreemapLayout {
    /// Раскладывает узлы по прямоугольникам пропорционально размерам
    static func layout(_ nodes: [FileNode], in rect: CGRect) -> [TreeMapSlice] {
        let items = nodes.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !items.isEmpty, rect.width > 0, rect.height > 0 else { return [] }

        var slices: [TreeMapSlice] = []
        var remaining = rect
        var idx = 0

        while idx < items.count {
            let sum = items[idx...].reduce(Int64(0)) { $0 + $1.size }
            let horizontal = remaining.width >= remaining.height
            let longSide = horizontal ? remaining.width : remaining.height
            let shortSide = horizontal ? remaining.height : remaining.width

            func thickness(_ rowSum: Int64) -> CGFloat {
                CGFloat(rowSum) / CGFloat(sum) * shortSide
            }
            func worstRatio(_ row: [FileNode], _ rowSum: Int64) -> CGFloat {
                guard rowSum > 0, longSide > 0, shortSide > 0 else { return .infinity }
                let t = thickness(rowSum)
                var worst: CGFloat = 0
                for n in row {
                    let len = CGFloat(n.size) / CGFloat(rowSum) * longSide
                    worst = max(worst, max(len / t, t / len))
                }
                return worst
            }

            var row: [FileNode] = []
            var rowSum: Int64 = 0
            while idx < items.count {
                let next = items[idx]
                if row.isEmpty {
                    row = [next]; rowSum = next.size; idx += 1
                    continue
                }
                if worstRatio(row + [next], rowSum + next.size) <= worstRatio(row, rowSum) {
                    row.append(next); rowSum += next.size; idx += 1
                } else {
                    break
                }
            }

            let t = thickness(rowSum)
            var offset: CGFloat = 0
            for n in row {
                let len = CGFloat(n.size) / CGFloat(rowSum) * longSide
                let frame = horizontal
                    ? CGRect(x: remaining.minX + offset, y: remaining.minY, width: len, height: t)
                    : CGRect(x: remaining.minX, y: remaining.minY + offset, width: t, height: len)
                slices.append(TreeMapSlice(node: n, rect: frame, depth: 0))
                offset += len
            }

            if horizontal {
                remaining = CGRect(x: remaining.minX, y: remaining.minY + t,
                                   width: remaining.width, height: remaining.height - t)
            } else {
                remaining = CGRect(x: remaining.minX + t, y: remaining.minY,
                                   width: remaining.width - t, height: remaining.height)
            }
        }
        return slices
    }

    /// Раскладывает дерево рекурсивно до заданной глубины, пропуская слишком мелкие блоки
    static func flatten(
        node: FileNode,
        in rect: CGRect,
        depth: Int = 0,
        maxDepth: Int = 2,
        minChildArea: CGFloat = 900,
        minChildWidth: CGFloat = 24
    ) -> [TreeMapSlice] {
        guard depth < maxDepth, !node.children.isEmpty else { return [] }
        var result: [TreeMapSlice] = []
        let slices = layout(node.children, in: rect)
        for slice in slices {
            let r = slice.rect.insetBy(dx: 1, dy: 1)
            guard r.width > 0, r.height > 0 else { continue }
            result.append(TreeMapSlice(node: slice.node, rect: r, depth: depth))
            if slice.node.isDirectory,
               r.width * r.height >= minChildArea, r.width >= minChildWidth, r.height >= minChildWidth {
                let inner = r.insetBy(dx: 1.5, dy: 1.5)
                result.append(contentsOf: flatten(
                    node: slice.node, in: inner,
                    depth: depth + 1, maxDepth: maxDepth,
                    minChildArea: minChildArea, minChildWidth: minChildWidth
                ))
            }
        }
        return result
    }
}
