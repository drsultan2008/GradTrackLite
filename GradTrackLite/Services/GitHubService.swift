import Foundation

// MARK: - Service protocol

protocol GitHubService {
    func fetchData(owner: String, repo: String, token: String?) async throws -> GitHubData
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case invalidURL
    case rateLimited
    case unauthorized
    case notFound
    case badStatus(Int)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "github.error.invalidURL")
        case .rateLimited:
            return String(localized: "github.error.rateLimited")
        case .unauthorized:
            return String(localized: "github.error.unauthorized")
        case .notFound:
            return String(localized: "github.error.notFound")
        case .badStatus:
            return String(localized: "github.error.badStatus")
        case .network:
            return String(localized: "github.error.network")
        }
    }
}

// MARK: - Implementation

final class RemoteGitHubService: GitHubService {
    private let session: URLSession
    private let now: () -> Date

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            for formatter in RemoteGitHubService.dateFormatters {
                if let date = formatter.date(from: string) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }()

    private static let dateFormatters: [ISO8601DateFormatter] = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return [fractional, plain]
    }()

    init(session: URLSession = .shared, now: @escaping () -> Date = { Date() }) {
        self.session = session
        self.now = now
    }

    func fetchData(owner: String, repo: String, token: String?) async throws -> GitHubData {
        let reference = now()
        let since = reference.addingTimeInterval(-28 * 24 * 60 * 60)
        let sinceISO = ISO8601DateFormatter().string(from: since)

        async let commits = fetchCommits(owner: owner, repo: repo, token: token, since: sinceISO)
        async let issues = fetchIssues(owner: owner, repo: repo, token: token)
        async let pulls = fetchPulls(owner: owner, repo: repo, token: token)

        let commitList = try await commits
        let issueList = try await issues
        let pullList = try await pulls

        return compute(commits: commitList, issues: issueList, pulls: pullList, now: reference)
    }

    // MARK: Endpoints

    private func fetchCommits(owner: String, repo: String, token: String?, since: String) async throws -> [GitHubCommit] {
        let url = try makeURL(path: "repos/\(owner)/\(repo)/commits",
                              query: ["per_page": "100", "since": since])
        return try await fetch(url: url, token: token, as: [GitHubCommit].self)
    }

    private func fetchIssues(owner: String, repo: String, token: String?) async throws -> [GitHubIssue] {
        let url = try makeURL(path: "repos/\(owner)/\(repo)/issues",
                              query: ["state": "all", "per_page": "100"])
        return try await fetch(url: url, token: token, as: [GitHubIssue].self)
    }

    private func fetchPulls(owner: String, repo: String, token: String?) async throws -> [GitHubPull] {
        let url = try makeURL(path: "repos/\(owner)/\(repo)/pulls",
                              query: ["state": "all", "per_page": "100"])
        return try await fetch(url: url, token: token, as: [GitHubPull].self)
    }

    // MARK: Networking

    private func makeURL(path: String, query: [String: String]) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/" + path
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw GitHubError.invalidURL }
        return url
    }

    private func fetch<T: Decodable>(url: URL, token: String?, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.network("Invalid response.")
        }

        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw GitHubError.unauthorized
        case 403:
            if http.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
                throw GitHubError.rateLimited
            }
            throw GitHubError.unauthorized
        case 404:
            throw GitHubError.notFound
        default:
            throw GitHubError.badStatus(http.statusCode)
        }

        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw GitHubError.network(error.localizedDescription)
        }
    }

    // MARK: Aggregation

    private func compute(commits: [GitHubCommit],
                         issues: [GitHubIssue],
                         pulls: [GitHubPull],
                         now: Date) -> GitHubData {
        let calendar = Calendar.current

        var weekly = [Int](repeating: 0, count: 4)
        for commit in commits {
            let days = calendar.dateComponents([.day], from: commit.commit.author.date, to: now).day ?? 0
            let weeksAgo = max(0, days / 7)
            if weeksAgo < 4 {
                weekly[3 - weeksAgo] += 1
            }
        }
        let activeWeeks = weekly.filter { $0 > 0 }.count
        let lastCommitDate = commits.map { $0.commit.author.date }.max()

        let realIssues = issues.filter { $0.pullRequest == nil }
        let totalIssues = realIssues.count
        let closedIssues = realIssues.filter { $0.state == "closed" }.count
        let openIssues = totalIssues - closedIssues

        let mergedPRs = pulls.filter { $0.mergedAt != nil }.count
        let openPRs = pulls.filter { $0.state == "open" && $0.mergedAt == nil }.count

        var memberCounts: [String: Int] = [:]
        for commit in commits {
            let name = commit.author?.login ?? commit.commit.author.name
            memberCounts[name, default: 0] += 1
        }
        let commitsPerMember = memberCounts
            .map { MemberCommitCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        return GitHubData(commitsPerWeek: weekly,
                          commitCount: commits.count,
                          openIssues: openIssues,
                          closedIssues: closedIssues,
                          totalIssues: totalIssues,
                          openPRs: openPRs,
                          mergedPRs: mergedPRs,
                          commitsPerMember: commitsPerMember,
                          lastCommitDate: lastCommitDate,
                          activeWeeks: activeWeeks)
    }
}
