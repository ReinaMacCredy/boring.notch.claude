//
//  ContextBar.swift
//  boringNotch
//
//  Claude Code context usage progress bar
//

import SwiftUI

struct ContextBar: View {
    let percentage: Double
    var width: CGFloat = 60
    var height: CGFloat = 8

    private var fillColor: Color {
        contextPercentageColor(for: percentage)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.3))

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(fillColor)
                    .frame(width: max(0, geo.size.width * min(1, percentage / 100)))
            }
        }
        .frame(width: width, height: height)
    }
}

struct ContextBarWithLabel: View {
    let percentage: Double
    let tokensUsed: Int
    let tokensTotal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Context")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(percentage))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.primary)
            }

            ContextBar(percentage: percentage, width: .infinity, height: 6)
                .frame(maxWidth: .infinity)

            HStack {
                Text(tokensUsed.formattedTokenCount)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                Text("used")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text((tokensTotal - tokensUsed).formattedTokenCount)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                Text("left")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

}

#Preview {
    VStack(spacing: 20) {
        ContextBar(percentage: 25)
        ContextBar(percentage: 55)
        ContextBar(percentage: 80)
        ContextBar(percentage: 95)

        ContextBarWithLabel(
            percentage: 42,
            tokensUsed: 84000,
            tokensTotal: 200000
        )
        .frame(width: 200)
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
    }
    .padding()
}
