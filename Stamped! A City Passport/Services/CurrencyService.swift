import Foundation

/// Simple protocol for fetching currency rates. Implementations should read the API key from
/// environment variables or Info.plist (do not hardcode keys in source).
protocol CurrencyFetching {
    /// Fetch latest rates. Returns rates and the date they were fetched.
    func fetchLatestRates() async throws -> ([String: Double], Date)
    /// Load cached rates (if any)
    func loadCachedRates() -> ([String: Double], Date?)
}

struct CurrencyServiceError: Error {}

final class DefaultCurrencyService: CurrencyFetching {
    private let cachedKey = "cached_currency_rates"
    private let cachedDateKey = "currency_rates_date"

    private var apiBaseURLString: String? {
        if let env = ProcessInfo.processInfo.environment["CURRENCY_API_BASE_URL"], !env.isEmpty {
            return env
        }
        if let info = Bundle.main.object(forInfoDictionaryKey: "CURRENCY_API_BASE_URL") as? String, !info.isEmpty {
            return info
        }
        return nil
    }

    private var apiKeyString: String? {
        if let env = ProcessInfo.processInfo.environment["CURRENCY_API_KEY"], !env.isEmpty {
            return env
        }
        if let info = Bundle.main.object(forInfoDictionaryKey: "CURRENCY_API_KEY") as? String, !info.isEmpty {
            return info
        }
        return nil
    }

    private func makeRatesURL() -> URL? {
        // If a full base URL is provided, use it; else fall back to exchangerate-api.com default
        if let base = apiBaseURLString, var comps = URLComponents(string: base) {
            if let key = apiKeyString, !key.isEmpty {
                var items = comps.queryItems ?? []
                if !items.contains(where: { $0.name.lowercased() == "apikey" }) {
                    items.append(URLQueryItem(name: "apikey", value: key))
                    comps.queryItems = items
                }
            }
            return comps.url
        }
        // fallback default (no key)
        let defaultURLString = "https://api.exchangerate-api.com/v4/latest/USD"
        if let key = apiKeyString, !key.isEmpty, var comps = URLComponents(string: defaultURLString) {
            var items = comps.queryItems ?? []
            items.append(URLQueryItem(name: "apikey", value: key))
            comps.queryItems = items
            return comps.url
        }
        return URL(string: defaultURLString)
    }

    func fetchLatestRates() async throws -> ([String: Double], Date) {
        guard let url = makeRatesURL() else { throw CurrencyServiceError() }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()

        // API shape: { "rates": {"USD":1.0, ... } }
        struct Response: Codable { let rates: [String: Double] }
        let response = try decoder.decode(Response.self, from: data)

        // Cache
        if let encoded = try? JSONEncoder().encode(response.rates) {
            UserDefaults.standard.set(encoded, forKey: cachedKey)
            UserDefaults.standard.set(Date(), forKey: cachedDateKey)
        }

        return (response.rates, Date())
    }

    func loadCachedRates() -> ([String: Double], Date?) {
        if let data = UserDefaults.standard.data(forKey: cachedKey) {
            if let rates = try? JSONDecoder().decode([String: Double].self, from: data) {
                let date = UserDefaults.standard.object(forKey: cachedDateKey) as? Date
                return (rates, date)
            }
        }
        return ([:], nil)
    }
}
