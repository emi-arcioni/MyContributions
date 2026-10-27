import AppKit
import SwiftUI

@main
struct MyContributionsApp: App {
    @StateObject private var store = ContributionsStore()

    var body: some Scene {
        MenuBarExtra {
            ContributionsPanel(store: store)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: .githubMark)
                Text(store.summary.map { "\($0.today)" } ?? "–")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class ContributionsStore: ObservableObject {
    @Published var username: String {
        didSet {
            UserDefaults.standard.set(username, forKey: "username")
            summary = nil
            Task { await refresh() }
        }
    }
    @Published private(set) var summary: ContributionSummary?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?

    private var loop: Task<Void, Never>?

    init() {
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                // Every 30 minutes, and right after midnight so "today" resets.
                let calendar = Calendar.current
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))!
                let wait = min(30 * 60, tomorrow.timeIntervalSinceNow + 5)
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    func refresh() async {
        guard !username.isEmpty else {
            summary = nil
            errorMessage = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await ContributionsService(username: username).fetchSummary()
            errorMessage = nil
            lastUpdated = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Refresh when the panel opens, unless the data is fresh.
    func refreshIfStale() async {
        if let lastUpdated, lastUpdated.timeIntervalSinceNow > -5 * 60 { return }
        await refresh()
    }
}

extension NSImage {
    /// GitHub's "mark-github" Octicon (https://primer.style/octicons), as a template
    /// image so the menu bar tints it for light and dark mode.
    static let githubMark: NSImage = {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><path d="M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 0 1-5.45 7.59c-.4.08-.55-.17-.55-.38 0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2 3.65-.88 3.65-3.95 0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0 0-.67-.22-2.2.82-.64-.18-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03-2.2-.82-2.2-.82-.44 1.1-.16 1.92-.08 2.12-.51.56-.82 1.28-.82 2.15 0 3.06 1.86 3.75 3.64 3.95-.23.2-.44.55-.51 1.07-.46.21-1.61.55-2.33-.66-.15-.24-.6-.83-1.23-.82-.67.01-.27.38.01.53.34.19.73.9.82 1.13.16.45.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21-.15.45-.55.38A7.995 7.995 0 0 1 0 8c0-4.42 3.58-8 8-8Z"/></svg>"#
        let image = NSImage(data: Data(svg.utf8)) ?? NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right", accessibilityDescription: nil)!
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }()
}
