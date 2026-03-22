//
//  AskUserQuestionView.swift
//  boringNotch
//
//  Expanded view for AskUserQuestion tool, shown when the notch opens.
//  Layout matches the music + calendar expanded view style.
//

import SwiftUI

struct AskUserQuestionView: View {
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    @ObservedObject var claudeVM: NotchViewModel
    let session: SessionState
    let onFocus: (SessionState) -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex: Int = 0

    private var question: String {
        guard let permission = session.activePermission,
              let input = permission.toolInput,
              let questions = input["questions"]?.value as? [[String: Any]],
              let firstQuestion = questions.first,
              let text = firstQuestion["question"] as? String
        else { return "Question" }
        return text
    }

    private var header: String? {
        guard let permission = session.activePermission,
              let input = permission.toolInput,
              let questions = input["questions"]?.value as? [[String: Any]],
              let firstQuestion = questions.first,
              let h = firstQuestion["header"] as? String
        else { return nil }
        return h
    }

    private var options: [(label: String, description: String?, preview: String?)] {
        guard let permission = session.activePermission,
              let input = permission.toolInput,
              let questions = input["questions"]?.value as? [[String: Any]],
              let firstQuestion = questions.first,
              let opts = firstQuestion["options"] as? [[String: Any]]
        else { return [] }

        return opts.map { opt in
            (label: opt["label"] as? String ?? "Option",
             description: opt["description"] as? String,
             preview: opt["preview"] as? String)
        }
    }

    private var hasPreview: Bool {
        options.contains { $0.preview != nil }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left: question + options list
            VStack(alignment: .leading, spacing: 10) {
                // Crab + ? + header
                HStack(spacing: 8) {
                    ClaudeCrabIcon(size: 16, animateLegs: false)

                    PermissionIndicatorIcon(
                        size: 14,
                        color: Color(red: 0.85, green: 0.47, blue: 0.34)
                    )

                    if let header = header {
                        Text(header)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            claudeVM.isPinned.toggle()
                        }
                    } label: {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(claudeVM.isPinned ? .white : .white.opacity(0.3))
                            .rotationEffect(.degrees(claudeVM.isPinned ? 0 : 45))
                    }
                    .buttonStyle(.plain)
                }

                // Question
                Text(question)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)

                // Options
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, opt in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedIndex = index
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.2))
                                    .frame(width: 6, height: 6)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(opt.label)
                                        .font(.system(size: 11, weight: index == selectedIndex ? .semibold : .medium))
                                        .foregroundColor(index == selectedIndex ? .white : .white.opacity(0.6))

                                    if let desc = opt.description {
                                        Text(desc)
                                            .font(.system(size: 9))
                                            .foregroundColor(.white.opacity(0.35))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(index == selectedIndex ? Color.white.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        onDismiss()
                        sessionMonitor.denyPermission(sessionId: session.sessionId, reason: nil)
                    } label: {
                        Text("Deny")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onFocus(session)
                    } label: {
                        Text("Terminal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDismiss()
                        onFocus(session)
                    } label: {
                        Text("Answer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.6, green: 0.8, blue: 0.4).opacity(0.85))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: hasPreview ? .infinity : .none)

            // Right: preview (if any option has preview)
            if hasPreview {
                VStack(alignment: .leading, spacing: 0) {
                    if let preview = options[safe: selectedIndex]?.preview {
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(preview)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text("No preview")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.25))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
