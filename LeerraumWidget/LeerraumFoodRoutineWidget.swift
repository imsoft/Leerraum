import SwiftUI
import WidgetKit

private struct FoodRoutineWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSnapshotPayload
}

private struct FoodRoutineWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FoodRoutineWidgetEntry {
        FoodRoutineWidgetEntry(
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
                    RoutineSlotRowPayload(id: "2", title: "Agua", timeText: "11:00", isWater: true, isDone: false)
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FoodRoutineWidgetEntry) -> Void) {
        completion(FoodRoutineWidgetEntry(date: .now, payload: WidgetSnapshotPayload.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FoodRoutineWidgetEntry>) -> Void) {
        let entry = FoodRoutineWidgetEntry(date: .now, payload: WidgetSnapshotPayload.load())
        let next = Calendar.current.date(byAdding: .minute, value: 20, to: .now) ?? .now.addingTimeInterval(1200)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct LeerraumFoodRoutineWidget: Widget {
    let kind: String = "LeerraumFoodRoutineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FoodRoutineWidgetProvider()) { entry in
            LeerraumFoodRoutineWidgetView(entry: entry)
                .widgetURL(URL(string: "leerraum://food"))
        }
        .configurationDisplayName("Horarios comida y agua")
        .description("Hora de cada recordatorio y si ya lo marcaste como hecho hoy.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct LeerraumFoodRoutineWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FoodRoutineWidgetEntry

    private var payload: WidgetSnapshotPayload { entry.payload }

    private var rows: [RoutineSlotRowPayload] { payload.routineRows }

    private var maxVisibleRows: Int {
        switch family {
        case .systemSmall:
            return 5
        default:
            return 9
        }
    }

    private var visibleRows: ArraySlice<RoutineSlotRowPayload> {
        rows.prefix(maxVisibleRows)
    }

    private var hiddenCount: Int {
        max(0, rows.count - visibleRows.count)
    }

    private var doneCount: Int {
        rows.filter(\.isDone).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            HStack(spacing: 8) {
                Label("Hoy", systemImage: "clock.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                if !rows.isEmpty {
                    Text("\(doneCount)/\(rows.count)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.95))
                }
            }

            if rows.isEmpty {
                Text("Sin horarios para hoy.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: family == .systemSmall ? 3 : 4) {
                    ForEach(Array(visibleRows)) { row in
                        routineRow(row)
                    }
                }
                if hiddenCount > 0 {
                    Text("+\(hiddenCount) más")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .leerraumWidgetBackground(routineGradient)
    }

    private func routineRow(_ row: RoutineSlotRowPayload) -> some View {
        HStack(spacing: 6) {
            Text(row.timeText)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 40, alignment: .leading)

            Image(systemName: row.isWater ? "drop.fill" : "fork.knife")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 14)

            Text(row.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 2)

            Text(row.isDone ? "Listo" : "Pend.")
                .font(.caption2.weight(.bold))
                .foregroundStyle(row.isDone ? Color(red: 0.55, green: 0.95, blue: 0.65) : .white.opacity(0.75))

            Image(systemName: row.isDone ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(row.isDone ? Color(red: 0.55, green: 0.95, blue: 0.65) : .white.opacity(0.55))
        }
    }

    private var routineGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.42, blue: 0.58),
                Color(red: 0.14, green: 0.36, blue: 0.48)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
