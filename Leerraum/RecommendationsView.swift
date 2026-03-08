import SwiftUI
import SwiftData
import OSLog

private enum RecommendationFilter: String, CaseIterable, Identifiable {
    case all
    case pending
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Todas"
        case .pending:
            return "Pendientes"
        case .completed:
            return "Hechas"
        }
    }
}

private struct RecommendationEditTarget: Identifiable {
    let id: UUID
}

struct RecommendationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecommendationEntry.createdAt, order: .reverse) private var recommendations: [RecommendationEntry]

    @State private var selectedFilter: RecommendationFilter = .all
    @State private var selectedKind: RecommendationKind?
    @State private var showingAddSheet = false
    @State private var editTarget: RecommendationEditTarget?
    @State private var cachedFilteredRecommendations: [RecommendationEntry] = []
    @State private var cachedMetrics = RecommendationsMetrics(recommendations: [])
    @State private var listRefreshTask: Task<Void, Never>?

    private var filteredRecommendations: [RecommendationEntry] {
        cachedFilteredRecommendations
    }

    private var metrics: RecommendationsMetrics {
        cachedMetrics
    }

    private var refreshSignature: Int {
        var hasher = Hasher()
        hasher.combine(selectedFilter.rawValue)
        hasher.combine(selectedKind?.rawValue)
        hasher.combine(recommendations.count)
        for item in recommendations {
            hasher.combine(item.id)
            hasher.combine(item.isCompleted)
            hasher.combine(item.kind.rawValue)
        }
        return hasher.finalize()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RecommendationsBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        RecommendationsSummaryCard(
                            total: metrics.total,
                            pending: metrics.pending,
                            completed: metrics.completed,
                            topKind: metrics.topKind
                        )

                        Picker("Filtro", selection: $selectedFilter) {
                            ForEach(RecommendationFilter.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(AppPalette.Recommendations.c600)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                RecommendationKindFilterChip(
                                    title: "Todo tipo",
                                    icon: "line.3.horizontal.decrease.circle",
                                    isSelected: selectedKind == nil,
                                    tint: AppPalette.Recommendations.c700
                                ) {
                                    selectedKind = nil
                                }

                                ForEach(RecommendationKind.allCases) { kind in
                                    RecommendationKindFilterChip(
                                        title: kind.displayName,
                                        icon: kind.icon,
                                        isSelected: selectedKind == kind,
                                        tint: kind.tint
                                    ) {
                                        selectedKind = kind
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        FeatureSectionHeader(title: "Tus recomendaciones") {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Label("Nueva", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.Recommendations.c600)
                        }

                        if filteredRecommendations.isEmpty {
                            RecommendationsEmptyStateCard {
                                showingAddSheet = true
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredRecommendations, id: \.id) { recommendation in
                                    RecommendationRow(item: recommendation) {
                                        editTarget = RecommendationEditTarget(id: recommendation.id)
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
            .navigationTitle("Recomendaciones")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddSheet) {
                AddRecommendationView { payload in
                    createRecommendation(payload)
                }
            }
            .sheet(item: $editTarget) { target in
                if let selectedRecommendation = recommendations.first(where: { $0.id == target.id }) {
                    AddRecommendationView(initialRecommendation: selectedRecommendation) { payload in
                        updateRecommendation(selectedRecommendation, payload: payload)
                    } onDelete: {
                        deleteRecommendation(selectedRecommendation)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Recomendacion no disponible",
                            systemImage: "sparkles.rectangle.stack",
                            description: Text("Este registro ya no existe.")
                        )
                    }
                }
            }
            .onAppear {
                scheduleListRefresh(immediate: true)
            }
            .onChange(of: refreshSignature) { _, _ in
                scheduleListRefresh()
            }
            .onDisappear {
                listRefreshTask?.cancel()
                listRefreshTask = nil
            }
        }
    }

    private func scheduleListRefresh(immediate: Bool = false) {
        listRefreshTask?.cancel()
        listRefreshTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard !Task.isCancelled else { return }
            recomputeListState()
        }
    }

    private func recomputeListState() {
        let interval = Observability.recommendationsSignposter.beginInterval("recommendations.listState.recompute")
        defer { Observability.recommendationsSignposter.endInterval("recommendations.listState.recompute", interval) }
        cachedMetrics = RecommendationsMetrics(recommendations: recommendations)
        cachedFilteredRecommendations = recommendations.filter { item in
            let matchesStatus: Bool
            switch selectedFilter {
            case .all:
                matchesStatus = true
            case .pending:
                matchesStatus = !item.isCompleted
            case .completed:
                matchesStatus = item.isCompleted
            }

            let matchesKind = selectedKind == nil || item.kind == selectedKind
            return matchesStatus && matchesKind
        }
        Observability.debug(
            Observability.recommendationsLogger,
            "Recommendations state recomputed. total: \(recommendations.count), filtered: \(cachedFilteredRecommendations.count)"
        )
    }

    private func createRecommendation(_ payload: RecommendationPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let entry = RecommendationEntry(
            title: title,
            detail: payload.detail.trimmingCharacters(in: .whitespacesAndNewlines),
            recommendedBy: payload.recommendedBy.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: payload.kind,
            isCompleted: payload.isCompleted
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(entry)
        }
    }

    private func updateRecommendation(_ recommendation: RecommendationEntry, payload: RecommendationPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            recommendation.title = title
            recommendation.detail = payload.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            recommendation.recommendedBy = payload.recommendedBy.trimmingCharacters(in: .whitespacesAndNewlines)
            recommendation.kind = payload.kind
            recommendation.isCompleted = payload.isCompleted
        }
    }

    private func deleteRecommendation(_ recommendation: RecommendationEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(recommendation)
        }
    }
}

