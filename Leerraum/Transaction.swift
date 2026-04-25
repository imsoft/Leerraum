import Foundation
import SwiftData
import SwiftUI

enum TransactionType: String, CaseIterable, Identifiable {
    case income = "Ingreso"
    case expense = "Gasto"
    case transfer = "Transferencia"

    var id: String { rawValue }
}

enum TransactionCurrency: String, CaseIterable, Identifiable, Codable {
    case mxn = "mxn"
    case usd = "usd"

    var id: String { rawValue }

    var code: String {
        switch self {
        case .mxn:
            return "MXN"
        case .usd:
            return "USD"
        }
    }

    var displayName: String {
        switch self {
        case .mxn:
            return "MXN"
        case .usd:
            return "USD"
        }
    }
}

enum AccountType: String, CaseIterable, Identifiable {
    case cash = "Efectivo"
    case bank = "Banco"
    case card = "Tarjeta"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cash:
            return "banknote"
        case .bank:
            return "building.columns"
        case .card:
            return "creditcard"
        }
    }
}

enum RoutineWeekday: String, CaseIterable, Identifiable, Codable {
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    case sunday = "sunday"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monday:
            return "Lunes"
        case .tuesday:
            return "Martes"
        case .wednesday:
            return "Miercoles"
        case .thursday:
            return "Jueves"
        case .friday:
            return "Viernes"
        case .saturday:
            return "Sabado"
        case .sunday:
            return "Domingo"
        }
    }
}

enum FoodMealType: String, CaseIterable, Identifiable, Codable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast:
            return "Desayuno"
        case .lunch:
            return "Comida"
        case .dinner:
            return "Cena"
        case .snack:
            return "Snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast:
            return "sunrise.fill"
        case .lunch:
            return "sun.max.fill"
        case .dinner:
            return "moon.stars.fill"
        case .snack:
            return "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .breakfast:
            return Color(red: 0.95, green: 0.58, blue: 0.20)
        case .lunch:
            return Color(red: 0.15, green: 0.56, blue: 0.90)
        case .dinner:
            return Color(red: 0.34, green: 0.41, blue: 0.78)
        case .snack:
            return Color(red: 0.15, green: 0.67, blue: 0.40)
        }
    }
}

enum FoodQualityType: String, CaseIterable, Identifiable, Codable {
    case healthy = "healthy"
    case medium = "medium"
    case junk = "junk"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healthy:
            return "Saludable"
        case .medium:
            return "Medio"
        case .junk:
            return "Chatarra"
        }
    }

    var icon: String {
        switch self {
        case .healthy:
            return "leaf.fill"
        case .medium:
            return "equal.circle.fill"
        case .junk:
            return "takeoutbag.and.cup.and.straw.fill"
        }
    }

    var tint: Color {
        switch self {
        case .healthy:
            return Color(red: 0.11, green: 0.62, blue: 0.36)
        case .medium:
            return Color(red: 0.95, green: 0.58, blue: 0.20)
        case .junk:
            return Color(red: 0.87, green: 0.26, blue: 0.24)
        }
    }
}

enum LifeGoalPriority: String, CaseIterable, Identifiable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high:
            return "Alta"
        case .medium:
            return "Media"
        case .low:
            return "Baja"
        }
    }

    var tint: Color {
        switch self {
        case .high:
            return Color(red: 0.90, green: 0.20, blue: 0.22)
        case .medium:
            return Color(red: 0.95, green: 0.58, blue: 0.20)
        case .low:
            return Color(red: 0.10, green: 0.61, blue: 0.37)
        }
    }
}

enum LifeGoalArea: String, CaseIterable, Identifiable, Codable {
    case health = "health"
    case money = "money"
    case personal = "personal"
    case family = "family"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .health:
            return "Salud"
        case .money:
            return "Dinero"
        case .personal:
            return "Personal"
        case .family:
            return "Familia"
        }
    }

    var icon: String {
        switch self {
        case .health:
            return "heart.text.square"
        case .money:
            return "banknote"
        case .personal:
            return "person.fill"
        case .family:
            return "person.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .health:
            return Color(red: 0.10, green: 0.61, blue: 0.37)
        case .money:
            return Color(red: 0.13, green: 0.49, blue: 0.89)
        case .personal:
            return Color(red: 0.49, green: 0.42, blue: 0.84)
        case .family:
            return Color(red: 0.90, green: 0.45, blue: 0.18)
        }
    }
}

