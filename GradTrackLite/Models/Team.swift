import Foundation
import SwiftData

@Model
final class Team {
    @Attribute(.unique) var id: UUID
    var name: String
    var projectTitle: String
    var repoOwner: String
    var repoName: String
    var displayOrder: Int

    init(id: UUID = UUID(),
         name: String,
         projectTitle: String,
         repoOwner: String,
         repoName: String,
         displayOrder: Int) {
        self.id = id
        self.name = name
        self.projectTitle = projectTitle
        self.repoOwner = repoOwner
        self.repoName = repoName
        self.displayOrder = displayOrder
    }

    var repoPath: String { "\(repoOwner)/\(repoName)" }
}
