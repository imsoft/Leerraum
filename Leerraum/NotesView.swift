import SwiftUI
import SwiftData

private struct NoteEditTarget: Identifiable {
    let id: UUID
}

private struct NoteCategoryColorOption: Identifiable, Equatable {
    let id: String
    let title: String
    let red: Double
    let green: Double
    let blue: Double

    init(id: String, title: String, red: Double, green: Double, blue: Double) {
        self.id = id
        self.title = title
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(id: String, title: String, hex: String) {
        let components = Self.rgbComponents(from: hex)
        self.init(
            id: id,
            title: title,
            red: components.red,
            green: components.green,
            blue: components.blue
        )
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    private static func rgbComponents(from hex: String) -> (red: Double, green: Double, blue: Double) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)

        return (
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }

    static let all: [NoteCategoryColorOption] = [
        .init(id: "green", title: "Verde", hex: "#16A34A"),
        .init(id: "violet", title: "Violeta", hex: "#7C3AED"),
        .init(id: "orange", title: "Naranja", hex: "#EA580C"),
        .init(id: "indigo", title: "Indigo", hex: "#4F46E5"),
        .init(id: "cyan", title: "Cian", hex: "#0891B2"),
        .init(id: "yellow", title: "Amarillo", hex: "#CA8A04"),
        .init(id: "pink", title: "Rosa", hex: "#DB2777"),
        .init(id: "lime", title: "Lima", hex: "#65A30D"),
        .init(id: "teal", title: "Turquesa", hex: "#0D9488"),
        .init(id: "amber", title: "Ambar", hex: "#D97706"),
        .init(id: "red", title: "Rojo", hex: "#DC2626"),
        .init(id: "emerald", title: "Esmeralda", hex: "#059669"),
        .init(id: "sky", title: "Cielo", hex: "#0284C7"),
        .init(id: "blue", title: "Azul", hex: "#2563EB"),
        .init(id: "purple", title: "Purpura", hex: "#9333EA"),
        .init(id: "fuchsia", title: "Fucsia", hex: "#C026D3"),
        .init(id: "rose", title: "Rosa intenso", hex: "#E11D48")
    ]
}

private enum NoteCategoryDefaults {
    struct Entry {
        let name: String
        let icon: String
        let color: NoteCategoryColorOption
    }

    private static func option(_ id: String) -> NoteCategoryColorOption {
        NoteCategoryColorOption.all.first(where: { $0.id == id }) ?? NoteCategoryColorOption.all[0]
    }

    static let entries: [Entry] = [
        .init(name: "Finanzas", icon: "chart.line.uptrend.xyaxis", color: option("green")),
        .init(name: "Gym", icon: "figure.strengthtraining.traditional", color: option("violet")),
        .init(name: "Comidas", icon: "fork.knife", color: option("orange")),
        .init(name: "Frases", icon: "quote.bubble", color: option("indigo")),
        .init(name: "Medidas", icon: "ruler", color: option("cyan")),
        .init(name: "Ideas", icon: "lightbulb", color: option("yellow")),
        .init(name: "Metas de vida", icon: "target", color: option("pink")),
        .init(name: "Habitos", icon: "checklist", color: option("lime")),
        .init(name: "Recomendaciones", icon: "sparkles.rectangle.stack", color: option("teal"))
    ]

