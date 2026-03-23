//
//  TerminalColors.swift
//  ClaudeIsland
//
//  Color palette for terminal-style UI
//

import SwiftUI

struct TerminalColors {
    static let green = Color(red: 0.4, green: 0.75, blue: 0.45)
    static let amber = Color(red: 1.0, green: 0.7, blue: 0.0)
    static let red = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let cyan = Color(red: 0.0, green: 0.8, blue: 0.8)
    static let blue = Color(red: 0.4, green: 0.6, blue: 1.0)
    static let magenta = Color(red: 0.8, green: 0.4, blue: 0.8)
    static let dim = Color.white.opacity(0.4)
    static let dimmer = Color.white.opacity(0.2)
    static let prompt = Color(red: 0.85, green: 0.47, blue: 0.34)  // #d97857
    static let background = Color.white.opacity(0.05)
    static let backgroundHover = Color.white.opacity(0.1)

    // MARK: - Usage utilization colors

    static let utilizationGreen = Color(red: 0.29, green: 0.87, blue: 0.50) // #4ade80
    static let utilizationAmber = Color(red: 0.98, green: 0.75, blue: 0.14) // #fbbf24
    static let utilizationRed = Color(red: 0.97, green: 0.44, blue: 0.44)   // #f87171

    /// Returns green / amber / red based on utilization percentage (0-100).
    static func utilizationColor(for utilization: Double) -> Color {
        if utilization < 50 {
            return utilizationGreen
        } else if utilization < 80 {
            return utilizationAmber
        } else {
            return utilizationRed
        }
    }
}
