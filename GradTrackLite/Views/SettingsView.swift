import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(DataLoader.self) private var loader

    @Query(sort: \Team.displayOrder) private var teams: [Team]

    @State private var token: String = ""

    var body: some View {
        Form {
            Section(String(localized: "settings.githubToken")) {
                SecureField(String(localized: "settings.tokenPlaceholder"), text: $token)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .onAppear { token = TokenStore.load() ?? "" }
                    .onChange(of: token) { _, newValue in
                        TokenStore.save(newValue)
                    }
            }

            Section {
                ForEach(teams) { team in
                    TeamRepoEditor(team: team)
                }
            } header: {
                Text(String(localized: "settings.repos"))
            }

            Section {
                Button {
                    TokenStore.save(token)
                    Task { await loader.refresh(context) }
                } label: {
                    if loader.isRefreshing {
                        ProgressView()
                    } else {
                        Label(String(localized: "settings.refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(loader.isRefreshing)
            }
        }
        .navigationTitle(String(localized: "settings.title"))
    }
}

private struct TeamRepoEditor: View {
    @Bindable var team: Team

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(team.name)
                .font(.headline)
            TextField(String(localized: "settings.owner"), text: $team.repoOwner)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField(String(localized: "settings.repo"), text: $team.repoName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.vertical, 4)
    }
}