    static let iconOptions: [String] = [
        "note.text",
        "book",
        "bookmark",
        "calendar",
        "chart.line.uptrend.xyaxis",
        "checklist",
        "doc.text",
        "flag",
        "fork.knife",
        "figure.strengthtraining.traditional",
        "heart.text.square",
        "lightbulb",
        "ruler",
        "sparkles.rectangle.stack",
        "target",
        "wallet.bifold"
    ]
}

private struct NotesMetrics {
    let totalNotes: Int
    let totalCategories: Int
    let filteredNotes: Int
}

private struct NotePayload {
    let title: String
    let detail: String
    let categoryID: UUID?
}

private struct NoteCategoryPayload {
    let name: String
    let icon: String
    let color: NoteCategoryColorOption
}

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteEntry.updatedAt, order: .reverse) private var notes: [NoteEntry]
    @Query(sort: \NoteCategory.createdAt, order: .forward) private var categories: [NoteCategory]

    @State private var selectedCategoryID: UUID?
    @State private var showingAddNoteSheet = false
    @State private var showingAddCategorySheet = false
    @State private var editTarget: NoteEditTarget?

    private var filteredNotes: [NoteEntry] {
        guard let selectedCategoryID else { return notes }
        return notes.filter { $0.category?.id == selectedCategoryID }
    }

    private var metrics: NotesMetrics {
        NotesMetrics(
            totalNotes: notes.count,
            totalCategories: categories.count,
            filteredNotes: filteredNotes.count
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NotesBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        NotesSummaryCard(metrics: metrics)

                        FeatureSectionHeader(title: "Categorias") {
                            Button {
                                showingAddCategorySheet = true
                            } label: {
                                Label("Nueva", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.Notes.c600)
                        }

                        CategoryFilterStrip(
                            categories: categories,
                            selectedCategoryID: $selectedCategoryID
                        )

                        FeatureSectionHeader(title: "Notas") {
                            Button {
                                showingAddNoteSheet = true
                            } label: {
                                Label("Nueva", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.Notes.c600)
                        }

                        if filteredNotes.isEmpty {
                            NotesEmptyStateCard {
                                showingAddNoteSheet = true
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredNotes, id: \.id) { note in
                                    NoteRow(note: note) {
                                        editTarget = NoteEditTarget(id: note.id)
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
            .navigationTitle("Notas")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                seedDefaultCategoriesIfNeeded()
                syncDefaultCategoriesStyleIfNeeded()
            }
            .sheet(isPresented: $showingAddCategorySheet) {
                AddNoteCategoryView(existingCategories: categories) { payload in
                    createCategory(payload)
                }
            }
            .sheet(isPresented: $showingAddNoteSheet) {
                AddNoteView(categories: categories) { payload in
                    createNote(payload)
                }
            }
            .sheet(item: $editTarget) { target in
                if let selectedNote = notes.first(where: { $0.id == target.id }) {
                    AddNoteView(categories: categories, initialNote: selectedNote) { payload in
                        updateNote(selectedNote, payload: payload)
                    } onDelete: {
                        deleteNote(selectedNote)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Nota no disponible",
                            systemImage: "note.text",
                            description: Text("Este registro ya no existe.")
                        )
                    }
                }
            }
        }
    }

    private func seedDefaultCategoriesIfNeeded() {
        let existingNames = Set(
            categories.map {
                $0.name
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }
        )

        let missingEntries = NoteCategoryDefaults.entries.filter {
            !existingNames.contains($0.name.lowercased())
        }

        guard !missingEntries.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            for entry in missingEntries {
                let category = NoteCategory(
                    name: entry.name,
                    icon: entry.icon,
                    red: entry.color.red,
                    green: entry.color.green,
                    blue: entry.color.blue
                )
                modelContext.insert(category)
            }
        }
    }

    private func syncDefaultCategoriesStyleIfNeeded() {
        let defaultsByName = Dictionary(
            uniqueKeysWithValues: NoteCategoryDefaults.entries.map {
                ($0.name.lowercased(), $0)
            }
        )

        for category in categories {
            let key = category.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let style = defaultsByName[key] else { continue }

            let isDifferentColor =
                abs(category.red - style.color.red) > 0.001
                || abs(category.green - style.color.green) > 0.001
                || abs(category.blue - style.color.blue) > 0.001

            if category.icon != style.icon || isDifferentColor {
                category.icon = style.icon
                category.red = style.color.red
                category.green = style.color.green
                category.blue = style.color.blue
            }
        }
    }

    private func createCategory(_ payload: NoteCategoryPayload) {
        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let category = NoteCategory(
            name: name,
            icon: payload.icon,
            red: payload.color.red,
            green: payload.color.green,
            blue: payload.color.blue
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(category)
        }
    }

    private func createNote(_ payload: NotePayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = payload.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let selectedCategory = payload.categoryID.flatMap { id in
            categories.first(where: { $0.id == id })
        }

        let note = NoteEntry(
            title: title,
            detail: detail,
            category: selectedCategory
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(note)
        }
    }

    private func updateNote(_ note: NoteEntry, payload: NotePayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = payload.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let selectedCategory = payload.categoryID.flatMap { id in
            categories.first(where: { $0.id == id })
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            note.title = title
            note.detail = detail
            note.category = selectedCategory
            note.updatedAt = .now
        }
    }

    private func deleteNote(_ note: NoteEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(note)
        }
    }
}