enum RecommendationKind: String, CaseIterable, Identifiable, Codable {
    case series = "series"
    case movie = "movie"
    case music = "music"
    case personal = "personal"
    case book = "book"
    case podcast = "podcast"
    case documentary = "documentary"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .series:
            return "Series"
        case .movie:
            return "Peliculas"
        case .music:
            return "Musica"
        case .personal:
            return "Personal"
        case .book:
            return "Libros"
        case .podcast:
            return "Podcast"
        case .documentary:
            return "Documentales"
        case .other:
            return "Otros"
        }
    }

    var icon: String {
        switch self {
        case .series:
            return "tv"
        case .movie:
            return "film"
        case .music:
            return "music.note"
        case .personal:
            return "person.2"
        case .book:
            return "book.closed"
        case .podcast:
            return "mic"
        case .documentary:
            return "doc.text.image"
        case .other:
            return "star"
        }
    }

    var tint: Color {
        switch self {
        case .series:
            return AppPalette.Recommendations.c700
        case .movie:
            return AppPalette.Recommendations.c800
        case .music:
            return AppPalette.Recommendations.c600
        case .personal:
            return AppPalette.Recommendations.c500
        case .book:
            return AppPalette.Recommendations.c900
        case .podcast:
            return AppPalette.Recommendations.c700
        case .documentary:
            return AppPalette.Recommendations.c800
        case .other:
            return AppPalette.Recommendations.c600
        }
    }
}

struct CategoryOption: Identifiable, Hashable {
    let name: String
    let icon: String
    let color: Color

    var id: String { name }
}

enum CategoryCatalog {
    static let incomeOptions: [CategoryOption] = [
        CategoryOption(name: "Nomina", icon: "wallet.bifold", color: Color(red: 0.07, green: 0.68, blue: 0.35)),
        CategoryOption(name: "Freelance", icon: "laptopcomputer", color: Color(red: 0.05, green: 0.63, blue: 0.31)),
        CategoryOption(name: "Venta", icon: "bag", color: Color(red: 0.09, green: 0.66, blue: 0.38)),
        CategoryOption(name: "Intereses", icon: "percent", color: Color(red: 0.13, green: 0.59, blue: 0.29)),
        CategoryOption(name: "Dividendos", icon: "chart.bar", color: Color(red: 0.17, green: 0.61, blue: 0.34)),
        CategoryOption(name: "Reembolso", icon: "arrow.uturn.left.circle", color: Color(red: 0.08, green: 0.64, blue: 0.36)),
        CategoryOption(name: "Bono", icon: "gift", color: Color(red: 0.11, green: 0.62, blue: 0.28)),
        CategoryOption(name: "Renta", icon: "building.2", color: Color(red: 0.14, green: 0.57, blue: 0.32)),
        CategoryOption(name: "Regalo", icon: "gift.circle", color: Color(red: 0.16, green: 0.60, blue: 0.33)),
        CategoryOption(name: "Otros", icon: "ellipsis.circle", color: Color(red: 0.25, green: 0.55, blue: 0.36))
    ]

    static let expenseOptions: [CategoryOption] = [
        CategoryOption(name: "Comida", icon: "fork.knife", color: Color(red: 0.96, green: 0.43, blue: 0.24)),
        CategoryOption(name: "Transporte", icon: "car", color: Color(red: 0.93, green: 0.36, blue: 0.30)),
        CategoryOption(name: "Casa", icon: "house", color: Color(red: 0.89, green: 0.41, blue: 0.30)),
        CategoryOption(name: "Suscripciones", icon: "repeat.circle", color: Color(red: 0.88, green: 0.33, blue: 0.43)),
        CategoryOption(name: "Salud", icon: "cross.case", color: Color(red: 0.90, green: 0.29, blue: 0.37)),
        CategoryOption(name: "Ocio", icon: "gamecontroller", color: Color(red: 0.97, green: 0.51, blue: 0.26)),
        CategoryOption(name: "Educacion", icon: "book", color: Color(red: 0.96, green: 0.44, blue: 0.33)),
        CategoryOption(name: "Ropa", icon: "tshirt", color: Color(red: 0.94, green: 0.36, blue: 0.47)),
        CategoryOption(name: "Servicios", icon: "bolt", color: Color(red: 0.98, green: 0.53, blue: 0.20)),
        CategoryOption(name: "Viajes", icon: "airplane", color: Color(red: 0.90, green: 0.39, blue: 0.34)),
        CategoryOption(name: "Impuestos", icon: "doc.text", color: Color(red: 0.84, green: 0.35, blue: 0.35)),
        CategoryOption(name: "Otros", icon: "ellipsis.circle", color: Color(red: 0.39, green: 0.48, blue: 0.64))
    ]

