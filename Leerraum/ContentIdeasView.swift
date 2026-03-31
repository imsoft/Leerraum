import SwiftUI
import SwiftData

private struct ContentIdeaEditTarget: Identifiable {
    let id: UUID
}

private struct ContentIdeaMetrics {
    let total: Int
    let pinned: Int
    let filtered: Int
}

private struct ContentIdeaPayload {
    let title: String
    let detail: String
    let tagsRaw: String
    let platform: String
    let isPinned: Bool
}

struct ContentIdeasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ContentIdeaEntry.updatedAt, order: .reverse) private var ideas: [ContentIdeaEntry]

    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var editTarget: ContentIdeaEditTarget?
    @State private var showPinnedOnly = false

    private var filteredIdeas: [ContentIdeaEntry] {
        ideas
            .filter { idea in
                if showPinnedOnly, !idea.isPinned { return false }
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !q.isEmpty else { return true }
                let haystack = [
                    idea.title,
                    idea.detail,
                    idea.tagsRaw,
                    idea.platform
                ]
                .joined(separator: " ")
                .lowercased()
                return haystack.contains(q.lowercased())
            }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var metrics: ContentIdeaMetrics {
        ContentIdeaMetrics(
            total: ideas.count,
            pinned: ideas.filter(\.isPinned).count,
            filtered: filteredIdeas.count
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ContentIdeasBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ContentIdeasSummaryCard(metrics: metrics)

                        ContentIdeasControlsCard(
                            searchText: $searchText,
                            showPinnedOnly: $showPinnedOnly
                        )

                        FeatureSectionHeader(title: "Ideas") {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Label("Nueva", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.ContentIdeas.c600)
                        }

                        if filteredIdeas.isEmpty {
                            ContentIdeasEmptyStateCard(
                                isFiltering: !(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || showPinnedOnly
                            ) {
                                showingAddSheet = true
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredIdeas, id: \.id) { idea in
                                    ContentIdeaRow(idea: idea) {
                                        editTarget = ContentIdeaEditTarget(id: idea.id)
                                    } onTogglePinned: {
                                        togglePinned(idea)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Ideas de contenido")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddSheet) {
                AddContentIdeaView { payload in
                    createIdea(payload)
                }
            }
            .sheet(item: $editTarget) { target in
                if let selected = ideas.first(where: { $0.id == target.id }) {
                    AddContentIdeaView(initialIdea: selected) { payload in
                        updateIdea(selected, payload: payload)
                    } onDelete: {
                        deleteIdea(selected)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Idea no disponible",
                            systemImage: "sparkles",
                            description: Text("Este registro ya no existe.")
                        )
                    }
                }
            }
        }
    }

    private func createIdea(_ payload: ContentIdeaPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let newIdea = ContentIdeaEntry(
            title: title,
            detail: payload.detail.trimmingCharacters(in: .whitespacesAndNewlines),
            tagsRaw: payload.tagsRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            platform: payload.platform.trimmingCharacters(in: .whitespacesAndNewlines),
            isPinned: payload.isPinned,
            createdAt: .now,
            updatedAt: .now
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(newIdea)
        }
    }

    private func updateIdea(_ idea: ContentIdeaEntry, payload: ContentIdeaPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            idea.title = title
            idea.detail = payload.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            idea.tagsRaw = payload.tagsRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            idea.platform = payload.platform.trimmingCharacters(in: .whitespacesAndNewlines)
            idea.isPinned = payload.isPinned
            idea.updatedAt = .now
        }
    }

    private func deleteIdea(_ idea: ContentIdeaEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(idea)
        }
    }

    private func togglePinned(_ idea: ContentIdeaEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            idea.isPinned.toggle()
            idea.updatedAt = .now
        }
    }
}

private struct ContentIdeasBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .contentIdeas)
    }
}

private struct ContentIdeasSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let metrics: ContentIdeaMetrics

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.ContentIdeas.c900, AppPalette.ContentIdeas.c700]
        }
        return [AppPalette.ContentIdeas.c700, AppPalette.ContentIdeas.c500]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Banco de ideas")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            HStack(spacing: 8) {
                ContentIdeasPill(title: "Ideas", value: "\(metrics.total)")
                ContentIdeasPill(title: "Fijadas", value: "\(metrics.pinned)")
                ContentIdeasPill(title: "Mostradas", value: "\(metrics.filtered)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(colorScheme == .dark ? 0.18 : 0.28), lineWidth: 1)
        )
    }
}

