import SwiftUI
import SwiftData

private struct ReminderEditTarget: Identifiable {
    let id: UUID
}

private struct ReminderDetailTarget: Identifiable {
    let id: UUID
}

private struct ReminderPayload {
    let title: String
    let note: String
}

struct RemindersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.createdAt, order: .reverse) private var reminders: [Reminder]

    @State private var showingAddSheet = false
    @State private var editTarget: ReminderEditTarget?
    @State private var detailTarget: ReminderDetailTarget?

    var deepLinkedReminderID: UUID?

    private var pendingReminders: [Reminder] {
        reminders.filter { !$0.isCompleted }
    }

    private var completedReminders: [Reminder] {
        reminders.filter { $0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RemindersBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if reminders.isEmpty {
                            RemindersEmptyStateCard {
                                showingAddSheet = true
                            }
                        } else {
                            if !pendingReminders.isEmpty {
                                FeatureSectionHeader(title: "Pendientes") {}

                                LazyVStack(spacing: 10) {
                                    ForEach(pendingReminders, id: \.id) { reminder in
                                        ReminderRow(
                                            reminder: reminder,
                                            onComplete: {
                                                completeReminder(reminder)
                                            },
                                            onTap: {
                                                detailTarget = ReminderDetailTarget(id: reminder.id)
                                            },
                                            onEditTap: {
                                                editTarget = ReminderEditTarget(id: reminder.id)
                                            }
                                        )
                                    }
                                }
                            }

                            if !completedReminders.isEmpty {
                                FeatureSectionHeader(title: "Completados") {}

                                LazyVStack(spacing: 10) {
                                    ForEach(completedReminders, id: \.id) { reminder in
                                        ReminderRow(
                                            reminder: reminder,
                                            onComplete: {
                                                uncompleteReminder(reminder)
                                            },
                                            onTap: {
                                                detailTarget = ReminderDetailTarget(id: reminder.id)
                                            },
                                            onEditTap: {
                                                editTarget = ReminderEditTarget(id: reminder.id)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Recordatorios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppPalette.Reminders.c600)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddReminderView { payload in
                    addReminder(payload)
                }
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
            }
            .sheet(item: $editTarget) { target in
                if let reminder = reminders.first(where: { $0.id == target.id }) {
                    AddReminderView(
                        initialReminder: reminder,
                        onSave: { payload in
                            updateReminder(reminder, with: payload)
                        },
                        onDelete: {
                            deleteReminder(reminder)
                        }
                    )
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.medium])
                }
            }
            .sheet(item: $detailTarget) { target in
                if let reminder = reminders.first(where: { $0.id == target.id }) {
                    ReminderDetailView(
                        reminder: reminder,
                        onComplete: {
                            if reminder.isCompleted {
                                uncompleteReminder(reminder)
                            } else {
                                completeReminder(reminder)
                            }
                        }
                    )
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.medium, .large])
                }
            }
            .onAppear {
                if let id = deepLinkedReminderID {
                    detailTarget = ReminderDetailTarget(id: id)
                }
            }
        }
    }

    private func addReminder(_ payload: ReminderPayload) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let reminder = Reminder(
                title: payload.title,
                note: payload.note
            )
            modelContext.insert(reminder)
        }
    }

    private func updateReminder(_ reminder: Reminder, with payload: ReminderPayload) {
        withAnimation(.easeInOut(duration: 0.2)) {
            reminder.title = payload.title
            reminder.note = payload.note
        }
    }

    private func deleteReminder(_ reminder: Reminder) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(reminder)
        }
    }

    private func completeReminder(_ reminder: Reminder) {
        withAnimation(.easeInOut(duration: 0.2)) {
            reminder.isCompleted = true
            reminder.completedAt = .now
        }
    }

    private func uncompleteReminder(_ reminder: Reminder) {
        withAnimation(.easeInOut(duration: 0.2)) {
            reminder.isCompleted = false
            reminder.completedAt = nil
        }
    }
}

private struct RemindersBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .reminders)
    }
}

private struct RemindersEmptyStateCard: View {
    let onCreateTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin recordatorios todavia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Agrega tareas pendientes y recibe notificaciones aleatorias hasta que las completes.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Crear recordatorio") {
                onCreateTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.Reminders.c600)
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

private struct ReminderRow: View {
    let reminder: Reminder
    let onComplete: () -> Void
    let onTap: () -> Void
    let onEditTap: () -> Void

