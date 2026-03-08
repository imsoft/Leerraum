import SwiftUI
import SwiftData

private struct LifeGoalEditTarget: Identifiable {
    let id: UUID
}

struct LifeGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LifeGoal.createdAt, order: .reverse) private var goals: [LifeGoal]

    @State private var showingAddSheet = false
    @State private var editTarget: LifeGoalEditTarget?

    private var metrics: LifeGoalsMetrics {
        LifeGoalsMetrics(goals: goals)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeGoalsBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        LifeGoalsSummaryCard(
                            total: metrics.total,
                            averageProgress: metrics.averageProgress,
                            notStarted: metrics.notStarted,
                            inProgress: metrics.inProgress,
                            completed: metrics.completed
                        )

                        FeatureSectionHeader(title: "Metas") {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Label("Nueva", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.LifeGoals.c600)
                        }

                        if goals.isEmpty {
                            LifeGoalsEmptyStateCard {
                                showingAddSheet = true
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(goals, id: \.id) { goal in
                                    LifeGoalRow(goal: goal) {
                                        editTarget = LifeGoalEditTarget(id: goal.id)
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
            .navigationTitle("Metas de vida")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddSheet) {
                AddLifeGoalView { payload in
                    createGoal(payload)
                }
            }
            .sheet(item: $editTarget) { target in
                if let selectedGoal = goals.first(where: { $0.id == target.id }) {
                    AddLifeGoalView(initialGoal: selectedGoal) { payload in
                        updateGoal(selectedGoal, payload: payload)
                    } onDelete: {
                        deleteGoal(selectedGoal)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Meta no disponible",
                            systemImage: "target",
                            description: Text("Este registro ya no existe.")
                        )
                    }
                }
            }
        }
    }

    private func createGoal(_ payload: LifeGoalPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let goal = LifeGoal(
            title: title,
            detail: payload.detail.trimmingCharacters(in: .whitespacesAndNewlines),
            targetDate: payload.targetDate,
            progress: max(0, min(payload.progress, 100)),
            priority: payload.priority,
            area: payload.area
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(goal)
        }
    }

    private func updateGoal(_ goal: LifeGoal, payload: LifeGoalPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            goal.title = title
            goal.detail = payload.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            goal.targetDate = payload.targetDate
            goal.progress = max(0, min(payload.progress, 100))
            goal.priority = payload.priority
            goal.area = payload.area
        }
    }

    private func deleteGoal(_ goal: LifeGoal) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(goal)
        }
    }
}

private struct LifeGoalsBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .lifeGoals)
    }
}

