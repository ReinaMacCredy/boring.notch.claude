//
//  ClaudeClosedView.swift
//  boringNotch
//
//  Dynamic Island-style activity indicator for the closed notch.
//  Shows crab icon (left), processing spinner or checkmark (right),
//  with optional permission indicator. Matches claude-island's headerRow.
//

import SwiftUI

struct ClaudeClosedView: View {
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    let closedNotchSize: CGSize
    let effectiveClosedNotchHeight: CGFloat

    @State private var waitingForInputTimestamps: [String: Date] = [:]
    @State private var previousWaitingIds: Set<String> = []

    // MARK: - Activity State

    private var isAnyProcessing: Bool {
        sessionMonitor.instances.contains { $0.phase == .processing || $0.phase == .compacting }
    }

    private var hasPendingPermission: Bool {
        sessionMonitor.instances.contains { $0.phase.isWaitingForApproval }
    }

    private var hasWaitingForInput: Bool {
        let now = Date()
        let displayDuration: TimeInterval = 30
        return sessionMonitor.instances.contains { session in
            guard session.phase == .waitingForInput else { return false }
            if let enteredAt = waitingForInputTimestamps[session.stableId] {
                return now.timeIntervalSince(enteredAt) < displayDuration
            }
            // No timestamp yet -- session entered waitingForInput before we tracked it.
            // Return true so it shows; trackWaitingForInput will assign a timestamp.
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
                // Left: crab + optional permission indicator
                HStack(spacing: 4) {
                    ClaudeCrabIcon(size: 14, animateLegs: isAnyProcessing)

                    if hasPendingPermission {
                        PermissionIndicatorIcon(
                            size: 14,
                            color: Color(red: 0.85, green: 0.47, blue: 0.34)
                        )
                    }
                }
                .frame(width: sideWidth + (hasPendingPermission ? 18 : 0))

                // Center: black spacer
                Rectangle()
                    .fill(.black)
                    .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top)

                // Right: spinner or checkmark
                if isAnyProcessing || hasPendingPermission {
                    ProcessingSpinner()
                        .frame(width: sideWidth)
                } else if hasWaitingForInput {
                    ReadyForInputIndicatorIcon(size: 14, color: TerminalColors.green)
                        .frame(width: sideWidth)
                }
            } else {
                // No activity: invisible placeholder (same as original idle)
                Rectangle().fill(.clear)
                    .frame(width: closedNotchSize.width - 20)
            }
        }
        .frame(height: effectiveClosedNotchHeight, alignment: .center)
        .onChange(of: sessionMonitor.instances) { _, instances in
            trackWaitingForInput(instances)
        }
    }

    // MARK: - Waiting-for-Input Tracking

    private func trackWaitingForInput(_ instances: [SessionState]) {
        let waiting = instances.filter { $0.phase == .waitingForInput }
        let currentIds = Set(waiting.map { $0.stableId })

        // Assign timestamps for any waiting session that doesn't have one yet
        let now = Date()
        for session in waiting where waitingForInputTimestamps[session.stableId] == nil {
            waitingForInputTimestamps[session.stableId] = now
        }

        // Clean up stale timestamps
        let staleIds = Set(waitingForInputTimestamps.keys).subtracting(currentIds)
        for staleId in staleIds {
            waitingForInputTimestamps.removeValue(forKey: staleId)
        }

        previousWaitingIds = currentIds
    }
}
