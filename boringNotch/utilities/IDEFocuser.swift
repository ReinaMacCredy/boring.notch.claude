//
//  IDEFocuser.swift
//  boringNotch
//
//  Brings the IDE running Claude Code to the front.
//  Extracted from ClaudeCodeManager (Phase 6.3).
//

import AppKit

enum IDEFocuser {
    /// Bring the IDE running Claude Code to the front
    /// - Parameter session: The session whose IDE to focus. If nil, focuses the selected session.
    @MainActor
    static func focusIDE(for session: ClaudeSession? = nil) {
        guard let targetSession = session ?? SessionDiscovery.shared.selectedSession else {
            print("[IDEFocuser] No session to focus")
            return
        }

        let ideName = targetSession.ideName.lowercased()
        #if DEBUG
        print("[IDEFocuser] Attempting to focus IDE: \(targetSession.ideName)")
        #endif

        // Map common IDE names to bundle identifiers
        let bundleIdentifiers: [String] = {
            if ideName.contains("cursor") {
                return ["com.todesktop.230313mzl4w4u92"]
            } else if ideName.contains("code") || ideName.contains("vscode") {
                return ["com.microsoft.VSCode", "com.visualstudio.code.oss"]
            } else if ideName.contains("windsurf") {
                return ["com.codeium.windsurf"]
            } else if ideName.contains("zed") {
                return ["dev.zed.Zed"]
            } else {
                // Try to find by process ID as fallback
                return []
            }
        }()

        // Try to activate by bundle identifier first
        for bundleId in bundleIdentifiers {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                #if DEBUG
                print("[IDEFocuser] Found app by bundle ID: \(bundleId)")
                #endif
                app.activate(options: [.activateIgnoringOtherApps])
                return
            }
        }

        // Fallback: find by PID
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.processIdentifier == Int32(targetSession.pid) }) {
            #if DEBUG
            print("[IDEFocuser] Found app by PID: \(targetSession.pid)")
            #endif
            app.activate(options: [.activateIgnoringOtherApps])
            return
        }

        // Last resort: try to find any app with matching name
        if let app = runningApps.first(where: {
            $0.localizedName?.lowercased().contains(ideName) == true
        }) {
            #if DEBUG
            print("[IDEFocuser] Found app by name match: \(app.localizedName ?? "unknown")")
            #endif
            app.activate(options: [.activateIgnoringOtherApps])
            return
        }

        print("[IDEFocuser] Could not find IDE to focus")
    }
}
