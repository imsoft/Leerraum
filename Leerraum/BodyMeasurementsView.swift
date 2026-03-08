import SwiftUI
import SwiftData
import Charts
import OSLog

private enum BodyMetric: String, CaseIterable, Identifiable {
    case weight
    case waist
    case hip
    case bodyFat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight:
            return "Peso"
        case .waist:
            return "Cintura"
        case .hip:
            return "Cadera"
        case .bodyFat:
            return "% Grasa"
        }
    }

    var unit: String {
        switch self {
        case .weight:
            return "kg"
        case .waist, .hip:
            return "cm"
        case .bodyFat:
            return "%"
        }
    }

    var icon: String {
        switch self {
        case .weight:
            return "scalemass.fill"
        case .waist:
            return "ruler.fill"
        case .hip:
            return "figure.walk"
        case .bodyFat:
            return "percent"
        }
    }

    var tint: Color {
        switch self {
        case .weight:
            return AppPalette.Body.c600
        case .waist:
            return Color(red: 0.95, green: 0.58, blue: 0.20)
        case .hip:
            return Color(red: 0.21, green: 0.64, blue: 0.45)
        case .bodyFat:
            return Color(red: 0.72, green: 0.50, blue: 0.15)
        }
    }

    func value(for entry: BodyMeasurementEntry) -> Double? {
        switch self {
        case .weight:
            return entry.weightKg
        case .waist:
            return entry.waistCm
        case .hip:
            return entry.hipCm
        case .bodyFat:
            return entry.bodyFatPercent
        }
    }
}

private struct BodyChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
}

private struct BMISnapshot {
    let value: Double
    let category: String
    let tint: Color
}

private struct BodyMeasurementEditTarget: Identifiable {
    let id: UUID
}

private enum BMICalculator {
    static func snapshot(weightKg: Double?, heightCm: Double?) -> BMISnapshot? {
        guard let weightKg, let heightCm, weightKg > 0, heightCm > 0 else { return nil }

        let heightMeters = heightCm / 100
        guard heightMeters > 0 else { return nil }

        let bmiValue = weightKg / (heightMeters * heightMeters)

        if bmiValue < 18.5 {
            return BMISnapshot(
                value: bmiValue,
                category: "Bajo peso",
                tint: AppPalette.Body.c500
            )
        } else if bmiValue < 25 {
            return BMISnapshot(
                value: bmiValue,
                category: "Peso normal",
                tint: Color(red: 0.09, green: 0.61, blue: 0.37)
            )
        } else if bmiValue < 30 {
            return BMISnapshot(
                value: bmiValue,
                category: "Sobrepeso",
                tint: Color(red: 0.95, green: 0.58, blue: 0.20)
            )
        } else if bmiValue < 35 {
            return BMISnapshot(
                value: bmiValue,
                category: "Obesidad grado I",
                tint: Color(red: 0.90, green: 0.45, blue: 0.18)
            )
        } else if bmiValue < 40 {
            return BMISnapshot(
                value: bmiValue,
                category: "Obesidad grado II",
                tint: Color(red: 0.90, green: 0.20, blue: 0.22)
            )
        } else {
            return BMISnapshot(
                value: bmiValue,
                category: "Obesidad grado III",
                tint: Color(red: 0.62, green: 0.13, blue: 0.18)
            )
        }
    }
}

