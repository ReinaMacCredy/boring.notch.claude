//
//  ClaudeClosedView.swift
//  boringNotch
//
//  Dynamic Island-style activity indicator for the closed notch.
//  Shows crab icon (left), processing spinner or checkmark (right),
//  with optional permission indicator. Matches claude-island's headerRow.
//
//  Multi-session behavior:
//  - Processing takes priority: if ANY session is processing, show spinner + animated crab
//  - Permission indicator: if ANY session needs approval, show amber dot (left) + spinner
//  - Checkmark: only when NO session is processing AND at least one is waitingForInput
//  - Bounce: notch briefly expands when a session newly enters waitingForInput
//  - Auto-hide: checkmark disappears after 30 seconds
//  - Sound: plays notification when session finishes (if not focused)
//

import SwiftUI

struct ClaudeClosedView: View {
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    let closedNotchSize: CGSize
    let effectiveClosedNotchHeight: CGFloat

    @State private var waitingForInputTimestamps: [String: Date] = [:]
    @State private var previousWaitingIds: Set<String> = []
    @State private var isBouncing: Bool = false
    // Trigger to force re-evaluation of hasWaitingForInput after 30s
    @State private var refreshTrigger: Bool = false

    // MARK: - Activity State

    private var isAnyProcessing: Bool {
        sessionMonitor.instances.contains { $0.phase == .processing || $0.phase == .compacting }
    }

    private var hasPendingPermission: Bool {
        sessionMonitor.instances.contains { $0.phase.isWaitingForApproval }
    }

    private var hasWaitingForInput: Bool {
        // refreshTrigger forces re-evaluation after 30s timeout
        _ = refreshTrigger
        let now = Date()
        let displayDuration: TimeInterval = 30
        return sessionMonitor.instances.contains { session in
            guard session.phase == .waitingForInput else { return false }
            if let enteredAt = waitingForInputTimestamps[session.stableId] {
                return now.timeIntervalSince(enteredAt) < displayDuration
            }
            return true
        }
    }

    private var showActivity: Bool {
        isAnyProcessing || hasPendingPermission || hasWaitingForInput
    }

    private var sideWidth: CGFloat {
        max(0, effectiveClosedNotchHeight - 12) + 10
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            if showActivity {
                // Left side: crab + dots + optional permission indicator
                // All positioned in the left expansion area, outside the physical notch
                HStack(spacing: 6) {
                    ClaudeCrabIcon(size: 14, animateLegs: isAnyProcessing)

                    // Per-session dots
                    HStack(spacing: 4) {
                        ForEach(sessionMonitor.instances.prefix(3)) { session in
                            Circle()
                                .fill(dotColor(for: session.phase))
                                .frame(width: 6, height: 6)
                        }
                    }

                    if hasPendingPermission {
                        PermissionIndicatorIcon(
                            size: 14,
                            color: Color(red: 0.85, green: 0.47, blue: 0.34)
                        )
                    }
                }

                // Center: black spacer covering the physical notch area
                Rectangle()
                    .fill(.black)
                    .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top + (isBouncing ? 16 : 0))

                // Right: spinner or checkmark
                // Priority: processing/permission > waitingForInput
                if isAnyProcessing || hasPendingPermission {
                    ProcessingSpinner()
                        .frame(width: sideWidth)
                } else if hasWaitingForInput {
                    ReadyForInputIndicatorIcon(size: 14, color: TerminalColors.green)
                        .frame(width: sideWidth)
                }
            } else {
                // No activity: invisible placeholder
                Rectangle().fill(.clear)
                    .frame(width: closedNotchSize.width - 20)
            }
        }
        .frame(height: effectiveClosedNotchHeight, alignment: .center)
        // No explicit animation -- relies on mainLayout's compositional springs
        // (same as MusicLiveActivity). chinWidth drives expand/collapse.
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isBouncing)
        .onChange(of: sessionMonitor.instances) { _, instances in
            trackWaitingForInput(instances)
        }
    }

    // MARK: - Dot Colors

    private func dotColor(for phase: SessionPhase) -> Color {
        switch phase {
        case .processing, .compacting:
            return TerminalColors.green
        case .waitingForApproval:
            return Color(red: 1.0, green: 0.7, blue: 0.0)
        case .waitingForInput:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        default:
            return .white.opacity(0.3)
        }
    }

    // MARK: - Waiting-for-Input Tracking

    private func trackWaitingForInput(_ instances: [SessionState]) {
        let waiting = instances.filter { $0.phase == .waitingForInput }
        let currentIds = Set(waiting.map { $0.stableId })
        let newlyWaitingIds = currentIds.subtracting(previousWaitingIds)

        // Assign timestamps for any waiting session that doesn't have one yet
        let now = Date()
        for session in waiting where waitingForInputTimestamps[session.stableId] == nil {
            waitingForInputTimestamps[session.stableId] = now
        }

        // Clean up timestamps for sessions no longer waiting
        let staleIds = Set(waitingForInputTimestamps.keys).subtracting(currentIds)
        for staleId in staleIds {
            waitingForInputTimestamps.removeValue(forKey: staleId)
        }

        // Bounce + sound when any session NEWLY enters waitingForInput
        if !newlyWaitingIds.isEmpty {
            // Bounce animation
            isBouncing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBouncing = false
            }

            // Play notification sound
            if let soundName = AppSettings.notificationSound.soundName {
                NSSound(named: soundName)?.play()
            }

            // Schedule re-evaluation after 30 seconds to hide the checkmark
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                refreshTrigger.toggle()
            }
        }

        previousWaitingIds = currentIds
    }
}
