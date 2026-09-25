import SwiftUI

/// Боковая панель навигации в стиле CleanMyMac
struct SidebarView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Divider().padding(.horizontal, 8).padding(.vertical, 6)
            ForEach(AppModel.Section.allCases) { section in
                navItem(section)
            }
            Spacer()
            footer
        }
        .padding(12)
        .frame(width: 216)
        .background(.bar)
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [.blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text("TreeSize")
                    .font(.system(size: 14, weight: .bold))
                Text("Анализ диска")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    // MARK: - Пункты навигации

    private func navItem(_ section: AppModel.Section) -> some View {
        let isSelected = model.section == section
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                model.section = section
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(section.gradient)
                    )
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.primary.opacity(0.09))
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Подвал: занятость системного диска

    private var footer: some View {
        Group {
            if let volume = model.volumes.first(where: \.isInternal) ?? model.volumes.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(volume.name)
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("\(Int((volume.usedFraction * 100).rounded()))%")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(volume.usedFraction < 0.7 ? .green : volume.usedFraction < 0.9 ? .orange : .red)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quinary)
                            Capsule()
                                .fill(volume.usedFraction < 0.7 ? Color.green : volume.usedFraction < 0.9 ? Color.orange : Color.red)
                                .frame(width: max(4, geo.size.width * volume.usedFraction))
                                .animation(.easeInOut(duration: 0.4), value: volume.usedFraction)
                        }
                    }
                    .frame(height: 5)
                    Text("Свободно \(formatBytes(volume.availableCapacity))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quinary.opacity(0.5))
                )
                .padding(.horizontal, 2)
            }
        }
    }
}
