import SwiftUI

struct MenubarLabel: View {
    @Bindable var store: UsageStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .foregroundStyle(iconTint)
            trailing
        }
        .onAppear { store.start() }
    }

    @ViewBuilder
    private var trailing: some View {
        switch store.menubarState {
        case .loading:
            Text("…").foregroundStyle(.secondary)
        case .ok(let pct):
            Text("\(pct)%")
        case .stale(let pct):
            Text("\(pct)%").foregroundStyle(.secondary)
        case .authBad:
            EmptyView()
        }
    }

    private var iconName: String {
        switch store.menubarState {
        case .loading: return "gauge.with.dots.needle.0percent"
        case .authBad: return "exclamationmark.circle.fill"
        case .ok(let pct), .stale(let pct):
            switch pct {
            case ..<33: return "gauge.with.dots.needle.0percent"
            case 33..<55: return "gauge.with.dots.needle.33percent"
            case 55..<78: return "gauge.with.dots.needle.50percent"
            case 78..<95: return "gauge.with.dots.needle.67percent"
            default: return "gauge.with.dots.needle.100percent"
            }
        }
    }

    private var iconTint: Color {
        switch store.menubarState {
        case .loading: return .secondary
        case .authBad: return .red
        case .stale: return .secondary
        case .ok(let pct):
            switch pct {
            case ..<50: return .secondary
            case 50..<80: return .yellow
            case 80..<95: return .orange
            default: return .red
            }
        }
    }
}
