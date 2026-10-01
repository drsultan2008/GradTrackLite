import Foundation
import SwiftData
import Observation

/// Owns seeding (from Blackboard), live GitHub refresh, and the error/loading
/// state that the UI observes.
@Observable
@MainActor
final class DataLoader {
    private let blackboard: BlackboardService
    private let github: GitHubService

    var isRefreshing = false
    var errorMessage: String?

    init(blackboard: BlackboardService = MockBlackboardService(),
         github: GitHubService = RemoteGitHubService()) {
        self.blackboard = blackboard
        self.github = github
    }

    /// Seeds the local store from Blackboard the first time the app runs.
    func loadIfNeeded(_ context: ModelContext) async {
        let count = (try? context.fetchCount(FetchDescriptor<Team>())) ?? 0
        if count == 0 {
            await seed(context)
        }
    }

    /// Refreshes live GitHub data for every team, updating the cache.
    func refresh(_ context: ModelContext) async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        let teams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
        for team in teams {
            await refresh(team: team, context: context)
        }
    }

    private func refresh(team: Team, context: ModelContext) async {
        let token = TokenStore.load()
        do {
            let data = try await github.fetchData(owner: team.repoOwner,
                                                  repo: team.repoName,
                                                  token: token)
            let teamID = team.id
            let existing = try? context.fetch(FetchDescriptor<CachedProgress>(
                predicate: #Predicate { $0.teamID == teamID }
            ))
            let cache = existing?.first ?? CachedProgress(teamID: team.id,
                                                          owner: team.repoOwner,
                                                          repo: team.repoName)
            cache.owner = team.repoOwner
            cache.repo = team.repoName
            cache.json = (try? JSONEncoder().encode(data)) ?? cache.json
            cache.updatedAt = Date()
            if existing?.first == nil {
                context.insert(cache)
            }
            try? context.save()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func seed(_ context: ModelContext) async {
        do {
            let teams = try await blackboard.fetchTeams()
            for (index, team) in teams.enumerated() {
                let model = Team(id: team.id,
                                 name: team.name,
                                 projectTitle: team.projectTitle,
                                 repoOwner: team.githubRepo.owner,
                                 repoName: team.githubRepo.name,
                                 displayOrder: index)
                context.insert(model)
                for milestone in team.milestones {
                    let dueDate = Calendar.current.date(byAdding: .day,
                                                        value: milestone.dueDateOffsetDays,
                                                        to: Date()) ?? Date()
                    let model = Milestone(teamID: team.id,
                                          title: milestone.title,
                                          dueDate: dueDate,
                                          status: milestone.status,
                                          grade: milestone.grade)
                    context.insert(model)
                }
            }
            try? context.save()
        } catch {
            errorMessage = String(localized: "error.seedFailed")
        }
    }
}
