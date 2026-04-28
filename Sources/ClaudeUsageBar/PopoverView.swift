import AppKit
import SwiftUI

struct PopoverView: View {
    @Bindable var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .foregroundStyle(.tint)
                if let tier = store.tier, !tier.isEmpty {
                    Text("Claude " + tier.capitalized)
                        .font(.headline)
                } else {
                    Text("Claude Usage")
                        .font(.headline)
                }
            }

            UsageRow(
                icon: "timer",
                title: "5-hour session",
                percent: store.usage?.five_hour?.utilization,
                resetsAt: store.usage?.five_hour?.resets_at
            )

            UsageRow(
                icon: "calendar",
                title: "Weekly (all)",
                percent: store.usage?.seven_day?.utilization,
                resetsAt: store.usage?.seven_day?.resets_at
            )

            UsageRow(
                icon: "sparkle",
                title: "Weekly (Sonnet)",
                percent: store.usage?.seven_day_sonnet?.utilization,
                resetsAt: store.usage?.seven_day_sonnet?.resets_at
            )

            Divider()

            statusLine

            HStack {
                Button {
                    store.refreshNow()
                } label: {
                    Label("Refresh now", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    @ViewBuilder
    private var statusLine: some View {
        if let err = store.lastError {
            Text(err)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        } else if let updated = store.lastUpdated {
            Text("Last updated " + Formatters.updatedAgo(updated))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Loading…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
