//
//  StreakView.swift
//  Mood8WatchApp
//
//  Hero display for the user's current consecutive-day streak.
//
//  Identity-based progress (Atomic Habits): the number is huge, italic, and the
//  only thing on screen — the user's job is to *be the kind of person* who keeps it
//  going, not to chase coins or badges (per CLAUDE.md "Don't Do" list).
//

import SwiftUI

@available(watchOS 10.0, *)
struct StreakView: View {

    @EnvironmentObject private var store: DataStore

    var body: some View {
        ZStack {
            AppColors.bgDeep.ignoresSafeArea()

            // Soft ambient pink behind the number — underscores the "🔥" theme
            // without resorting to literal flame artwork.
            AppGradients.ambientPink
                .frame(width: 240, height: 240)
                .blur(radius: 20)

            VStack(spacing: 6) {
                // The streak number — gradient-filled serif italic, oversized.
                Text("\(store.currentStreak)")
                    .font(.system(size: 64, weight: .regular, design: .serif))
                    .italic()
                    // `foregroundStyle` accepts a ShapeStyle, so we can pass the
                    // gradient directly — no `.mask` gymnastics needed on watchOS 10+.
                    .foregroundStyle(AppGradients.primary)
                    // Tighten line height so the number sits flush above the label.
                    .padding(.bottom, -8)

                Text(store.currentStreak == 1 ? "day streak" : "day streak")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.inkSoft)

                // Flame emoji as a small accent. Kept emoji-only (not "Fire 🔥")
                // to avoid the childish-gamification anti-pattern in CLAUDE.md.
                Text("🔥")
                    .font(.system(size: 22))
                    .padding(.top, 4)

                // Gentle context line — speaks to identity, not metric.
                if store.currentStreak > 0 {
                    Text(identityLine)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.inkDim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                } else {
                    Text("Start today.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.inkDim)
                }
            }
        }
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Phrasing escalates with streak length — keeps the screen feeling fresh
    /// rather than printing the same line forever.
    private var identityLine: String {
        switch store.currentStreak {
        case 1...6:    return "You're showing up."
        case 7...20:   return "This is who you are."
        case 21...49:  return "A practice, not an attempt."
        default:       return "Foundational."
        }
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview {
    NavigationStack {
        StreakView()
            .environmentObject(DataStore.shared)
    }
}
#endif
