//
//  SessionDiscovery.swift
//  boringNotch
//
//  Scans ~/.claude/ide/*.lock to discover active Claude Code sessions.
//  Extracted from ClaudeCodeManager (Phase 6.2).
//

import Combine
import Foundation
import AppKit

@MainActor
final class SessionDiscovery: ObservableObject {
    static let shared = SessionDiscovery()

    // MARK: - Published Properties

    @Published private(set) var availableSessions: [ClaudeSession] = []
    @Published var selectedSession: ClaudeSession?

    // MARK: - Activity Grace Period

    /// Track when we last had activity (for grace period before notch collapses)
    private var lastActivityTime: Date = Date()
    /// Grace period to keep notch visible after activity stops (seconds)
    private let activityGracePeriod: TimeInterval = 2.0

    /// Cached session states from SessionStore (for activity checks)
    private var sessionStates: [SessionState] = []
    private var cancellables = Set<AnyCancellable>()

    /// True if any session has activity (processing, waiting for approval)
    /// Includes a grace period to prevent flickering when switching between tools.
    var hasAnySessionActivity: Bool {
        // Check if any session is active or waiting for approval
        for state in sessionStates {
            if state.phase.isActive || state.phase.isWaitingForApproval {
                return true
            }
        }

        // Grace period: keep showing activity for a short time after it stops
        // This prevents the notch from flickering during tool transitions
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
        if timeSinceLastActivity < activityGracePeriod {
            return true
        }

        return false
    }

    /// Call when a session becomes active (thinking, tool started, permission needed)
    func markActivity() {
        lastActivityTime = Date()
    }

    // MARK: - Private Properties

    // Use the real home directory, not the sandboxed container
    private let claudeDir: URL = URL(fileURLWithPath: realHomeDirectory())
        .appendingPathComponent(".claude")
    private var ideDir: URL { claudeDir.appendingPathComponent("ide") }

    private var sessionScanTimer: Timer?

    // MARK: - Initialization

    private init() {
        // Subscribe to SessionStore for activity tracking
        SessionStore.shared.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.sessionStates = sessions
            }
            .store(in: &cancellables)

        startSessionScanning()
    }

    // MARK: - Public Methods

    /// Scan for active Claude Code sessions
    func scanForSessions() {
        let fm = FileManager.default

        guard fm.fileExists(atPath: ideDir.path) else {
            availableSessions = []
            return
        }

        do {
            let lockFiles = try fm.contentsOfDirectory(at: ideDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "lock" }

            var sessions: [ClaudeSession] = []

            // Snapshot running apps once to avoid repeated IPC in the loop
            let runningApps = NSWorkspace.shared.runningApplications

            for lockFile in lockFiles {
                guard let data = fm.contents(atPath: lockFile.path) else {
                    continue
                }

                do {
                    let session = try JSONDecoder().decode(ClaudeSession.self, from: data)

                    // Verify process is still running
                    if isProcessRunning(pid: session.pid, runningApps: runningApps) {
                        sessions.append(session)
                    }
                } catch {
                    // Skip invalid lock files silently
                }
            }

            // Only log when session count changes
            #if DEBUG
            if sessions.count != availableSessions.count {
                print("[SessionDiscovery] Active sessions: \(sessions.count)")
            }
            #endif
            availableSessions = sessions

            // Auto-select if only one session and none selected
            if selectedSession == nil && sessions.count == 1 {
                selectSession(sessions[0])
            }

            // Clear selection if selected session no longer exists
            if let selected = selectedSession,
               !sessions.contains(where: { $0.pid == selected.pid }) {
                selectedSession = nil
            }

            // Refresh daily stats if CCM still exists
            ClaudeCodeManager.shared.loadDailyStats()

        } catch {
            print("[SessionDiscovery] Error scanning for sessions: \(error)")
        }
    }

    /// Select a session to monitor
    func selectSession(_ session: ClaudeSession) {
        guard session != selectedSession else { return }

        #if DEBUG
        print("[SessionDiscovery] Selecting session: \(session.displayName)")
        #endif
        selectedSession = session
    }

    // MARK: - Session Scanning

    private func startSessionScanning() {
        // Initial scan
        scanForSessions()

        // Periodic scan every 10 seconds (reduced from 5 to minimize memory pressure)
        sessionScanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanForSessions()
            }
        }
    }

    func isProcessRunning(pid: Int, runningApps: [NSRunningApplication]? = nil) -> Bool {
        // Use NSRunningApplication or check /proc to avoid sandbox restrictions with kill()
        // The kill() approach doesn't work in sandboxed apps
        let apps = runningApps ?? NSWorkspace.shared.runningApplications
        if apps.contains(where: { $0.processIdentifier == Int32(pid) }) {
            return true
        }

        // Fallback: check if the process directory exists (works for any process)
        let procPath = "/proc/\(pid)"
        if FileManager.default.fileExists(atPath: procPath) {
            return true
        }

        // Another fallback: try to get process info via sysctl
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

        // If sysctl succeeds and returns data, process exists
        return result == 0 && size > 0
    }

    /// Stop scanning (for cleanup)
    func stopScanning() {
        sessionScanTimer?.invalidate()
        sessionScanTimer = nil
    }
}
