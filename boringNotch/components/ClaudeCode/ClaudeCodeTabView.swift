//
//  ClaudeCodeTabView.swift
//  boringNotch
//
//  Adapter that integrates claude-island's Claude Code views
//  into boring.notch's tab system.
//

import SwiftUI

struct ClaudeCodeTabView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject private var claudeVM = NotchViewModel()
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()

    var body: some View {
        VStack(spacing: 0) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            // HookSocketServer is started at app launch in AppDelegate.
            // Just set correct size when this view appears.
            updateNotchSize()
        }
        .onChange(of: vm.notchState) { _, newState in
            if newState == .open {
                claudeVM.notchOpen(reason: .click)
                // Resize immediately when opening to Claude tab
                updateNotchSize()
            } else {
                claudeVM.notchClose()
            }
        }
        .onChange(of: claudeVM.contentType) { _, _ in
            updateNotchSize()
        }
    }

    private func updateNotchSize() {
        let newSize = claudeVM.openedSize
        if vm.notchState == .open {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                vm.notchSize = newSize
            }
        }
    }
}
