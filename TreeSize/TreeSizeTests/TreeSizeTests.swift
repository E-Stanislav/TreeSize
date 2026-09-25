import Testing
import Foundation
import CoreGraphics
@testable import TreeSize

struct TreeSizeTests {

    // MARK: - Категории файлов

    @Test func categoryClassification() {
        func cat(_ path: String, dir: Bool = false) -> FileCategory {
            FileCategory.classify(url: URL(fileURLWithPath: path), isDirectory: dir)
        }
        #expect(cat("video/movie.mp4") == .media)
        #expect(cat("photo/img.heic") == .image)
        #expect(cat("docs/report.pdf") == .document)
        #expect(cat("arch/backup.zip") == .archive)
        #expect(cat("code/main.swift") == .developer)
        #expect(cat("unknown.xyz") == .other)
        #expect(cat("/Applications/Safari.app", dir: true) == .application)
        #expect(cat("/Users/x/Library/Caches/com.foo", dir: true) == .cache)
    }

    // MARK: - Treemap layout

    private func makeNode(_ size: Int64, children: [FileNode] = []) -> FileNode {
        let node = FileNode(url: URL(fileURLWithPath: "/tmp/node-\(UUID().uuidString)"), isDirectory: children.isEmpty ? false : true)
        node.size = size
        node.children = children
        return node
    }

    @Test func treemapCoversFullRect() {
        let nodes = (0..<20).map { _ in makeNode(Int64.random(in: 100...10_000)) }
        let rect = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let slices = TreemapLayout.layout(nodes, in: rect)

        #expect(slices.count == 20)
        // Суммарная площадь блоков равна площади прямоугольника (без отступов)
        let area = slices.reduce(CGFloat(0)) { $0 + $1.rect.width * $1.rect.height }
        #expect(abs(area - rect.width * rect.height) < 1)
        // Все блоки внутри прямоугольника
        for slice in slices {
            #expect(rect.contains(slice.rect))
        }
    }

    @Test func treemapEmptyInput() {
        #expect(TreemapLayout.layout([], in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty)
        let zero = makeNode(0)
        #expect(TreemapLayout.layout([zero], in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty)
    }

    @Test func treemapProportionality() {
        // Блок в 3 раза больше — площадь примерно в 3 раза больше
        let big = makeNode(3000)
        let small = makeNode(1000)
        let slices = TreemapLayout.layout([big, small], in: CGRect(x: 0, y: 0, width: 300, height: 300))
        guard let bigSlice = slices.first(where: { $0.node === big }),
              let smallSlice = slices.first(where: { $0.node === small }) else {
            Issue.record("slices not found")
            return
        }
        let ratio = (bigSlice.rect.width * bigSlice.rect.height) / (smallSlice.rect.width * smallSlice.rect.height)
        #expect(abs(ratio - 3) < 0.05)
    }

    // MARK: - Сканер

    @Test func scannerAggregatesSizes() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("treesize-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data(count: 100_000).write(to: dir.appendingPathComponent("a.bin"))
        let sub = dir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(count: 50_000).write(to: sub.appendingPathComponent("b.bin"))

        let (root, filesScanned) = try await DiskScanner.scan(root: dir) { _, _ in }
        #expect(root.isDirectory)
        #expect(root.fileCount == 2)
        #expect(root.directoryCount == 1)
        #expect(filesScanned >= 2)
        #expect(root.size > 150_000) // с учётом выделения блоков на диске
        #expect(root.children.count == 2)
    }
}