private struct ContentIdeasPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(colorScheme == .dark ? 0.12 : 0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ContentIdeasControlsCard: View {
    @Binding var searchText: String
    @Binding var showPinnedOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.ContentIdeas.c700)
                    .frame(width: 32, height: 32)
                    .background(AppPalette.ContentIdeas.c200.opacity(0.50), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                TextField("Buscar por titulo, tags o plataforma", text: $searchText)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
            }

            Toggle(isOn: $showPinnedOnly) {
                Text("Solo fijadas")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
            }
            .tint(AppPalette.ContentIdeas.c600)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct ContentIdeasEmptyStateCard: View {
    let isFiltering: Bool
    let onAddTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentUnavailableView(
                isFiltering ? "Sin resultados" : "Aun no hay ideas",
                systemImage: isFiltering ? "magnifyingglass" : "sparkles",
                description: Text(isFiltering ? "Prueba con otro texto o desactiva el filtro." : "Guarda cualquier idea apenas se te ocurra.")
            )

            Button {
                onAddTap()
            } label: {
                Label("Crear idea", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.ContentIdeas.c600)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct ContentIdeaRow: View {
    let idea: ContentIdeaEntry
    let onEditTap: () -> Void
    let onTogglePinned: () -> Void

    private var subtitle: String {
        var parts: [String] = []
        let platform = idea.platform.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = idea.tagsRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !platform.isEmpty { parts.append(platform) }
        if !tags.isEmpty { parts.append(tags) }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        Button(action: onEditTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if idea.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppPalette.ContentIdeas.c700)
                            }
                            Text(idea.title)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.appTextPrimary)
                                .lineLimit(2)
                        }

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        onTogglePinned()
                    } label: {
                        Image(systemName: idea.isPinned ? "pin.slash" : "pin")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppPalette.ContentIdeas.c700)
                            .frame(width: 30, height: 30)
                            .background(AppPalette.ContentIdeas.c200.opacity(0.65), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                if !idea.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(idea.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(4)
                }

                Text("Actualizado: \(idea.updatedAt.formatted(.dateTime.locale(Locale(identifier: "es_MX")).day().month(.abbreviated).hour().minute()))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appField, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appStrokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AddContentIdeaView: View {
    @Environment(\.dismiss) private var dismiss

    private let initialIdea: ContentIdeaEntry?
    private let onSave: (ContentIdeaPayload) -> Void
    private let onDelete: (() -> Void)?

    @State private var title: String
    @State private var detail: String
    @State private var tagsRaw: String
    @State private var platform: String
    @State private var isPinned: Bool

    init(
        initialIdea: ContentIdeaEntry? = nil,
        onSave: @escaping (ContentIdeaPayload) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.initialIdea = initialIdea
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: initialIdea?.title ?? "")
        _detail = State(initialValue: initialIdea?.detail ?? "")
        _tagsRaw = State(initialValue: initialIdea?.tagsRaw ?? "")
        _platform = State(initialValue: initialIdea?.platform ?? "")
        _isPinned = State(initialValue: initialIdea?.isPinned ?? false)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ContentIdeasBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ContentIdeasFormCard(title: "Titulo", icon: "sparkles") {
                            TextField("Ej. Guion de 60s sobre...", text: $title)
                                .textInputAutocapitalization(.sentences)
                        }

                        ContentIdeasFormCard(title: "Detalle", icon: "text.alignleft") {
                            TextEditor(text: $detail)
                                .frame(minHeight: 140)
                                .scrollContentBackground(.hidden)
                        }

                        ContentIdeasFormCard(title: "Tags (opcional)", icon: "number") {
                            TextField("Ej. #swiftui #finanzas #gym", text: $tagsRaw)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        ContentIdeasFormCard(title: "Plataforma (opcional)", icon: "tv") {
                            TextField("Ej. TikTok / YouTube / Instagram", text: $platform)
                                .textInputAutocapitalization(.words)
                        }

                        ContentIdeasFormCard(title: "Prioridad", icon: "pin") {
                            Toggle(isOn: $isPinned) {
                                Text("Fijar idea")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appTextPrimary)
                            }
                            .tint(AppPalette.ContentIdeas.c600)
                        }

                        Button {
                            onSave(
                                ContentIdeaPayload(
                                    title: title,
                                    detail: detail,
                                    tagsRaw: tagsRaw,
                                    platform: platform,
                                    isPinned: isPinned
                                )
                            )
                            dismiss()
                        } label: {
                            Label(initialIdea == nil ? "Guardar" : "Actualizar", systemImage: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppPalette.ContentIdeas.c600)
                        .disabled(!canSave)

                        if let onDelete {
                            Button(role: .destructive) {
                                onDelete()
                                dismiss()
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(initialIdea == nil ? "Nueva idea" : "Editar idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }
}

private struct ContentIdeasFormCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.ContentIdeas.c700)
                    .frame(width: 30, height: 30)
                    .background(AppPalette.ContentIdeas.c200.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

