import Foundation
import Observation

@MainActor
@Observable
final class MarketService {
    private(set) var quotes: [MarketQuote] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func refresh(items: [MarketItem], force: Bool = false) async {
        guard !items.isEmpty else { quotes = []; return }
        if !force,
           quotes.count == items.count,
           let fetchedAt = quotes.first?.fetchedAt,
           MarketCachePolicy.isValid(fetchedAt: fetchedAt) { return }
        isLoading = true
        defer { isLoading = false }
        var values: [MarketQuote] = []
        var failed = false
        for item in items {
            do {
                values.append(try await quote(for: item))
            } catch {
                failed = true
            }
        }
        if !values.isEmpty { quotes = values }
        errorMessage = failed ? "Some market quotes could not be refreshed." : nil
    }

    private func quote(for item: MarketItem) async throws -> MarketQuote {
        switch item {
        case let .currency(base, quote):
            let from = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            let url = URL(string: "https://api.frankfurter.dev/v2/rates?base=\(base.uppercased())&quotes=\(quote.uppercased())&from=\(formatter.string(from: from))")!
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
            let rates = try JSONDecoder().decode([FrankfurterRate].self, from: data).sorted { $0.date < $1.date }
            guard let latest = rates.last else { throw URLError(.cannotParseResponse) }
            return MarketQuote(item: item, displayName: nil, value: latest.rate, currencyCode: quote.uppercased(), previousClose: rates.dropLast().last?.rate, fetchedAt: Date(), isDelayed: true)
        case let .stock(symbol):
            for candidate in Self.stockSymbolCandidates(symbol) {
                do {
                    let encoded = candidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? candidate
                    let url = URL(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(encoded)?range=1d&interval=1m")!
                    var request = URLRequest(url: url)
                    request.setValue("Mozilla/5.0 Dynamic-Nook/1.0", forHTTPHeaderField: "User-Agent")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { continue }
                    let chart = try JSONDecoder().decode(YahooChart.self, from: data)
                    guard let result = chart.chart.result.first, let value = result.meta.regularMarketPrice else { continue }
                    let name = await stockName(for: candidate) ?? result.meta.longName ?? result.meta.shortName
                    return MarketQuote(item: item, displayName: name, value: value, currencyCode: result.meta.currency, previousClose: result.meta.chartPreviousClose, fetchedAt: Date(), isDelayed: true)
                } catch { continue }
            }
            throw URLError(.cannotParseResponse)
        }
    }

    nonisolated static func stockSymbolCandidates(_ symbol: String) -> [String] {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.range(of: "^[0-9]{6}$", options: .regularExpression) != nil {
            return ["\(trimmed).KS", "\(trimmed).KQ"]
        }
        return [trimmed]
    }

    private func stockName(for symbol: String) async -> String? {
        var components = URLComponents(string: "https://query2.finance.yahoo.com/v1/finance/search")!
        let korean = symbol.hasSuffix(".KS") || symbol.hasSuffix(".KQ") || Locale.current.language.languageCode?.identifier == "ko"
        components.queryItems = [
            URLQueryItem(name: "q", value: symbol),
            URLQueryItem(name: "quotesCount", value: "5"),
            URLQueryItem(name: "newsCount", value: "0"),
            URLQueryItem(name: "lang", value: korean ? "ko-KR" : "en-US"),
            URLQueryItem(name: "region", value: korean ? "KR" : "US")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 Dynamic-Nook/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
              let result = try? JSONDecoder().decode(YahooSearch.self, from: data) else { return nil }
        let quote = result.quotes.first { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }
        return quote?.longName ?? quote?.shortName
    }
}

private struct FrankfurterRate: Decodable { let date: String; let rate: Double }

private struct YahooChart: Decodable {
    struct Chart: Decodable {
        struct Result: Decodable {
            struct Meta: Decodable {
                let regularMarketPrice: Double?
                let chartPreviousClose: Double?
                let currency: String?
                let shortName: String?
                let longName: String?
            }
            let meta: Meta
        }
        let result: [Result]
    }
    let chart: Chart
}

private struct YahooSearch: Decodable {
    struct Quote: Decodable {
        let symbol: String
        let shortName: String?
        let longName: String?

        enum CodingKeys: String, CodingKey {
            case symbol
            case shortName = "shortname"
            case longName = "longname"
        }
    }
    let quotes: [Quote]
}
