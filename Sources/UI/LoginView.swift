import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            Palette.bgBase.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 18) {
                    Logomark(height: 88, tone: .color)
                        .shadow(color: Palette.brand.opacity(0.5), radius: 22, y: 6)
                    VStack(spacing: 4) {
                        Text("RaceCor Pro Drive")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(Palette.textPrimary)
                        Text("Broadcast-grade race analytics")
                            .font(.system(size: 14))
                            .foregroundColor(Palette.textSecondary)
                    }
                }
                .padding(32)
                .liquidGlassBackground(cornerRadius: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.borderSubtle, lineWidth: 1)
                )

                VStack(spacing: 12) {
                    Button(action: {
                        isSigningIn = true
                        authManager.signIn()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Sign in with Discord")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(hex: "#5865F2"))
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningIn)
                    .opacity(isSigningIn ? 0.6 : 1)

                    if isSigningIn {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Opening browser…")
                                .font(.system(size: 12))
                                .foregroundColor(Palette.textDim)
                        }
                        .frame(height: 20)
                    }
                }
                .frame(maxWidth: 320)

                Spacer()

                Text("Sign in to access your racing data and analytics")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.textMuted)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
        .frame(width: 800, height: 600)
}