    static let transferOption = CategoryOption(
        name: "Transferencia interna",
        icon: "arrow.left.arrow.right.circle",
        color: Color(red: 0.13, green: 0.49, blue: 0.89)
    )

    private static let optionMapByType: [TransactionType: [String: CategoryOption]] = {
        [
            .income: Dictionary(uniqueKeysWithValues: incomeOptions.map { ($0.name, $0) }),
            .expense: Dictionary(uniqueKeysWithValues: expenseOptions.map { ($0.name, $0) }),
            .transfer: Dictionary(uniqueKeysWithValues: [transferOption].map { ($0.name, $0) })
        ]
    }()

    static func options(for type: TransactionType) -> [CategoryOption] {
        switch type {
        case .income:
            return incomeOptions
        case .expense:
            return expenseOptions
        case .transfer:
            return [transferOption]
        }
    }

    static func option(for category: String, type: TransactionType? = nil) -> CategoryOption? {
        if let type {
            return optionMapByType[type]?[category]
        }

        return optionMapByType[.expense]?[category]
            ?? optionMapByType[.income]?[category]
            ?? optionMapByType[.transfer]?[category]
    }

    static func icon(for category: String, type: TransactionType? = nil) -> String {
        option(for: category, type: type)?.icon ?? "tag"
    }

    static func color(for category: String, type: TransactionType? = nil) -> Color {
        option(for: category, type: type)?.color ?? Color(red: 0.39, green: 0.48, blue: 0.64)
    }
}

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var initialBalance: Double
    var createdAt: Date

    init(
        name: String,
        type: AccountType,
        initialBalance: Double = 0,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.initialBalance = initialBalance
        self.createdAt = createdAt
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .cash }
        set { typeRaw = newValue.rawValue }
    }
}

@Model
final class CategoryBudget {
    @Attribute(.unique) var id: UUID
    var category: String
    var amountLimit: Double
    var month: Int
    var year: Int
    var createdAt: Date

    init(
        category: String,
        amountLimit: Double,
        month: Int,
        year: Int,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.category = category
        self.amountLimit = amountLimit
        self.month = month
        self.year = year
        self.createdAt = createdAt
    }
}

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetAmount: Double
    var savedAmount: Double
    var createdAt: Date

    init(
        title: String,
        targetAmount: Double,
        savedAmount: Double = 0,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.createdAt = createdAt
    }
}

@Model
final class FixedTransaction {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String
    var amount: Double
    var dayOfMonth: Int
    var typeRaw: String
    var isActive: Bool
    var createdAt: Date

    init(
        title: String,
        category: String,
        amount: Double,
        dayOfMonth: Int = 1,
        type: TransactionType,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.amount = amount
        self.dayOfMonth = max(1, min(dayOfMonth, 31))
        self.typeRaw = type.rawValue
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var type: TransactionType {
        get {
            let parsed = TransactionType(rawValue: typeRaw) ?? .expense
            return parsed == .transfer ? .expense : parsed
        }
        set {
            switch newValue {
            case .income, .expense:
                typeRaw = newValue.rawValue
            case .transfer:
                typeRaw = TransactionType.expense.rawValue
            }
        }
    }
}

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var category: String
    var amount: Double
    var currencyCodeRaw: String?
    var date: Date
    var typeRaw: String
    var account: Account?
    var sourceAccount: Account?
    var destinationAccount: Account?

    init(
        title: String,
        note: String = "",
        category: String,
        amount: Double,
        currency: TransactionCurrency = .mxn,
        date: Date = .now,
        type: TransactionType,
        account: Account? = nil,
        sourceAccount: Account? = nil,
        destinationAccount: Account? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.category = category
        self.amount = amount
        self.currencyCodeRaw = currency.rawValue
        self.date = date
        self.typeRaw = type.rawValue
        self.account = account
        self.sourceAccount = sourceAccount
        self.destinationAccount = destinationAccount
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var currency: TransactionCurrency {
        get { TransactionCurrency(rawValue: currencyCodeRaw ?? "") ?? .mxn }
        set { currencyCodeRaw = newValue.rawValue }
    }
}

@Model
final class GymRoutine {
    @Attribute(.unique) var id: UUID
    var name: String
    var note: String
    var scheduledWeekdayRaw: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \GymExercise.routine)
    var exercises: [GymExercise]