struct BodyMeasurementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurementEntry.date, order: .reverse) private var entries: [BodyMeasurementEntry]
    @AppStorage("body.height.cm") private var configuredHeightStorage: Double = 0

    @State private var selectedMetric: BodyMetric = .weight
    @State private var showingAddSheet = false
    @State private var showingHeightSetupSheet = false
    @State private var editTarget: BodyMeasurementEditTarget?
    @State private var cachedChartPoints: [BodyChartPoint] = []
    @State private var chartRefreshTask: Task<Void, Never>?

    private var chartRefreshSignature: Int {
        var hasher = Hasher()
        hasher.combine(selectedMetric.rawValue)
        hasher.combine(entries.count)
        hasher.combine(entries.first?.id)
        hasher.combine(entries.first?.date.timeIntervalSinceReferenceDate)
        hasher.combine(entries.last?.id)
        hasher.combine(entries.last?.date.timeIntervalSinceReferenceDate)
        return hasher.finalize()
    }

    private var latestEntry: BodyMeasurementEntry? {
        entries.first
    }

    private var oldestEntry: BodyMeasurementEntry? {
        entries.last
    }

    private var weightDeltaSinceStart: Double? {
        guard let latest = latestEntry?.weightKg, let oldest = oldestEntry?.weightKg else { return nil }
        return latest - oldest
    }

    private var configuredHeightCm: Double? {
        configuredHeightStorage > 0 ? configuredHeightStorage : nil
    }

    private var chartPoints: [BodyChartPoint] { cachedChartPoints }

    var body: some View {
        NavigationStack {
            ZStack {
                BodyMeasurementsBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        BodyMeasurementsSummaryCard(
                            latestEntry: latestEntry,
                            totalEntries: entries.count,
                            weightDeltaSinceStart: weightDeltaSinceStart
                        )

                        HStack {
                            Text("Registros")
                                .font(.title3.weight(.bold))
                                .fontDesign(.rounded)
                                .foregroundStyle(Color.appTextPrimary)

                            Spacer()

                            HStack(spacing: 8) {
                                Button {
                                    showingHeightSetupSheet = true
                                } label: {
                                    Label("Estatura", systemImage: "ruler")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .tint(AppPalette.Body.c600)

                                Button {
                                    showingAddSheet = true
                                } label: {
                                    Label("Nuevo", systemImage: "plus")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppPalette.Body.c600)
                            }
                        }

                        if entries.isEmpty {
                            BodyMeasurementsEmptyStateCard {
                                showingAddSheet = true
                            }
                        } else {
                            BodyMeasurementsChartCard(
                                selectedMetric: $selectedMetric,
                                points: chartPoints
                            )

                            LazyVStack(spacing: 10) {
                                ForEach(entries, id: \.id) { entry in
                                    BodyMeasurementRow(
                                        entry: entry,
                                        configuredHeightCm: configuredHeightCm
                                    ) {
                                        editTarget = BodyMeasurementEditTarget(id: entry.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Medidas")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingHeightSetupSheet) {
                BodyHeightSetupView(heightCm: $configuredHeightStorage)
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBodyMeasurementView(
                    fixedHeightCm: configuredHeightCm
                ) { payload in
                    createEntry(payload)
                }
            }
            .sheet(item: $editTarget) { target in
                if let selectedEntryForEditing = entries.first(where: { $0.id == target.id }) {
                    AddBodyMeasurementView(
                        initialEntry: selectedEntryForEditing,
                        fixedHeightCm: configuredHeightCm
                    ) { payload in
                        updateEntry(selectedEntryForEditing, payload: payload)
                    } onDelete: {
                        delete(selectedEntryForEditing)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Registro no disponible",
                            systemImage: "ruler",
                            description: Text("Este registro ya no existe.")
                        )
                    }
                }
            }
            .onAppear {
                scheduleChartRefresh(immediate: true)
            }
            .onChange(of: chartRefreshSignature) { _, _ in
                scheduleChartRefresh()
            }
            .onDisappear {
                chartRefreshTask?.cancel()
                chartRefreshTask = nil
            }
        }
    }

    private func scheduleChartRefresh(immediate: Bool = false) {
        chartRefreshTask?.cancel()
        chartRefreshTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(120))
            }
            guard !Task.isCancelled else { return }
            recomputeChartPoints()
        }
    }

    private func recomputeChartPoints() {
        let interval = Observability.bodySignposter.beginInterval("body.chartPoints.recompute")
        defer { Observability.bodySignposter.endInterval("body.chartPoints.recompute", interval) }
        cachedChartPoints = entries
            .compactMap { entry in
                guard let value = selectedMetric.value(for: entry) else { return nil }
                return BodyChartPoint(id: entry.id, date: entry.date, value: value)
            }
            .sorted { $0.date < $1.date }
        Observability.debug(
            Observability.bodyLogger,
            "Chart points recomputed. metric: \(selectedMetric.rawValue), points: \(cachedChartPoints.count)"
        )
    }

    private func createEntry(_ payload: BodyMeasurementPayload) {
        let entry = BodyMeasurementEntry(
            date: payload.date,
            weightKg: payload.weightKg,
            heightCm: configuredHeightCm,
            bodyFatPercent: payload.bodyFatPercent,
            waistCm: payload.waistCm,
            hipCm: payload.hipCm,
            chestCm: payload.chestCm,
            armCm: payload.armCm,
            thighCm: payload.thighCm,
            note: payload.note
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(entry)
        }
    }

    private func updateEntry(_ entry: BodyMeasurementEntry, payload: BodyMeasurementPayload) {
        withAnimation(.easeInOut(duration: 0.2)) {
            entry.date = payload.date
            entry.weightKg = payload.weightKg
            if let configuredHeightCm {
                entry.heightCm = configuredHeightCm
            }
            entry.bodyFatPercent = payload.bodyFatPercent
            entry.waistCm = payload.waistCm
            entry.hipCm = payload.hipCm
            entry.chestCm = payload.chestCm
            entry.armCm = payload.armCm
            entry.thighCm = payload.thighCm
            entry.note = payload.note
        }
    }

    private func delete(_ entry: BodyMeasurementEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(entry)
        }
    }
}

