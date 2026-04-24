import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: "#e53935"))
                Text("RaceCor Pro Drive")
                    .font(.system(size: 32, weight: .bold))
                Text("Broadcast-grade race analytics")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                Button(action: {
                    isSigningIn = true
                    authManager.signIn()
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                        Text("Sign in with Discord")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#5865F2"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isSigningIn)

                if isSigningIn {
                    ProgressView()
                        .frame(height: 44)
                }
            }

            Spacer()

            Text("Sign in to access your racing data and analytics")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .padding(32)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
