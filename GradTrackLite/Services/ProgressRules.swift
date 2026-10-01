import Foundation

/// A lightweight, framework-free value type describing one milestone.
/// Kept separate from the SwiftData model so the progress logic stays pure.
struct MilestoneInput {
    let title: MilestoneTitle
    let dueDate: Date
    let status: MilestoneStatus
    let grade: Double?
}

/// Pure progress rules. No I/O, no side effects — fully unit-testable.
enum ProgressRules {

    /// Documentation progress (0...100) averaged across milestones.
    /// notSubmitted = 0, submitted = 60, graded = 60 + 40 * (grade / 100).
    static func documentationPercent(_ milestones: [MilestoneInput]) -> Double {
        guard !milestones.isEmpty else { return 0 }
        let sum = milestones.reduce(0.0) { $0 + score($1) }
        return sum / Double(milestones.count)
    }

    private static func score(_ m: MilestoneInput) -> Double {
        switch m.status {
        case .notSubmitted:
            return 0
        case .submitted:
            return 60
        case .graded:
            return 60 + 40 * ((m.grade ?? 0) / 100)
        }
    }

    /// Coding progress (0...100).
    /// closed / total issues when there are issues; otherwise activeWeeks + 25.
    static func codingPercent(closedIssues: Int, totalIssues: Int, activeWeeks: Int) -> Double {
        if totalIssues > 0 {
            return Double(closedIssues) / Double(totalIssues) * 100
        }
        return Double(activeWeeks) * 25
    }

    /// Team status. Checked in priority order: Behind, then At risk, then On track.
    static func teamStatus(milestones: [MilestoneInput],
                           lastCommitDate: Date?,
                           activeWeeks: Int,
                           now: Date) -> TeamStatus {
        let calendar = Calendar.current

        // Behind: any milestone past its due date and not submitted.
        let pastDueNotSubmitted = milestones.contains {
            $0.status == .notSubmitted && $0.dueDate < now
        }

        // Behind: no commits in the last 21 days.
        let cutoff21 = calendar.date(byAdding: .day, value: -21, to: now) ?? now
        let noRecentCommit: Bool
        if let lastCommitDate {
            noRecentCommit = lastCommitDate < cutoff21
        } else {
            noRecentCommit = true
        }

        if pastDueNotSubmitted || noRecentCommit {
            return .behind
        }

        // At risk: a milestone due within the next 7 days and not submitted.
        let windowEnd7 = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        let dueWithin7 = milestones.contains {
            $0.status == .notSubmitted && $0.dueDate >= now && $0.dueDate <= windowEnd7
        }

        // At risk: only 1 to 2 active weeks out of the last 4.
        let lowActivity = (1...2).contains(activeWeeks)

        if dueWithin7 || lowActivity {
            return .atRisk
        }

        return .onTrack
    }
}
