import Foundation

// MARK: - Service protocol

/// Abstraction over Blackboard so a real REST implementation can replace
/// the mock later without touching the UI.
protocol BlackboardService {
    func fetchTeams() async throws -> [BlackboardTeam]
}

// MARK: - DTOs

struct BlackboardTeam: Codable, Identifiable {
    let id: UUID
    let name: String
    let projectTitle: String
    let members: [String]
    let githubRepo: RepoRef
    let milestones: [BlackboardMilestone]
}

struct RepoRef: Codable {
    let owner: String
    let name: String
}

struct BlackboardMilestone: Codable {
    let title: MilestoneTitle
    /// Days from "today"; the mock resolves this to a concrete Date at seed time
    /// so the demo statuses stay deterministic whenever the app is run.
    let dueDateOffsetDays: Int
    let status: MilestoneStatus
    let grade: Double?
}

// MARK: - Errors

enum BlackboardError: LocalizedError {
    case fileMissing
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return String(localized: "blackboard.error.fileMissing")
        case .decodeFailed(let message):
            return message
        }
    }
}

// MARK: - Mock implementation

final class MockBlackboardService: BlackboardService {
    func fetchTeams() async throws -> [BlackboardTeam] {
        guard let url = Bundle.main.url(forResource: "mock_blackboard", withExtension: "json") else {
            throw BlackboardError.fileMissing
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode([BlackboardTeam].self, from: data)
        } catch {
            throw BlackboardError.decodeFailed(error.localizedDescription)
        }
    }
}
