import SwiftUI
import WidgetKit

private struct FoodWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSnapshotPayload
}

private struct FoodWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FoodWidgetEntry {
        FoodWidgetEntry(
            date: .now,
            payload: WidgetSnapshotPayload(
                updatedAt: .now,
                foodTotalToday: 3,
                foodHealthyToday: 1,
                foodMediumToday: 1,
                foodJunkToday: 1,
                foodPreviewLines: ["Desayuno · Avena", "Comida · Pollo", "Cena · Ensalada"],
                quoteText: "",
                quoteAuthor: "",
                lifeGoalTitle: "",
                lifeGoalProgress: 0,
                lifeGoalAreaDisplayName: "",
                routineRows: []
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FoodWidgetEntry) -> Void) {
        completion(FoodWidgetEntry(date: .now, payload: WidgetSnapshotPayload.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FoodWidgetEntry>) -> Void) {
        let entry = FoodWidgetEntry(date: .now, payload: WidgetSnapshotPayload.load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct LeerraumFoodWidget: Widget {
    let kind: String = "LeerraumFoodWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FoodWidgetProvider()) { entry in
            LeerraumFoodWidgetView(entry: entry)
                .widgetURL(URL(string: "leerraum://food"))
        }
        .configurationDisplayName("Comidas")
        .description("Resumen de lo que registraste hoy y la calidad de tus alimentos.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct LeerraumFoodWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FoodWidgetEntry

    private var payload: WidgetSnapshotPayload { entry.payload }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallContent
            default:
                mediumContent
            }
        }
        .leerraumWidgetBackground(foodGradient)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Comidas hoy", systemImage: "fork.knife")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text("\(payload.foodTotalToday) alimento(s)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                chip("S", payload.foodHealthyToday, Color(red: 0.20, green: 0.72, blue: 0.45))
                chip("M", payload.foodMediumToday, Color(red: 0.95, green: 0.62, blue: 0.22))
                chip("C", payload.foodJunkToday, Color(red: 0.92, green: 0.32, blue: 0.28))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Comidas hoy", systemImage: "fork.knife")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(payload.foodTotalToday)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                pill("Saludable", payload.foodHealthyToday, Color(red: 0.20, green: 0.72, blue: 0.45))
                pill("Medio", payload.foodMediumToday, Color(red: 0.95, green: 0.62, blue: 0.22))
                pill("Chatarra", payload.foodJunkToday, Color(red: 0.92, green: 0.32, blue: 0.28))
            }

            if !payload.foodPreviewLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(payload.foodPreviewLines, id: \.self) { line in
                        Text(line)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private func chip(_ title: String, _ count: Int, _ tint: Color) -> some View {
        Text("\(title) \(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.35), in: Capsule())
    }

    private func pill(_ title: String, _ count: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(tint.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var foodGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.55, blue: 0.34),
                Color(red: 0.10, green: 0.45, blue: 0.62)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
