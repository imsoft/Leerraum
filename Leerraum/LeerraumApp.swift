import SwiftUI
import SwiftData
import UserNotifications
import AudioToolbox
import OSLog

@main
struct LeerraumApp: App {
    init() {
        AppNotificationService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.locale, Locale(identifier: "es_MX"))
                .onAppear {
                    AppNotificationService.shared.configure()
                }
        }
        .modelContainer(for: [
            Transaction.self,
            FixedTransaction.self,
            Account.self,
            CategoryBudget.self,
            SavingsGoal.self,
            GymRoutine.self,
            GymExercise.self,
            GymSetRecord.self,
            FoodEntry.self,
            QuoteMessage.self,
            Habit.self,
            HabitEntry.self,
            BodyMeasurementEntry.self,
            RecommendationEntry.self,
            NoteCategory.self,
            NoteEntry.self,
            AppIdeaNote.self,
            LifeGoal.self,
            Reminder.self
        ])
    }
}

final class AppNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let customSoundName = UNNotificationSoundName("notification_sound.caf")
    private let maxPendingNotificationRequests = 64
    private let monthlyReminderIDPrefix = "finance.monthly.review."
    private let quoteReminderIDPrefix = "quotes.random."
    private let habitReminderIDPrefix = "habits.daily."
    private let lifeGoalReminderIDPrefix = "lifegoals.daily."
    private let reminderIDPrefix = "reminders.random."
    private let quoteUserInfoTypeKey = "leerraumNotificationType"
    private let quoteUserInfoTypeValue = "quoteMessage"
    private let habitUserInfoTypeValue = "habitSummary"
    private let lifeGoalUserInfoTypeValue = "lifeGoalSummary"
    private let reminderUserInfoTypeValue = "reminderTask"
    private let quoteUserInfoIDKey = "quoteID"
    private let reminderUserInfoIDKey = "reminderID"
    private let stateQueue = DispatchQueue(label: "leerraum.notification.state")
    private var pendingQuoteMessageID: UUID?
    private var pendingReminderID: UUID?
    private var pendingHabitsOpenRequest = false
    private var pendingLifeGoalsOpenRequest = false
    private var lastQuoteScheduleSignature: Int?
    private var lastQuoteScheduleDate: Date?
    private var lastHabitScheduleSignature: Int?
    private var lastHabitScheduleDate: Date?
    private var lastLifeGoalScheduleSignature: Int?
    private var lastLifeGoalScheduleDate: Date?
    private var lastReminderScheduleSignature: Int?
    private var lastReminderScheduleDate: Date?

    private override init() {
        super.init()
    }

    func configure() {
        center.delegate = self
    }

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { [weak self] settings in
            guard self != nil else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion?(true) }
            case .notDetermined:
                self?.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async { completion?(granted) }
                }
            case .denied:
                DispatchQueue.main.async { completion?(false) }
            @unknown default:
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    func notifyRestFinished(body: String) {
        configure()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        requestAuthorizationIfNeeded { [weak self] granted in
            guard granted, let self else { return }

            let content = UNMutableNotificationContent()
            content.title = "Descanso terminado"
            content.body = body
            content.sound = UNNotificationSound(named: self.customSoundName)

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            self.center.add(request)
        }
    }

    func scheduleRandomQuoteReminders(
        quotes: [QuoteMessage]
    ) {
        configure()

        let validQuotes = quotes.filter {
            $0.isActive && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let signature = quoteScheduleSignature(for: validQuotes)
        let shouldSkip = stateQueue.sync { () -> Bool in
            guard let lastQuoteScheduleSignature, let lastQuoteScheduleDate else { return false }
            let isSameSignature = lastQuoteScheduleSignature == signature
            let wasScheduledRecently = Date().timeIntervalSince(lastQuoteScheduleDate) < 10
            return isSameSignature && wasScheduledRecently
        }
        if shouldSkip {
            Observability.debug(
                Observability.notificationsLogger,
                "Skipped quote scheduling because signature did not change recently."
            )
            return
        }

        requestAuthorizationIfNeeded { [weak self] granted in
            guard granted, let self else { return }

            self.center.getPendingNotificationRequests { [weak self] requests in
                guard let self else { return }
                let interval = Observability.notificationSignposter.beginInterval("quote.schedule.pendingRequests")
                defer { Observability.notificationSignposter.endInterval("quote.schedule.pendingRequests", interval) }

                let existingQuoteIDs = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.quoteReminderIDPrefix) }
                if !existingQuoteIDs.isEmpty {
                    self.center.removePendingNotificationRequests(withIdentifiers: existingQuoteIDs)
                }

                guard !validQuotes.isEmpty else {
                    self.stateQueue.sync {
                        self.lastQuoteScheduleSignature = nil
                        self.lastQuoteScheduleDate = nil
                    }
                    return
                }

                // iOS allows a limited number of pending requests per app.
                // Keep non-quote reminders and fill remaining slots with daily quote reminders.
                let nonQuotePendingCount = max(0, requests.count - existingQuoteIDs.count)
                let availableSlots = max(0, self.maxPendingNotificationRequests - nonQuotePendingCount)
                guard availableSlots > 0 else { return }
                if validQuotes.count > availableSlots {
                    Observability.debug(
                        Observability.notificationsLogger,
                        "Quote reminders limited by iOS pending cap. Active: \(validQuotes.count), available: \(availableSlots)"
                    )
                }

                let quoteRequests = self.dailyQuoteReminderRequests(
                    quotes: validQuotes,
                    maxCount: availableSlots
                )
                quoteRequests.forEach { self.center.add($0) }
                self.stateQueue.sync {
                    self.lastQuoteScheduleSignature = signature
                    self.lastQuoteScheduleDate = Date()
                }
                Observability.debug(
                    Observability.notificationsLogger,
                    "Scheduled \(quoteRequests.count) quote reminders"
                )
            }
        }
    }

    func consumePendingQuoteMessageID() -> UUID? {
        stateQueue.sync {
            let id = pendingQuoteMessageID
            pendingQuoteMessageID = nil
            return id
        }
    }

    func consumePendingHabitsOpenRequest() -> Bool {
        stateQueue.sync {
            let shouldOpen = pendingHabitsOpenRequest
            pendingHabitsOpenRequest = false
            return shouldOpen
        }
    }

    func consumePendingLifeGoalsOpenRequest() -> Bool {
        stateQueue.sync {
            let shouldOpen = pendingLifeGoalsOpenRequest
            pendingLifeGoalsOpenRequest = false
            return shouldOpen
        }
    }

    func consumePendingReminderID() -> UUID? {
        stateQueue.sync {
            let id = pendingReminderID
            pendingReminderID = nil
            return id
        }
    }

    func scheduleDailyHabitReminders(habits: [Habit]) {
        configure()

        let validHabits = habits.filter {
            $0.isActive && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let signature = habitScheduleSignature(for: validHabits)
        let shouldSkip = stateQueue.sync { () -> Bool in
            guard let lastHabitScheduleSignature, let lastHabitScheduleDate else { return false }
            let isSameSignature = lastHabitScheduleSignature == signature
            let wasScheduledRecently = Date().timeIntervalSince(lastHabitScheduleDate) < 10
            return isSameSignature && wasScheduledRecently
        }
        if shouldSkip {
            Observability.debug(
                Observability.notificationsLogger,
                "Skipped habit scheduling because signature did not change recently."
            )
            return
        }

        requestAuthorizationIfNeeded { [weak self] granted in
            guard granted, let self else { return }

            self.center.getPendingNotificationRequests { [weak self] requests in
                guard let self else { return }
                let interval = Observability.notificationSignposter.beginInterval("habit.schedule.pendingRequests")
                defer { Observability.notificationSignposter.endInterval("habit.schedule.pendingRequests", interval) }

                let existingHabitIDs = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.habitReminderIDPrefix) }
                if !existingHabitIDs.isEmpty {
                    self.center.removePendingNotificationRequests(withIdentifiers: existingHabitIDs)
                }

                guard !validHabits.isEmpty else {
                    self.stateQueue.sync {
                        self.lastHabitScheduleSignature = nil
                        self.lastHabitScheduleDate = nil
                    }
                    return
                }

                let nonHabitPendingCount = max(0, requests.count - existingHabitIDs.count)
                let availableSlots = max(0, self.maxPendingNotificationRequests - nonHabitPendingCount)
                guard availableSlots > 0 else { return }
                let reminderRequest = self.dailyHabitReminderRequest(habits: validHabits)
                self.center.add(reminderRequest)
                self.stateQueue.sync {
                    self.lastHabitScheduleSignature = signature
                    self.lastHabitScheduleDate = Date()
                }
                Observability.debug(
                    Observability.notificationsLogger,
                    "Scheduled 1 general habits reminder."
                )
            }
        }
    }

    func scheduleDailyLifeGoalReminders(goals: [LifeGoal]) {
        configure()

        let pendingGoals = goals.filter {
            $0.progress < 100 && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let daySeed = lifeGoalDaySeed()
        let signature = lifeGoalScheduleSignature(for: pendingGoals, daySeed: daySeed)
        let shouldSkip = stateQueue.sync { () -> Bool in
            guard let lastLifeGoalScheduleSignature, let lastLifeGoalScheduleDate else { return false }
            let isSameSignature = lastLifeGoalScheduleSignature == signature
            let wasScheduledRecently = Date().timeIntervalSince(lastLifeGoalScheduleDate) < 10
            return isSameSignature && wasScheduledRecently
        }
        if shouldSkip {
            Observability.debug(
                Observability.notificationsLogger,
                "Skipped life goals scheduling because signature did not change recently."
            )
            return
        }

        requestAuthorizationIfNeeded { [weak self] granted in
            guard granted, let self else { return }

            self.center.getPendingNotificationRequests { [weak self] requests in
                guard let self else { return }
                let interval = Observability.notificationSignposter.beginInterval("lifeGoals.schedule.pendingRequests")
                defer { Observability.notificationSignposter.endInterval("lifeGoals.schedule.pendingRequests", interval) }

                let existingLifeGoalIDs = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.lifeGoalReminderIDPrefix) }
                if !existingLifeGoalIDs.isEmpty {
                    self.center.removePendingNotificationRequests(withIdentifiers: existingLifeGoalIDs)
                }

                guard !pendingGoals.isEmpty else {
                    self.stateQueue.sync {
                        self.lastLifeGoalScheduleSignature = nil
                        self.lastLifeGoalScheduleDate = nil
                    }
                    return
                }

                let nonLifeGoalPendingCount = max(0, requests.count - existingLifeGoalIDs.count)
                let availableSlots = max(0, self.maxPendingNotificationRequests - nonLifeGoalPendingCount)
                guard availableSlots > 0 else { return }

                let reminderRequest = self.dailyLifeGoalReminderRequest(
                    goals: pendingGoals,
                    daySeed: daySeed
                )
                self.center.add(reminderRequest)
                self.stateQueue.sync {
                    self.lastLifeGoalScheduleSignature = signature
                    self.lastLifeGoalScheduleDate = Date()
                }
                Observability.debug(
                    Observability.notificationsLogger,
                    "Scheduled 1 life goals reminder."
                )
            }
        }
    }

    func scheduleRandomReminderNotifications(reminders: [Reminder]) {
        configure()

        let pendingReminders = reminders.filter {
            !$0.isCompleted && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let signature = reminderScheduleSignature(for: pendingReminders)
        let shouldSkip = stateQueue.sync { () -> Bool in
            guard let lastReminderScheduleSignature, let lastReminderScheduleDate else { return false }
            let isSameSignature = lastReminderScheduleSignature == signature
            let wasScheduledRecently = Date().timeIntervalSince(lastReminderScheduleDate) < 10
            return isSameSignature && wasScheduledRecently
        }
        if shouldSkip {
            Observability.debug(
                Observability.notificationsLogger,
                "Skipped reminder scheduling because signature did not change recently."
            )
            return
        }

        requestAuthorizationIfNeeded { [weak self] granted in
            guard granted, let self else { return }

            self.center.getPendingNotificationRequests { [weak self] requests in
                guard let self else { return }
                let interval = Observability.notificationSignposter.beginInterval("reminder.schedule.pendingRequests")
                defer { Observability.notificationSignposter.endInterval("reminder.schedule.pendingRequests", interval) }

                let existingReminderIDs = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.reminderIDPrefix) }
                if !existingReminderIDs.isEmpty {
                    self.center.removePendingNotificationRequests(withIdentifiers: existingReminderIDs)
                }

                guard !pendingReminders.isEmpty else {
                    self.stateQueue.sync {
                        self.lastReminderScheduleSignature = nil
                        self.lastReminderScheduleDate = nil
                    }
                    return
                }

                let nonReminderPendingCount = max(0, requests.count - existingReminderIDs.count)
                let availableSlots = max(0, self.maxPendingNotificationRequests - nonReminderPendingCount)
                guard availableSlots > 0 else { return }

                let reminderRequests = self.randomReminderNotificationRequests(
                    reminders: pendingReminders,
                    maxCount: availableSlots
                )
                reminderRequests.forEach { self.center.add($0) }
                self.stateQueue.sync {
                    self.lastReminderScheduleSignature = signature
                    self.lastReminderScheduleDate = Date()
                }
                Observability.debug(
                    Observability.notificationsLogger,
                    "Scheduled \(reminderRequests.count) reminder notifications."
                )
            }
        }
    }

    func scheduleMonthlyFinanceReviewReminders(monthsAhead: Int = 12) {
        configure()

        requestAuthorizationIfNeeded { [weak self] granted in
            guard granted, let self else { return }

            self.center.getPendingNotificationRequests { [weak self] requests in
                guard let self else { return }
                let interval = Observability.notificationSignposter.beginInterval("monthly.schedule.pendingRequests")
                defer { Observability.notificationSignposter.endInterval("monthly.schedule.pendingRequests", interval) }

                let existingMonthlyIDs = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.monthlyReminderIDPrefix) }
                if !existingMonthlyIDs.isEmpty {
                    self.center.removePendingNotificationRequests(withIdentifiers: existingMonthlyIDs)
                }

                let reminderRequests = self.monthlyReminderRequests(count: monthsAhead)
                reminderRequests.forEach { self.center.add($0) }
                Observability.debug(
                    Observability.notificationsLogger,
                    "Scheduled \(reminderRequests.count) monthly finance reminders"
                )
            }
        }
    }

    private func monthlyReminderRequests(count: Int) -> [UNNotificationRequest] {
        let interval = Observability.notificationSignposter.beginInterval("monthlyReminderRequests")
        defer { Observability.notificationSignposter.endInterval("monthlyReminderRequests", interval) }
        guard count > 0 else { return [] }

        let now = Date()
        var requests: [UNNotificationRequest] = []
        var monthOffset = 0
        let maxIterations = count + 24

        while requests.count < count && monthOffset < maxIterations {
            defer { monthOffset += 1 }

            guard let reminderDate = monthEndDate(forMonthOffset: monthOffset) else { continue }
            guard reminderDate > now else { continue }

            let triggerComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerComponents,
                repeats: false
            )

            let content = UNMutableNotificationContent()
            content.title = "Cierre mensual de finanzas"
            content.body = "Es fin de mes. Revisa la mensualidad completa de tus finanzas en Leerraum."
            content.sound = UNNotificationSound(named: customSoundName)

            let identifier = "\(monthlyReminderIDPrefix)\(triggerComponents.year ?? 0)-\(triggerComponents.month ?? 0)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            requests.append(request)
        }

        return requests
    }

    private func dailyQuoteReminderRequests(
        quotes: [QuoteMessage],
        maxCount: Int
    ) -> [UNNotificationRequest] {
        let interval = Observability.notificationSignposter.beginInterval("quoteReminderRequests")
        defer { Observability.notificationSignposter.endInterval("quoteReminderRequests", interval) }
        guard !quotes.isEmpty, maxCount > 0 else { return [] }

        let selectedQuotes = Array(quotes.shuffled().prefix(maxCount))
        let reminderTimes = randomReminderTimes(
            count: selectedQuotes.count,
            startHour: 8,
            endHour: 22
        )

        return zip(selectedQuotes, reminderTimes).map { quote, triggerComponents in
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerComponents,
                repeats: true
            )

            let content = UNMutableNotificationContent()
            content.title = "Leerraum"
            content.subtitle = quoteNotificationMessage(from: quote.text)
            content.body = "Por \(quoteNotificationAuthor(from: quote.author))"
            content.sound = UNNotificationSound(named: customSoundName)
            content.userInfo = [
                quoteUserInfoTypeKey: quoteUserInfoTypeValue,
                quoteUserInfoIDKey: quote.id.uuidString
            ]

            let identifier = "\(quoteReminderIDPrefix)\(quote.id.uuidString)"
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
    }

    private func dailyHabitReminderRequest(habits: [Habit]) -> UNNotificationRequest {
        let interval = Observability.notificationSignposter.beginInterval("habitReminderRequest")
        defer { Observability.notificationSignposter.endInterval("habitReminderRequest", interval) }

        let triggerComponents = habitReminderTimeComponents(from: habits)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerComponents,
            repeats: true
        )

        let content = UNMutableNotificationContent()
        content.title = "Leerraum"
        content.subtitle = "Es hora de registrar tus habitos"
        content.body = "Solo te toma unos segundos"
        content.sound = UNNotificationSound(named: customSoundName)
        content.userInfo = [quoteUserInfoTypeKey: habitUserInfoTypeValue]

        let identifier = "\(habitReminderIDPrefix)general"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func dailyLifeGoalReminderRequest(
        goals: [LifeGoal],
        daySeed: Int
    ) -> UNNotificationRequest {
        let interval = Observability.notificationSignposter.beginInterval("lifeGoalReminderRequest")
        defer { Observability.notificationSignposter.endInterval("lifeGoalReminderRequest", interval) }

        let triggerComponents = lifeGoalReminderTimeComponents()
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerComponents,
            repeats: true
        )

        let selectedGoal = selectedLifeGoalForReminder(goals: goals, daySeed: daySeed)
        let sanitizedTitle = sanitizedLifeGoalTitle(selectedGoal?.title ?? "tu meta")
        let prompt = lifeGoalPrompt(for: sanitizedTitle, daySeed: daySeed)

        let content = UNMutableNotificationContent()
        content.title = "Leerraum"
        content.subtitle = prompt.subtitle
        content.body = prompt.body
        content.sound = UNNotificationSound(named: customSoundName)
        content.userInfo = [quoteUserInfoTypeKey: lifeGoalUserInfoTypeValue]

        let identifier = "\(lifeGoalReminderIDPrefix)general"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func randomReminderTimes(
        count: Int,
        startHour: Int,
        endHour: Int
    ) -> [DateComponents] {
        guard count > 0, startHour <= endHour else { return [] }

        let startSecond = startHour * 3600
        let endSecond = endHour * 3600 + 3599
        let maxSlots = max(endSecond - startSecond + 1, 0)
        guard maxSlots > 0 else { return [] }

        let targetCount = min(count, maxSlots)
        var selectedSeconds: Set<Int> = []
        while selectedSeconds.count < targetCount {
            selectedSeconds.insert(Int.random(in: startSecond...endSecond))
        }

        return selectedSeconds
            .sorted()
            .map { secondOfDay in
                var components = DateComponents()
                components.hour = secondOfDay / 3600
                components.minute = (secondOfDay % 3600) / 60
                components.second = secondOfDay % 60
                return components
            }
    }

    private func quoteNotificationMessage(from text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return "Mensaje"
        }

        let maxLength = 220
        guard normalized.count > maxLength else { return normalized }
        let endIndex = normalized.index(normalized.startIndex, offsetBy: maxLength)
        return String(normalized[..<endIndex]) + "..."
    }

    private func quoteNotificationAuthor(from author: String) -> String {
        let normalized = author.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "Sin autor" : normalized
    }

    private func quoteScheduleSignature(for quotes: [QuoteMessage]) -> Int {
        var hasher = Hasher()
        for quote in quotes.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(quote.id)
            hasher.combine(quote.isActive)
            hasher.combine(quote.text)
            hasher.combine(quote.author)
        }
        return hasher.finalize()
    }

    private func habitReminderTimeComponents(from habits: [Habit]) -> DateComponents {
        let defaultComponents = DateComponents(hour: 21, minute: 0, second: 0)
        guard let selectedHabit = habits.min(by: { lhs, rhs in
            if lhs.reminderHour != rhs.reminderHour {
                return lhs.reminderHour < rhs.reminderHour
            }
            if lhs.reminderMinute != rhs.reminderMinute {
                return lhs.reminderMinute < rhs.reminderMinute
            }
            return lhs.createdAt < rhs.createdAt
        }) else {
            return defaultComponents
        }

        return DateComponents(
            hour: selectedHabit.reminderHour,
            minute: selectedHabit.reminderMinute,
            second: 0
        )
    }

    private func lifeGoalReminderTimeComponents() -> DateComponents {
        DateComponents(hour: 20, minute: 0, second: 0)
    }

    private func selectedLifeGoalForReminder(
        goals: [LifeGoal],
        daySeed: Int
    ) -> LifeGoal? {
        guard !goals.isEmpty else { return nil }
        let sortedGoals = goals.sorted(by: { $0.id.uuidString < $1.id.uuidString })
        let index = abs(daySeed) % sortedGoals.count
        return sortedGoals[index]
    }

    private func sanitizedLifeGoalTitle(_ title: String) -> String {
        let normalized = title
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return "tu meta"
        }

        let maxLength = 80
        guard normalized.count > maxLength else { return normalized }
        let endIndex = normalized.index(normalized.startIndex, offsetBy: maxLength)
        return String(normalized[..<endIndex]) + "..."
    }

    private func lifeGoalPrompt(
        for goalTitle: String,
        daySeed: Int
    ) -> (subtitle: String, body: String) {
        let quotedGoalTitle = "\"\(goalTitle)\""
        let prompts: [(subtitle: String, body: String)] = [
            (
                subtitle: "¿Como vas con \(quotedGoalTitle)?",
                body: "Revisa hoy tu progreso y da un paso mas."
            ),
            (
                subtitle: "¿Que te falta para completar \(quotedGoalTitle)?",
                body: "Actualiza tu avance en Metas de vida."
            ),
            (
                subtitle: "¿Como si puedes cumplir \(quotedGoalTitle)?",
                body: "Define el siguiente paso y registralo en Leerraum."
            )
        ]

        let index = abs(daySeed) % prompts.count
        return prompts[index]
    }

    private func habitScheduleSignature(for habits: [Habit]) -> Int {
        var hasher = Hasher()
        for habit in habits.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(habit.id)
            hasher.combine(habit.isActive)
            hasher.combine(habit.title)
            hasher.combine(habit.reminderHour)
            hasher.combine(habit.reminderMinute)
        }
        return hasher.finalize()
    }

    private func randomReminderNotificationRequests(
        reminders: [Reminder],
        maxCount: Int
    ) -> [UNNotificationRequest] {
        let interval = Observability.notificationSignposter.beginInterval("reminderNotificationRequests")
        defer { Observability.notificationSignposter.endInterval("reminderNotificationRequests", interval) }
        guard !reminders.isEmpty, maxCount > 0 else { return [] }

        // Each pending reminder gets up to 3 random notifications per day
        let notificationsPerReminder = 3
        var allRequests: [UNNotificationRequest] = []

        for reminder in reminders {
            let days = calendar.dateComponents([.day], from: reminder.createdAt, to: Date()).day ?? 0
            let postponedText: String
            if days == 0 {
                postponedText = "Creado hoy"
            } else if days == 1 {
                postponedText = "1 dia postergado"
            } else {
                postponedText = "\(days) dias postergado"
            }

            let times = randomReminderTimes(
                count: notificationsPerReminder,
                startHour: 9,
                endHour: 21
            )

            for (index, triggerComponents) in times.enumerated() {
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: triggerComponents,
                    repeats: true
                )

                let content = UNMutableNotificationContent()
                content.title = "Leerraum"
                content.subtitle = reminder.title
                content.body = postponedText
                content.sound = UNNotificationSound(named: customSoundName)
                content.userInfo = [
                    quoteUserInfoTypeKey: reminderUserInfoTypeValue,
                    reminderUserInfoIDKey: reminder.id.uuidString
                ]

                let identifier = "\(reminderIDPrefix)\(reminder.id.uuidString).\(index)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                allRequests.append(request)
            }
        }

        // Respect the available slots limit
        if allRequests.count > maxCount {
            allRequests = Array(allRequests.shuffled().prefix(maxCount))
        }

        return allRequests
    }

    private func reminderScheduleSignature(for reminders: [Reminder]) -> Int {
        var hasher = Hasher()
        for reminder in reminders.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(reminder.id)
            hasher.combine(reminder.isCompleted)
            hasher.combine(reminder.title)
        }
        // Include day so postponed text refreshes daily
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
        hasher.combine(dayOfYear)
        return hasher.finalize()
    }

    private func lifeGoalScheduleSignature(for goals: [LifeGoal], daySeed: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(daySeed)
        for goal in goals.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(goal.id)
            hasher.combine(goal.title)
            hasher.combine(goal.progress)
            hasher.combine(goal.targetDate)
        }
        return hasher.finalize()
    }

    private func lifeGoalDaySeed() -> Int {
        let now = Date()
        let year = calendar.component(.year, from: now)
        let day = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        return year * 1000 + day
    }

    private func monthEndDate(forMonthOffset monthOffset: Int) -> Date? {
        guard let targetMonthDate = calendar.date(byAdding: .month, value: monthOffset, to: Date()),
              let monthInterval = calendar.dateInterval(of: .month, for: targetMonthDate),
              let lastDayDate = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: lastDayDate)
        components.hour = 20
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Observability.debug(
            Observability.notificationsLogger,
            "Foreground notification presented: \(notification.request.identifier)"
        )
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let interval = Observability.notificationSignposter.beginInterval("notification.response.handle")
        defer { Observability.notificationSignposter.endInterval("notification.response.handle", interval) }
        let userInfo = response.notification.request.content.userInfo
        if let quoteID = quoteID(from: userInfo) {
            stateQueue.sync {
                pendingQuoteMessageID = quoteID
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openQuoteMessage, object: quoteID)
            }
            Observability.debug(
                Observability.notificationsLogger,
                "Notification tap routed to quote: \(quoteID.uuidString)"
            )
        } else if isHabitSummaryNotification(userInfo: userInfo) {
            stateQueue.sync {
                pendingHabitsOpenRequest = true
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openHabitsTracking, object: nil)
            }
            Observability.debug(
                Observability.notificationsLogger,
                "Notification tap routed to habits."
            )
        } else if isLifeGoalSummaryNotification(userInfo: userInfo) {
            stateQueue.sync {
                pendingLifeGoalsOpenRequest = true
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openLifeGoalsTracking, object: nil)
            }
            Observability.debug(
                Observability.notificationsLogger,
                "Notification tap routed to life goals."
            )
        } else if let reminderID = reminderID(from: userInfo) {
            stateQueue.sync {
                pendingReminderID = reminderID
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openReminderDetail, object: reminderID)
            }
            Observability.debug(
                Observability.notificationsLogger,
                "Notification tap routed to reminder: \(reminderID.uuidString)"
            )
        }

        completionHandler()
    }

    private func quoteID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let type = userInfo[quoteUserInfoTypeKey] as? String,
              type == quoteUserInfoTypeValue,
              let quoteIDText = userInfo[quoteUserInfoIDKey] as? String else {
            return nil
        }
        return UUID(uuidString: quoteIDText)
    }

    private func isHabitSummaryNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let type = userInfo[quoteUserInfoTypeKey] as? String else {
            return false
        }
        return type == habitUserInfoTypeValue
    }

    private func isLifeGoalSummaryNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let type = userInfo[quoteUserInfoTypeKey] as? String else {
            return false
        }
        return type == lifeGoalUserInfoTypeValue
    }

    private func reminderID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let type = userInfo[quoteUserInfoTypeKey] as? String,
              type == reminderUserInfoTypeValue,
              let reminderIDText = userInfo[reminderUserInfoIDKey] as? String else {
            return nil
        }
        return UUID(uuidString: reminderIDText)
    }
}

extension Notification.Name {
    static let openQuoteMessage = Notification.Name("leerraum.openQuoteMessage")
    static let openHabitsTracking = Notification.Name("leerraum.openHabitsTracking")
    static let openLifeGoalsTracking = Notification.Name("leerraum.openLifeGoalsTracking")
    static let openReminderDetail = Notification.Name("leerraum.openReminderDetail")
}
