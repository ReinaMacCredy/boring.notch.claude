//
//  PermissionBannerView.swift
//  boringNotch
//
//  Permission approval row that appears inside the closed notch,
//  expanding its height downward. No separate pill -- just content
//  inside the existing notch shape.
//
//  Three modes:
//  - Tool permission: compact row with Deny/Allow
//  - Plan approval (ExitPlanMode): compact row with Deny/Manual/Bypass
//  - User question (AskUserQuestion): compact or expanded with preview
//

import SwiftUI

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct PermissionBannerView: View {
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    let session: SessionState?
    let onFocus: (SessionState) -> Void

    @State private var selectedPreviewIndex: Int = 0

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

    // MARK: - Body

    var body: some View {
        if let session = pendingSession {
            if isUserQuestion && hasPreviewContent(for: session) {
                expandedQuestionView(session: session)
            } else {
                compactBannerView(session: session)
            }
        }
    }

    // MARK: - Compact Banner (tool permission, plan approval, question without preview)

    @ViewBuilder
    private func compactBannerView(session: SessionState) -> some View {
        HStack(spacing: 6) {
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

            terminalButton(session: session)
            denyButton(session: session)

            if isPlanApproval {
                manualButton(session: session)
                bypassButton(session: session)
            } else {
                allowButton(session: session)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Expanded Question (AskUserQuestion with previews)

    @ViewBuilder
    private func expandedQuestionView(session: SessionState) -> some View {
        let previews = questionPreviews(for: session)

        VStack(alignment: .leading, spacing: 8) {
            // Question text
            HStack(spacing: 4) {
                Image(systemName: "questionmark.bubble")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(bannerIconColor)

                Text(fullQuestionText(for: session))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }

            // Option pills
            HStack(spacing: 6) {
                ForEach(Array(previews.enumerated()), id: \.offset) { index, opt in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedPreviewIndex = index
                        }
                    } label: {
                        Text(opt.label)
                            .font(.system(size: 10, weight: index == selectedPreviewIndex ? .semibold : .medium))
                            .foregroundColor(index == selectedPreviewIndex ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(index == selectedPreviewIndex
                                ? Color.white.opacity(0.85)
                                : Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Preview content
            if let preview = previews[safe: selectedPreviewIndex]?.preview {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(preview)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .padding(8)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Action buttons
            HStack {
                Spacer()
                terminalButton(session: session)
                denyButton(session: session)

                Button {
                    sessionMonitor.approvePermission(sessionId: session.sessionId)
                    onFocus(session)
                } label: {
                    Text("Select")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.6, green: 0.8, blue: 0.4).opacity(0.85))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Shared Buttons

    @ViewBuilder
    private func terminalButton(session: SessionState) -> some View {
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
    }

    @ViewBuilder
    private func denyButton(session: SessionState) -> some View {
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
    }

    @ViewBuilder
    private func allowButton(session: SessionState) -> some View {
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

    @ViewBuilder
    private func manualButton(session: SessionState) -> some View {
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
    }

    @ViewBuilder
    private func bypassButton(session: SessionState) -> some View {
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
    }

    // MARK: - Data Extraction

    private func hasPreviewContent(for session: SessionState) -> Bool {
        questionPreviews(for: session).contains { $0.preview != nil }
    }

    private func questionPreviews(for session: SessionState) -> [(label: String, preview: String?)] {
        guard let permission = session.activePermission,
              let input = permission.toolInput,
              let questions = input["questions"]?.value as? [[String: Any]],
              let firstQuestion = questions.first,
              let options = firstQuestion["options"] as? [[String: Any]]
        else { return [] }

        return options.prefix(4).map { opt in
            (label: opt["label"] as? String ?? "Option",
             preview: opt["preview"] as? String)
        }
    }

    private func questionOptions(for session: SessionState) -> [String] {
        guard let permission = session.activePermission,
              let input = permission.toolInput,
              let questions = input["questions"]?.value as? [[String: Any]],
              let firstQuestion = questions.first,
              let options = firstQuestion["options"] as? [[String: Any]]
        else { return ["Answer"] }

        let labels = options.prefix(4).compactMap { $0["label"] as? String }
        return labels.isEmpty ? ["Answer"] : labels
    }

    private func fullQuestionText(for session: SessionState) -> String {
        guard let permission = session.activePermission,
              let input = permission.toolInput,
              let questions = input["questions"]?.value as? [[String: Any]],
              let firstQuestion = questions.first,
              let questionText = firstQuestion["question"] as? String
        else { return "Question" }
        return questionText
    }

    private func toolDescription(for session: SessionState) -> String {
        let toolName = session.pendingToolName ?? "Tool"

        if toolName == "ExitPlanMode" {
            return "Plan ready to execute"
        }

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
