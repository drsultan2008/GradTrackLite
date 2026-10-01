import SwiftUI

/// VoiceOver-friendly status badge.
struct StatusBadge: View {
    let status: TeamStatus

    var body: some View {
        Label(status.label, systemImage: status.systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.15), in: Capsule())
            .foregroundStyle(status.color)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(status.label)
    }
}

/// A thin progress bar that supports Dynamic Type-independent height.
struct PercentBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemFill))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value / 100)) * geo.size.width)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("a11y.percent"))
        .accessibilityValue(Text("\(Int(value))%"))
    }
}

/// A labeled percentage with a progress bar.
struct ProgressRow: View {
    let label: String
    let percent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(percent))%")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            PercentBar(value: percent, tint: tint)
        }
        .padding(.vertical, 2)
    }

    private var tint: Color {
        if percent >= 70 { return .green }
        if percent >= 40 { return .orange }
        return .red
    }
}