    init(
        name: String,
        note: String = "",
        scheduledWeekday: RoutineWeekday = .monday,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.note = note
        self.scheduledWeekdayRaw = scheduledWeekday.rawValue
        self.createdAt = createdAt
        self.exercises = []
    }

    var scheduledWeekday: RoutineWeekday {
        get { RoutineWeekday(rawValue: scheduledWeekdayRaw ?? "") ?? .monday }
        set { scheduledWeekdayRaw = newValue.rawValue }
    }
}

@Model
final class GymExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var weightKg: Double
    var restSeconds: Int
    var order: Int
    var createdAt: Date
    var routine: GymRoutine?

    init(
        name: String,
        sets: Int,
        reps: Int,
        weightKg: Double,
        restSeconds: Int,
        order: Int = 0,
        createdAt: Date = .now,
        routine: GymRoutine? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.restSeconds = restSeconds
        self.order = order
        self.createdAt = createdAt
        self.routine = routine
    }
}

@Model
final class GymSetRecord {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID
    var exerciseName: String
    var routineName: String
    var performedAt: Date
    var setNumber: Int
    var reps: Int
    var weightKg: Double
    var volumeKg: Double
    var createdAt: Date

    init(
        exerciseID: UUID,
        exerciseName: String,
        routineName: String,
        performedAt: Date = .now,
        setNumber: Int,
        reps: Int,
        weightKg: Double,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.routineName = routineName
        self.performedAt = performedAt
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = max(weightKg, 0)
        self.volumeKg = max(weightKg, 0) * Double(max(reps, 0))
        self.createdAt = createdAt
    }
}