private struct RecommendationsBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .recommendations)
    }
}

private struct RecommendationsSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let total: Int
    let pending: Int
    let completed: Int
    let topKind: RecommendationKind?

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.Recommendations.c900, AppPalette.Recommendations.c700]
        }
        return [AppPalette.Recommendations.c700, AppPalette.Recommendations.c500]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Radar de recomendaciones")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            Text("\(total)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                RecommendationSummaryPill(title: "Pendientes", value: "\(pending)")
                RecommendationSummaryPill(title: "Hechas", value: "\(completed)")
                RecommendationSummaryPill(
                    title: "Top",
                    value: topKind?.displayName ?? "-"
                )
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
                .stroke(.white.opacity(colorScheme == .dark ? 0.18 : 0.28), lineWidth: 1)
        )
    }
}

private struct RecommendationSummaryPill: View {
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
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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

private struct RecommendationKindFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isSelected ? tint : tint.opacity(0.12),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(isSelected ? 0.0 : 0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct RecommendationsEmptyStateCard: View {
    let onCreateTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin recomendaciones todavia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Guarda aqui series, peliculas, musica y recomendaciones personales para no perderlas.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Agregar recomendacion") {
                onCreateTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.Recommendations.c600)
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

private struct RecommendationRow: View {
    let item: RecommendationEntry
    let onTap: () -> Void

    private var createdAtText: String {
        item.createdAt.formatted(
            .dateTime
                .locale(Locale(identifier: "es_MX"))
                .day()
                .month(.abbreviated)
                .year()
        )
    }

    private var byText: String {
        let cleanAuthor = item.recommendedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanAuthor.isEmpty {
            return createdAtText
        }
        return "Por \(cleanAuthor) · \(createdAtText)"
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)

                    Text(byText)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)

                    if !item.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        Label(item.kind.displayName, systemImage: item.kind.icon)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(item.kind.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(item.kind.tint.opacity(0.14), in: Capsule())

                        if item.isCompleted {
                            Label("Hecha", systemImage: "checkmark.circle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppPalette.Recommendations.c700)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(AppPalette.Recommendations.c300.opacity(0.32), in: Capsule())
                        }
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 20, height: 20, alignment: .center)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
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

private struct RecommendationPayload {
    let title: String
    let detail: String
    let recommendedBy: String
    let kind: RecommendationKind
    let isCompleted: Bool
}

private struct AddRecommendationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var recommendedBy = ""
    @State private var kind: RecommendationKind = .series
    @State private var isCompleted = false
    @State private var showingDeleteAlert = false

    private let isEditing: Bool
    let onSave: (RecommendationPayload) -> Void
    let onDelete: (() -> Void)?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RecommendationsBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            RecommendationInputLabel(title: "Titulo", systemImage: "textformat")
                            TextField("", text: $title)
                                .textInputAutocapitalization(.sentences)
                                .recommendationsInputField()

                            RecommendationInputLabel(title: "Tipo", systemImage: kind.icon)
                            Menu {
                                ForEach(RecommendationKind.allCases) { option in
                                    Button {
                                        kind = option
                                    } label: {
                                        Label(option.displayName, systemImage: option.icon)
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: kind.icon)
                                        .foregroundStyle(kind.tint)
                                    Text(kind.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appTextPrimary)
                                    Spacer(minLength: 6)
                                    Image(systemName: "chevron.down")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                .contentShape(Rectangle())
                                .recommendationsInputField()
                            }
                            .buttonStyle(.plain)

                            RecommendationInputLabel(title: "Quien te lo recomendo", systemImage: "person.2")
                            TextField("", text: $recommendedBy)
                                .textInputAutocapitalization(.words)
                                .recommendationsInputField()

                            RecommendationInputLabel(title: "Notas (opcional)", systemImage: "note.text")
                            TextField("", text: $detail, axis: .vertical)
                                .lineLimit(3...6)
                                .recommendationsInputField(minHeight: 90)

                            Toggle(isOn: $isCompleted) {
                                Label("Ya la completaste", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appTextPrimary)
                            }
                            .tint(AppPalette.Recommendations.c600)
                            .padding(.top, 4)
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
                                Text("Eliminar recomendacion")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.62, green: 0.13, blue: 0.18))

                                Button(role: .destructive) {
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Eliminar recomendacion", systemImage: "trash.fill")
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
            .navigationTitle(isEditing ? "Editar recomendacion" : "Nueva recomendacion")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.Recommendations.c600)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Actualizar" : "Guardar") {
                        onSave(
                            RecommendationPayload(
                                title: title,
                                detail: detail,
                                recommendedBy: recommendedBy,
                                kind: kind,
                                isCompleted: isCompleted
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Eliminar recomendacion", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Esta recomendacion se eliminara de la lista.")
            }
        }
    }

    init(
        initialRecommendation: RecommendationEntry? = nil,
        onSave: @escaping (RecommendationPayload) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.isEditing = initialRecommendation != nil

        if let initialRecommendation {
            _title = State(initialValue: initialRecommendation.title)
            _detail = State(initialValue: initialRecommendation.detail)
            _recommendedBy = State(initialValue: initialRecommendation.recommendedBy)
            _kind = State(initialValue: initialRecommendation.kind)
            _isCompleted = State(initialValue: initialRecommendation.isCompleted)
        }
    }
}

private struct RecommendationInputLabel: View {
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
    func recommendationsInputField(minHeight: CGFloat = 0) -> some View {
        self
            .foregroundStyle(Color.appTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.appField,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.Recommendations.c600.opacity(0.26), lineWidth: 1)
            )
    }
}
