//
//  PermissionBannerView.swift
//  boringNotch
//
//  Pill-shaped drop-down banner that appears below the closed notch
//  when a Claude session needs tool permission approval. Shows tool name,
//  Allow/Deny buttons, and a Go button to focus the terminal.
//

import SwiftUI

struct PermissionBannerView: View {
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    let onFocus: (SessionState) -> Void

    private var pendingSession: SessionState? {
        sessionMonitor.instances.first { $0.phase.isWaitingForApproval }
    }

    var body: some View {
        if let session = pendingSession {
            HStack(spacing: 8) {
                // Tool name + input
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))

                    Text(toolDescription(for: session))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 4)

                // Go to terminal
                Button {
                    focusSession(session)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
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
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            )
            .padding(.horizontal, 8)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.3, anchor: .top)
                        .combined(with: .opacity)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8)),
                    removal: .scale(scale: 0.3, anchor: .top)
                        .combined(with: .opacity)
                        .animation(.spring(response: 0.25, dampingFraction: 1.0))
                )
            )
        }
    }

    private func toolDescription(for session: SessionState) -> String {
        let toolName = session.pendingToolName ?? "Tool"
        if let input = session.pendingToolInput {
            let truncated = input.count > 40 ? String(input.prefix(40)) + "..." : input
            return "\(toolName): \(truncated)"
        }
        return toolName
    }

    private func focusSession(_ session: SessionState) {
        guard session.isInTmux, let pid = session.pid else { return }
        Task {
            _ = await YabaiController.shared.focusWindow(forClaudePid: pid)
        }
    }
}
