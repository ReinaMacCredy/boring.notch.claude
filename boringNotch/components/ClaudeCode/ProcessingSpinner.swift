//
//  ProcessingSpinner.swift
//  ClaudeIsland
//
//  Animated symbol spinner for processing state
//

import Combine
import SwiftUI

struct ProcessingSpinner: View {
    var color: Color = TerminalColors.prompt

    @State private var phase: Int = 0
    @State private var timerCancellable: Cancellable?

    private let symbols = ["·", "✢", "✳", "∗", "✻", "✽"]
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common)

    var body: some View {
        Text(symbols[phase % symbols.count])
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(color)
            .frame(width: 12, alignment: .center)
            .onReceive(timer) { _ in
                phase = (phase + 1) % symbols.count
            }
            .onAppear {
                timerCancellable = timer.connect()
            }
            .onDisappear {
                timerCancellable?.cancel()
                timerCancellable = nil
            }
    }
}

#Preview {
    ProcessingSpinner()
        .frame(width: 30, height: 30)
        .background(.black)
}
