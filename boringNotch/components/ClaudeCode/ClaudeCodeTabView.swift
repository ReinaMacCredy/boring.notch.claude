//
//  ClaudeCodeTabView.swift
//  boringNotch
//
//  Adapter that integrates claude-island's Claude Code views
//  into boring.notch's tab system. State (claudeVM, sessionMonitor)
//  is owned by ContentView so it persists across notch open/close.
//

import SwiftUI

struct ClaudeCodeTabView: View {
    @ObservedObject var claudeVM: NotchViewModel
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor

    var body: some View {
        Group {
            switch claudeVM.contentType {
            case .instances:
                ClaudeInstancesView(
                    sessionMonitor: sessionMonitor,
                    viewModel: claudeVM
                )
            case .menu:
                NotchMenuView(viewModel: claudeVM)
            case .chat(let session):
                ChatView(
                    sessionId: session.sessionId,
                    initialSession: session,
                    sessionMonitor: sessionMonitor,
                    viewModel: claudeVM
                )
            }
        }
        .frame(width: claudeVM.openedSize.width - 24, alignment: .top)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.8, anchor: .top)
                    .combined(with: .opacity)
                    .animation(.smooth(duration: 0.35)),
                removal: .opacity.animation(.easeOut(duration: 0.15))
            )
        )
    }
}