private struct BodyMeasurementsBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .body)
    }
}

private struct BodyMeasurementsSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let latestEntry: BodyMeasurementEntry?
    let totalEntries: Int
    let weightDeltaSinceStart: Double?

    private var latestWeightText: String {
        guard let latestWeight = latestEntry?.weightKg else { return "--" }
        return "\(format(latestWeight)) kg"
    }

    private var dateText: String {
        guard let latestDate = latestEntry?.date else { return "Sin registros" }
        return latestDate.formatted(.dateTime.locale(Locale(identifier: "es_MX")).day().month(.wide).year())
    }

    private var deltaText: String {
        guard let weightDeltaSinceStart else { return "--" }
        let prefix = weightDeltaSinceStart > 0 ? "+" : ""
        return "\(prefix)\(format(weightDeltaSinceStart)) kg"
    }

    private var deltaTint: Color {
        guard let weightDeltaSinceStart else {
            return Color.white.opacity(colorScheme == .dark ? 0.86 : 0.94)
        }
        if weightDeltaSinceStart > 0 {
            return Color(red: 0.95, green: 0.74, blue: 0.66)
        }
        if weightDeltaSinceStart < 0 {
            return Color(red: 0.71, green: 0.94, blue: 0.80)
        }
        return Color.white
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.Body.c900, AppPalette.Body.c700]
        }
        return [AppPalette.Body.c600, AppPalette.Body.c400]
    }

    private var strokeColor: Color {
        .white.opacity(colorScheme == .dark ? 0.18 : 0.28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seguimiento corporal")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            Text(latestWeightText)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(dateText.capitalized)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.90))

            HStack(spacing: 8) {
                BodyMeasurementsPill(title: "Registros", value: "\(totalEntries)")
                BodyMeasurementsPill(title: "Cambio", value: deltaText, valueColor: deltaTint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct BodyMeasurementsPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.82 : 0.92))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            .white.opacity(colorScheme == .dark ? 0.17 : 0.24),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct BodyMeasurementsChartCard: View {
    @Binding var selectedMetric: BodyMetric
    let points: [BodyChartPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Metrica", selection: $selectedMetric) {
                ForEach(BodyMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("Fecha", point.date),
                        y: .value(selectedMetric.title, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(selectedMetric.tint)

                    PointMark(
                        x: .value("Fecha", point.date),
                        y: .value(selectedMetric.title, point.value)
                    )
                    .symbolSize(42)
                    .foregroundStyle(selectedMetric.tint)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6))
                            .foregroundStyle(Color.appAxis)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.locale(Locale(identifier: "es_MX")).day().month(.abbreviated)))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYScale(domain: chartYDomain)
                .frame(height: 190)
            } else if let point = points.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aun no hay suficiente historial para grafica.")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                    Text("Actual: \(point.value.formatted(.number.precision(.fractionLength(0...1)))) \(selectedMetric.unit)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 120)
            } else {
                Text("Esta metrica no tiene datos aun.")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 120)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }

    private var chartYDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else { return 0...1 }
        if abs(maxValue - minValue) < 0.001 {
            let padding = max(maxValue * 0.05, 1)
            return (minValue - padding)...(maxValue + padding)
        }
        let padding = max((maxValue - minValue) * 0.12, 0.6)
        return (minValue - padding)...(maxValue + padding)
    }
}

