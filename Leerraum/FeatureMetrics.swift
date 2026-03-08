import Foundation

struct AppIdeasMetrics {
    let total: Int
    let pending: Int
    let inProgress: Int
    let done: Int

    init(ideas: [AppIdeaNote]) {
        total = ideas.count
        pending = ideas.filter { Self.normalizedStatus($0.statusRaw) == "pendiente" }.count
        inProgress = ideas.filter { Self.normalizedStatus($0.statusRaw) == "en progreso" }.count
        done = ideas.filter { Self.normalizedStatus($0.statusRaw) == "hecha" }.count
    }

    private static func normalizedStatus(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct LifeGoalsMetrics {
    let total: Int
    let notStarted: Int
    let inProgress: Int
    let completed: Int
    let averageProgress: Int

    init(goals: [LifeGoal]) {
        total = goals.count
        notStarted = goals.filter { $0.progress <= 0 }.count
        inProgress = goals.filter { $0.progress > 0 && $0.progress < 100 }.count
        completed = goals.filter { $0.progress >= 100 }.count

        guard !goals.isEmpty else {
            averageProgress = 0
            return
        }

        let totalProgress = goals.reduce(0) { partial, goal in
            partial + max(0, min(goal.progress, 100))
        }
        averageProgress = Int(Double(totalProgress) / Double(goals.count))
    }
}

struct RecommendationsMetrics {
    let total: Int
    let pending: Int
    let completed: Int
    let topKind: RecommendationKind?

    init(recommendations: [RecommendationEntry]) {
        total = recommendations.count
        pending = recommendations.filter { !$0.isCompleted }.count
        completed = recommendations.filter(\.isCompleted).count
        topKind = Dictionary(grouping: recommendations, by: \.kind)
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?
            .key
    }
}
