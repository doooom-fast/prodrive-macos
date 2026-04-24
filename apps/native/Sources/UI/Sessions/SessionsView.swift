import SwiftUI

struct SessionsView: View {
    @State private var sessions: [SessionListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCategory = "all"
    @State private var offset = 0

    let categories = ["all", "road", "oval", "sports", "dirt", "dirt_oval"]

    var body: some View {
        ZStack {
            if isLoading && sessions.isEmpty {
                ProgressView()
            } else if sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.dash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No sessions found")
                        .font(.headline)
                    Button("Refresh") {
                        Task {
                            await loadSessions()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            } else {
                VStack(spacing: 0) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category.capitalized).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .onChange(of: selectedCategory) { _, _ in
                        offset = 0
                        Task {
                            await loadSessions()
                        }
                    }

                    List(sessions) { session in
                        NavigationLink(destination: SessionDetailView(sessionId: session.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(session.seriesName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if let position = session.finishPosition {
                                        Text("P\(position)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color(hex: "#e53935"))
                                    }
                                }
                                Text(session.trackName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if let laps = session.lapsCompleted {
                                        Text("\(laps) laps")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await loadSessions()
                    }
                }
            }
        }
        .task {
            await loadSessions()
        }
    }

    private func loadSessions() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIClient.shared.sessions(limit: 50, offset: offset, category: selectedCategory)
            sessions = response.sessions
        } catch {
            errorMessage = error.localizedDescription
            Log.error("Failed to load sessions: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    SessionsView()
}
