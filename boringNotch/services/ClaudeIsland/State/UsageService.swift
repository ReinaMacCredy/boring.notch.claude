//
//  UsageService.swift
//  boringNotch
//
//  Fetches Claude API usage data from Anthropic's OAuth usage endpoint.
//  Reads credentials from macOS Keychain ("Claude Code-credentials").
//

import Combine
import Defaults
import Foundation

// MARK: - Usage Data Models

struct UsageData: Equatable {
    var fiveHour: UsageWindow
    var sevenDay: UsageWindow
    var sevenDaySonnet: UsageWindow?
    var extraUsage: ExtraUsage?
    var fetchedAt: Date

    static let empty = UsageData(
        fiveHour: .init(utilization: 0, resetsAt: nil),
        sevenDay: .init(utilization: 0, resetsAt: nil),
        fetchedAt: .distantPast
    )
}

struct UsageWindow: Equatable {
    let utilization: Double // 0-100
    let resetsAt: Date?
}

struct ExtraUsage: Equatable {
    let isEnabled: Bool
    let usedCredits: Double // cents
    let monthlyLimit: Double // cents
}

struct TokenUsageData: Equatable {
    let totalTokens: Int
    let totalCost: Double
}

// MARK: - Service

@MainActor
final class UsageService: ObservableObject {
    static let shared = UsageService()

    @Published var usage: UsageData = .empty
    @Published var tokenUsage: TokenUsageData?
    @Published var isLoading = false
    @Published var lastError: String?

    private var refreshTimer: AnyCancellable?
    private var isRefreshing = false

    private let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    private let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let keychainService = "Claude Code-credentials"
    private let refreshBufferSeconds: TimeInterval = 5 * 60

    // Threshold notification tracking
    private var lastNotifiedBucket: Int = -1
    private var lastResetDate: Date?

    private init() {
        startAutoRefresh()
    }

    // MARK: - Public

