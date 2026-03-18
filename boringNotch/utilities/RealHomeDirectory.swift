//
//  RealHomeDirectory.swift
//  boringNotch
//
//  Returns the real user home directory, bypassing sandbox container redirection.
//

import Foundation

/// Returns the real user home directory (e.g., /Users/username),
/// not the sandbox container path that NSHomeDirectory() returns.
func realHomeDirectory() -> String {
    if let pw = getpwuid(getuid()) {
        return String(cString: pw.pointee.pw_dir)
    }
    return NSHomeDirectory()
}
