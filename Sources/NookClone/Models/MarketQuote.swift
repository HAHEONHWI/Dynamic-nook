import Foundation

enum MarketItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    case currency(base: String, quote: String)
    case stock(symbol: String)

    var id: String {
        switch self {
        case let .currency(base, quote): "fx:\(base.uppercased())-\(quote.uppercased())"
        case let .stock(symbol): "stock:\(symbol.uppercased())"
        }
    }

    var title: String {
        switch self {
        case let .currency(base, quote): "\(base.uppercased())/\(quote.uppercased())"
        case let .stock(symbol): symbol.uppercased()
        }
    }

    var storageValue: String { id }

    init?(storageValue: String) {
        let components = storageValue.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return nil }
        switch components[0] {
        case "fx":
            let pair = components[1].split(separator: "-", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { return nil }
            self = .currency(base: pair[0], quote: pair[1])
        case "stock": self = .stock(symbol: components[1])
        default: return nil
        }
    }
}

struct MarketQuote: Identifiable, Equatable, Sendable {
    let item: MarketItem
    let displayName: String?
    let value: Double
    let currencyCode: String?
    let previousClose: Double?
    let fetchedAt: Date
    let isDelayed: Bool

    var id: String { item.id }

    var primaryLabel: String {
        guard let displayName, !displayName.isEmpty else { return item.title }
        return displayName
    }
    var secondaryLabel: String? {
        guard case .stock = item, primaryLabel != item.title else { return nil }
        return item.title
    }

    var change: Double? { previousClose.map { value - $0 } }
    var changePercent: Double? {
        guard let previousClose, previousClose != 0 else { return nil }
        return (value - previousClose) / previousClose * 100
    }
}

enum MarketCachePolicy {
    static let lifetime: TimeInterval = 15 * 60

    static func isValid(fetchedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) >= 0 && now.timeIntervalSince(fetchedAt) < lifetime
    }
}
