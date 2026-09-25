import SwiftUI
import AppKit

/// Корневая модель приложения: сканирование, навигация, операции с файлами
@Observable
@MainActor
final class AppModel {
    enum Visualization: String, CaseIterable, Identifiable {
        case treemap = "Карта"
        case sunburst = "Круг"
        var id: String { rawValue }
    }

    /// Разделы боковой панели (как в CleanMyMac)
    enum Section: String, CaseIterable, Identifiable {
        case overview = "Обзор"
        case diskMap = "Диск"
        case topFiles = "Топ файлов"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overview: return "gauge.with.dots.needle.bottom.50percent"
            case .diskMap: return "square.grid.3x3.fill"
            case .topFiles: return "flame.fill"
            }
        }

        var gradient: LinearGradient {
            switch self {
            case .overview:
                LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .diskMap:
                LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .topFiles:
                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    // MARK: - Состояние

    private(set) var volumes: [VolumeInfo] = []
    private(set) var root: FileNode?
    private(set) var scannedURL: URL?
    private(set) var isScanning = false
    private(set) var filesScanned = 0
    private(set) var currentPath = ""
    private(set) var lastError: String?

    var visualization: Visualization = .treemap
    var section: Section = .overview

    /// Стек навигации по папкам; последний элемент — текущая папка
    private(set) var navigationPath: [FileNode] = []
    private(set) var selected: FileNode?
    private(set) var topFiles: [FileNode] = []

    var currentDirectory: FileNode? { navigationPath.last ?? root }
    var scanProgressText: String? {
        isScanning ? "\(formatCount(filesScanned)) файлов — \(currentPath)" : nil
    }

    private var scanTask: Task<Void, Never>?

    init() {
        volumes = VolumeService.mountedVolumes()
    }

    // MARK: - Сканирование (ТЗ 2.1.1)

    func scan(_ url: URL) {
        cancelScan()
        volumes = VolumeService.mountedVolumes()
        isScanning = true
        filesScanned = 0
        currentPath = url.path
        lastError = nil

        let securityScoped = url.startAccessingSecurityScopedResource()
        section = .diskMap
        scanTask = Task {
            defer {
                if securityScoped { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let (node, total) = try await DiskScanner.scan(root: url) { [weak self] count, path in
                    Task { @MainActor [weak self] in
                        self?.filesScanned = count
                        self?.currentPath = path
                    }
                }
                guard !Task.isCancelled else { return }
                self.root = node
                self.scannedURL = url
                self.filesScanned = total
                self.navigationPath = [node]
                self.selected = nil
                self.computeTopFiles()
            } catch is CancellationError {
                // пользователь отменил сканирование
            } catch {
                self.lastError = error.localizedDescription
            }
            self.isScanning = false
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    func clearError() {
        lastError = nil
    }

    // MARK: - Навигация (drill-down, ТЗ 2.1.2)

    func navigate(to node: FileNode) {
        guard node.isDirectory, !node.children.isEmpty else {
            selected = node
            return
        }
        navigationPath.append(node)
        selected = node
    }

    func navigateUp() {
        if navigationPath.count > 1 {
            navigationPath.removeLast()
            selected = navigationPath.last
        }
    }

    func navigate(toDepth index: Int) {
        guard index >= 0, index < navigationPath.count else { return }
        navigationPath = Array(navigationPath[...index])
        selected = navigationPath.last
    }

    func select(_ node: FileNode?) {
        selected = node
    }

    // MARK: - Операции с файлами (ТЗ 2.2.1)

    func revealInFinder(_ node: FileNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    func copyPath(_ node: FileNode) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.path, forType: .string)
    }

    /// Перемещает файл/папку в корзину и обновляет дерево
    func trash(_ node: FileNode) {
        NSWorkspace.shared.recycle([node.url]) { [weak self] trashedURLs, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.lastError = "Не удалось переместить в корзину: \(error.localizedDescription)"
                } else {
                    self.removeFromTree(node)
                }
                _ = trashedURLs
            }
        }
    }

    /// Удаляет узел из дерева и пересчитывает размеры у предков
    private func removeFromTree(_ node: FileNode) {
        guard let parent = node.parent else {
            root = nil
            navigationPath = []
            selected = nil
            return
        }
        parent.children.removeAll { $0.id == node.id }
        var ancestor: FileNode? = parent
        while let current = ancestor {
            current.size -= node.size
            current.fileCount -= node.fileCount
            if node.isDirectory { current.directoryCount -= node.directoryCount + 1 }
            ancestor = current.parent
        }
        if selected?.id == node.id { selected = parent }
        // Если удалили узел из текущего пути навигации — усекаем путь до его родителя
        if let index = navigationPath.firstIndex(where: { $0.id == node.id }) {
            navigationPath = Array(navigationPath[..<index])
            if navigationPath.isEmpty { navigationPath = [parent] }
            selected = navigationPath.last
        }
        computeTopFiles()
    }

    // MARK: - Отчёты (ТЗ 2.1.3)

    /// Топ-N самых больших файлов (US-1)
    private func computeTopFiles() {
        guard let root else {
            topFiles = []
            return
        }
        let scanRoot = root
        Task.detached(priority: .utility) {
            var stack: [FileNode] = [scanRoot]
            var buffer: [(FileNode, Int64)] = []
            buffer.reserveCapacity(200)
            while let node = stack.popLast() {
                if node.isDirectory {
                    stack.append(contentsOf: node.children)
                } else if node.size > 0 {
                    buffer.append((node, node.size))
                }
            }
            buffer.sort { $0.1 > $1.1 }
            let result = Array(buffer.prefix(200).map(\.0))
            await MainActor.run { [weak self] in
                self?.topFiles = result
            }
        }
    }
}
