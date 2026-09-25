import SwiftUI

/// Главное окно: боковая панель + контент раздела (ТЗ 4.1)
struct ContentView: View {
    @State private var model = AppModel()
    @State private var trashTarget: FileNode?

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(model: model)
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1020, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("TreeSize")
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.lastError ?? "")
        }
        .confirmationDialog(
            "Переместить «\(trashTarget?.name ?? "")» в корзину?",
            isPresented: trashBinding,
            titleVisibility: .visible
        ) {
            Button("Переместить в корзину", role: .destructive) {
                if let target = trashTarget { model.trash(target) }
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.lastError != nil }, set: { if !$0 { model.clearError() } })
    }
    private var trashBinding: Binding<Bool> {
        Binding(get: { trashTarget != nil }, set: { if !$0 { trashTarget = nil } })
    }

    // MARK: - Контент раздела

    @ViewBuilder
    private var content: some View {
        switch model.section {
        case .overview:
            DashboardView(model: model, onChooseFolder: chooseFolder)
        case .diskMap:
            diskMapSection
        case .topFiles:
            VStack(spacing: 0) {
                sectionHeader(
                    title: "Топ файлов",
                    subtitle: model.root.map { "Самые большие файлы в \(formatBytes($0.size)) данных" }
                )
                TopFilesView(
                    files: model.topFiles,
                    onSelect: { model.select($0) },
                    onTrash: { trashTarget = $0 }
                )
            }
        }
    }

    // MARK: - Раздел «Диск»

    private var diskMapSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Диск",
                subtitle: model.scannedURL?.path,
                trailing: {
                    if model.isScanning {
                        Button {
                            model.cancelScan()
                        } label: {
                            Label("Стоп", systemImage: "stop.fill")
                        }
                        .controlSize(.regular)
                        .keyboardShortcut(.cancelAction)
                    } else if model.scannedURL != nil {
                        Button {
                            if let url = model.scannedURL { model.scan(url) }
                        } label: {
                            Label("Пересканировать", systemImage: "arrow.clockwise")
                        }
                    }
                    Picker("Визуализация", selection: $model.visualization) {
                        ForEach(AppModel.Visualization.allCases) { viz in
                            Text(viz.rawValue).tag(viz)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                    .disabled(model.currentDirectory == nil)
                }
            )

            if model.isScanning {
                progressBanner
            }

            if let directory = model.currentDirectory {
                HSplitView {
                    VStack(spacing: 8) {
                        breadcrumb(directory: directory)
                        mapCard(directory)
                        legend
                    }
                    .padding(12)
                    DetailsPanelView(
                        node: model.selected ?? model.currentDirectory,
                        onReveal: model.revealInFinder,
                        onCopyPath: model.copyPath,
                        onTrash: { trashTarget = $0 }
                    )
                    .frame(minWidth: 270, maxWidth: 300)
                    .padding(.vertical, 12)
                    .padding(.trailing, 12)
                }
            } else {
                emptyMapState
            }
        }
    }

    private func sectionHeader<Trailing: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var progressBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(model.scanProgressText ?? "Сканирование…")
                .font(.callout.monospacedDigit())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text("Esc — отменить")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    /// Хлебные крошки-чипы для drill-down навигации
    private func breadcrumb(directory: FileNode) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(model.navigationPath.enumerated()), id: \.element.id) { index, node in
                    let isCurrent = index == model.navigationPath.count - 1
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    Button {
                        model.navigate(toDepth: index)
                    } label: {
                        HStack(spacing: 5) {
                            if isCurrent {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 9))
                            }
                            Text(node.name.isEmpty ? "/" : node.name)
                                .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(isCurrent ? AnyShapeStyle(Color.accentColor.opacity(0.2)) : AnyShapeStyle(.quaternary.opacity(0.6)))
                        )
                        .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if model.navigationPath.count > 1 {
                    Button {
                        model.navigateUp()
                    } label: {
                        Label("Вверх", systemImage: "arrow.up")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.upArrow, modifiers: .command)
                }
            }
        }
    }

    private func mapCard(_ directory: FileNode) -> some View {
        Group {
            switch model.visualization {
            case .treemap:
                TreemapView(directory: directory, selected: model.selected, onTap: handleMapTap)
            case .sunburst:
                SunburstView(directory: directory, selected: model.selected, onTap: handleMapTap)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FileCategory.allCases, id: \.self) { category in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(category.color(variant: 0))
                            .frame(width: 7, height: 7)
                        Text(category.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var emptyMapState: some View {
        ContentUnavailableView {
            Label("Диск не просканирован", systemImage: "square.grid.3x3")
        } description: {
            Text("Выберите папку на экране «Обзор» или просканируйте том")
        } actions: {
            Button("Выбрать папку…") { chooseFolder() }
                .buttonStyle(.borderedProminent)
            Button("К обзору") { model.section = .overview }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleMapTap(_ node: FileNode) {
        model.navigate(to: node)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Выберите папку или том для анализа"
        if panel.runModal() == .OK, let url = panel.url {
            model.scan(url)
        }
    }
}
