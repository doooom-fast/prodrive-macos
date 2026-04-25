import SwiftUI

struct SessionDetailView: View {
    @State private var session: SessionDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    let sessionId: String

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let session = session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.seriesName)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(session.trackName)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Performance metrics
                        if session.iRatingPre != nil || session.srPre != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Performance")
                                    .font(.headline)

                                HStack(spacing: 16) {
                                    if let pre = session.iRatingPre, let post = session.iRatingPost {
                                        StatCol(label: "iRating", before: String(pre), after: String(post))
                                    }
                                    if let pre = session.srPre, let post = session.srPost {
                                        StatCol(label: "SR", before: String(format: "%.2f", pre), after: String(format: "%.2f", post))
                                    }
                                }
                            }
                        }

                        // Race results
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results")
                                .font(.headline)

                            VStack(spacing: 8) {
                                if let pos = session.finishPosition {
                                    HStack {
                                        Text("Finish")
                                        Spacer()
                                        Text("P\(pos)")
                                            .fontWeight(.semibold)
                                    }
                                }
                                if let laps = session.lapsCompleted {
                                    HStack {
                                        Text("Laps")
                                        Spacer()
                                        Text(String(laps))
                                            .fontWeight(.semibold)
                                    }
                                }
                                if let incidents = session.incidents {
                                    HStack {
                                        Text("Incidents")
                                        Spacer()
                                        Text(String(incidents))
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .font(.caption)
                        }

                        Spacer()
                    }
                    .padding()
                }
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text("Failed to load session")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task {
                            await loadSession()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .navigationTitle("Session")
        .task {
            await loadSession()
        }
    }

    private func loadSession() async {
        isLoading = true
        errorMessage = nil
        do {
            session = try await APIClient.shared.session(id: sessionId)
        } catch {
            errorMessage = error.localizedDescription
            Log.error("Failed to load session: \(error)")
        }
        isLoading = false
    }
}

struct StatCol: View {
    let label: String
    let before: String
    let after: String

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Text(before)
                    .font(.caption2)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                Text(after)
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    SessionDetailView(sessionId: "test-session")
}
