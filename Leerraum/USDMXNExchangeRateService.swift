import Foundation
import SwiftUI
import Combine

struct USDMXNRateSnapshot: Codable, Equatable {
    let rate: Double
    let fetchedAt: Date
    let source: String
}

enum USDMXNRateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingRate
    case missingBanxicoToken
    case invalidBanxicoToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL del proveedor no es valida."
        case .invalidResponse:
            return "El proveedor regreso una respuesta no valida."
        case .missingRate:
            return "No se encontro la tasa USD/MXN en la respuesta."
        case .missingBanxicoToken:
            return "Falta el token de Banxico en Ajustes."
        case .invalidBanxicoToken:
            return "Token Banxico invalido o sin permisos."
        }
    }
}

@MainActor
final class USDMXNExchangeRateService {
    static let shared = USDMXNExchangeRateService()

    private enum CacheKey {
        static let rate = "finance.exchange.usd_mxn.rate"
        static let fetchedAt = "finance.exchange.usd_mxn.fetched_at"
        static let source = "finance.exchange.usd_mxn.source"
    }

    private struct OpenERResponse: Decodable {
        let rates: [String: Double]
        let timeLastUpdateUTC: String?

        enum CodingKeys: String, CodingKey {
            case rates
            case timeLastUpdateUTC = "time_last_update_utc"
        }
    }

    private struct FrankfurterResponse: Decodable {
        let rates: [String: Double]
        let date: String
    }

    private struct BanxicoResponse: Decodable {
        let bmx: BanxicoEnvelope

        struct BanxicoEnvelope: Decodable {
            let series: [BanxicoSeries]
        }

        struct BanxicoSeries: Decodable {
            let datos: [BanxicoDato]
        }

        struct BanxicoDato: Decodable {
            let fecha: String
            let dato: String
        }
    }

    private let session: URLSession
    private let defaults: UserDefaults
    private let decoder = JSONDecoder()

    private let rfc1123Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()