    func startAutoRefresh(interval: TimeInterval = 300) {
        // Fetch immediately
        Task { await fetch() }

        // Then on interval
        refreshTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.fetch() }
            }
    }

    func stopAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    // MARK: - Threshold Notifications

    private func checkThresholdCrossing(_ data: UsageData) {
        guard Defaults[.showUsageThresholdNotifications],
              Defaults[.enableClaudeCode] else { return }

        let step = Defaults[.usageThresholdStep]
        guard step > 0 else { return }

        let utilization = data.fiveHour.utilization

        // Reset tracking when the 5-hour window rolls over
        if let newReset = data.fiveHour.resetsAt, newReset != lastResetDate {
            lastResetDate = newReset
            lastNotifiedBucket = -1
        }

        let currentBucket = Int(utilization / step)

        // Only fire when crossing into a new higher bucket
        if currentBucket > lastNotifiedBucket && currentBucket > 0 {
            lastNotifiedBucket = currentBucket
            BoringViewCoordinator.shared.toggleExpandingView(
                status: true,
                type: .usageThreshold,
                value: CGFloat(utilization)
            )
        }
    }

    func fetch() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        isLoading = usage == .empty

        do {
            var creds = try readCredentials()

            // Refresh token if near expiry
            if creds.expiresAt.timeIntervalSinceNow < refreshBufferSeconds {
                creds = try await refreshToken(creds)
            }

            let data = try await fetchUsage(accessToken: creds.accessToken)
            self.usage = data
            self.lastError = nil
            checkThresholdCrossing(data)
        } catch let error as UsageError {
            // On rate limit, keep stale data and don't show error if we have data
            if case .rateLimited = error, usage != .empty {
                // Silently keep stale data
            } else if usage == .empty {
                self.lastError = error.localizedDescription
            }
            // If we have data, don't overwrite lastError -- keep showing pills
        } catch {
            if usage == .empty {
                self.lastError = error.localizedDescription
            }
        }

        // Fetch token usage from ccusage (independent of API)
        await fetchTokenUsage()

        isLoading = false
    }

    // MARK: - Token Usage (ccusage)

    private func fetchTokenUsage() async {
        let today = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd"
            return f.string(from: Date())
        }()

        // Run via login shell so PATH includes homebrew/node
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "ccusage daily --since \(today) --json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return // shell not available
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daily = json["daily"] as? [[String: Any]],
              let first = daily.first
        else { return }

        let totalTokens: Int
        if let t = first["totalTokens"] as? Int { totalTokens = t }
        else if let t = first["totalTokens"] as? Double { totalTokens = Int(t) }
        else { return }

        let totalCost: Double
        if let c = first["totalCost"] as? Double { totalCost = c }
        else if let c = first["totalCost"] as? Int { totalCost = Double(c) }
        else { totalCost = 0 }

        self.tokenUsage = TokenUsageData(totalTokens: totalTokens, totalCost: totalCost)
    }

    // MARK: - Credentials

    private struct OAuthCredentials {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
    }

    private func readCredentials() throws -> OAuthCredentials {
        // Use `security` CLI to avoid macOS keychain password popup.
        // SecItemCopyMatching triggers the system dialog for items created by other apps.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", keychainService, "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            throw UsageError.noCredentials
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UsageError.noCredentials
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = str.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            throw UsageError.invalidCredentials
        }

        guard let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              let refreshToken = oauth["refreshToken"] as? String,
              let expiresAtMs = oauth["expiresAt"] as? Int
        else {
            throw UsageError.invalidCredentials
        }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(expiresAtMs) / 1000)
        )
    }

    // MARK: - Token Refresh

    private func refreshToken(_ creds: OAuthCredentials) async throws -> OAuthCredentials {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": creds.refreshToken,
            "client_id": clientId,
            "scope": "user:profile user:inference user:sessions:claude_code user:mcp_servers",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UsageError.tokenRefreshFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccess = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int
        else {
            throw UsageError.tokenRefreshFailed
        }

        let newRefresh = json["refresh_token"] as? String ?? creds.refreshToken
        let newCreds = OAuthCredentials(
            accessToken: newAccess,
            refreshToken: newRefresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )

        return newCreds
    }

    // MARK: - API Call

    private func fetchUsage(accessToken: String) async throws -> UsageData {
        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.networkError
        }

        if http.statusCode == 401 {
            throw UsageError.unauthorized
        }

        if http.statusCode == 429 {
            // Rate limited -- parse retry-after header if available
            let retryAfter = http.value(forHTTPHeaderField: "retry-after")
                .flatMap { Double($0) } ?? 300
            throw UsageError.rateLimited(retryAfter: retryAfter)
        }

        guard http.statusCode == 200 else {
            throw UsageError.apiError(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.parseError
        }

        return parseUsageResponse(json)
    }

    private func parseUsageResponse(_ json: [String: Any]) -> UsageData {
        let fiveHour = parseWindow(json["five_hour"] as? [String: Any])
        let sevenDay = parseWindow(json["seven_day"] as? [String: Any])
        let sevenDaySonnet: UsageWindow? = (json["seven_day_sonnet"] as? [String: Any]).map { parseWindow($0) }

        var extraUsage: ExtraUsage?
        if let extra = json["extra_usage"] as? [String: Any] {
            let used: Double
            if let d = extra["used_credits"] as? Double { used = d }
            else if let i = extra["used_credits"] as? Int { used = Double(i) }
            else { used = 0 }

            let limit: Double
            if let d = extra["monthly_limit"] as? Double { limit = d }
            else if let i = extra["monthly_limit"] as? Int { limit = Double(i) }
            else { limit = 0 }

            extraUsage = ExtraUsage(
                isEnabled: extra["is_enabled"] as? Bool ?? false,
                usedCredits: used,
                monthlyLimit: limit
            )
        }

        return UsageData(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            sevenDaySonnet: sevenDaySonnet,
            extraUsage: extraUsage,
            fetchedAt: Date()
        )
    }

    private func parseWindow(_ dict: [String: Any]?) -> UsageWindow {
        guard let dict = dict else {
            return UsageWindow(utilization: 0, resetsAt: nil)
        }
        // utilization can arrive as Int or Double
        let util: Double
        if let d = dict["utilization"] as? Double {
            util = d
        } else if let i = dict["utilization"] as? Int {
            util = Double(i)
        } else {
            util = 0
        }

        var resetsAt: Date?
        if let ts = dict["resets_at"] as? String {
            // Try ISO8601 with fractional seconds first
            let fmtFrac = ISO8601DateFormatter()
            fmtFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmtFrac.date(from: ts) {
                resetsAt = d
            } else {
                // Fallback: standard ISO8601
                resetsAt = ISO8601DateFormatter().date(from: ts)
            }
        } else if let ts = dict["resets_at"] as? Double {
            resetsAt = Date(timeIntervalSince1970: ts)
        } else if let ts = dict["resets_at"] as? Int {
            resetsAt = Date(timeIntervalSince1970: TimeInterval(ts))
        }
        return UsageWindow(utilization: util, resetsAt: resetsAt)
    }
}

// MARK: - Errors

enum UsageError: LocalizedError {
    case noCredentials
    case invalidCredentials
    case tokenRefreshFailed
    case unauthorized
    case networkError
    case apiError(Int)
    case rateLimited(retryAfter: Double)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No Claude credentials found"
        case .invalidCredentials: return "Invalid credentials format"
        case .tokenRefreshFailed: return "Token refresh failed"
        case .unauthorized: return "Unauthorized"
        case .networkError: return "Network error"
        case .apiError(let code): return "API error (\(code))"
        case .rateLimited: return "Rate limited -- will retry"
        case .parseError: return "Failed to parse response"
        }
    }
}

