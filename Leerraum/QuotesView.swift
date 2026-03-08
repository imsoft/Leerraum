import SwiftUI
import SwiftData

private struct QuoteEditTarget: Identifiable {
    let id: UUID
}

private struct QuoteDetailTarget: Identifiable {
    let id: UUID
}

struct QuotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuoteMessage.createdAt, order: .reverse) private var quotes: [QuoteMessage]
    @Binding var deepLinkedQuoteID: UUID?

    @State private var showingAddSheet = false
    @State private var editTarget: QuoteEditTarget?
    @State private var detailTarget: QuoteDetailTarget?
    @State private var pendingEditQuoteID: UUID?

    private var activeQuotesCount: Int {
        quotes.filter(\.isActive).count
    }

    private var selectedQuoteForDetail: QuoteMessage? {
        guard let detailTarget else { return nil }
        return quotes.first(where: { $0.id == detailTarget.id })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuotesBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        QuotesSummaryCard(
                            totalQuotes: quotes.count,
                            activeQuotes: activeQuotesCount
                        )

                        FeatureSectionHeader(title: "Mensajes") {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Label("Nuevo", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.Quotes.c600)
                        }

                        if quotes.isEmpty {
                            QuotesEmptyStateCard {
                                showingAddSheet = true
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(quotes, id: \.id) { quote in
                                    QuoteMessageRow(quote: quote) {
                                        editTarget = QuoteEditTarget(id: quote.id)
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
            .navigationTitle("Frases")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddSheet) {
                AddQuoteMessageView { text, author, isActive in
                    createQuote(text: text, author: author, isActive: isActive)
                }
            }
            .sheet(item: $editTarget) { target in
                if let selectedQuoteForEditing = quotes.first(where: { $0.id == target.id }) {
                    AddQuoteMessageView(initialQuote: selectedQuoteForEditing) { text, author, isActive in
                        updateQuote(
                            selectedQuoteForEditing,
                            text: text,
                            author: author,
                            isActive: isActive
                        )
                    } onDelete: {
                        deleteQuote(selectedQuoteForEditing)
                    }
                }
            }
            .fullScreenCover(item: $detailTarget, onDismiss: {
                if let pendingEditQuoteID {
                    openEditTarget(for: pendingEditQuoteID)
                    self.pendingEditQuoteID = nil
                }
            }) { _ in
                if let selectedQuoteForDetail {
                    QuoteMessageDetailView(quote: selectedQuoteForDetail) {
                        openEditSheet(fromDetailID: selectedQuoteForDetail.id)
                    }
                    .id(selectedQuoteForDetail.id)
                } else {
                    MissingQuoteDetailView {
                        detailTarget = nil
                    }
                }
            }
            .onAppear {
                openDeepLinkedQuoteIfNeeded()
            }
            .onChange(of: deepLinkedQuoteID) { _, _ in
                openDeepLinkedQuoteIfNeeded()
            }
            .onChange(of: quotes.map(\.id)) { _, _ in
                openDeepLinkedQuoteIfNeeded()
            }
        }
    }

    private func createQuote(text: String, author: String, isActive: Bool) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let quote = QuoteMessage(
            text: trimmedText,
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: isActive
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(quote)
        }
    }

    private func updateQuote(_ quote: QuoteMessage, text: String, author: String, isActive: Bool) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            quote.text = trimmedText
            quote.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
            quote.isActive = isActive
        }
    }

    private func deleteQuote(_ quote: QuoteMessage) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(quote)
        }
        if detailTarget?.id == quote.id {
            detailTarget = nil
        }
        if editTarget?.id == quote.id { editTarget = nil }
        if pendingEditQuoteID == quote.id { pendingEditQuoteID = nil }
    }

    private func openDeepLinkedQuoteIfNeeded() {
        guard let deepLinkedQuoteID else { return }
        guard let quote = quotes.first(where: { $0.id == deepLinkedQuoteID }) else {
            return
        }

        detailTarget = QuoteDetailTarget(id: quote.id)
        self.deepLinkedQuoteID = nil
    }

    private func openEditSheet(fromDetailID id: UUID) {
        pendingEditQuoteID = id
        detailTarget = nil
    }

    private func openEditTarget(for id: UUID) {
        guard quotes.contains(where: { $0.id == id }) else { return }
        editTarget = QuoteEditTarget(id: id)
    }
}

private struct MissingQuoteDetailView: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                QuotesBackgroundView()
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    Text("No se pudo cargar el mensaje")
                        .font(.headline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.appTextPrimary)

                    Text("Intenta abrirlo de nuevo desde la lista de frases.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Mensaje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { onClose() }
                }
            }
        }
    }
}

