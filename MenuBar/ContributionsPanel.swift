import SwiftUI

struct ContributionsPanel: View {
    @ObservedObject var store: ContributionsStore
    @State private var usernameDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.username.isEmpty {
                Text("Enter a GitHub username to see their public contributions.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let summary = store.summary {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(summary.today)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(summary.today > 0 ? Color.green : Color.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("This week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(summary.weekTotal)")
                            .font(.title2.weight(.semibold))
                    }
                }
                WeekRow(days: summary.week)
            } else if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Divider()

            TextField("GitHub username", text: $usernameDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { store.username = usernameDraft.trimmingCharacters(in: .whitespaces) }

            HStack {
                if let lastUpdated = store.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoading || store.username.isEmpty)
                .help("Refresh")
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear { usernameDraft = store.username }
        .task { await store.refreshIfStale() }
    }
}

private struct WeekRow: View {
    let days: [ContributionDay]

    private var maxCount: Int { max(days.compactMap(\.count).max() ?? 0, 1) }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.date) { day in
                VStack(spacing: 3) {
                    Text(day.count.map(String.init) ?? " ")
                        .font(.caption2.monospacedDigit())
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: day))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if Calendar.current.isDateInToday(day.date) {
                                RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.6), lineWidth: 1)
                            }
                        }
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func color(for day: ContributionDay) -> Color {
        guard let count = day.count else { return Color.secondary.opacity(0.08) }
        guard count > 0 else { return Color.secondary.opacity(0.2) }
        return Color.green.opacity(0.35 + 0.65 * Double(count) / Double(maxCount))
    }
}