private struct BodyMeasurementsEmptyStateCard: View {
    let onAddTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin registros todavia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Agrega tus medidas para ver como cambian con el tiempo.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Agregar medida") {
                onAddTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.Body.c600)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct BodyMeasurementRow: View {
    let entry: BodyMeasurementEntry
    let configuredHeightCm: Double?
    let onTap: () -> Void

    private var bmiSnapshot: BMISnapshot? {
        let effectiveHeightCm = configuredHeightCm ?? entry.heightCm
        return BMICalculator.snapshot(weightKg: entry.weightKg, heightCm: effectiveHeightCm)
    }

    private var dateText: String {
        entry.date.formatted(
            .dateTime
                .locale(Locale(identifier: "es_MX"))
                .weekday(.abbreviated)
                .day()
                .month(.abbreviated)
                .year()
        ).capitalized
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dateText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)

                    HStack(spacing: 6) {
                        metricBadge(title: "Peso", value: entry.weightKg, unit: "kg", tint: BodyMetric.weight.tint)
                        metricBadge(title: "Cintura", value: entry.waistCm, unit: "cm", tint: BodyMetric.waist.tint)
                        metricBadge(title: "% Grasa", value: entry.bodyFatPercent, unit: "%", tint: BodyMetric.bodyFat.tint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let bmiSnapshot {
                        Text("IMC \(bmiSnapshot.value.formatted(.number.precision(.fractionLength(1)))) · \(bmiSnapshot.category)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(bmiSnapshot.tint)
                    }

                    if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.note)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color.appField,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.appStrokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metricBadge(title: String, value: Double?, unit: String, tint: Color) -> some View {
        if let value {
            Text("\(title): \(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.14), in: Capsule())
        }
    }
}

private struct BodyMeasurementPayload {
    let date: Date
    let weightKg: Double?
    let bodyFatPercent: Double?
    let waistCm: Double?
    let hipCm: Double?
    let chestCm: Double?
    let armCm: Double?
    let thighCm: Double?
    let note: String
}

private struct AddBodyMeasurementView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var weightText: String
    @State private var bodyFatText: String
    @State private var waistText: String
    @State private var hipText: String
    @State private var chestText: String
    @State private var armText: String
    @State private var thighText: String
    @State private var note: String
    @State private var showingDeleteAlert = false
    @State private var showingDateTimeSheet = false

    private let isEditing: Bool
    private let fixedHeightCm: Double?
    private let fallbackHeightCm: Double?
    let onSave: (BodyMeasurementPayload) -> Void
    let onDelete: (() -> Void)?

    private var payload: BodyMeasurementPayload {
        BodyMeasurementPayload(
            date: date,
            weightKg: parseDecimal(weightText),
            bodyFatPercent: parseDecimal(bodyFatText),
            waistCm: parseDecimal(waistText),
            hipCm: parseDecimal(hipText),
            chestCm: parseDecimal(chestText),
            armCm: parseDecimal(armText),
            thighCm: parseDecimal(thighText),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var canSave: Bool {
        payload.weightKg != nil ||
        payload.bodyFatPercent != nil ||
        payload.waistCm != nil ||
        payload.hipCm != nil ||
        payload.chestCm != nil ||
        payload.armCm != nil ||
        payload.thighCm != nil
    }

    private var effectiveHeightCm: Double? {
        fixedHeightCm ?? fallbackHeightCm
    }

    private var bmiPreviewSnapshot: BMISnapshot? {
        BMICalculator.snapshot(weightKg: payload.weightKg, heightCm: effectiveHeightCm)
    }

    private var dateSummaryText: String {
        AppDateFormatters.esMXShortDate.string(from: date).capitalized
    }

    private var timeSummaryText: String {
        AppDateFormatters.esMXTime12h.string(from: date).lowercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BodyMeasurementsBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            BodyMeasurementsInputLabel(title: "Fecha y hora", systemImage: "calendar")

                            Button {
                                showingDateTimeSheet = true
                            } label: {
                                HStack(spacing: 12) {
                                    HStack(spacing: 0) {
                                        Text(dateSummaryText)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appTextPrimary)
                                        Text(" / ")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appTextSecondary)
                                        Text(timeSummaryText)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appTextSecondary)
                                    }
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.86)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppPalette.Body.c600.opacity(0.24), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            BodyMeasurementsInputLabel(title: "Peso (kg)", systemImage: "scalemass")
                            TextField("", text: $weightText)
                                .keyboardType(.decimalPad)
                                .bodyMeasurementsInputField()

                            if let fixedHeightCm {
                                HStack(spacing: 8) {
                                    Label("Estatura", systemImage: "ruler")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.appTextSecondary)
                                    Spacer()
                                    Text("\(fixedHeightCm.formatted(.number.precision(.fractionLength(0...1)))) cm")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appTextPrimary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppPalette.Body.c600.opacity(0.24), lineWidth: 1)
                                )
                            } else {
                                Text("Configura tu estatura una sola vez desde el boton Estatura en la pantalla Medidas para calcular IMC.")
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        Color.appField,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(AppPalette.Body.c600.opacity(0.24), lineWidth: 1)
                                    )
                            }

                            if let bmiPreviewSnapshot {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Indice de masa corporal (IMC)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.appTextSecondary)

                                    HStack {
                                        Text("IMC \(bmiPreviewSnapshot.value.formatted(.number.precision(.fractionLength(1))))")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(Color.appTextPrimary)

                                        Spacer(minLength: 8)

                                        Text(bmiPreviewSnapshot.category)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(bmiPreviewSnapshot.tint)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 6)
                                            .background(bmiPreviewSnapshot.tint.opacity(0.15), in: Capsule())
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppPalette.Body.c600.opacity(0.24), lineWidth: 1)
                                )
                            }

                            BodyMeasurementsInputLabel(title: "Grasa corporal (%)", systemImage: "percent")
                            TextField("", text: $bodyFatText)
                                .keyboardType(.decimalPad)
                                .bodyMeasurementsInputField()

                            BodyMeasurementsInputLabel(title: "Cintura (cm)", systemImage: "ruler")
                            TextField("", text: $waistText)
                                .keyboardType(.decimalPad)
                                .bodyMeasurementsInputField()

                            BodyMeasurementsInputLabel(title: "Cadera (cm)", systemImage: "figure.walk")
                            TextField("", text: $hipText)
                                .keyboardType(.decimalPad)
                                .bodyMeasurementsInputField()

                            BodyMeasurementsInputLabel(title: "Pecho (cm)", systemImage: "figure.strengthtraining.traditional")
                            TextField("", text: $chestText)
                                .keyboardType(.decimalPad)
                                .bodyMeasurementsInputField()

                            BodyMeasurementsInputLabel(title: "Brazo (cm)", systemImage: "figure.arms.open")
                            TextField("", text: $armText)
                                .keyboardType(.decimalPad)
                                .bodyMeasurementsInputField()

                            BodyMeasurementsInputLabel(title: "Muslo (cm)", systemImage: "figure.run")
                            TextField("", text: $thighText)
                                .keyboardType(.decimalPad)
                                .bodyMeasurementsInputField()

                            BodyMeasurementsInputLabel(title: "Nota (opcional)", systemImage: "note.text")
                            TextField("", text: $note, axis: .vertical)
                                .lineLimit(2...4)
                                .bodyMeasurementsInputField(minHeight: 72)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appStrokeSoft, lineWidth: 1)
                        )

                        if isEditing, onDelete != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Eliminar registro")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.62, green: 0.13, blue: 0.18))

                                Button(role: .destructive) {
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Eliminar registro", systemImage: "trash.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 0.90, green: 0.20, blue: 0.22))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color(red: 1.00, green: 0.94, blue: 0.95),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(red: 0.90, green: 0.20, blue: 0.22).opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(isEditing ? "Editar medida" : "Nueva medida")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.Body.c600)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Actualizar" : "Guardar") {
                        onSave(payload)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingDateTimeSheet) {
                BodyMeasurementsDateTimePickerSheet(date: $date)
            }
            .alert("Eliminar registro", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Este registro se eliminara de tu historial.")
            }
        }
    }

    init(
        initialEntry: BodyMeasurementEntry? = nil,
        fixedHeightCm: Double? = nil,
        onSave: @escaping (BodyMeasurementPayload) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.isEditing = initialEntry != nil
        self.fixedHeightCm = fixedHeightCm
        self.fallbackHeightCm = initialEntry?.heightCm

        _date = State(initialValue: initialEntry?.date ?? .now)
        _weightText = State(initialValue: Self.initialText(from: initialEntry?.weightKg))
        _bodyFatText = State(initialValue: Self.initialText(from: initialEntry?.bodyFatPercent))
        _waistText = State(initialValue: Self.initialText(from: initialEntry?.waistCm))
        _hipText = State(initialValue: Self.initialText(from: initialEntry?.hipCm))
        _chestText = State(initialValue: Self.initialText(from: initialEntry?.chestCm))
        _armText = State(initialValue: Self.initialText(from: initialEntry?.armCm))
        _thighText = State(initialValue: Self.initialText(from: initialEntry?.thighCm))
        _note = State(initialValue: initialEntry?.note ?? "")
    }

    private func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else { return nil }
        return value
    }

    private static func initialText(from value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct BodyHeightSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var heightCm: Double

    @State private var heightText: String

    private var parsedHeightCm: Double? {
        let trimmed = heightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private var canSave: Bool {
        parsedHeightCm != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BodyMeasurementsBackgroundView()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        BodyMeasurementsInputLabel(title: "Estatura", systemImage: "ruler")

                        TextField("", text: $heightText)
                            .keyboardType(.decimalPad)
                            .bodyMeasurementsInputField()

                        Text("Este valor se usara para calcular tu IMC en todos los registros.")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.appStrokeSoft, lineWidth: 1)
                    )

                    if heightCm > 0 {
                        Button(role: .destructive) {
                            heightCm = 0
                            dismiss()
                        } label: {
                            Label("Quitar estatura guardada", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.90, green: 0.20, blue: 0.22))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle("Estatura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guard let parsedHeightCm else { return }
                        heightCm = parsedHeightCm
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    init(heightCm: Binding<Double>) {
        _heightCm = heightCm
        if heightCm.wrappedValue > 0 {
            _heightText = State(
                initialValue: heightCm.wrappedValue.formatted(
                    .number.precision(.fractionLength(0...1))
                )
            )
        } else {
            _heightText = State(initialValue: "")
        }
    }
}

private struct BodyMeasurementsDateTimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date
    @State private var selectedDetent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            ZStack {
                BodyMeasurementsBackgroundView()
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fecha")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                        DatePicker(
                            "",
                            selection: $date,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                        Divider()
                            .overlay(AppPalette.Body.c600.opacity(0.20))

                        Text("Hora")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                        DatePicker(
                            "",
                            selection: $date,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "es_MX"))
                        .frame(width: 220, height: 170)
                        .clipped()
                        .frame(maxWidth: .infinity)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.appStrokeSoft, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle("Fecha y hora")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }
}

private struct BodyMeasurementsInputLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.appTextSecondary)
    }
}

private extension View {
    func bodyMeasurementsInputField(minHeight: CGFloat = 0) -> some View {
        self
            .foregroundStyle(Color.appTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background(
                Color.appField,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.Body.c600.opacity(0.24), lineWidth: 1)
            )
    }
}