private struct QuotesBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .quotes)
    }
}

private struct QuotesSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let totalQuotes: Int
    let activeQuotes: Int

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.Quotes.c900, AppPalette.Quotes.c700]
        }
        return [AppPalette.Quotes.c600, AppPalette.Quotes.c400]
    }

    private var strokeColor: Color {
        .white.opacity(colorScheme == .dark ? 0.18 : 0.28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu coleccion")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            Text("Mensajes que te importan")
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                QuotesMetricPill(title: "Frases", value: "\(totalQuotes)")
                QuotesMetricPill(title: "Activas", value: "\(activeQuotes)")
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

private struct QuotesMetricPill: View {
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
            .white.opacity(colorScheme == .dark ? 0.18 : 0.24),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct QuotesEmptyStateCard: View {
    let onAddTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin frases todavia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Guarda frases que te gusten y recibirlas aleatoriamente durante el dia.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Agregar frase") {
                onAddTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.Quotes.c600)
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

private struct QuoteMessageRow: View {
    let quote: QuoteMessage
    let onTap: () -> Void

    private var previewText: String {
        let normalized = quote.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > 92 else { return normalized }
        let endIndex = normalized.index(normalized.startIndex, offsetBy: 92)
        return String(normalized[..<endIndex]) + "..."
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(previewText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if !quote.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Por \(quote.author)")
                        }
                        Text(quote.isActive ? "Activa" : "Pausada")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(quote.isActive ? Color(red: 0.09, green: 0.61, blue: 0.37) : AppPalette.Quotes.c400)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                (quote.isActive ? Color.green.opacity(0.15) : Color.orange.opacity(0.14)),
                                in: Capsule()
                            )
                    }
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 20, height: 20, alignment: .center)
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

private struct QuoteMessageDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let quote: QuoteMessage
    let onEdit: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                QuotesBackgroundView()
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        Text(quote.text)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color.appTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 24)
                            .frame(minHeight: proxy.size.height, alignment: .center)
                    }
                }
            }
            .navigationTitle("Mensaje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Editar") {
                        onEdit()
                    }
                }
            }
        }
    }
}

private struct AddQuoteMessageView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var author = ""
    @State private var isActive = true
    @State private var showingDeleteAlert = false
    @FocusState private var focusedField: QuoteField?

    private let isEditing: Bool
    let onSave: (_ text: String, _ author: String, _ isActive: Bool) -> Void
    let onDelete: (() -> Void)?

    private enum QuoteField {
        case author
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuotesBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            QuotesInputLabel(title: "Frase", systemImage: "quote.bubble")

                            TextEditor(text: $text)
                                .scrollContentBackground(.hidden)
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .frame(minHeight: 130, alignment: .topLeading)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppPalette.Quotes.c600.opacity(0.24), lineWidth: 1)
                                )

                            QuotesInputLabel(title: "Autor o referencia (opcional)", systemImage: "person")

                            TextField("", text: $author)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .author)
                                .quotesInputField()

                            QuotesInputLabel(title: "Notificaciones", systemImage: "bell")

                            Toggle(isOn: $isActive) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mostrar esta frase aleatoriamente")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appTextPrimary)
                                    Text("Si la desactivas, no aparecera en notificaciones.")
                                        .font(.caption)
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(AppPalette.Quotes.c600)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Color.appField,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppPalette.Quotes.c600.opacity(0.24), lineWidth: 1)
                            )
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
                                Text("Eliminar frase")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.62, green: 0.13, blue: 0.18))

                                Button(role: .destructive) {
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Eliminar frase", systemImage: "trash.fill")
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
            .navigationTitle(isEditing ? "Editar frase" : "Nueva frase")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.Quotes.c600)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Actualizar" : "Guardar") {
                        onSave(text, author, isActive)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Eliminar frase", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Esta frase se eliminara de tu coleccion.")
            }
        }
    }

    init(
        initialQuote: QuoteMessage? = nil,
        onSave: @escaping (_ text: String, _ author: String, _ isActive: Bool) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.isEditing = initialQuote != nil

        if let initialQuote {
            _text = State(initialValue: initialQuote.text)
            _author = State(initialValue: initialQuote.author)
            _isActive = State(initialValue: initialQuote.isActive)
        }
    }
}

private struct QuotesInputLabel: View {
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
    func quotesInputField() -> some View {
        self
            .foregroundStyle(Color.appTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color.appField,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.Quotes.c600.opacity(0.24), lineWidth: 1)
            )
    }
}
