import SwiftUI

// Общие элементы дизайна в стиле CleanMyMac: карточки, кольца занятости, чипы

extension View {
    /// Карточка: материал, скругления, тонкая рамка и мягкая тень
    func cardStyle(padding: CGFloat = 16, radius: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }
}

/// Кольцевой индикатор занятости диска
struct UsageRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 9
    var caption: String = "занято"

    var body: some View {
        ZStack {
            Circle().stroke(.quinary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.015, min(fraction, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: fraction)
            VStack(spacing: 0) {
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .monospacedDigit()
                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var color: Color {
        fraction < 0.7 ? .green : fraction < 0.9 ? .orange : .red
    }
}

/// Цветной чип (категория файла, хлебная крошка)
struct Chip: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color == .secondary ? .secondary : color)
    }
}
