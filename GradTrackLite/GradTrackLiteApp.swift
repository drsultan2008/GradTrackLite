import SwiftUI
import SwiftData

@main
struct GradTrackLiteApp: App {
    @State private var loader = DataLoader()

    var body: some Scene {
        WindowGroup {
            TeamsListView()
                .environment(loader)
        }
        .modelContainer(for: [Team.self, Milestone.self, CachedProgress.self])
    }
}
