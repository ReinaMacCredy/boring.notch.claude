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
            sessionMonitor.startMonitoring()
        }
        .onChange(of: vm.notchState) { _, newState in
            // Sync boring.notch open/close with claude-island's NotchViewModel
            if newState == .open {
                claudeVM.notchOpen(reason: .click)
            } else {
                claudeVM.notchClose()
            }
        }
        .onChange(of: claudeVM.contentType) { _, _ in
            // Update notch size when content type changes
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
