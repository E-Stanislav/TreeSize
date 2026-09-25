import SwiftUI

/// Панель деталей выбранного элемента (ТЗ 4.1): свойства и операции
struct DetailsPanelView: View {
    let node: FileNode?
    let onReveal: (FileNode) -> Void
    let onCopyPath: (FileNode) -> Void
    let onTrash: (FileNode) -> Void

    @State private var showTrashConfirmation = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            if let node {
                VStack(alignment: .leading, spacing: 14) {
                    header(node)
                    infoCard(node)
                    actions(node)
                }
            } else {
                ContentUnavailableView(
                    "Ничего не выбрано",
                    systemImage: "cursorarrow.click",
                    description: Text("Кликните по блоку на карте")
                )
                .frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .confirmationDialog(
            "Переместить «\(node?.name ?? "")» в корзину?",
            isPresented: $showTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("Переместить в корзину", role: .destructive) {
                if let node { onTrash(node) }
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    // MARK: - Шапка

    private func header(_ node: FileNode) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: node.path))
                .resizable()
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(node.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(formatBytes(node.size))
                        .font(.system(size: 15, weight: .heavy).monospacedDigit())
                        .foregroundStyle(node.category.color(variant: 0))
                    Chip(text: node.category.displayName, color: node.category.color(variant: 0))
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Свойства

    private func infoCard(_ node: FileNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if node.isDirectory {
                infoRow(icon: "doc.fill", label: "Файлов", value: formatCount(node.fileCount))
                infoRow(icon: "folder.fill", label: "Папок", value: formatCount(node.directoryCount))
            }
            infoRow(icon: "tag.fill", label: "Тип", value: node.isDirectory ? "Папка" : "Файл")
            VStack(alignment: .leading, spacing: 3) {
                Label("Путь", systemImage: "link")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(node.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(4)
                    .truncationMode(.middle)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quinary.opacity(0.4))
        )
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
        }
    }

    // MARK: - Действия

    private func actions(_ node: FileNode) -> some View {
        VStack(spacing: 8) {
            Button {
                onReveal(node)
            } label: {
                Label("Показать в Finder", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            Button {
                onCopyPath(node)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    copied = false
                }
            } label: {
                Label(copied ? "Скопировано!" : "Копировать путь", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            Button(role: .destructive) {
                showTrashConfirmation = true
            } label: {
                Label("Удалить (в корзину)", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .buttonStyle(.bordered)
    }
}
