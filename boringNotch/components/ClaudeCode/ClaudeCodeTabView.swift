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
        .frame(maxWidth: .infinity, alignment: .top)
        .onChange(of: vm.notchState) { _, newState in
            if newState == .open {
                claudeVM.notchOpen(reason: .click)
            } else {
                claudeVM.notchClose()
            }
        }
        .onChange(of: claudeVM.contentType) { _, newContent in
            // Only resize when entering/exiting chat or menu (not for instances,
            // which uses the default openNotchSize)
            guard vm.notchState == .open else { return }
            let newSize = claudeVM.openedSize
            if newSize != vm.notchSize {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    vm.notchSize = newSize
                }
            }
        }
    }
}