    private var postponedText: String {
        let days = Calendar.current.dateComponents([.day], from: reminder.createdAt, to: .now).day ?? 0
        if days == 0 {
            return "Creado hoy"
        } else if days == 1 {
            return "1 dia postergado"
        } else {
            return "\(days) dias postergado"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                            .strikethrough(reminder.isCompleted)
                            .lineLimit(2)

                        if !reminder.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(reminder.note)
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        onEditTap()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppPalette.Reminders.c700)
                            .frame(width: 30, height: 30)
                            .background(AppPalette.Reminders.c200.opacity(0.65), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    if !reminder.isCompleted {
                        Label(postponedText, systemImage: "clock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.Reminders.c700)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                AppPalette.Reminders.c100.opacity(0.70),
                                in: Capsule()
                            )
                    } else {
                        Label("Completado", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.Reminders.c700)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                AppPalette.Reminders.c100.opacity(0.70),
                                in: Capsule()
                            )
                    }

                    Spacer()

                    Button {
                        onComplete()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: reminder.isCompleted ? "arrow.uturn.backward" : "checkmark")
                                .font(.caption.weight(.bold))
                            Text(reminder.isCompleted ? "Reabrir" : "Completar")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(reminder.isCompleted ? AppPalette.Reminders.c700 : .white)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(reminder.isCompleted ? AppPalette.Reminders.c100 : AppPalette.Reminders.c600)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                Color.appField,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appStrokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ReminderDetailView: View {
    let reminder: Reminder
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var postponedText: String {
        let days = Calendar.current.dateComponents([.day], from: reminder.createdAt, to: .now).day ?? 0
        if days == 0 {
            return "Creado hoy"
        } else if days == 1 {
            return "1 dia postergado"
        } else {
            return "\(days) dias postergado"
        }
    }

    private var createdDateText: String {
        reminder.createdAt.formatted(
            .dateTime
                .locale(Locale(identifier: "es_MX"))
                .day()
                .month(.wide)
                .year()
                .hour()
                .minute()
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RemindersBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        RemindersFormCard(title: "Tarea", icon: "text.alignleft") {
                            Text(reminder.title)
                                .font(.body)
                                .foregroundStyle(Color.appTextPrimary)
                        }

                        if !reminder.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            RemindersFormCard(title: "Nota", icon: "note.text") {
                                Text(reminder.note)
                                    .font(.body)
                                    .foregroundStyle(Color.appTextPrimary)
                            }
                        }

                        RemindersFormCard(title: "Estado", icon: "clock") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(reminder.isCompleted ? "Completado" : "Pendiente")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(reminder.isCompleted ? AppPalette.Reminders.c600 : Color.appTextPrimary)

                                Text(postponedText)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appTextSecondary)

                                Text("Creado: \(createdDateText)")
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }

                        Button {
                            onComplete()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: reminder.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill")
                                    .font(.body.weight(.bold))
                                Text(reminder.isCompleted ? "Reabrir tarea" : "Marcar como completada")
                                    .font(.body.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(
                                AppPalette.Reminders.c600,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Detalle")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss

    private let initialReminder: Reminder?
    private let onSave: (ReminderPayload) -> Void
    private let onDelete: (() -> Void)?

    @State private var title: String
    @State private var note: String

    init(
        initialReminder: Reminder? = nil,
        onSave: @escaping (ReminderPayload) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.initialReminder = initialReminder
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: initialReminder?.title ?? "")
        _note = State(initialValue: initialReminder?.note ?? "")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var screenTitle: String {
        initialReminder == nil ? "Nuevo recordatorio" : "Editar recordatorio"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RemindersBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        RemindersFormCard(title: "Tarea", icon: "text.alignleft") {
                            TextField("Ej. Llamar al banco", text: $title)
                                .font(.body)
                                .textInputAutocapitalization(.sentences)
                        }

                        RemindersFormCard(title: "Nota (opcional)", icon: "note.text") {
                            TextField("Detalles adicionales", text: $note, axis: .vertical)
                                .font(.body)
                                .lineLimit(3...6)
                                .textInputAutocapitalization(.sentences)
                        }

                        if let onDelete {
                            Button(role: .destructive) {
                                onDelete()
                                dismiss()
                            } label: {
                                Label("Eliminar recordatorio", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let payload = ReminderPayload(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onSave(payload)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private struct RemindersFormCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.Reminders.c700)

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appField, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}
