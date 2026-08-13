import Foundation

struct NetworkSnapshot: Equatable, Sendable {
    let ssid: String?
    let downloadMbps: Double?
    let uploadMbps: Double?
    let publicIP: String?
    let isVPNConnected: Bool
    let fetchedAt: Date
}

enum NetworkCachePolicy {
    static let lifetime: TimeInterval = 60

    static func isValid(fetchedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) >= 0 && now.timeIntervalSince(fetchedAt) < lifetime
    }
}
