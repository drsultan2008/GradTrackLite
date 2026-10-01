import SwiftUI
import SwiftData

struct TeamsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(DataLoader.self) private var loader

    @Query(sort: \Team.displayOrder) private var teams: [Team]
    @Query private var milestones: [Milestone]
    @Query private var cached: [CachedProgress]

    var body: some View {
        NavigationStack {
            List {
                ForEach(teams) { team in
                    NavigationLink(value: team) {
                        TeamRow(team: team,
                                milestones: milestones(for: team),
                                cache: cache(for: team))
                    }
                }
            }
            .navigationTitle(String(localized: "teams.title"))
            .navigationDestination(for: Team.self) { team in
                TeamDetailView(team: team)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .refreshable {
                await loader.refresh(context)
            }
            .task {
                await loader.loadIfNeeded(context)
                await loader.refresh(context)
            }
            .overlay {
                if teams.isEmpty {
                    ContentUnavailableView(String(localized: "teams.empty"),
                                           systemImage: "person.3")
                }
            }
        }
        .alert(String(localized: "error.title"),
               isPresented: errorBinding) {
            Button(String(localized: "error.ok"), role: .cancel) {}
        } message: {
            Text(loader.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { loader.errorMessage != nil },
            set: { if !$0 { loader.errorMessage = nil } }
        )
    }

    private func milestones(for team: Team) -> [Milestone] {
        milestones
            .filter { $0.teamID == team.id }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private func cache(for team: Team) -> CachedProgress? {
        cached.first { $0.teamID == team.id }
    }
}

private struct TeamRow: View {
    let team: Team
    let milestones: [Milestone]
    let cache: CachedProgress?

    private var inputs: [MilestoneInput] { milestones.map { $0.input } }

    private var docPercent: Double {
        ProgressRules.documentationPercent(inputs)
    }

    private var gitData: GitHubData? { cache?.data }
    private var codingPercent: Double { gitData?.codingPercent ?? 0 }

    private var status: TeamStatus {
        ProgressRules.teamStatus(milestones: inputs,
                                 lastCommitDate: gitData?.lastCommitDate,
                                 activeWeeks: gitData?.activeWeeks ?? 0,
                                 now: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(team.name)
                    .font(.headline)
                Spacer()
                StatusBadge(status: status)
            }
            Text(team.projectTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressRow(label: String(localized: "team.docLabel"), percent: docPercent)
            ProgressRow(label: String(localized: "team.codingLabel"), percent: codingPercent)
        }
        .padding(.vertical, 4)
    }
}
