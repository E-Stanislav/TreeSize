import SwiftUI

/// Экран «Обзор»: сводка и карточки томов (в стиле CleanMyMac Smart Scan)
struct DashboardView: View {
    let model: AppModel
    let onChooseFolder: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Обзор")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))

                if let root = model.root {
                    statsSection(root: root)
                } else {
                    hero
                }

                volumesSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Приветственный блок

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.25), .purple.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 84, height: 84)
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 66, height: 66)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 6) {
                Text("Что занимает место на диске?")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Просканируйте диск — приложение построит интерактивную карту,\nнайдёт самые большие файлы и поможет освободить место")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                onChooseFolder()
            } label: {
                Label("Выбрать папку для анализа", systemImage: "folder.badge.plus")
                    .frame(minWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
    }

    // MARK: - Статистика после сканирования

    private func statsSection(root: FileNode) -> some View {
        HStack(spacing: 12) {
            statCard(icon: "externaldrive.fill", tint: .blue,
                     title: "Просканировано", value: formatBytes(root.size))
            statCard(icon: "doc.fill", tint: .purple,
                     title: "Файлов", value: formatCount(root.fileCount))
            statCard(icon: "folder.fill", tint: .orange,
                     title: "Папок", value: formatCount(root.directoryCount))
            Button {
                model.section = .diskMap
            } label: {
                Label("Открыть карту диска", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func statCard(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .cardStyle(padding: 12)
    }

    // MARK: - Карточки томов

    private var volumesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Диски")
                .font(.system(.headline, design: .rounded))
            if model.volumes.isEmpty {
                Text("Томы не найдены")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.volumes) { volume in
                        volumeCard(volume)
                    }
                }
            }
        }
    }

    private func volumeCard(_ volume: VolumeInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: volume.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(volume.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("\(formatBytes(volume.usedCapacity)) из \(formatBytes(volume.totalCapacity))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                UsageRing(fraction: volume.usedFraction, lineWidth: 5)
                    .frame(width: 44, height: 44)
            }
            Button {
                model.scan(volume.url)
            } label: {
                Label("Анализировать", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(model.isScanning)
        }
        .cardStyle(padding: 14)
    }
}
