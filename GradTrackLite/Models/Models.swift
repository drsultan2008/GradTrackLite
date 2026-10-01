import Foundation
import SwiftUI
import SwiftData

// MARK: - MilestoneTitle

enum MilestoneTitle: String, CaseIterable, Codable, Identifiable {
    case proposal
    case srs
    case design
    case finalReport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .proposal: return String(localized: "milestone.proposal")
        case .srs: return String(localized: "milestone.srs")
        case .design: return String(localized: "milestone.design")
        case .finalReport: return String(localized: "milestone.finalReport")
        }
    }
}

// MARK: - MilestoneStatus

enum MilestoneStatus: String, CaseIterable, Codable {
    case notSubmitted
    case submitted
    case graded

    var label: String {
        switch self {
        case .notSubmitted: return String(localized: "milestone.status.notSubmitted")
        case .submitted: return String(localized: "milestone.status.submitted")
        case .graded: return String(localized: "milestone.status.graded")
        }
    }

    var color: Color {
        switch self {
        case .notSubmitted: return .red
        case .submitted: return .orange
        case .graded: return .green
        }
    }
}

// MARK: - TeamStatus

enum TeamStatus: String, CaseIterable, Codable {
    case onTrack
    case atRisk
    case behind

    var label: String {
        switch self {
        case .onTrack: return String(localized: "team.status.onTrack")
        case .atRisk: return String(localized: "team.status.atRisk")
        case .behind: return String(localized: "team.status.behind")
        }
    }

    var color: Color {
        switch self {
        case .onTrack: return .green
        case .atRisk: return .orange
        case .behind: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .onTrack: return "checkmark.circle.fill"
        case .atRisk: return "exclamationmark.triangle.fill"
        case .behind: return "xmark.circle.fill"
        }
    }
}

// MARK: - GitHub DTOs

struct GitUser: Codable {
    let login: String?
}

struct GitHubCommit: Codable {
    let sha: String
    let commit: CommitInfo
    let author: GitUser?

    struct CommitInfo: Codable {
        let author: CommitAuthor
        let message: String
    }

    struct CommitAuthor: Codable {
        let date: Date
        let name: String
    }
}

struct GitHubIssue: Codable {
    let number: Int
    let state: String
    let pullRequest: PullRef?

    struct PullRef: Codable {
        let url: String?
    }
}

struct GitHubPull: Codable {
    let number: Int
    let state: String
    let mergedAt: Date?
    let user: GitUser?
}

// MARK: - Progress / cached data

struct MemberCommitCount: Codable, Identifiable, Hashable {
    let name: String
    let count: Int
    var id: String { name }
}

struct GitHubData: Codable {
    var commitsPerWeek: [Int]
    var commitCount: Int
    var openIssues: Int
    var closedIssues: Int
    var totalIssues: Int
    var openPRs: Int
    var mergedPRs: Int
    var commitsPerMember: [MemberCommitCount]
    var lastCommitDate: Date?
    var activeWeeks: Int

    var codingPercent: Double {
        ProgressRules.codingPercent(closedIssues: closedIssues,
                                    totalIssues: totalIssues,
                                    activeWeeks: activeWeeks)
    }
}

@Model
final class CachedProgress {
    var teamID: UUID
    var owner: String
    var repo: String
    var json: Data
    var updatedAt: Date

    init(teamID: UUID,
         owner: String,
         repo: String,
         data: GitHubData? = nil,
         updatedAt: Date = Date()) {
        self.teamID = teamID
        self.owner = owner
        self.repo = repo
        self.json = (try? JSONEncoder().encode(data)) ?? Data()
        self.updatedAt = updatedAt
    }

    var data: GitHubData? {
        try? JSONDecoder().decode(GitHubData.self, from: json)
    }
}
