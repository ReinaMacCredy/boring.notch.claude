//
//  ClaudeCodeTabView.swift
//  boringNotch
//
//  Adapter that integrates claude-island's Claude Code views
//  into boring.notch's tab system. Matches claude-island's transition
//  animations exactly: container size and content swap happen in the
//  same synchronous transaction, animated by .animation() modifiers.
//

import SwiftUI

struct ClaudeCodeTabView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject private var claudeVM = NotchViewModel()
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()

    var body: some View {
        // Content with asymmetric transitions matching claude-island.
        // The Group switch triggers SwiftUI's view identity change,
        // which fires the .transition() modifiers.
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
        .onAppear {
            // Wire up the BoringViewModel reference so size changes
            // are synchronous with content type changes
            claudeVM.boringVM = vm
        }
        .onChange(of: vm.notchState) { _, newState in
            if newState == .open {
                claudeVM.notchOpen(reason: .click)
            } else {
                claudeVM.notchClose()
            }
        }
    }
}
