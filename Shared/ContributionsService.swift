import Foundation

struct ContributionDay: Hashable, Codable {
    let date: Date
    /// `nil` for days later than today.
    let count: Int?
}

struct ContributionSummary: Codable {
    let today: Int
    /// The seven days of the current week, first weekday first.
    let week: [ContributionDay]

    var weekTotal: Int { week.reduce(0) { $0 + ($1.count ?? 0) } }

    static var placeholder: ContributionSummary {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let counts = [3, 7, 0, 12, 5, 1, 9]
        let days = counts.enumerated().map { offset, count in
            ContributionDay(date: calendar.date(byAdding: .day, value: offset, to: start)!, count: count)
        }
        return ContributionSummary(today: 5, week: days)
    }
}

enum ContributionsError: LocalizedError {
    case missingUsername
    case invalidUsername
    case userNotFound
    case http(Int)
    case unexpectedPage

    var errorDescription: String? {
        switch self {
        case .missingUsername: "Right-click → Edit Widget to set a GitHub username."
        case .invalidUsername: "That doesn't look like a GitHub username."
        case .userNotFound: "GitHub user not found."
        case .http(let code): "GitHub returned HTTP \(code)."
        case .unexpectedPage: "Couldn't read GitHub's contributions page."
        }
    }
}

/// Reads the public contribution graph at `github.com/users/<username>/contributions`
/// (the same HTML fragment a profile page loads). No token needed, but this is not
/// an official API, so the markup could change.
struct ContributionsService {
    let username: String

    func fetchSummary(now: Date = .now, calendar: Calendar = .current) async throws -> ContributionSummary {
        let username = username.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard !username.isEmpty else { throw ContributionsError.missingUsername }
        guard username.wholeMatch(of: try! Regex("[A-Za-z0-9-]{1,39}")) != nil,
              let url = URL(string: "https://github.com/users/\(username)/contributions")
        else { throw ContributionsError.invalidUsername }
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            throw ContributionsError.unexpectedPage
        }

        var request = URLRequest(url: url)
        request.setValue("MyContributions-Widget", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { throw ContributionsError.userNotFound }
            if http.statusCode != 200 { throw ContributionsError.http(http.statusCode) }
        }

        let countsByDay = Self.parseCounts(html: String(decoding: data, as: UTF8.self))
        guard !countsByDay.isEmpty else { throw ContributionsError.unexpectedPage }

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.timeZone = calendar.timeZone
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: now)
        let days = (0..<7).compactMap { offset -> ContributionDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let count = date > today ? nil : countsByDay[dayFormatter.string(from: date)] ?? 0
            return ContributionDay(date: date, count: count)
        }

        return ContributionSummary(
            today: countsByDay[dayFormatter.string(from: today)] ?? 0,
            week: days
        )
    }

    /// Maps "yyyy-MM-dd" to a contribution count. Day cells look like
    /// `<td data-date="2026-10-24" id="contribution-day-component-6-51" …>` and their counts
    /// live in `<tool-tip for="contribution-day-component-6-51">18 contributions on …</tool-tip>`.
    static func parseCounts(html: String) -> [String: Int] {
        var dateByID: [String: String] = [:]
        for match in html.matches(of: try! Regex("<td\\b[^>]*>")) {
            let tag = html[match.range]
            if let date = attribute("data-date", in: tag), let id = attribute("id", in: tag) {
                dateByID[id] = date
            }
        }

        var counts: [String: Int] = [:]
        for match in html.matches(of: try! Regex("<tool-tip\\b([^>]*)>([^<]*)</tool-tip>")) {
            guard let attributes = match.output[1].substring,
                  let text = match.output[2].substring,
                  let id = attribute("for", in: attributes),
                  let date = dateByID[id]
            else { continue }
            // "18 contributions on …", "1 contribution on …" or "No contributions on …"
            let number = text.prefix { $0.isNumber || $0 == "," }.replacingOccurrences(of: ",", with: "")
            counts[date] = Int(number) ?? 0
        }
        return counts
    }

    private static func attribute(_ name: String, in tag: Substring) -> String? {
        guard let match = tag.firstMatch(of: try! Regex("(?:^|\\s)\(name)=\"([^\"]*)\"")),
              let value = match.output[1].substring
        else { return nil }
        return String(value)
    }
}
