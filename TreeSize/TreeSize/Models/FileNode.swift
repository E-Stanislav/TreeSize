import Foundation

/// Узел дерева файловой системы: файл, папка или бандл (ТЗ 2.1.1)
nonisolated final class FileNode: Identifiable, Hashable, @unchecked Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let category: FileCategory

    /// Размер на диске в байтах (для папок — сумма детей)
    var size: Int64 = 0
    /// Количество файлов внутри (для файлов — 1)
    var fileCount: Int = 0
    /// Количество вложенных папок
    var directoryCount: Int = 0
    var children: [FileNode] = []
    weak var parent: FileNode?

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.category = FileCategory.classify(url: url, isDirectory: isDirectory)
    }

    var path: String { url.path }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Форматирование размеров
nonisolated func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

nonisolated func formatCount(_ count: Int) -> String {
    count.formatted(.number.grouping(.automatic))
}
