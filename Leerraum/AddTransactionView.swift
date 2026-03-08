import SwiftUI
import SwiftData

private enum ReadablePalette {
    static let secondaryText = Color.appTextSecondary
    static let cardBackground = Color.appSurface
    static let fieldBackground = Color.appField
}

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt, order: .forward) private var accounts: [Account]
    @FocusState private var focusedField: Field?
    private let onClose: (() -> Void)?

    @State private var title = ""
    @State private var note = ""
    @State private var category = ""
    @State private var amountText = ""
    @State private var isFormattingAmount = false
    @State private var currency: TransactionCurrency = .mxn
    @State private var date = Date()
    @State private var type: TransactionType = .income
    @State private var selectedAccountID: UUID?
    @State private var sourceAccountID: UUID?
    @State private var destinationAccountID: UUID?
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    private enum Field {
        case title
        case amount
        case note
    }

    private var categoryOptions: [CategoryOption] {
        CategoryCatalog.options(for: type)
    }

    private var categoryAccent: Color {
        if type == .expense {
            return Color.financeExpenseAccent
        }
        if let selected = categoryOptions.first(where: { $0.name == category }) {
            return selected.color
        }
        return CategoryCatalog.color(for: category, type: type)
    }

    private var typeAccent: Color {
        switch type {
        case .income:
            return Color.financeIncomeAccent
        case .expense:
            return Color.financeExpenseAccent
        case .transfer:
            return Color.financeTransferAccent
        }
    }

    private var canSave: Bool {
        guard let amount = parseAmount(amountText), amount > 0 else { return false }

        switch type {
        case .income, .expense:
            return selectedAccount != nil
        case .transfer:
            guard let source = sourceAccount, let destination = destinationAccount else { return false }
            return source.id != destination.id
        }
    }

    private var selectedAccount: Account? {
        account(for: selectedAccountID)
    }

    private var sourceAccount: Account? {
        account(for: sourceAccountID)
    }

    private var destinationAccount: Account? {
        account(for: destinationAccountID)
    }

    private var typeIcon: String {
        switch type {
        case .income:
            return "arrow.down.left.circle.fill"
        case .expense:
            return "arrow.up.right.circle.fill"
        case .transfer:
            return "arrow.left.arrow.right.circle.fill"
        }
    }

    private var typeHelpText: String {
        switch type {
        case .income:
            return "Se sumara a tu balance"
        case .expense:
            return "Se restara de tu balance"
        case .transfer:
            return "Mueve saldo entre tus cuentas"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AddBackgroundView(accent: typeAccent)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        typeCard
                        detailCard
                        if type == .transfer {
                            transferAccountsCard
                        } else {
                            accountCard
                            categoryCard
                        }
                        noteCard
                        saveButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Nuevo movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        closeView()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        saveTransaction()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("No se puede guardar", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
        .onAppear {
            DefaultAccountSeeder.ensureDefaultAccountsIfNeeded(in: modelContext)
            ensureValidCategory()
            ensureValidAccountSelection()
        }
        .onChange(of: type) { _, _ in
            ensureValidCategory()
            ensureValidAccountSelection()
        }
        .onChange(of: accounts.count) { _, _ in
            ensureValidAccountSelection()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var typeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tipo de movimiento")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ReadablePalette.secondaryText)

                Picker("Tipo", selection: $type) {
                    ForEach(TransactionType.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .tint(typeAccent)

                HStack(spacing: 8) {
                    Image(systemName: typeIcon)
                        .foregroundStyle(typeAccent)
                    Text(typeHelpText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ReadablePalette.secondaryText)
                }
            }
        }
    }

    private var detailCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                InputRow(icon: "textformat", title: "Titulo") {
                    TextField("", text: $title)
                        .focused($focusedField, equals: .title)
                        .textInputAutocapitalization(.sentences)
                }

                InputRow(icon: "banknote", title: "Monto") {
                    TextField("", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .onChange(of: amountText) { _, newValue in
                            formatAmountOnChange(newValue)
                        }
                }

                InputRow(icon: "coloncurrencysign.circle", title: "Moneda") {
                    Picker("Moneda", selection: $currency) {
                        ForEach(TransactionCurrency.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(typeAccent)
                }

                DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .fontDesign(.rounded)
            }
        }
    }

    private var accountCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cuenta")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ReadablePalette.secondaryText)

                accountMenu(
                    title: selectedAccount?.name ?? "Selecciona cuenta",
                    subtitle: selectedAccount?.type.rawValue ?? "",
                    icon: selectedAccount?.type.icon ?? "wallet.pass"
                ) {
                    ForEach(accounts, id: \.id) { account in
                        Button {
                            selectedAccountID = account.id
                        } label: {
                            if account.id == selectedAccountID {
                                Label(account.name, systemImage: "checkmark")
                            } else {
                                Label(account.name, systemImage: account.type.icon)
                            }
                        }
                    }
                }
            }
        }
    }

    private var transferAccountsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Transferencia interna")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ReadablePalette.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Desde")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ReadablePalette.secondaryText)

                    accountMenu(
                        title: sourceAccount?.name ?? "Cuenta origen",
                        subtitle: sourceAccount?.type.rawValue ?? "",
                        icon: sourceAccount?.type.icon ?? "arrow.up.right.circle"
                    ) {
                        ForEach(accounts, id: \.id) { account in
                            Button {
                                sourceAccountID = account.id
                                ensureValidAccountSelection()
                            } label: {
                                if account.id == sourceAccountID {
                                    Label(account.name, systemImage: "checkmark")
                                } else {
                                    Label(account.name, systemImage: account.type.icon)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hacia")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ReadablePalette.secondaryText)

                    accountMenu(
                        title: destinationAccount?.name ?? "Cuenta destino",
                        subtitle: destinationAccount?.type.rawValue ?? "",
                        icon: destinationAccount?.type.icon ?? "arrow.down.left.circle"
                    ) {
                        ForEach(accounts, id: \.id) { account in
                            Button {
                                destinationAccountID = account.id
                            } label: {
                                if account.id == destinationAccountID {
                                    Label(account.name, systemImage: "checkmark")
                                } else {
                                    Label(account.name, systemImage: account.type.icon)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var categoryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Categoria")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ReadablePalette.secondaryText)

                Menu {
                    ForEach(categoryOptions) { item in
                        Button {
                            category = item.name
                        } label: {
                            HStack {
                                Image(systemName: item.icon)
                                    .foregroundStyle(type == .expense ? Color.financeExpenseAccent : item.color)

                                Text(item.name)

                                Spacer()

                                if item.name == category {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(typeAccent)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: CategoryCatalog.icon(for: category, type: type))
                            .foregroundStyle(categoryAccent)

                        Text(category)
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(typeAccent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background(ReadablePalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(typeAccent.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func accountMenu<MenuContent: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder content: @escaping () -> MenuContent
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(typeAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(ReadablePalette.secondaryText)
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(typeAccent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(ReadablePalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(typeAccent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var noteCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nota")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ReadablePalette.secondaryText)

                TextField("", text: $note, axis: .vertical)
                    .focused($focusedField, equals: .note)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(ReadablePalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var saveButton: some View {
        Button {
            saveTransaction()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Guardar movimiento")
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [typeAccent, typeAccent.opacity(0.75)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: typeAccent.opacity(0.35), radius: 10, x: 0, y: 6)
            .opacity(canSave ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func saveTransaction() {
        guard let amount = parseAmount(amountText), amount > 0 else {
            validationMessage = "Ingresa un monto mayor que cero."
            showingValidationAlert = true
            return
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)

        let transaction: Transaction
        switch type {
        case .income, .expense:
            guard let account = selectedAccount else {
                validationMessage = "Selecciona una cuenta para el movimiento."
                showingValidationAlert = true
                return
            }

            transaction = Transaction(
                title: cleanTitle.isEmpty ? "Sin titulo" : cleanTitle,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                category: cleanCategory.isEmpty ? "Sin categoria" : cleanCategory,
                amount: amount,
                currency: currency,
                date: date,
                type: type,
                account: account
            )
        case .transfer:
            guard let source = sourceAccount, let destination = destinationAccount else {
                validationMessage = "Selecciona cuenta origen y cuenta destino."
                showingValidationAlert = true
                return
            }

            guard source.id != destination.id else {
                validationMessage = "La cuenta origen y destino no pueden ser la misma."
                showingValidationAlert = true
                return
            }

            transaction = Transaction(
                title: cleanTitle.isEmpty ? "Transferencia" : cleanTitle,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                category: "Transferencia interna",
                amount: amount,
                currency: currency,
                date: date,
                type: .transfer,
                sourceAccount: source,
                destinationAccount: destination
            )
        }

        modelContext.insert(transaction)
        closeView()
    }

    private func closeView() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func parseAmount(_ input: String) -> Double? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let normalized = text.replacingOccurrences(of: ",", with: "")
        return Double(normalized)
    }

    private func ensureValidCategory() {
        if type == .transfer {
            category = "Transferencia interna"
            return
        }

        if !categoryOptions.map(\.name).contains(category) {
            category = categoryOptions.first?.name ?? ""
        }
    }

    private func ensureValidAccountSelection() {
        if selectedAccount == nil {
            selectedAccountID = accounts.first?.id
        }

        if sourceAccount == nil {
            sourceAccountID = accounts.first?.id
        }

        if destinationAccount == nil || sourceAccountID == destinationAccountID {
            destinationAccountID = accounts.first(where: { $0.id != sourceAccountID })?.id ?? accounts.first?.id
        }
    }

    private func account(for id: UUID?) -> Account? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    private func formatAmountOnChange(_ value: String) {
        guard !isFormattingAmount else { return }

        let formatted = formatAmountText(value)
        guard formatted != value else { return }

        isFormattingAmount = true
        amountText = formatted
        isFormattingAmount = false
    }

    private func formatAmountText(_ rawValue: String) -> String {
        let filtered = rawValue.filter { $0.isNumber || $0 == "." }
        guard !filtered.isEmpty else { return "" }

        let pieces = filtered.split(separator: ".", omittingEmptySubsequences: false)
        let integerPartRaw = String(pieces.first ?? "")
        let fractionalPartRaw = pieces.count > 1 ? String(pieces[1]) : ""

        let strippedInteger = String(integerPartRaw.drop { $0 == "0" })
        let normalizedInteger = strippedInteger.isEmpty ? "0" : strippedInteger

        let groupedInteger = Self.amountGroupingFormatter.string(from: NSNumber(value: Int(normalizedInteger) ?? 0)) ?? normalizedInteger

        if pieces.count > 1 {
            let fractionalLimited = String(fractionalPartRaw.prefix(2))
            return groupedInteger + "." + fractionalLimited
        }

        return groupedInteger
    }

    private static let amountGroupingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.secondaryGroupingSize = 3
        formatter.decimalSeparator = "."
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private struct AddBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                ? [AppPalette.Finance.c950, AppPalette.Finance.c900]
                : [AppPalette.Finance.c50, AppPalette.Finance.c100],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 16)
                .offset(x: -120, y: -260)

            Circle()
                .fill(AppPalette.Finance.c400.opacity(colorScheme == .dark ? 0.10 : 0.15))
                .frame(width: 240, height: 240)
                .blur(radius: 18)
                .offset(x: 140, y: 290)
        }
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding(14)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
    }
}

private struct InputRow<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var field: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ReadablePalette.secondaryText)

            field
                .padding(10)
                .background(ReadablePalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: [Transaction.self, Account.self, CategoryBudget.self, SavingsGoal.self], inMemory: true)
}
