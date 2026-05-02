//
//  RoutineView.swift
//  Mood8WatchApp
//
//  Today's routine at a glance.
//
//  MVP scope: hardcoded sample routines (matching the Flutter "Up next" section).
//  When the iPhone companion app ships, this list will sync via WatchConnectivity.
//

import SwiftUI

@available(watchOS 10.0, *)
struct RoutineView: View {

    /// Local model — kept private so it doesn't pollute the shared Models/ folder
    /// until routine data has a real persistence story.
    private struct RoutineItem: Identifiable {
        let id = UUID()
        let time: String        // e.g. "14:30"
        let title: String       // e.g. "Deep work block"
        let subtitle: String    // e.g. "Mood8 — design system"
        let symbol: String      // SF Symbol name
        let isNow: Bool         // pulses gradient border if true
    }

    /// Hardcoded sample routine matching the Flutter UpNext section verbatim.
    /// Order is chronological so the "NOW" item naturally appears at the top
    /// of the relevant time window.
    private let items: [RoutineItem] = [
        .init(time: "14:30",
              title: "Deep work block",
              subtitle: "Mood8 — design system",
              symbol: "brain.head.profile",
              isNow: true),
        .init(time: "16:00",
              title: "Walk & sunlight",
              subtitle: "20 min · zone 2",
              symbol: "figure.walk",
              isNow: false),
        .init(time: "19:00",
              title: "Evening reset",
              subtitle: "Journal · stretch · plan",
              symbol: "moon.stars.fill",
              isNow: false),
    ]

    var body: some View {
        ZStack {
            AppColors.bgDeep.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        row(for: item)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// One row in the routine list. Extracted so the body stays scannable.
    @ViewBuilder
    private func row(for item: RoutineItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Icon tile.
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.bgCard)
                    .frame(width: 36, height: 36)
                Image(systemName: item.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppGradients.primary)
            }

            // Title + subtitle.
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.time)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.inkDim)

                    if item.isNow {
                        // "NOW" pill — visually emphatic, kept tiny.
                        Text("NOW")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(AppGradients.button)
                            .clipShape(Capsule())
                    }
                }
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.inkDim)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.bgCard.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            // "NOW" rows get the brand stroke; others a faint divider.
                            item.isNow
                                ? AnyShapeStyle(AppGradients.primary)
                                : AnyShapeStyle(AppColors.purple.opacity(0.15)),
                            lineWidth: item.isNow ? 1.5 : 1
                        )
                )
        )
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview {
    NavigationStack {
        RoutineView()
    }
}
#endif
