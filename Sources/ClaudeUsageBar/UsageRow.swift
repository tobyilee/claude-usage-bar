import SwiftUI

struct UsageRow: View {
    let icon: String
    let title: String
    let percent: Int?
    let resetsAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let pct = percent {
                    Text("\(pct)%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            ProgressView(value: Double(percent ?? 0), total: 100)
                .tint(barTint)
            if let resets = resetsAt {
                Text(Formatters.resetsIn(resets))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var barTint: Color {
        switch percent ?? 0 {
        case ..<50: return .accentColor
        case 50..<80: return .yellow
        case 80..<95: return .orange
        default: return .red
        }
    }
}
