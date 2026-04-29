import SwiftUI

/// Library destination — grid of recorded `.rcpdv` bundles. Click a tile
/// to open the editor (currently a metadata preview; real timeline lands
/// in a later PR).
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedEntry: LibraryEntry?

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 18),
    ]

    var body: some View {
        ZStack {
            Palette.bgBase.ignoresSafeArea()
            content
        }
        .task { await viewModel.refresh() }
        .sheet(item: $selectedEntry) { entry in
            EditorView(entry: entry)
                .frame(minWidth: 720, idealWidth: 880, minHeight: 520, idealHeight: 640)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.entries.isEmpty {
            loadingState
        } else if viewModel.entries.isEmpty {
            emptyState
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(viewModel.entries) { entry in
                        LibraryTile(entry: entry) {
                            selectedEntry = entry
                        }
                    }
                }
                if let err = viewModel.lastError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.brand)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Palette.textPrimary)
                Text("\(viewModel.entries.count) recorded session\(viewModel.entries.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.textDim)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Refresh")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Palette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Palette.bgElevated)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Palette.textMuted)
            Text("No bundles yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
            Text("Record a session in the overlay or drop a .rcpdv file in\n~/Documents/RaceCor/sessions/ to see it here.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundColor(Palette.textDim)
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("Refresh")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Palette.bgElevated)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)
            Text("Scanning...")
                .font(.system(size: 11))
                .foregroundColor(Palette.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Single bundle tile — track + car, duration, file size. Click opens the editor.
private struct LibraryTile: View {
    let entry: LibraryEntry
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                thumbnail
                meta
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isHovered ? Palette.borderAccent : Palette.borderSubtle,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.35 : 0.15),
                radius: isHovered ? 14 : 6,
                y: isHovered ? 8 : 3
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var thumbnail: some View {
        // No real thumbnail yet (pending AVAsset frame extract in a later PR).
        // Placeholder is a branded glow with a film-strip glyph.
        ZStack {
            LinearGradient(
                colors: [
                    Palette.bgPanel,
                    Palette.brand.opacity(0.08),
                    Palette.bgPanel,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "film")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Palette.textMuted)
            VStack {
                HStack {
                    if entry.header.race.isDemo == true {
                        chip("DEMO", tint: Palette.warning)
                    }
                    Spacer()
                    chip(entry.displayDuration, tint: Palette.textPrimary)
                }
                Spacer()
            }
            .padding(10)
        }
        .frame(height: 160)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 12,
                style: .continuous
            )
        )
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Text(DateFormatter.tile.string(from: entry.header.createdAt))
                Text("·")
                Text(entry.displayFileSize)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(Palette.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.5)
            .foregroundColor(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.black.opacity(0.45))
            )
    }
}

private extension DateFormatter {
    static let tile: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

private extension Bool? {
    /// Used in the chip-vs-no-chip switch above. Not strictly necessary
    /// but reads cleaner than `entry.header.race.isDemo == true` everywhere.
    var isTrue: Bool { self == true }
}
