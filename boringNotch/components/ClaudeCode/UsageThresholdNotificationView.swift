//
//  UsageThresholdNotificationView.swift
//  boringNotch
//
//  Battery-style sneak peek notification for Claude 5h usage thresholds.
//  Mirrors the battery notification layout: text (left) | notch | bar (right).
//

import SwiftUI

struct UsageThresholdNotificationView: View {
    let utilization: CGFloat // 0-100, from expandingView.value
    let closedNotchWidth: CGFloat
    let effectiveClosedNotchHeight: CGFloat

    private var thresholdColor: Color {
        if utilization < 50 {
            return Color(red: 0.29, green: 0.87, blue: 0.50) // green
        } else if utilization < 80 {
            return Color(red: 0.98, green: 0.75, blue: 0.14) // amber
        } else {
            return Color(red: 0.97, green: 0.44, blue: 0.44) // red
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: status text
            HStack(spacing: 6) {
                Text("Session")
                    .font(.subheadline)
                    .foregroundStyle(.white)

                Text("\(Int(utilization))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(thresholdColor)
            }

            // Center: black notch separator
            Rectangle()
                .fill(.black)
                .frame(width: closedNotchWidth + 10)

            // Right: mini usage bar
            HStack(spacing: 6) {
                UsageMiniBar(utilization: utilization, color: thresholdColor)
                    .frame(width: 30, height: 8)

                Text("5h")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(width: 76, alignment: .trailing)
        }
        .frame(height: effectiveClosedNotchHeight, alignment: .center)
    }
}

// MARK: - Mini Progress Bar

struct UsageMiniBar: View {
    let utilization: CGFloat // 0-100
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))

                Capsule()
                    .fill(color)
                    .frame(width: max(geo.size.height, geo.size.width * (utilization / 100)))
            }
        }
    }
}