private struct NotesBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .notes)
    }
}

private struct NotesSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let metrics: NotesMetrics

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.Notes.c900, AppPalette.Notes.c700]
        }
        return [AppPalette.Notes.c700, AppPalette.Notes.c500]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cuaderno personal")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            Text("\(metrics.totalNotes)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                NotesSummaryPill(title: "Notas", value: "\(metrics.totalNotes)")
                NotesSummaryPill(title: "Categorias", value: "\(metrics.totalCategories)")
                NotesSummaryPill(title: "Vista", value: "\(metrics.filteredNotes)")
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

private struct NotesSummaryPill: View {
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

private struct CategoryFilterStrip: View {
    let categories: [NoteCategory]
    @Binding var selectedCategoryID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedCategoryID = nil
                } label: {
                    Label("Todas", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedCategoryID == nil ? .white : AppPalette.Notes.c700)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            selectedCategoryID == nil ? AppPalette.Notes.c700 : AppPalette.Notes.c200.opacity(0.55),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)

                ForEach(categories, id: \.id) { category in
                    let isSelected = selectedCategoryID == category.id
                    Button {
                        selectedCategoryID = category.id
                    } label: {
                        Label(category.name, systemImage: category.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : category.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                isSelected ? category.tint : category.tint.opacity(0.14),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(category.tint.opacity(isSelected ? 0 : 0.34), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct NotesEmptyStateCard: View {
    let onCreateTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin notas todavia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Crea tu primera nota y clasificala por categoria para encontrarla rapido.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Agregar nota") {
                onCreateTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.Notes.c600)
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

private struct NoteRow: View {
    let note: NoteEntry
    let onTap: () -> Void

    private var categoryName: String {
        note.category?.name ?? "Sin categoria"
    }

    private var categoryIcon: String {
        note.category?.icon ?? "tag"
    }

    private var categoryTint: Color {
        note.category?.tint ?? AppPalette.Notes.c600
    }

    private var subtitleDateText: String {
        note.updatedAt.formatted(
            .dateTime
                .locale(Locale(identifier: "es_MX"))
                .day()
                .month(.abbreviated)
                .hour()
                .minute()
        )
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(categoryTint)
                    .frame(width: 5)

                VStack(alignment: .leading, spacing: 7) {
                    Text(note.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)

                    if !note.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(note.detail)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        Label(categoryName, systemImage: categoryIcon)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(categoryTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(categoryTint.opacity(0.14), in: Capsule())

                        Text(subtitleDateText)
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 16, height: 16, alignment: .center)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                categoryTint.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(categoryTint.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [NoteCategory]
    let initialNote: NoteEntry?
    let onSave: (NotePayload) -> Void
    let onDelete: (() -> Void)?

    @State private var title: String
    @State private var detail: String
    @State private var selectedCategoryID: UUID?
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(
        categories: [NoteCategory],
        initialNote: NoteEntry? = nil,
        onSave: @escaping (NotePayload) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.categories = categories
        self.initialNote = initialNote
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: initialNote?.title ?? "")
        _detail = State(initialValue: initialNote?.detail ?? "")
        _selectedCategoryID = State(initialValue: initialNote?.category?.id)
    }

    private var selectedCategory: NoteCategory? {
        guard let selectedCategoryID else { return nil }
        return categories.first(where: { $0.id == selectedCategoryID })
    }

    private var selectedCategoryTitle: String {
        selectedCategory?.name ?? "Sin categoria"
    }

    private var selectedCategoryIcon: String {
        selectedCategory?.icon ?? "tag"
    }

    private var selectedCategoryTint: Color {
        selectedCategory?.tint ?? AppPalette.Notes.c600
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        NotesFormCard(title: "Titulo", icon: "textformat") {
                            TextField("", text: $title)
                                .textInputAutocapitalization(.sentences)
                                .autocorrectionDisabled(false)
                                .padding(12)
                                .background(Color.appField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.appStrokeSoft, lineWidth: 1)
                                )
                        }

                        NotesFormCard(title: "Categoria", icon: "tag") {
                            Menu {
                                Button {
                                    selectedCategoryID = nil
                                } label: {
                                    Label("Sin categoria", systemImage: "tag")
                                }

                                ForEach(categories, id: \.id) { category in
                                    Button {
                                        selectedCategoryID = category.id
                                    } label: {
                                        Label(category.name, systemImage: category.icon)
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedCategoryIcon)
                                        .foregroundStyle(selectedCategoryTint)

                                    Text(selectedCategoryTitle)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.appTextPrimary)

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedCategoryTint.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        NotesFormCard(title: "Nota", icon: "note.text") {
                            TextEditor(text: $detail)
                                .frame(minHeight: 180)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(Color.appField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.appStrokeSoft, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(initialNote == nil ? "Nueva nota" : "Editar nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        guard canSave else {
                            alertMessage = "Escribe un titulo para la nota."
                            showAlert = true
                            return
                        }

                        onSave(
                            NotePayload(
                                title: title,
                                detail: detail,
                                categoryID: selectedCategoryID
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let onDelete {
                    Button {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Eliminar nota", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.financeExpenseAccent)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(.thinMaterial)
                }
            }
            .alert("No se puede guardar", isPresented: $showAlert) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

private struct NotesFormCard<Content: View>: View {
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)

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

private struct AddNoteCategoryView: View {
    @Environment(\.dismiss) private var dismiss

    let existingCategories: [NoteCategory]
    let onSave: (NoteCategoryPayload) -> Void

    @State private var name = ""
    @State private var selectedIcon = NoteCategoryDefaults.iconOptions.first ?? "note.text"
    @State private var selectedColor = NoteCategoryColorOption.all.first ?? .init(id: "slate", title: "Pizarra", red: 0.20, green: 0.25, blue: 0.33)
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        NotesFormCard(title: "Nombre", icon: "character.book.closed") {
                            TextField("", text: $name)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(Color.appField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.appStrokeSoft, lineWidth: 1)
                                )
                        }

                        NotesFormCard(title: "Icono", icon: "sparkles") {
                            Menu {
                                ForEach(NoteCategoryDefaults.iconOptions, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        Label(iconDisplayName(for: icon), systemImage: icon)
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedIcon)
                                        .foregroundStyle(selectedColor.color)

                                    Text(iconDisplayName(for: selectedIcon))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.appTextPrimary)

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedColor.color.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        NotesFormCard(title: "Color", icon: "paintpalette") {
                            Menu {
                                ForEach(NoteCategoryColorOption.all) { option in
                                    Button {
                                        selectedColor = option
                                    } label: {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(option.color)
                                                .frame(width: 10, height: 10)
                                            Text(option.title)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(selectedColor.color)
                                        .frame(width: 16, height: 16)

                                    Text(selectedColor.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.appTextPrimary)

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedColor.color.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Nueva categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        saveCategory()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("No se puede guardar", isPresented: $showAlert) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func saveCategory() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else {
            alertMessage = "Ingresa un nombre para la categoria."
            showAlert = true
            return
        }

        let existing = existingCategories.contains {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanedName.lowercased()
        }
        guard !existing else {
            alertMessage = "Ya existe una categoria con ese nombre."
            showAlert = true
            return
        }

        onSave(
            NoteCategoryPayload(
                name: cleanedName,
                icon: selectedIcon,
                color: selectedColor
            )
        )
        dismiss()
    }

    private func iconDisplayName(for icon: String) -> String {
        switch icon {
        case "note.text":
            return "Nota"
        case "book":
            return "Libro"
        case "bookmark":
            return "Marcador"
        case "calendar":
            return "Calendario"
        case "chart.line.uptrend.xyaxis":
            return "Finanzas"
        case "checklist":
            return "Checklist"
        case "doc.text":
            return "Documento"
        case "flag":
            return "Bandera"
        case "fork.knife":
            return "Comidas"
        case "figure.strengthtraining.traditional":
            return "Gym"
        case "heart.text.square":
            return "Salud"
        case "lightbulb":
            return "Idea"
        case "ruler":
            return "Medidas"
        case "sparkles.rectangle.stack":
            return "Recomendaciones"
        case "target":
            return "Meta"
        case "wallet.bifold":
            return "Dinero"
        default:
            return "Icono"
        }
    }
}
