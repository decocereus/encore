import SwiftUI

struct SearchTab: View {
    @Bindable var model: AppModel
    @State private var results: [Track] = []
    @State private var searching = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Songs, artists", text: $model.searchQuery)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { Task { await run(debounce: false) } }
                if !model.searchQuery.isEmpty {
                    Button { model.searchQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.primary.opacity(0.08), in: .capsule)
            .padding(.horizontal, 16)

            content.frame(maxHeight: .infinity)
        }
        .onAppear { focused = true }
        .task(id: model.searchQuery) { await run() }
    }

    @ViewBuilder private var content: some View {
        if model.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            Text("Search YouTube Music for a song to play.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity)
        } else if let error {
            VStack(spacing: 6) {
                Text("Search failed").font(.headline)
                Text(error).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        } else if results.isEmpty {
            if searching { ProgressView() } else {
                Text("No songs match “\(model.searchQuery)”.").font(.callout).foregroundStyle(.secondary)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { track in
                        TrackRow(title: track.title, subtitle: track.subtitle, thumb: track.thumb,
                                 isCurrent: track.title == model.player.state.title) {
                            model.play(track)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.never)
            .fadingEdges()
            .opacity(searching ? 0.6 : 1)
        }
    }

    private func run(debounce: Bool = true) async {
        let text = model.searchQuery.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { results = []; error = nil; return }
        if debounce {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
        }
        searching = true
        defer { searching = false }
        do {
            let found = try await model.player.search(text)
            guard !Task.isCancelled, text == model.searchQuery.trimmingCharacters(in: .whitespaces) else { return }
            results = found
            error = nil
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
