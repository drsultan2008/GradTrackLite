import XCTest
@testable import GradTrackLite

final class ProgressRulesTests: XCTestCase {

    // A fixed base "now" so status boundaries are deterministic.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(offsetDays: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offsetDays, to: now)!
    }

    private func milestone(_ title: MilestoneTitle,
                           offsetDays: Int,
                           status: MilestoneStatus,
                           grade: Double? = nil) -> MilestoneInput {
        MilestoneInput(title: title, dueDate: date(offsetDays: offsetDays), status: status, grade: grade)
    }

    // MARK: - Documentation percent

    func testDocPercentEmptyIsZero() {
        XCTAssertEqual(ProgressRules.documentationPercent([]), 0, accuracy: 0.001)
    }

    func testDocPercentNotSubmittedIsZero() {
        let m = milestone(.proposal, offsetDays: -1, status: .notSubmitted)
        XCTAssertEqual(ProgressRules.documentationPercent([m]), 0, accuracy: 0.001)
    }

    func testDocPercentSubmittedIsSixty() {
        let m = milestone(.srs, offsetDays: 0, status: .submitted)
        XCTAssertEqual(ProgressRules.documentationPercent([m]), 60, accuracy: 0.001)
    }

    func testDocPercentGradedDefaultGradeIsSixty() {
        let m = milestone(.design, offsetDays: 0, status: .graded, grade: nil)
        XCTAssertEqual(ProgressRules.documentationPercent([m]), 60, accuracy: 0.001)
    }

    func testDocPercentGradedNinety() {
        let m = milestone(.design, offsetDays: 0, status: .graded, grade: 90)
        XCTAssertEqual(ProgressRules.documentationPercent([m]), 96, accuracy: 0.001)
    }

    func testDocPercentAveragesAcrossMilestones() {
        let ms = [
            milestone(.proposal, offsetDays: 0, status: .notSubmitted),
            milestone(.srs, offsetDays: 0, status: .submitted),
            milestone(.design, offsetDays: 0, status: .graded, grade: 90)
        ]
        // (0 + 60 + 96) / 3 = 52
        XCTAssertEqual(ProgressRules.documentationPercent(ms), 52, accuracy: 0.001)
    }

    // MARK: - Coding percent

    func testCodingPercentWithIssues() {
        XCTAssertEqual(ProgressRules.codingPercent(closedIssues: 5, totalIssues: 10, activeWeeks: 4), 50, accuracy: 0.001)
    }

    func testCodingPercentWithIssuesAllClosed() {
        XCTAssertEqual(ProgressRules.codingPercent(closedIssues: 10, totalIssues: 10, activeWeeks: 4), 100, accuracy: 0.001)
    }

    func testCodingPercentWithIssuesNoneClosed() {
        XCTAssertEqual(ProgressRules.codingPercent(closedIssues: 0, totalIssues: 10, activeWeeks: 4), 0, accuracy: 0.001)
    }

    func testCodingPercentNoIssuesUsesActiveWeeks() {
        XCTAssertEqual(ProgressRules.codingPercent(closedIssues: 0, totalIssues: 0, activeWeeks: 2), 50, accuracy: 0.001)
    }

    func testCodingPercentNoIssuesAllWeeks() {
        XCTAssertEqual(ProgressRules.codingPercent(closedIssues: 0, totalIssues: 0, activeWeeks: 4), 100, accuracy: 0.001)
    }

    func testCodingPercentNoIssuesNoActivity() {
        XCTAssertEqual(ProgressRules.codingPercent(closedIssues: 0, totalIssues: 0, activeWeeks: 0), 0, accuracy: 0.001)
    }

    // MARK: - Status

    func testStatusBehindPastDueNotSubmitted() {
        let ms = [milestone(.proposal, offsetDays: -1, status: .notSubmitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 4,
            now: now)
        XCTAssertEqual(status, .behind)
    }

    func testStatusBehindNoRecentCommit() {
        let ms = [milestone(.srs, offsetDays: 1, status: .submitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -22),
            activeWeeks: 4,
            now: now)
        XCTAssertEqual(status, .behind)
    }

    func testStatusBehindNoCommitDateAtAll() {
        let ms = [milestone(.srs, offsetDays: 1, status: .submitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: nil,
            activeWeeks: 4,
            now: now)
        XCTAssertEqual(status, .behind)
    }

    func testStatusAtRiskDueWithinSevenDays() {
        let ms = [milestone(.srs, offsetDays: 3, status: .notSubmitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 4,
            now: now)
        XCTAssertEqual(status, .atRisk)
    }

    func testStatusAtRiskDueExactlySevenDays() {
        let ms = [milestone(.srs, offsetDays: 7, status: .notSubmitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 4,
            now: now)
        XCTAssertEqual(status, .atRisk)
    }

    func testStatusAtRiskLowActivityOneWeek() {
        let ms = [milestone(.proposal, offsetDays: -2, status: .submitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 1,
            now: now)
        XCTAssertEqual(status, .atRisk)
    }

    func testStatusAtRiskLowActivityTwoWeeks() {
        let ms = [milestone(.proposal, offsetDays: -2, status: .submitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 2,
            now: now)
        XCTAssertEqual(status, .atRisk)
    }

    func testStatusOnTrack() {
        let ms = [
            milestone(.proposal, offsetDays: -2, status: .graded, grade: 95),
            milestone(.srs, offsetDays: -1, status: .submitted)
        ]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 3,
            now: now)
        XCTAssertEqual(status, .onTrack)
    }

    func testStatusOnTrackActiveFourWeeks() {
        let ms = [milestone(.srs, offsetDays: 1, status: .submitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 4,
            now: now)
        XCTAssertEqual(status, .onTrack)
    }

    func testStatusBehindWinsOverAtRiskLowActivity() {
        // Past-due notSubmitted exists, so Behind takes priority even though
        // activeWeeks would otherwise flag At risk.
        let ms = [milestone(.proposal, offsetDays: -1, status: .notSubmitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 1,
            now: now)
        XCTAssertEqual(status, .behind)
    }

    func testStatusGradedMilestoneDueSoonIsNotAtRisk() {
        // A graded milestone due within 7 days is not a risk trigger.
        let ms = [milestone(.srs, offsetDays: 3, status: .graded, grade: 80)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 4,
            now: now)
        XCTAssertEqual(status, .onTrack)
    }

    func testStatusDueInEightDaysNotAtRiskWhenActive() {
        let ms = [milestone(.srs, offsetDays: 8, status: .notSubmitted)]
        let status = ProgressRules.teamStatus(
            milestones: ms,
            lastCommitDate: date(offsetDays: -1),
            activeWeeks: 4,
            now: now)
        XCTAssertEqual(status, .onTrack)
    }
}
