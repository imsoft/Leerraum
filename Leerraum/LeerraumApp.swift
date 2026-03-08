import SwiftUI
import SwiftData
import UserNotifications
import AudioToolbox
import OSLog

@main
struct LeerraumApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
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
            BodyMeasurementEntry.self,
            RecommendationEntry.self,
            AppIdeaNote.self,
            LifeGoal.self
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
    private let quoteUserInfoTypeKey = "leerraumNotificationType"
    private let quoteUserInfoTypeValue = "quoteMessage"
    private let quoteUserInfoIDKey = "quoteID"
    private let stateQueue = DispatchQueue(label: "leerraum.notification.state")
    private var pendingQuoteMessageID: UUID?
    private var lastQuoteScheduleSignature: Int?
    private var lastQuoteScheduleDate: Date?

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
            content.title = quoteNotificationTitle(from: quote.text)
            content.subtitle = "Autor: \(quoteNotificationAuthor(from: quote.author))"
            content.body = quoteNotificationTitle(from: quote.text)
            content.sound = UNNotificationSound(named: customSoundName)
            content.userInfo = [
                quoteUserInfoTypeKey: quoteUserInfoTypeValue,
                quoteUserInfoIDKey: quote.id.uuidString
            ]

            let identifier = "\(quoteReminderIDPrefix)\(quote.id.uuidString)"
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
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

    private func quoteNotificationTitle(from text: String) -> String {
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
}

extension Notification.Name {
    static let openQuoteMessage = Notification.Name("leerraum.openQuoteMessage")
}
