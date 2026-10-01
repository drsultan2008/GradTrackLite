import SwiftUI
import SwiftData
import Charts

struct TeamDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(DataLoader.self) private var loader

    @Query private var milestones: [Milestone]
    @Query private var cached: [CachedProgress]

    let team: Team

    private var teamMilestones: [Milestone] {
        milestones
            .filter { $0.teamID == team.id }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var gitData: GitHubData? {
        cached.first { $0.teamID == team.id }?.data
    }

    var body: some View {
        List {
            Section(String(localized: "detail.documentation")) {
                ForEach(teamMilestones, id: \.persistentModelID) { milestone in
                    MilestoneRow(milestone: milestone)
                }
            }

            Section {
                if let gitData {
                    codingSection(gitData)
                } else {
                    ProgressView(String(localized: "detail.loading"))
                }
            } header: {
                Text(String(localized: "detail.coding"))
            }
        }
        .navigationTitle(team.name)
        .task {
            await loader.loadIfNeeded(context)
            await loader.refresh(context)
        }
        .refreshable {
            await loader.refresh(context)
        }
    }

    @ViewBuilder
    private func codingSection(_ data: GitHubData) -> some View {
        CommitChart(commitsPerWeek: data.commitsPerWeek)
            .frame(height: 160)
            .padding(.vertical, 4)
            .accessibilityLabel(String(localized: "chart.a11yLabel"))
            .accessibilityValue(String(localized: "chart.a11yValue"))

        LabeledContent(String(localized: "detail.issues")) {
            Text("\(data.closedIssues)/\(data.totalIssues)")
        }
        LabeledContent(String(localized: "detail.openPRs")) {
            Text("\(data.openPRs)")
        }
        LabeledContent(String(localized: "detail.mergedPRs")) {
            Text("\(data.mergedPRs)")
        }
        LabeledContent(String(localized: "detail.lastCommit")) {
            Text(data.lastCommitDate?.formatted(date: .abbreviated, time: .omitted)
                 ?? String(localized: "detail.none"))
        }
        LabeledContent(String(localized: "detail.commitCount")) {
            Text("\(data.commitCount)")
        }

        Text(String(localized: "detail.members"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)

        ForEach(data.commitsPerMember) { member in
            LabeledContent(member.name) {
                Text("\(member.count)")
            }
        }
    }
}

private struct MilestoneRow: View {
    let milestone: Milestone

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title.label)
                    .font(.body)
                Text(milestone.dueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(milestone.status.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(milestone.status.color)
                if let grade = milestone.grade {
                    Text(String(format: "%.0f", grade))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct CommitChart: View {
    let commitsPerWeek: [Int]

    var body: some View {
        Chart {
            ForEach(Array(commitsPerWeek.enumerated()), id: \.offset) { index, value in
                BarMark(
                    x: .value(String(localized: "chart.xLabel"),
                              String(localized: "chart.week") + " \(index + 1)"),
                    y: .value(String(localized: "chart.yLabel"), value)
                )
                .foregroundStyle(Color.accentColor)
                .annotation(position: .top) {
                    Text("\(value)")
                        .font(.caption2)
                }
            }
        }
    }
}
