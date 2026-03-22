//
//  NotchViewModel.swift
//  boringNotch
//
//  Adapted from ClaudeIsland's NotchViewModel.
//  Handles Claude tab internal navigation (instances/chat/menu) and sizing.
//  Open/close, hover, and gesture handling remain in BoringViewModel.
//
//  Key design: when contentType changes, boringVM.notchSize is updated
//  in the same synchronous block so both animate together (matching
//  claude-island where notchSize is a computed var).
//

import AppKit
import Combine
import Defaults
import SwiftUI

enum NotchStatus: Equatable {
    case closed
    case opened
    case popping
}

enum NotchOpenReason {
    case click
    case hover
    case notification
    case boot
    case unknown
}

enum NotchContentType: Equatable {
    case instances
    case menu
    case chat(SessionState)

    var id: String {
        switch self {
        case .instances: return "instances"
        case .menu: return "menu"
        case .chat(let session): return "chat-\(session.sessionId)"
        }
    }
}

@MainActor
class NotchViewModel: ObservableObject {
    // MARK: - Published State

    @Published var status: NotchStatus = .closed
    @Published var openReason: NotchOpenReason = .unknown
    @Published var contentType: NotchContentType = .instances
    @Published var isPinned: Bool = false

    /// Reference to boring.notch's view model for synchronized size updates
    weak var boringVM: BoringViewModel?

    // MARK: - Sizing

    /// Dynamic opened size based on content type.
    /// Instances use the standard notch height; chat expands taller.
    var openedSize: CGSize {
        switch contentType {
        case .chat:
            return CGSize(width: openNotchSize.width, height: 480)
        case .menu:
            return CGSize(width: openNotchSize.width, height: 300)
        case .instances:
            return CGSize(width: openNotchSize.width, height: CGFloat(Defaults[.claudeTabHeight]))
        }
    }

    // MARK: - Private

    private var currentChatSession: SessionState?

    /// Set contentType and synchronously update boringVM.notchSize
    /// so both changes are in the same SwiftUI transaction.
    private func setContentType(_ newType: NotchContentType) {
        contentType = newType
        syncSize()
    }

    private func syncSize() {
        guard let vm = boringVM, vm.notchState == .open else { return }
        let target = openedSize
        if vm.notchSize != target {
            vm.notchSize = target
        }
    }

    // MARK: - Actions

    func notchOpen(reason: NotchOpenReason = .unknown) {
        openReason = reason
        status = .opened

        if reason == .notification {
            currentChatSession = nil
            return
        }

        if let chatSession = currentChatSession {
            if case .chat(let current) = contentType, current.sessionId == chatSession.sessionId {
                // Content type unchanged but notchSize may have been reset
                // (e.g. switching away from Claude tab shrinks the notch).
                syncSize()
                return
            }
            setContentType(.chat(chatSession))
        } else {
            // No saved chat session but contentType may still be .chat from
            // a tab switch (notchClose is only called on notch close, not tab switch).
            syncSize()
        }
    }

    func notchClose() {
        isPinned = false
        if case .chat(let session) = contentType {
            currentChatSession = session
        }
        status = .closed
        contentType = .instances
        // Size reset is handled by BoringViewModel.close()
    }

    func toggleMenu() {
        setContentType(contentType == .menu ? .instances : .menu)
    }

    func showChat(for session: SessionState) {
        if case .chat(let current) = contentType, current.sessionId == session.sessionId {
            return
        }
        setContentType(.chat(session))
    }

    func exitChat() {
        isPinned = false
        currentChatSession = nil
        setContentType(.instances)
    }
}
