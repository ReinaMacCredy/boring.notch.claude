//
//  ClaudeCodeTabView.swift
//  boringNotch
//
//  Adapter that integrates claude-island's Claude Code views
//  into boring.notch's tab system. Matches claude-island's transition
//  animations: spring-driven container resize + asymmetric content transitions.
//

import SwiftUI

struct ClaudeCodeTabView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject private var claudeVM = NotchViewModel()
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()

    // Match claude-island animation parameters exactly
    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)

    var body: some View {
        // Content with asymmetric transitions matching claude-island
        Group {
            switch claudeVM.contentType {
            case .instances:
                ClaudeInstancesView(
                    sessionMonitor: sessionMonitor,
                    viewModel: claudeVM
                )
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .top)
                            .combined(with: .opacity)
                            .animation(.smooth(duration: 0.35)),
                        removal: .opacity.animation(.easeOut(duration: 0.15))
                    )
                )
            case .menu:
                NotchMenuView(viewModel: claudeVM)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .top)
                            .combined(with: .opacity)
                            .animation(.smooth(duration: 0.35)),
                        removal: .opacity.animation(.easeOut(duration: 0.15))
                    )
                )
            case .chat(let session):
                ChatView(
                    sessionId: session.sessionId,
                    initialSession: session,
                    sessionMonitor: sessionMonitor,
                    viewModel: claudeVM
                )
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
        .frame(maxWidth: .infinity, alignment: .top)
        // Animate container size changes between content types (matches claude-island)
        .animation(openAnimation, value: vm.notchSize)
        .onChange(of: vm.notchState) { _, newState in
            if newState == .open {
                claudeVM.notchOpen(reason: .click)
            } else {
                claudeVM.notchClose()
            }
        }
        .onChange(of: claudeVM.contentType) { _, _ in
            guard vm.notchState == .open else { return }
            let newSize = claudeVM.openedSize
            if newSize != vm.notchSize {
                withAnimation(openAnimation) {
                    vm.notchSize = newSize
                }
            }
        }
    }
}
