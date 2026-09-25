import Foundation

/// Асинхронный многопоточный сканер файловой системы (ТЗ 2.1.1, 6.3)
nonisolated enum DiskScanner {
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
        .totalFileAllocatedSizeKey, .fileSizeKey,
    ]

    /// Расширения, которые считаем единым файлом, а не раскрываем как папку
    private static let packageExtensions: Set<String> = [
        "app", "appex", "bundle", "framework", "plugin", "kext", "xpc",
        "photoslibrary", "calendar", "lock",
    ]

    /// Счётчик обработанных файлов для прогресса
    private actor ScanCounter {
        var count = 0
        var lastReported = 0

        func next() -> (count: Int, shouldReport: Bool) {
            count += 1
            if count - lastReported >= 1000 {
                lastReported = count
                return (count, true)
            }
            return (count, false)
        }

        func finalCount() -> Int { count }
    }

    /// Сканирует каталог рекурсивно. Прогресс: (кол-во файлов, текущий путь).
    nonisolated static func scan(
        root url: URL,
        progress: @escaping @Sendable (_ filesScanned: Int, _ currentPath: String) -> Void
    ) async throws -> (root: FileNode, filesScanned: Int) {
        let counter = ScanCounter()
        let node = try await scanNode(url, counter: counter, progress: progress)
        let total = await counter.finalCount()
        return (node, total)
    }

    private nonisolated static func scanNode(
        _ url: URL,
        counter: ScanCounter,
        progress: @escaping @Sendable (Int, String) -> Void
    ) async throws -> FileNode {
        try Task.checkCancellation()

        guard let values = try? url.resourceValues(forKeys: resourceKeys) else {
            throw CancellationError()
        }
        if values.isSymbolicLink == true {
            return FileNode(url: url, isDirectory: false)
        }

        let isDirectory = values.isDirectory ?? false
        let isPackage = (values.isPackage ?? false)
            || packageExtensions.contains(url.pathExtension.lowercased())

        // Пакеты (.app и т.п.) считаем одним файлом: размер берём рекурсивно из ресурсов
        if isDirectory && !isPackage {
            let node = FileNode(url: url, isDirectory: true)
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys)
            )) ?? []

            var children = await withTaskGroup(of: FileNode?.self) { group in
                for childURL in contents {
                    group.addTask {
                        try? await scanNode(childURL, counter: counter, progress: progress)
                    }
                }
                var result: [FileNode] = []
                result.reserveCapacity(contents.count)
                for await child in group {
                    if let child { result.append(child) }
                }
                return result
            }

            children.sort { $0.size > $1.size }
            node.children = children
            node.size = children.reduce(Int64(0)) { $0 + $1.size }
            node.fileCount = children.reduce(0) { $0 + ($1.isDirectory ? $1.fileCount : 1) }
            node.directoryCount = children.reduce(0) { $0 + ($1.isDirectory ? $1.directoryCount + 1 : 0) }
            for child in children { child.parent = node }
            return node
        } else {
            let size = values.totalFileAllocatedSize ?? values.fileSize ?? 0
            let node = FileNode(url: url, isDirectory: isDirectory)
            node.size = Int64(size)
            node.fileCount = 1

            let (count, shouldReport) = await counter.next()
            if shouldReport {
                progress(count, url.path)
            }
            return node
        }
    }
}