@Model
final class FoodEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var mealTypeRaw: String
    var quantity: String
    var qualityRaw: String?
    var calories: Int
    var proteinGrams: Double?
    var note: String
    var date: Date
    var createdAt: Date

    init(
        name: String,
        mealType: FoodMealType,
        quantity: String = "",
        quality: FoodQualityType = .medium,
        calories: Int = 0,
        proteinGrams: Double? = nil,
        note: String = "",
        date: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.mealTypeRaw = mealType.rawValue
        self.quantity = quantity
        self.qualityRaw = quality.rawValue
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.note = note
        self.date = date
        self.createdAt = createdAt
    }

    var mealType: FoodMealType {
        get { FoodMealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var quality: FoodQualityType {
        get { FoodQualityType(rawValue: qualityRaw ?? "") ?? .medium }
        set { qualityRaw = newValue.rawValue }
    }
}

/// Horario sugerido de comida o toma de agua (configurable en datos; se crean valores por defecto al instalar).
@Model
final class MealWaterRoutineSlot {
    @Attribute(.unique) var id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var isWater: Bool
    var sortOrder: Int
    var isEnabled: Bool

    init(
        title: String,
        hour: Int,
        minute: Int,
        isWater: Bool,
        sortOrder: Int,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.hour = max(0, min(hour, 23))
        self.minute = max(0, min(minute, 59))
        self.isWater = isWater
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

/// Marca si un horario se cumplio en un dia concreto (inicio de dia en calendario actual).
@Model
final class MealWaterRoutineDayMark {
    var id: UUID
    var slotId: UUID
    var dayStart: Date
    var isDone: Bool
    var updatedAt: Date

    init(slotId: UUID, dayStart: Date, isDone: Bool, updatedAt: Date = .now) {
        self.id = UUID()
        self.slotId = slotId
        self.dayStart = dayStart
        self.isDone = isDone
        self.updatedAt = updatedAt
    }
}

@Model
final class QuoteMessage {
    @Attribute(.unique) var id: UUID
    var text: String
    var author: String
    var isActive: Bool
    var createdAt: Date

    init(
        text: String,
        author: String = "",
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.text = text
        self.author = author
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var reminderHour: Int
    var reminderMinute: Int
    var isActive: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry]

    init(
        title: String,
        note: String = "",
        reminderHour: Int = 21,
        reminderMinute: Int = 0,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.reminderHour = max(0, min(reminderHour, 23))
        self.reminderMinute = max(0, min(reminderMinute, 59))
        self.isActive = isActive
        self.createdAt = createdAt
        self.entries = []
    }

    var reminderDate: Date {
        get {
            let calendar = Calendar.current
            let now = Date()
            let components = DateComponents(
                year: calendar.component(.year, from: now),
                month: calendar.component(.month, from: now),
                day: calendar.component(.day, from: now),
                hour: reminderHour,
                minute: reminderMinute
            )
            return calendar.date(from: components) ?? now
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = max(0, min(components.hour ?? 21, 23))
            reminderMinute = max(0, min(components.minute ?? 0, 59))
        }
    }
}

@Model
final class HabitEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var didComplete: Bool
    var createdAt: Date
    var habit: Habit?

    init(
        date: Date = .now,
        didComplete: Bool,
        habit: Habit? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.didComplete = didComplete
        self.habit = habit
        self.createdAt = createdAt
    }
}

@Model
final class BodyMeasurementEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKg: Double?
    var heightCm: Double?
    var bodyFatPercent: Double?
    var waistCm: Double?
    var hipCm: Double?
    var chestCm: Double?
    var armCm: Double?
    var thighCm: Double?
    var note: String
    var createdAt: Date

    init(
        date: Date = .now,
        weightKg: Double? = nil,
        heightCm: Double? = nil,
        bodyFatPercent: Double? = nil,
        waistCm: Double? = nil,
        hipCm: Double? = nil,
        chestCm: Double? = nil,
        armCm: Double? = nil,
        thighCm: Double? = nil,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.bodyFatPercent = bodyFatPercent
        self.waistCm = waistCm
        self.hipCm = hipCm
        self.chestCm = chestCm
        self.armCm = armCm
        self.thighCm = thighCm
        self.note = note
        self.createdAt = createdAt
    }
}

@Model
final class AppIdeaNote {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var statusRaw: String
    var createdAt: Date

    init(
        title: String,
        detail: String = "",
        statusRaw: String = "Pendiente",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.statusRaw = statusRaw
        self.createdAt = createdAt
    }
}

@Model
final class ContentIdeaEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var tagsRaw: String
    var platform: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        detail: String = "",
        tagsRaw: String = "",
        platform: String = "",
        isPinned: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.tagsRaw = tagsRaw
        self.platform = platform
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class LifeGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var targetDate: Date?
    var progress: Int
    var priorityRaw: String?
    var areaRaw: String?
    var createdAt: Date

    init(
        title: String,
        detail: String = "",
        targetDate: Date? = nil,
        progress: Int = 0,
        priority: LifeGoalPriority = .medium,
        area: LifeGoalArea = .personal,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.targetDate = targetDate
        self.progress = max(0, min(progress, 100))
        self.priorityRaw = priority.rawValue
        self.areaRaw = area.rawValue
        self.createdAt = createdAt
    }

    var priority: LifeGoalPriority {
        get { LifeGoalPriority(rawValue: priorityRaw ?? "") ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var area: LifeGoalArea {
        get { LifeGoalArea(rawValue: areaRaw ?? "") ?? .personal }
        set { areaRaw = newValue.rawValue }
    }
}

@Model
final class RecommendationEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var recommendedBy: String
    var kindRaw: String
    var isCompleted: Bool
    var createdAt: Date

    init(
        title: String,
        detail: String = "",
        recommendedBy: String = "",
        kind: RecommendationKind = .other,
        isCompleted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.recommendedBy = recommendedBy
        self.kindRaw = kind.rawValue
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }

    var kind: RecommendationKind {
        get { RecommendationKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class NoteCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var red: Double
    var green: Double
    var blue: Double
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \NoteEntry.category)
    var notes: [NoteEntry]

    init(
        name: String,
        icon: String,
        red: Double,
        green: Double,
        blue: Double,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.red = max(0, min(red, 1))
        self.green = max(0, min(green, 1))
        self.blue = max(0, min(blue, 1))
        self.createdAt = createdAt
        self.notes = []
    }

    var tint: Color {
        Color(red: red, green: green, blue: blue)
    }
}

@Model
final class NoteEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var createdAt: Date
    var updatedAt: Date
    var category: NoteCategory?

    init(
        title: String,
        detail: String,
        category: NoteCategory?,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
    }
}

@Model
final class Reminder {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date

    init(
        title: String,
        note: String = "",
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
}
