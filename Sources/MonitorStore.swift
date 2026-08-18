import Foundation

enum QuotaAPIError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "接口地址无效"
        case .invalidResponse:
            return "服务器返回了无法识别的数据"
        case .httpStatus(let code):
            if code == 401 || code == 403 { return "Token 无效或没有权限（HTTP \(code)）" }
            return "请求失败（HTTP \(code)）"
        }
    }
}

enum QuotaAPI {
    static func fetch(endpoint: String, token: String) async throws -> (QuotaResponse, Data) {
        guard let url = URL(string: endpoint),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            throw QuotaAPIError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QuotaMonitor/1.0 macOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw QuotaAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw QuotaAPIError.httpStatus(http.statusCode) }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return (try decoder.decode(QuotaResponse.self, from: data), data)
        } catch {
            throw QuotaAPIError.invalidResponse
        }
    }
}

@MainActor
final class MonitorStore: ObservableObject {
    static let defaultEndpoint = "https://sub2api.labuta.diy/quota/v1/group"

    @Published private(set) var snapshot: QuotaResponse? {
        didSet { onStatusChanged?() }
    }
    @Published private(set) var isRefreshing = false {
        didSet { onStatusChanged?() }
    }
    @Published private(set) var errorMessage: String? {
        didSet { onStatusChanged?() }
    }
    @Published private(set) var lastUpdated: Date?

    var onStatusChanged: (() -> Void)?

    private(set) var endpoint: String
    private(set) var token: String
    private(set) var refreshIntervalMinutes: Int
    private var timer: Timer?

    private let defaults = UserDefaults.standard
    private let endpointKey = "quotaEndpoint"
    private let intervalKey = "refreshIntervalMinutes"
    private let cachedResponseKey = "cachedQuotaResponse"
    private let lastUpdatedKey = "lastQuotaUpdate"

    init() {
        endpoint = UserDefaults.standard.string(forKey: "quotaEndpoint") ?? Self.defaultEndpoint
        let storedInterval = UserDefaults.standard.integer(forKey: "refreshIntervalMinutes")
        refreshIntervalMinutes = [1, 5, 15, 30].contains(storedInterval) ? storedInterval : 5
        token = (try? KeychainStore.loadToken()) ?? ""

        if let data = UserDefaults.standard.data(forKey: "cachedQuotaResponse") {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            snapshot = try? decoder.decode(QuotaResponse.self, from: data)
        }
        lastUpdated = UserDefaults.standard.object(forKey: "lastQuotaUpdate") as? Date
    }

    deinit {
        timer?.invalidate()
    }

    var hasToken: Bool { !token.isEmpty }

    func startMonitoring() {
        scheduleTimer()
        Task { await refresh() }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        guard !token.isEmpty else {
            errorMessage = "请先设置 API Token"
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let (response, rawData) = try await QuotaAPI.fetch(endpoint: endpoint, token: token)
            snapshot = response
            lastUpdated = Date()
            errorMessage = nil
            defaults.set(rawData, forKey: cachedResponseKey)
            defaults.set(lastUpdated, forKey: lastUpdatedKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateSettings(endpoint: String, token: String, refreshIntervalMinutes: Int) throws {
        let cleanEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleanEndpoint), url.scheme == "https" || url.scheme == "http" else {
            throw QuotaAPIError.invalidEndpoint
        }
        guard !cleanToken.isEmpty else {
            throw SettingsError.emptyToken
        }

        try KeychainStore.saveToken(cleanToken)
        self.endpoint = cleanEndpoint
        self.token = cleanToken
        self.refreshIntervalMinutes = refreshIntervalMinutes
        defaults.set(cleanEndpoint, forKey: endpointKey)
        defaults.set(refreshIntervalMinutes, forKey: intervalKey)
        scheduleTimer()
        errorMessage = nil
    }

    func removeToken() throws {
        try KeychainStore.deleteToken()
        token = ""
        errorMessage = "请先设置 API Token"
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshIntervalMinutes * 60), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        timer?.tolerance = 15
    }
}

enum SettingsError: LocalizedError {
    case emptyToken

    var errorDescription: String? { "API Token 不能为空" }
}
