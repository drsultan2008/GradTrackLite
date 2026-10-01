import Foundation
import SwiftData

@Model
final class Milestone {
    var teamID: UUID
    var titleRaw: String
    var dueDate: Date
    var statusRaw: String
    var grade: Double?

    init(teamID: UUID,
         title: MilestoneTitle,
         dueDate: Date,
         status: MilestoneStatus,
         grade: Double? = nil) {
        self.teamID = teamID
        self.titleRaw = title.rawValue
        self.dueDate = dueDate
        self.statusRaw = status.rawValue
        self.grade = grade
    }

    var title: MilestoneTitle { MilestoneTitle(rawValue: titleRaw) ?? .proposal }
    var status: MilestoneStatus { MilestoneStatus(rawValue: statusRaw) ?? .notSubmitted }

    var input: MilestoneInput {
        MilestoneInput(title: title, dueDate: dueDate, status: status, grade: grade)
    }
}
