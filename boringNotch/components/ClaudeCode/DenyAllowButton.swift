//
//  DenyAllowButton.swift
//  ClaudeIsland
//
//  Reusable deny/allow pill button for permission flows
//

import SwiftUI

struct DenyAllowButton: View {
    enum Role { case deny, allow }
    let role: Role
    let label: String
    var fontSize: CGFloat = 11
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: fontSize, weight: role == .allow ? .semibold : .medium))
                .foregroundColor(role == .allow ? .black : .white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(role == .allow ? Color.white.opacity(0.9) : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
