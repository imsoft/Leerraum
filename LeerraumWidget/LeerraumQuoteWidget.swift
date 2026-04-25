import SwiftUI
import WidgetKit

private struct QuoteWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSnapshotPayload
}

private struct QuoteWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteWidgetEntry {
        QuoteWidgetEntry(
            date: .now,
            payload: WidgetSnapshotPayload(
                updatedAt: .now,
                foodTotalToday: 0,
                foodHealthyToday: 0,
                foodMediumToday: 0,
                foodJunkToday: 0,
                foodPreviewLines: [],
                quoteText: "Cada dia es una nueva oportunidad de ser mejor.",
                quoteAuthor: "Leerraum",
                lifeGoalTitle: "",
                lifeGoalProgress: 0,
                lifeGoalAreaDisplayName: "",
                routineRows: []
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteWidgetEntry) -> Void) {
        completion(QuoteWidgetEntry(date: .now, payload: WidgetSnapshotPayload.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteWidgetEntry>) -> Void) {
        let entry = QuoteWidgetEntry(date: .now, payload: WidgetSnapshotPayload.load())
        let next = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now.addingTimeInterval(7200)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct LeerraumQuoteWidget: Widget {
    let kind: String = "LeerraumQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteWidgetProvider()) { entry in
            LeerraumQuoteWidgetView(entry: entry)
                .widgetURL(URL(string: "leerraum://quotes"))
        }
        .configurationDisplayName("Frases")
        .description("Una frase activa de tu coleccion en Leerraum.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct LeerraumQuoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuoteWidgetEntry

    private var payload: WidgetSnapshotPayload { entry.payload }

    var body: some View {
        Group {
            if family == .systemSmall {
                smallContent
            } else {
                mediumContent
            }
        }
        .leerraumWidgetBackground(quoteGradient)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Frase", systemImage: "quote.bubble.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if payload.quoteText.isEmpty {
                Text("Agrega frases activas en la app.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.leading)
                    .lineLimit(8)
            } else {
                Text("“\(payload.quoteText)”")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(12)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
                if !payload.quoteAuthor.isEmpty {
                    Text("— \(payload.quoteAuthor)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Frase del dia", systemImage: "quote.bubble.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            if payload.quoteText.isEmpty {
                Text("Abre Leerraum en Frases y activa al menos una frase con texto.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.leading)
                    .lineLimit(10)
            } else {
                Text("“\(payload.quoteText)”")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(18)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                if !payload.quoteAuthor.isEmpty {
                    Text("— \(payload.quoteAuthor)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private var quoteGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.45, green: 0.28, blue: 0.78),
                Color(red: 0.20, green: 0.42, blue: 0.82)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
