import WidgetKit
import SwiftUI

private struct LeerraumWidgetEntry: TimelineEntry {
    let date: Date
    let tip: String
}

private struct LeerraumWidgetProvider: TimelineProvider {
    private let tips: [String] = [
        "Registra tus gastos de hoy.",
        "Anota tu rutina del gym.",
        "Guarda lo que comiste hoy.",
        "Escribe una frase que te motive.",
        "Actualiza tus medidas corporales.",
        "Agrega una meta de vida.",
        "Guarda una recomendacion nueva."
    ]

    func placeholder(in context: Context) -> LeerraumWidgetEntry {
        LeerraumWidgetEntry(date: .now, tip: tips[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (LeerraumWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LeerraumWidgetEntry>) -> Void) {
        let now = Date()
        var entries: [LeerraumWidgetEntry] = []

        for hourOffset in 0..<8 {
            guard let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: now) else {
                continue
            }
            let tip = tips[hourOffset % tips.count]
            entries.append(LeerraumWidgetEntry(date: entryDate, tip: tip))
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func currentEntry() -> LeerraumWidgetEntry {
        let hour = Calendar.current.component(.hour, from: .now)
        return LeerraumWidgetEntry(date: .now, tip: tips[hour % tips.count])
    }
}

struct LeerraumSummaryWidget: Widget {
    let kind: String = "LeerraumSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LeerraumWidgetProvider()) { entry in
            LeerraumSummaryWidgetView(entry: entry)
                .widgetURL(URL(string: "leerraum://home"))
        }
        .configurationDisplayName("Leerraum")
        .description("Resumen rapido para abrir tus secciones de Leerraum.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct LeerraumSummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LeerraumWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Leerraum")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text(entry.date.formatted(.dateTime.day().month(.abbreviated)))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.86))

            Spacer(minLength: 0)

            Text(entry.tip)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .leerraumWidgetBackground(widgetGradient)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Leerraum")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text(entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
            }

            Text("Recordatorio")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(entry.tip)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                quickTag("Finanzas", icon: "chart.line.uptrend.xyaxis")
                quickTag("Gym", icon: "figure.strengthtraining.traditional")
                quickTag("Comidas", icon: "fork.knife")
                quickTag("Frases", icon: "quote.bubble")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .leerraumWidgetBackground(widgetGradient)
    }

    private var widgetGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.19, green: 0.60, blue: 0.29),
                Color(red: 0.12, green: 0.50, blue: 0.76)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func quickTag(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.16), in: Capsule())
    }
}

