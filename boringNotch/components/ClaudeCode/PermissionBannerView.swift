//
//  PermissionBannerView.swift
//  boringNotch
//
//  Permission approval row that appears inside the closed notch,
//  expanding its height downward. No separate pill -- just content
//  inside the existing notch shape.
//

import SwiftUI

struct PermissionBannerView: View {
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    let session: SessionState?
    let onFocus: (SessionState) -> Void

    private var pendingSession: SessionState? {
        session ?? sessionMonitor.instances.first { $0.phase.isWaitingForApproval }
    }

    init(
        sessionMonitor: ClaudeSessionMonitor,
        session: SessionState? = nil,
        onFocus: @escaping (SessionState) -> Void
    ) {
        self.sessionMonitor = sessionMonitor
        self.session = session
        self.onFocus = onFocus
    }

    var body: some View {
        if let session = pendingSession {
            HStack(spacing: 6) {
                // Tool name + input
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))

                    Text(toolDescription(for: session))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 2)

                // Go to terminal
                Button {
                    onFocus(session)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 28, height: 24)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Deny
                Button {
                    sessionMonitor.denyPermission(sessionId: session.sessionId, reason: nil)
                } label: {
                    Text("Deny")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Allow
                Button {
                    sessionMonitor.approvePermission(sessionId: session.sessionId)
                } label: {
                    Text("Allow")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func toolDescription(for session: SessionState) -> String {
        let toolName = session.pendingToolName ?? "Tool"
        if let input = session.pendingToolInput {
            let truncated = input.count > 30 ? String(input.prefix(30)) + "..." : input
            return "\(toolName): \(truncated)"
        }
        return toolName
    }
}
