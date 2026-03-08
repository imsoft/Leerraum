import SwiftData

enum DefaultAccountSeeder {
    @MainActor
    static func ensureDefaultAccountsIfNeeded(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Account>()
        let hasAnyAccount = (try? modelContext.fetch(descriptor).isEmpty == false) ?? false
        guard !hasAnyAccount else { return }

        let defaults = [
            Account(name: "Efectivo", type: .cash),
            Account(name: "Banco", type: .bank),
            Account(name: "Tarjeta", type: .card)
        ]

        defaults.forEach { modelContext.insert($0) }
    }
}
