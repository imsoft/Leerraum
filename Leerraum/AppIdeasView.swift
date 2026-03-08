import SwiftUI
import SwiftData

private enum IdeaStatus: String, CaseIterable, Identifiable {
    case pending = "Pendiente"
    case inProgress = "En progreso"
    case done = "Hecha"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pending:
            return "clock"
        case .inProgress:
            return "bolt"
        case .done:
            return "checkmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending:
            return Color(red: 0.95, green: 0.58, blue: 0.20)
        case .inProgress:
            return Color(red: 0.13, green: 0.49, blue: 0.89)
        case .done:
            return Color(red: 0.09, green: 0.61, blue: 0.37)
        }
    }

    static func from(raw: String) -> IdeaStatus {
        IdeaStatus(rawValue: raw) ?? .pending
    }
}

private struct AppIdeaEditTarget: Identifiable {
    let id: UUID
}

struct AppIdeasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppIdeaNote.createdAt, order: .reverse) private var ideas: [AppIdeaNote]

    @State private var showingAddSheet = false
    @State private var editTarget: AppIdeaEditTarget?

    private var metrics: AppIdeasMetrics {
        AppIdeasMetrics(ideas: ideas)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppIdeasBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        AppIdeasSummaryCard(
                            total: metrics.total,
                            pending: metrics.pending,
                            inProgress: metrics.inProgress,
                            done: metrics.done
                        )

                        FeatureSectionHeader(title: "Ideas") {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Label("Nueva", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.Ideas.c500)
                        }

                        if ideas.isEmpty {
                            AppIdeasEmptyStateCard {
                                showingAddSheet = true
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(ideas, id: \.id) { idea in
                                    AppIdeaRow(idea: idea) {
                                        editTarget = AppIdeaEditTarget(id: idea.id)
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
            .navigationTitle("Ideas")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddSheet) {
                AddIdeaView { payload in
                    createIdea(payload)
                }
            }
            .sheet(item: $editTarget) { target in
                if let selectedIdea = ideas.first(where: { $0.id == target.id }) {
                    AddIdeaView(initialIdea: selectedIdea) { payload in
                        updateIdea(selectedIdea, payload: payload)
                    } onDelete: {
                        deleteIdea(selectedIdea)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Idea no disponible",
                            systemImage: "lightbulb",
                            description: Text("Este registro ya no existe.")
                        )
                    }
                }
            }
        }
    }

    private func createIdea(_ payload: IdeaPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let idea = AppIdeaNote(
            title: title,
            detail: payload.detail.trimmingCharacters(in: .whitespacesAndNewlines),
            statusRaw: payload.status.rawValue
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(idea)
        }
    }

    private func updateIdea(_ idea: AppIdeaNote, payload: IdeaPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            idea.title = title
            idea.detail = payload.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            idea.statusRaw = payload.status.rawValue
        }
    }

    private func deleteIdea(_ idea: AppIdeaNote) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(idea)
        }
    }
}

private struct AppIdeasBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .ideas)
    }
}

private struct AppIdeasSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let total: Int
    let pending: Int
    let inProgress: Int
    let done: Int

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.Ideas.c900, AppPalette.Ideas.c700]
        }
        return [AppPalette.Ideas.c600, AppPalette.Ideas.c400]
    }

    private var strokeColor: Color {
        .white.opacity(colorScheme == .dark ? 0.18 : 0.28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roadmap personal")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            Text("\(total) ideas")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                AppIdeasPill(title: "Pend.", value: "\(pending)")
                AppIdeasPill(title: "Proceso", value: "\(inProgress)")
                AppIdeasPill(title: "Hechas", value: "\(done)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
    }
}

private struct AppIdeasPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.82 : 0.92))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            .white.opacity(colorScheme == .dark ? 0.17 : 0.24),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct AppIdeasEmptyStateCard: View {
    let onCreateTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin ideas todavia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Anota mejoras o funciones nuevas para seguir evolucionando Leerraum.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Agregar idea") {
                onCreateTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.Ideas.c500)
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

private struct AppIdeaRow: View {
    let idea: AppIdeaNote
    let onTap: () -> Void

    private var status: IdeaStatus {
        IdeaStatus.from(raw: idea.statusRaw)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(idea.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)

                    if !idea.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(idea.detail)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        Label(status.rawValue, systemImage: status.icon)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(status.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(status.tint.opacity(0.15), in: Capsule())

                        Text(idea.createdAt.formatted(.dateTime.locale(Locale(identifier: "es_MX")).day().month(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color.appField,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.appStrokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IdeaPayload {
    let title: String
    let detail: String
    let status: IdeaStatus
}

private struct AddIdeaView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var status: IdeaStatus = .pending
    @State private var showingDeleteAlert = false

    private let isEditing: Bool
    let onSave: (IdeaPayload) -> Void
    let onDelete: (() -> Void)?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppIdeasBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            AppIdeasInputLabel(title: "Titulo", systemImage: "textformat")
                            TextField("", text: $title)
                                .textInputAutocapitalization(.words)
                                .appIdeasInputField()

                            AppIdeasInputLabel(title: "Estado", systemImage: status.icon)
                            Picker("", selection: $status) {
                                ForEach(IdeaStatus.allCases) { current in
                                    Text(current.rawValue).tag(current)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(AppPalette.Ideas.c500)

                            AppIdeasInputLabel(title: "Detalle (opcional)", systemImage: "note.text")
                            TextField("", text: $detail, axis: .vertical)
                                .lineLimit(3...6)
                                .appIdeasInputField(minHeight: 90)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appStrokeSoft, lineWidth: 1)
                        )

                        if isEditing, onDelete != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Eliminar idea")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.62, green: 0.13, blue: 0.18))

                                Button(role: .destructive) {
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Eliminar idea", systemImage: "trash.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 0.90, green: 0.20, blue: 0.22))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color(red: 1.00, green: 0.94, blue: 0.95),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(red: 0.90, green: 0.20, blue: 0.22).opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(isEditing ? "Editar idea" : "Nueva idea")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.Ideas.c500)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Actualizar" : "Guardar") {
                        onSave(IdeaPayload(title: title, detail: detail, status: status))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Eliminar idea", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Esta idea se eliminara de la lista.")
            }
        }
    }

    init(
        initialIdea: AppIdeaNote? = nil,
        onSave: @escaping (IdeaPayload) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.isEditing = initialIdea != nil

        if let initialIdea {
            _title = State(initialValue: initialIdea.title)
            _detail = State(initialValue: initialIdea.detail)
            _status = State(initialValue: IdeaStatus.from(raw: initialIdea.statusRaw))
        }
    }
}

private struct AppIdeasInputLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.appTextSecondary)
    }
}

private extension View {
    func appIdeasInputField(minHeight: CGFloat = 0) -> some View {
        self
            .foregroundStyle(Color.appTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background(
                Color.appField,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.Ideas.c500.opacity(0.24), lineWidth: 1)
            )
    }
}
