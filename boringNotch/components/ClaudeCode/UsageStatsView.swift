//
//  UsageStatsView.swift
//  boringNotch
//
//  Compact usage stat pills displayed above the instances list.
//  Design: Option D - colored pills showing 5h%, 7d%, extra credits, reset time.
//

import SwiftUI

struct UsageStatsView: View {
    @ObservedObject var usageService: UsageService

    private var usage: UsageData { usageService.usage }

    var body: some View {
        if usageService.isLoading && usage == .empty {
            loadingState
        } else if usage != .empty {
            HStack(spacing: 4) {
                pillsRow

                refreshButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        } else if usageService.lastError != nil {
            errorState
                .contentShape(Rectangle())
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 56, height: 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    // MARK: - Error State

    private var errorState: some View {
        HStack(spacing: 6) {
            Text(usageService.lastError ?? "Failed to load")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
                .lineLimit(1)

            Button {
                Task { await usageService.fetch() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    // MARK: - Pills Row

    private var pillsRow: some View {
        HStack(spacing: 6) {
            // 5-hour utilization
            usagePill(
                value: usage.fiveHour.utilization,
                label: "5h",
                color: pillColor(for: usage.fiveHour.utilization)
            )

            // 7-day utilization
            usagePill(
                value: usage.sevenDay.utilization,
                label: "7d",
                color: pillColor(for: usage.sevenDay.utilization)
            )

            // Sonnet (if present and distinct)
            if let sonnet = usage.sevenDaySonnet {
                usagePill(
                    value: sonnet.utilization,
                    label: "Snt",
                    color: pillColor(for: sonnet.utilization)
                )
            }

            // Extra usage credits (hide when both are zero)
            if let extra = usage.extraUsage, extra.usedCredits > 0 || extra.monthlyLimit > 0 {
                creditsPill(used: extra.usedCredits, limit: extra.monthlyLimit)
            }

            // Reset time (shortest window)
            if let resetDate = nearestReset {
                resetPill(date: resetDate)
            }
        }
    }

    // MARK: - Refresh Button

    private var refreshButton: some View {
        Button {
            Task { await usageService.fetch() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.2))
                .padding(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pill Components

    private func usagePill(value: Double, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)

            Text("\(Int(value))%")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
    }

    private func creditsPill(used: Double, limit: Double) -> some View {
        HStack(spacing: 3) {
            Text(formatCredits(used))
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.35))

            Text("/")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.2))

            Text(formatCredits(limit))
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private func resetPill(date: Date) -> some View {
        HStack(spacing: 3) {
            Text(formatReset(date))
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private func pillColor(for utilization: Double) -> Color {
        if utilization < 50 {
            return Color(red: 0.29, green: 0.87, blue: 0.50) // green #4ade80
        } else if utilization < 80 {
            return Color(red: 0.98, green: 0.75, blue: 0.14) // amber #fbbf24
        } else {
            return Color(red: 0.97, green: 0.44, blue: 0.44) // red #f87171
        }
    }

    private var nearestReset: Date? {
        let candidates = [usage.fiveHour.resetsAt, usage.sevenDay.resetsAt].compactMap { $0 }
        let future = candidates.filter { $0 > Date() }
        return future.min()
    }

    private func formatCredits(_ cents: Double) -> String {
        if cents == 0 { return "$0" }
        let dollars = cents / 100
        if dollars < 1 {
            return String(format: "%.0f\u{00A2}", cents)
        }
        return String(format: "$%.2f", dollars)
    }

    private func formatReset(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "now" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
