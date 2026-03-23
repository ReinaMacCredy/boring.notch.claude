//
//  ClaudeCodeHelpers.swift
//  boringNotch
//
//  Shared formatting and display helpers for Claude Code views.
//

import SwiftUI

// MARK: - Token Formatting

extension Int {
    /// Human-readable token count: 1.2B, 42M, 128k, or raw number.
    var formattedTokenCount: String {
        if self >= 1_000_000_000 {
            return String(format: "%.1fB", Double(self) / 1_000_000_000)
        } else if self >= 1_000_000 {
            return String(format: "%.0fM", Double(self) / 1_000_000)
        } else if self >= 1000 {
            return String(format: "%.0fk", Double(self) / 1_000)
        }
        return "\(self)"
    }
}

// MARK: - Model Display Name

extension String {
    /// Canonical Claude model display name: Opus, Sonnet, Haiku, or the original string.
    var claudeModelDisplayName: String {
        if contains("opus") { return "Opus" }
        if contains("sonnet") { return "Sonnet" }
        if contains("haiku") { return "Haiku" }
        return self
    }
}

// MARK: - Context Percentage Color

/// Fill color for a context usage percentage bar.
/// 4-tier scale: >90 red, >75 orange, >50 yellow, else green.
func contextPercentageColor(for percentage: Double) -> Color {
    if percentage > 90 { return .red }
    if percentage > 75 { return .orange }
    if percentage > 50 { return .yellow }
    return .green
}
