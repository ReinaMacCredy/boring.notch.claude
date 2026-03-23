//
//  SessionDotsIndicator.swift
//  boringNotch
//
//  Row of dots showing all active Claude Code sessions
//  Green blinking = active (thinking or running tools), Orange blinking = needs permission, Gray = idle
//

import SwiftUI

struct SessionDotsIndicator: View {
    @ObservedObject var sessionDiscovery = SessionDiscovery.shared
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(sessionDiscovery.availableSessions) { session in
                SessionDot(
                    session: session,
                    state: sessionMonitor.instances.first { $0.sessionId == session.id }
                )
                .onTapGesture {
                    IDEFocuser.focusIDE(for: session)
                }
            }
        }
    }
}

struct SessionDot: View {
    let session: ClaudeSession
    let state: SessionState?
    var showTooltip: Bool = true

    @State private var isBlinking = false

    private var isWaitingForApproval: Bool {
        state?.phase.isWaitingForApproval == true
    }

    private var isActive: Bool {
        state?.phase.isActive == true
    }

    private var dotColor: Color {
        if isWaitingForApproval {
            return .orange
        } else if isActive {
            return .green
        }
        return .gray
    }

    private var shouldBlink: Bool {
        isWaitingForApproval || isActive
    }

    var body: some View {
        let dot = RoundedRectangle(cornerRadius: 1)
            .fill(dotColor)
            .frame(width: 14, height: 3)
            .opacity(shouldBlink ? (isBlinking ? 1.0 : 0.3) : 0.5)
            .animation(.easeInOut(duration: 0.6), value: isBlinking)
            .onAppear {
                startBlinkingIfNeeded()
            }
            .onChange(of: shouldBlink) { _, newValue in
                if newValue {
                    startBlinkingIfNeeded()
                } else {
                    isBlinking = false
                }
            }
            .onChange(of: isWaitingForApproval) { _, _ in
                // Reset animation when permission state changes
                if shouldBlink {
                    isBlinking = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        startBlinkingIfNeeded()
                    }
                }
            }

        if showTooltip {
            dot.help(tooltipText)
        } else {
            dot
        }
    }

    private var tooltipText: String {
        var text = session.displayName
        if isWaitingForApproval {
            text += " - Needs permission"
        } else if isActive {
            text += " - Working"
        } else {
            text += " - Idle"
        }
        return text
    }

    private func startBlinkingIfNeeded() {
        guard shouldBlink else { return }
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            isBlinking = true
        }
    }
}

/// Compact version showing just the dots without additional styling
struct SessionDotsIndicatorCompact: View {
    @ObservedObject var sessionDiscovery = SessionDiscovery.shared
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(sessionDiscovery.availableSessions) { session in
                SessionDot(
                    session: session,
                    state: sessionMonitor.instances.first { $0.sessionId == session.id },
                    showTooltip: false
                )
                .onTapGesture {
                    IDEFocuser.focusIDE(for: session)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Normal size
        SessionDotsIndicator()
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)

        // Compact size
        SessionDotsIndicatorCompact()
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
    }
    .padding()
}
