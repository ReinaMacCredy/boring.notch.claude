//
//  Array+SafeSubscript.swift
//  boringNotch
//
//  Safe subscript for bounds-checked array access.
//

import Foundation

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
