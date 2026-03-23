//
//  ClaudeCodeStatsView.swift
//  boringNotch
//
//  Compact view showing Claude Code stats - designed to fit in 190px notch height
//

import SwiftUI

struct ClaudeCodeStatsView: View {
    @ObservedObject var sessionDiscovery = SessionDiscovery.shared
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()

    /// The SessionState matching the currently selected session
    private var selectedState: SessionState? {
        guard let selectedId = sessionDiscovery.selectedSession?.id else { return nil }
        return sessionMonitor.instances.first { $0.sessionId == selectedId }
    }

    /// Whether a selected session exists in the session store (replaces isConnected)
    private var isConnected: Bool { selectedState != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Session picker + connection status + model/branch
            HStack(spacing: 6) {
                SessionPicker()

                if isConnected, let state = selectedState {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)

                    if let model = state.model, !model.isEmpty {
                        Text(model.claudeModelDisplayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let branch = state.gitBranch, !branch.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 8))
                            Text(branch)
                                .lineLimit(1)
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if isConnected, let state = selectedState {
                // Row 2: Context bar with token breakdown
                ContextBarWithBreakdown(
                    percentage: state.contextPercentage,
                    usage: state.tokenUsage ?? TokenUsage()
                )

                // Row 3: Todo list (show up to 3)
                if !state.todos.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(state.todos.prefix(3)) { todo in
                            HStack(spacing: 4) {
                                Image(systemName: todo.status.icon)
                                    .font(.system(size: 8))
                                    .foregroundColor(todo.status.color)
                                Text(todo.content)
                                    .font(.caption2)
                                    .foregroundColor(todo.status == .completed ? .secondary.opacity(0.6) : .secondary)
                                    .lineLimit(1)
                                    .strikethrough(todo.status == .completed)
                                Spacer()
                            }
                        }
                    }
                }

                // Row 4: Last message output
                if let lastMessage = state.lastMessage, !lastMessage.isEmpty {
                    Text(lastMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Row 5: Active tools
                // TODO: Add recentTools tracking to SessionState (Phase 7)
                if !state.toolTracker.inProgress.isEmpty {
                    HStack(spacing: 4) {
                        if let activeTool = state.toolTracker.inProgress.values.first {
                            ToolActivityIndicator(isActive: true, toolName: activeTool.name)
                                .scaleEffect(0.5)
                            Text(activeTool.name)
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Spacer()
                    }
                }

            } else {
                // Not connected state - centered
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No session selected")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if sessionDiscovery.availableSessions.isEmpty {
                            Text("Start Claude Code to begin")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        } else {
                            Text("\(sessionDiscovery.availableSessions.count) session\(sessionDiscovery.availableSessions.count == 1 ? "" : "s") available")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// Context bar with token breakdown
struct ContextBarWithBreakdown: View {
    let percentage: Double
    let usage: TokenUsage

    private var barColor: Color {
        contextPercentageColor(for: percentage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Progress bar row
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: max(0, geo.size.width * min(1, percentage / 100)))
                    }
                }
                .frame(height: 6)

                Text("\(Int(percentage))%")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundColor(barColor)
                    .frame(width: 36, alignment: .trailing)
            }

            // Token breakdown row
            HStack(spacing: 12) {
                TokenLabel(label: "In", value: usage.inputTokens, color: .blue)
                TokenLabel(label: "Out", value: usage.outputTokens, color: .purple)
                TokenLabel(label: "Cache", value: usage.cacheReadInputTokens, color: .cyan)

                Spacer()

                Text("\(usage.totalTokens.formattedTokenCount) / \(TokenUsage.contextWindow.formattedTokenCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
    }

}

struct TokenLabel: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 4, height: 4)
            Text("\(label):")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value.formattedTokenCount)
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ClaudeCodeStatsView()
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .padding()
}