private struct LifeGoalsSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let total: Int
    let averageProgress: Int
    let notStarted: Int
    let inProgress: Int
    let completed: Int

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.LifeGoals.c900, AppPalette.LifeGoals.c700]
        }
        return [AppPalette.LifeGoals.c600, AppPalette.LifeGoals.c400]
    }

    private var strokeColor: Color {
        .white.opacity(colorScheme == .dark ? 0.18 : 0.28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vision personal")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(averageProgress)%")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("avance")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }

            HStack(spacing: 8) {
                LifeGoalsPill(title: "Metas", value: "\(total)")
                LifeGoalsPill(title: "Proceso", value: "\(inProgress)")
                LifeGoalsPill(title: "Hechas", value: "\(completed)")
                LifeGoalsPill(title: "Inicio", value: "\(notStarted)")
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

private struct LifeGoalsPill: View {
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
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            .white.opacity(colorScheme == .dark ? 0.18 : 0.24),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct LifeGoalsEmptyStateCard: View {
    let onCreateTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin metas todavia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Define metas de vida y lleva su progreso para ver como avanzas con el tiempo.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Crear meta") {
                onCreateTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.LifeGoals.c600)
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

private struct LifeGoalRow: View {
    let goal: LifeGoal
    let onTap: () -> Void

    private var clampedProgress: Int {
        max(0, min(goal.progress, 100))
    }

    private var progressTint: Color {
        if clampedProgress >= 100 {
            return AppPalette.LifeGoals.c600
        } else if clampedProgress > 0 {
            return AppPalette.LifeGoals.c500
        } else {
            return Color.appTextSecondary
        }
    }

    private var priorityTint: Color {
        goal.priority.tint
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)

                    if !goal.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(goal.detail)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        Label(goal.priority.displayName, systemImage: "flag.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(priorityTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(priorityTint.opacity(0.14), in: Capsule())

                        Label(goal.area.displayName, systemImage: goal.area.icon)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(goal.area.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(goal.area.tint.opacity(0.14), in: Capsule())
                    }

                    ProgressView(value: Double(clampedProgress), total: 100)
                        .tint(progressTint)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 6) {
                        Text("\(clampedProgress)%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(progressTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(progressTint.opacity(0.14), in: Capsule())

                        if let targetDate = goal.targetDate {
                            Label(
                                targetDate.formatted(
                                    .dateTime
                                        .locale(Locale(identifier: "es_MX"))
                                        .day()
                                        .month(.abbreviated)
                                        .year()
                                ),
                                systemImage: "calendar"
                            )
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 16, height: 16, alignment: .center)
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

private struct LifeGoalPayload {
    let title: String
    let detail: String
    let targetDate: Date?
    let progress: Int
    let priority: LifeGoalPriority
    let area: LifeGoalArea
}

private struct AddLifeGoalView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var progress: Double = 0
    @State private var priority: LifeGoalPriority = .medium
    @State private var area: LifeGoalArea = .personal
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var showingDeleteAlert = false

    private let isEditing: Bool
    let onSave: (LifeGoalPayload) -> Void
    let onDelete: (() -> Void)?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeGoalsBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            LifeGoalsInputLabel(title: "Meta", systemImage: "target")
                            TextField("", text: $title)
                                .textInputAutocapitalization(.sentences)
                                .lifeGoalInputField()

                            LifeGoalsInputLabel(title: "Detalle (opcional)", systemImage: "note.text")
                            TextField("", text: $detail, axis: .vertical)
                                .lineLimit(3...6)
                                .lifeGoalInputField(minHeight: 90)

                            LifeGoalsInputLabel(title: "Progreso", systemImage: "chart.bar.fill")
                            HStack(spacing: 10) {
                                Slider(value: $progress, in: 0...100, step: 1)
                                    .tint(AppPalette.LifeGoals.c600)
                                Text("\(Int(progress))%")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.appTextPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        Color.appField,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                            }

                            LifeGoalsInputLabel(title: "Prioridad", systemImage: "flag.fill")
                            Picker("Prioridad", selection: $priority) {
                                ForEach(LifeGoalPriority.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(AppPalette.LifeGoals.c600)

                            LifeGoalsInputLabel(title: "Area", systemImage: area.icon)
                            Menu {
                                ForEach(LifeGoalArea.allCases) { option in
                                    Button {
                                        area = option
                                    } label: {
                                        HStack {
                                            Image(systemName: option.icon)
                                                .foregroundStyle(option.tint)
                                            Text(option.displayName)
                                            Spacer()
                                            if option == area {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(AppPalette.LifeGoals.c600)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: area.icon)
                                        .foregroundStyle(area.tint)
                                    Text(area.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appTextPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppPalette.LifeGoals.c600)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppPalette.LifeGoals.c600.opacity(0.24), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            LifeGoalsInputLabel(title: "Fecha objetivo (opcional)", systemImage: "calendar")
                            Toggle("Activar fecha objetivo", isOn: $hasTargetDate)
                                .font(.subheadline.weight(.semibold))
                                .tint(AppPalette.LifeGoals.c600)

                            if hasTargetDate {
                                DatePicker("", selection: $targetDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 6)
                            }
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
                                Text("Eliminar meta")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.62, green: 0.13, blue: 0.18))

                                Button(role: .destructive) {
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Eliminar meta", systemImage: "trash.fill")
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
            .navigationTitle(isEditing ? "Editar meta" : "Nueva meta")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.LifeGoals.c600)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Actualizar" : "Guardar") {
                        onSave(
                            LifeGoalPayload(
                                title: title,
                                detail: detail,
                                targetDate: hasTargetDate ? targetDate : nil,
                                progress: Int(progress),
                                priority: priority,
                                area: area
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Eliminar meta", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Esta meta se eliminara de tu lista.")
            }
        }
    }

    init(
        initialGoal: LifeGoal? = nil,
        onSave: @escaping (LifeGoalPayload) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.isEditing = initialGoal != nil

        if let initialGoal {
            _title = State(initialValue: initialGoal.title)
            _detail = State(initialValue: initialGoal.detail)
            _progress = State(initialValue: Double(max(0, min(initialGoal.progress, 100))))
            _priority = State(initialValue: initialGoal.priority)
            _area = State(initialValue: initialGoal.area)
            if let targetDate = initialGoal.targetDate {
                _hasTargetDate = State(initialValue: true)
                _targetDate = State(initialValue: targetDate)
            }
        }
    }
}

private struct LifeGoalsInputLabel: View {
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
    func lifeGoalInputField(minHeight: CGFloat = 0) -> some View {
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
                    .stroke(AppPalette.LifeGoals.c600.opacity(0.24), lineWidth: 1)
            )
    }
}