    private let yyyyMMddFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let banxicoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        self.defaults = defaults
    }

    func cachedSnapshot() -> USDMXNRateSnapshot? {
        let rate = defaults.double(forKey: CacheKey.rate)
        let fetchedAtInterval = defaults.double(forKey: CacheKey.fetchedAt)
        guard rate > 0, fetchedAtInterval > 0 else { return nil }

        let source = defaults.string(forKey: CacheKey.source) ?? "cache"
        return USDMXNRateSnapshot(
            rate: rate,
            fetchedAt: Date(timeIntervalSince1970: fetchedAtInterval),
            source: source
        )
    }

    func fetchLatestRate() async throws -> USDMXNRateSnapshot {
        let preference = exchangeProviderPreference()

        switch preference {
        case .banxico:
            let snapshot = try await fetchFromBanxico()
            save(snapshot)
            return snapshot
        case .openERAPI:
            let snapshot = try await fetchFromOpenERAPI()
            save(snapshot)
            return snapshot
        case .frankfurter:
            let snapshot = try await fetchFromFrankfurter()
            save(snapshot)
            return snapshot
        case .automatic:
            if banxicoToken() != nil {
                do {
                    let snapshot = try await fetchFromBanxico()
                    save(snapshot)
                    return snapshot
                } catch {
                    Observability.debug(
                        Observability.financeLogger,
                        "banxico failed in automatic mode. Fallback to open.er-api: \(error.localizedDescription)"
                    )
                }
            }

            do {
                let snapshot = try await fetchFromOpenERAPI()
                save(snapshot)
                return snapshot
            } catch {
                Observability.debug(
                    Observability.financeLogger,
                    "open.er-api failed. Falling back to frankfurter: \(error.localizedDescription)"
                )
                let snapshot = try await fetchFromFrankfurter()
                save(snapshot)
                return snapshot
            }
        }
    }

    private func fetchFromOpenERAPI() async throws -> USDMXNRateSnapshot {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            throw USDMXNRateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDMXNRateError.invalidResponse
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw USDMXNRateError.invalidBanxicoToken
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw USDMXNRateError.invalidResponse
        }

        let payload = try decoder.decode(OpenERResponse.self, from: data)
        guard let rate = payload.rates["MXN"], rate > 0 else {
            throw USDMXNRateError.missingRate
        }

        let fetchedAt = payload.timeLastUpdateUTC.flatMap(rfc1123Formatter.date(from:)) ?? .now
        return USDMXNRateSnapshot(rate: rate, fetchedAt: fetchedAt, source: "open.er-api")
    }

    private func fetchFromFrankfurter() async throws -> USDMXNRateSnapshot {
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=USD&to=MXN") else {
            throw USDMXNRateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw USDMXNRateError.invalidResponse
        }

        let payload = try decoder.decode(FrankfurterResponse.self, from: data)
        guard let rate = payload.rates["MXN"], rate > 0 else {
            throw USDMXNRateError.missingRate
        }

        let baseDate = yyyyMMddFormatter.date(from: payload.date) ?? .now
        let fetchedAt = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: baseDate) ?? baseDate

        return USDMXNRateSnapshot(rate: rate, fetchedAt: fetchedAt, source: "frankfurter")
    }

    private func fetchFromBanxico() async throws -> USDMXNRateSnapshot {
        guard let token = banxicoToken() else {
            throw USDMXNRateError.missingBanxicoToken
        }

        guard let url = URL(string: "https://www.banxico.org.mx/SieAPIRest/service/v1/series/SF43718/datos/oportuno") else {
            throw USDMXNRateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(token, forHTTPHeaderField: "Bmx-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw USDMXNRateError.invalidResponse
        }

        let payload = try decoder.decode(BanxicoResponse.self, from: data)
        guard
            let series = payload.bmx.series.first,
            let latest = series.datos.first
        else {
            throw USDMXNRateError.missingRate
        }

        guard let rate = parseBanxicoRate(latest.dato), rate > 0 else {
            throw USDMXNRateError.missingRate
        }

        let fetchedAt = parseBanxicoDate(latest.fecha) ?? .now
        return USDMXNRateSnapshot(rate: rate, fetchedAt: fetchedAt, source: "banxico")
    }

    private func parseBanxicoRate(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = Double(trimmed) {
            return direct
        }

        let commaAsThousands = trimmed.replacingOccurrences(of: ",", with: "")
        if let parsed = Double(commaAsThousands) {
            return parsed
        }

        let commaAsDecimal = trimmed
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(commaAsDecimal)
    }

    private func parseBanxicoDate(_ raw: String) -> Date? {
        banxicoDateFormatter.date(from: raw)
    }

    private func exchangeProviderPreference() -> ExchangeRateProviderPreference {
        let rawValue = defaults.string(forKey: AppStorageKey.exchangeRateProvider) ?? ""
        return ExchangeRateProviderPreference(rawValue: rawValue) ?? .automatic
    }

    private func banxicoToken() -> String? {
        guard let token = defaults.string(forKey: AppStorageKey.banxicoToken)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return nil }
        return token
    }

    private func save(_ snapshot: USDMXNRateSnapshot) {
        defaults.set(snapshot.rate, forKey: CacheKey.rate)
        defaults.set(snapshot.fetchedAt.timeIntervalSince1970, forKey: CacheKey.fetchedAt)
        defaults.set(snapshot.source, forKey: CacheKey.source)
    }
}

@MainActor
final class USDMXNExchangeRateViewModel: ObservableObject {
    @Published private(set) var snapshot: USDMXNRateSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: USDMXNExchangeRateService
    private var refreshTask: Task<Void, Never>?

    init(service: USDMXNExchangeRateService? = nil) {
        self.service = service ?? .shared
        self.snapshot = self.service.cachedSnapshot()
    }

    var effectiveRate: Double {
        snapshot?.rate ?? 17.0
    }

    var lastUpdated: Date? {
        snapshot?.fetchedAt
    }

    var sourceName: String {
        snapshot?.source ?? "sin fuente"
    }

    func refreshIfNeeded(maxAge: TimeInterval = 30 * 60) {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < maxAge {
            return
        }
        refresh(force: false)
    }

    func refresh(force: Bool) {
        if isLoading {
            return
        }

        if !force, let lastUpdated, Date().timeIntervalSince(lastUpdated) < 60 {
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            self.errorMessage = nil

            do {
                let latestSnapshot = try await self.service.fetchLatestRate()
                guard !Task.isCancelled else { return }
                self.snapshot = latestSnapshot
                Observability.debug(
                    Observability.financeLogger,
                    "USD/MXN updated: \(latestSnapshot.rate) from \(latestSnapshot.source)"
                )
            } catch {
                guard !Task.isCancelled else { return }
                if let rateError = error as? USDMXNRateError {
                    self.errorMessage = rateError.localizedDescription
                } else {
                    self.errorMessage = "No se pudo actualizar el dolar. Se mantiene el ultimo valor guardado."
                }
                Observability.debug(
                    Observability.financeLogger,
                    "USD/MXN update failed: \(error.localizedDescription)"
                )
            }

            self.isLoading = false
        }
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
