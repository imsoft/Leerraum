import SwiftUI
import WidgetKit

private struct RoutineProgressEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSnapshotPayload
}

private struct RoutineProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> RoutineProgressEntry {
        RoutineProgressEntry(
            date: .now,
            payload: WidgetSnapshotPayload(
                updatedAt: .now,
                foodTotalToday: 0,
                foodHealthyToday: 0,
                foodMediumToday: 0,
                foodJunkToday: 0,
                foodPreviewLines: [],
                quoteText: "",
                quoteAuthor: "",
                lifeGoalTitle: "",
                lifeGoalProgress: 0,
                lifeGoalAreaDisplayName: "",
                routineRows: [
                    RoutineSlotRowPayload(id: "1", title: "Desayuno", timeText: "08:00", isWater: false, isDone: true),
                    RoutineSlotRowPayload(id: "2", title: "Comida", timeText: "14:00", isWater: false, isDone: false),
                    RoutineSlotRowPayload(id: "3", title: "Agua", timeText: "11:00", isWater: true, isDone: true),
                    RoutineSlotRowPayload(id: "4", title: "Agua", timeText: "13:00", isWater: true, isDone: false)
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RoutineProgressEntry) -> Void) {
        completion(RoutineProgressEntry(date: .now, payload: WidgetSnapshotPayload.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RoutineProgressEntry>) -> Void) {
        let entry = RoutineProgressEntry(date: .now, payload: WidgetSnapshotPayload.load())
        let next = Calendar.current.date(byAdding: .minute, value: 20, to: .now) ?? .now.addingTimeInterval(1200)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct LeerraumMealsRoutineWidget: Widget {
    let kind: String = "LeerraumMealsRoutineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RoutineProgressProvider()) { entry in
            RoutineProgressWidgetView(entry: entry, isWaterWidget: false)
                .widgetURL(URL(string: "leerraum://food"))
        }
        .configurationDisplayName("Comidas hoy")
        .description("Horarios de comida y si ya los cumpliste hoy.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LeerraumWaterRoutineWidget: Widget {
    let kind: String = "LeerraumWaterRoutineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RoutineProgressProvider()) { entry in
            RoutineProgressWidgetView(entry: entry, isWaterWidget: true)
                .widgetURL(URL(string: "leerraum://food"))
        }
        .configurationDisplayName("Agua hoy")
        .description("Horarios de agua y avance del dia.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct RoutineProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RoutineProgressEntry
    let isWaterWidget: Bool

    private var title: String {
        isWaterWidget ? "Agua hoy" : "Comidas hoy"
    }

    private var iconName: String {
        isWaterWidget ? "drop.fill" : "fork.knife"
    }

    private var rows: [RoutineSlotRowPayload] {
        entry.payload.routineRows.filter { $0.isWater == isWaterWidget }
    }

    private var doneCount: Int {
        rows.filter(\.isDone).count
    }

    private var maxRows: Int {
        if isWaterWidget { return 4 }
        return family == .systemSmall ? 3 : 5
    }

    private var gradient: LinearGradient {
        if isWaterWidget {
            return LinearGradient(
                colors: [Color(red: 0.11, green: 0.46, blue: 0.68), Color(red: 0.09, green: 0.31, blue: 0.50)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color(red: 0.17, green: 0.55, blue: 0.35), Color(red: 0.13, green: 0.39, blue: 0.27)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 8) {
            HStack(spacing: 8) {
                Label(title, systemImage: iconName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("\(doneCount)/\(rows.count)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.95))
            }

            if rows.isEmpty {
                Text("Sin horarios configurados.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                Spacer(minLength: 0)
            } else {
                ForEach(Array(rows.prefix(maxRows))) { row in
                    HStack(spacing: 6) {
                        Text(row.timeText)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(width: 42, alignment: .leading)

                        Text(row.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer(minLength: 2)

                        Image(systemName: row.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(row.isDone ? Color(red: 0.55, green: 0.95, blue: 0.65) : .white.opacity(0.68))
                    }
                }
                if rows.count > maxRows {
                    Text("+\(rows.count - maxRows) mas")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .leerraumWidgetBackground(gradient)
    }
}
