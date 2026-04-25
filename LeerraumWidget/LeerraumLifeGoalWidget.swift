import SwiftUI
import WidgetKit

private struct LifeGoalWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSnapshotPayload
}

private struct LifeGoalWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LifeGoalWidgetEntry {
        LifeGoalWidgetEntry(
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
                lifeGoalTitle: "Correr 5 km sin parar",
                lifeGoalProgress: 35,
                lifeGoalAreaDisplayName: "Salud",
                routineRows: []
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LifeGoalWidgetEntry) -> Void) {
        completion(LifeGoalWidgetEntry(date: .now, payload: WidgetSnapshotPayload.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LifeGoalWidgetEntry>) -> Void) {
        let entry = LifeGoalWidgetEntry(date: .now, payload: WidgetSnapshotPayload.load())
        let next = Calendar.current.date(byAdding: .hour, value: 3, to: .now) ?? .now.addingTimeInterval(10800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct LeerraumLifeGoalWidget: Widget {
    let kind: String = "LeerraumLifeGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LifeGoalWidgetProvider()) { entry in
            LeerraumLifeGoalWidgetView(entry: entry)
                .widgetURL(URL(string: "leerraum://lifegoals"))
        }
        .configurationDisplayName("Metas de vida")
        .description("Una meta pendiente y tu porcentaje de avance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct LeerraumLifeGoalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LifeGoalWidgetEntry

    private var payload: WidgetSnapshotPayload { entry.payload }

    var body: some View {
        Group {
            if family == .systemSmall {
                smallContent
            } else {
                mediumContent
            }
        }
        .leerraumWidgetBackground(goalGradient)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Meta", systemImage: "target")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            if payload.lifeGoalTitle.isEmpty {
                Text("Crea metas en Mas > Metas de vida.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(4)
            } else {
                Text(payload.lifeGoalTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text("\(payload.lifeGoalProgress)%")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Meta de vida", systemImage: "target")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if !payload.lifeGoalAreaDisplayName.isEmpty {
                    Text(payload.lifeGoalAreaDisplayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.18), in: Capsule())
                }
            }

            if payload.lifeGoalTitle.isEmpty {
                Text("Abre Leerraum y agrega una meta en Mas > Metas de vida.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
            } else {
                Text(payload.lifeGoalTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)

                ProgressView(value: Double(payload.lifeGoalProgress), total: 100)
                    .tint(.white)

                Text("Avance: \(payload.lifeGoalProgress)%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private var goalGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.35, blue: 0.22),
                Color(red: 0.55, green: 0.22, blue: 0.65)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
