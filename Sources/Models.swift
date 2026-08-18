import Foundation

struct QuotaResponse: Codable {
    let group: QuotaGroup
    let summary: QuotaSummary
    let accounts: [QuotaAccount]
    let generatedAt: String
}

struct QuotaGroup: Codable {
    let id: Int
    let name: String
}

struct QuotaSummary: Codable {
    let accountsTotal: Int
    let supported: Int
    let usableNow: Int
    let earliestRecovery: String?
}

struct QuotaAccount: Codable, Identifiable {
    let id: Int
    let platform: String
    let supported: Bool
    let windows: [QuotaWindow]?
    let sampledAt: String?

    var isUsable: Bool {
        guard supported, let windows, !windows.isEmpty else { return false }
        return windows.allSatisfy { $0.expired || $0.usedPercent < 100 }
    }
}
struct QuotaWindow: Codable, Identifiable {
    let name: String
    let usedPercent: Double
    let resetAt: String
    let expired: Bool

    var id: String { name }
    var displayPercent: Double { expired ? 0 : min(max(usedPercent, 0), 100) }
}

enum QuotaDate {
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardFormatter = ISO8601DateFormatter()

    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
    }

    static func recoveryText(_ value: String?, now: Date = Date()) -> String? {
        guard let date = parse(value) else { return nil }
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "已恢复" }
        if seconds < 3_600 {
            return "约 \(max(1, Int(ceil(seconds / 60)))) 分钟后"
        }
        if seconds < 86_400 {
            let hours = Int(seconds) / 3_600
            let minutes = (Int(seconds) % 3_600) / 60
            return minutes > 0 ? "\(hours) 小时 \(minutes) 分后" : "约 \(hours) 小时后"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
