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

    private var isPlanApproval: Bool {
        pendingSession?.pendingToolName == "ExitPlanMode"
    }

    private var isUserQuestion: Bool {
        pendingSession?.pendingToolName == "AskUserQuestion"
    }

    private var bannerIcon: String {
        if isUserQuestion { return "questionmark.bubble" }
        if isPlanApproval { return "doc.text" }
        return "exclamationmark.shield"
    }

    private var bannerIconColor: Color {
        if isUserQuestion { return Color(red: 0.6, green: 0.8, blue: 0.4) }
        if isPlanApproval { return Color(red: 0.4, green: 0.7, blue: 1.0) }
        return Color(red: 1.0, green: 0.7, blue: 0.0)
    }

    var body: some View {
        if let session = pendingSession {
            HStack(spacing: 6) {
                // Tool name + input
                HStack(spacing: 4) {
                    Image(systemName: bannerIcon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(bannerIconColor)

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

                if isPlanApproval {
                    // Plan: Manual -- sends "ask" so CLI shows interactive prompt
                    Button {
                        sessionMonitor.askPermission(sessionId: session.sessionId)
                    } label: {
                        Text("Manual")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Plan: Bypass permissions (primary)
                    Button {
                        sessionMonitor.approvePermission(sessionId: session.sessionId)
                    } label: {
                        Text("Bypass")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.85))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if isUserQuestion {
                    // User question: Allow sends to terminal to answer
                    Button {
                        sessionMonitor.approvePermission(sessionId: session.sessionId)
                    } label: {
                        Text("Allow")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.6, green: 0.8, blue: 0.4).opacity(0.85))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    // Tool: Allow
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func toolDescription(for session: SessionState) -> String {
        let toolName = session.pendingToolName ?? "Tool"

        // Plan approval
        if toolName == "ExitPlanMode" {
            return "Plan ready to execute"
        }

        // User question: extract question text from toolInput
        if toolName == "AskUserQuestion" {
            if let permission = session.activePermission,
               let input = permission.toolInput,
               let questions = input["questions"]?.value as? [[String: Any]],
               let firstQuestion = questions.first,
               let questionText = firstQuestion["question"] as? String
            {
                let truncated = questionText.count > 35 ? String(questionText.prefix(35)) + "..." : questionText
                return truncated
            }
            return "User question"
        }

        if let input = session.pendingToolInput {
            let truncated = input.count > 30 ? String(input.prefix(30)) + "..." : input
            return "\(toolName): \(truncated)"
        }
        return toolName
    }
}
