//
//  ClaudeCodeManager.swift
//  boringNotch
//
//  Thin coordinator for daily stats and notifications.
//  JSONL parsing, file watchers, and session state moved to SessionStore/ConversationParser.
//  View consumers migrated to SessionDiscovery/ClaudeSessionMonitor (Phase 6.4).
//

import Foundation
import UserNotifications

@MainActor
final class ClaudeCodeManager: ObservableObject {
    static let shared = ClaudeCodeManager()

    // MARK: - Cached Formatters (expensive to create repeatedly)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Published Properties

    @Published private(set) var dailyStats: DailyStats = DailyStats()

    // MARK: - Private Properties

    // Use the real home directory, not the sandboxed container
    private let claudeDir: URL = URL(fileURLWithPath: realHomeDirectory())
        .appendingPathComponent(".claude")

    /// Last observed modification time of stats-cache.json (skip re-reads when unchanged)
    private var lastStatsMtime: Date?

    // MARK: - Initialization

    private init() {
        setupNotifications()
        loadDailyStats()
    }

    // MARK: - IDE Focus

    /// Forward to IDEFocuser for backward compatibility.
    func focusIDE(for session: ClaudeSession? = nil) {
        IDEFocuser.focusIDE(for: session)
    }

    // MARK: - Notifications

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyAgentCompletion(agent: AgentInfo) {
        let content = UNMutableNotificationContent()
        content.title = "Agent Completed"
        content.body = "\(agent.name): \(agent.description)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Daily Stats

    /// Load daily stats from ~/.claude/stats-cache.json
    /// Skips re-reading when the file's modification time hasn't changed.
    func loadDailyStats() {
        let statsFile = claudeDir.appendingPathComponent("stats-cache.json")

        let fm = FileManager.default
        guard fm.fileExists(atPath: statsFile.path) else { return }

        // Check modification time -- skip if unchanged since last read
        if let attrs = try? fm.attributesOfItem(atPath: statsFile.path),
           let mtime = attrs[.modificationDate] as? Date {
            if let lastMtime = lastStatsMtime, mtime == lastMtime {
                return
            }
            lastStatsMtime = mtime
        }

        guard let data = fm.contents(atPath: statsFile.path) else {
            return
        }

        do {
            let cache = try JSONDecoder().decode(StatsCache.self, from: data)

            // Get today's date in the format used by the cache (YYYY-MM-DD)
            let today = Self.dateFormatter.string(from: Date())

            var stats = DailyStats()

            // Try to find today's activity first, otherwise get the most recent
            let sortedActivity = cache.dailyActivity?.sorted { $0.date > $1.date }
            if let todayActivity = sortedActivity?.first(where: { $0.date == today }) {
                stats.date = today
                stats.messageCount = todayActivity.messageCount ?? 0
                stats.toolCallCount = todayActivity.toolCallCount ?? 0
                stats.sessionCount = todayActivity.sessionCount ?? 0
            } else if let latestActivity = sortedActivity?.first {
                // Use most recent day's stats
                stats.date = latestActivity.date
                stats.messageCount = latestActivity.messageCount ?? 0
                stats.toolCallCount = latestActivity.toolCallCount ?? 0
                stats.sessionCount = latestActivity.sessionCount ?? 0
            }

            // Try to find today's token usage first, otherwise get the most recent
            let sortedTokens = cache.dailyModelTokens?.sorted { $0.date > $1.date }
            let targetDate = stats.date.isEmpty ? today : stats.date
            if let dayTokens = sortedTokens?.first(where: { $0.date == targetDate }),
               let tokensByModel = dayTokens.tokensByModel {
                stats.tokensUsed = tokensByModel.values.reduce(0, +)
            } else if let latestTokens = sortedTokens?.first,
                      let tokensByModel = latestTokens.tokensByModel {
                stats.tokensUsed = tokensByModel.values.reduce(0, +)
                if stats.date.isEmpty {
                    stats.date = latestTokens.date
                }
            }

            // Only update and log if stats changed
            if stats != dailyStats {
                dailyStats = stats
            }

        } catch {
            print("[ClaudeCode] Error parsing stats-cache.json: \(error)")
        }
    }
}
