import SwiftUI

struct MainShell: View {
    @EnvironmentObject var authManager: AuthManager
    let user: Me

    var body: some View {
        ContentView()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("RaceCor Pro Drive")
                        .font(.headline)
                }
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("Sign Out") {
                            authManager.signOut()
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
    }
}

#Preview {
    MainShell(user: Me(
        id: "test",
        discordId: "0",
        discordUsername: "testuser",
        discordDisplayName: "Test User",
        discordAvatar: nil,
        customLogoUrl: nil,
        email: "test@example.com",
        createdAt: Date()
    ))
    .environmentObject(AuthManager())
}
