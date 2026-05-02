//
//  HomeView.swift
//  Mood8WatchApp
//
//  The root screen the user sees when they raise their wrist.
//
//  Layout, top-to-bottom:
//    1. Greeting line ("Good afternoon")
//    2. Mood orb (animated, intensity bound to last entry)
//    3. Composite score readout ("7.2 /10  ·  Today")
//    4. "Quick log" primary button → MoodCheckInView
//    5. NavigationLinks to Streak and Routine
//
//  All vertical content lives inside a ScrollView so smaller watches can pan
//  rather than truncate.
//

import SwiftUI

@available(watchOS 10.0, *)
struct HomeView: View {

    @EnvironmentObject private var store: DataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // MARK: Greeting
                Text(greeting)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: Mood orb
                // Intensity comes from the latest entry's composite score.
                // Falls back to 0.7 (mildly glowing) before the user has logged anything.
                MoodOrb(
                    size: 72,
                    intensity: store.latest?.compositeScore ?? 0.7
                )

                // MARK: Score readout
                if let latest = store.latest {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(latest.displayScore)
                            .font(.system(size: 30, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(AppColors.ink)
                        Text("/10")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.inkDim)
                    }
                } else {
                    // First-run state — invite the user.
                    Text("How are you,\nright now?")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.inkSoft)
                }

                // MARK: Primary action
                NavigationLink {
                    MoodCheckInView()
                } label: {
                    // Wrap as label to inherit the link's tap behavior; QuickButton
                    // expects a closure but we want a NavigationLink, so use a plain
                    // styled HStack here and let NavigationLink handle the tap.
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Quick log")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppGradients.button)
                    .clipShape(Capsule())
                    .shadow(color: AppColors.pink.opacity(0.5), radius: 8, y: 4)
                }
                // Strip the default link chevron / box — we provide our own pill.
                .buttonStyle(.plain)

                // MARK: Secondary navigation
                HStack(spacing: 8) {
                    NavigationLink {
                        StreakView()
                    } label: {
                        ghostChip(icon: "flame.fill",
                                  text: "\(store.currentStreak)d")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        RoutineView()
                    } label: {
                        ghostChip(icon: "list.bullet",
                                  text: "Today")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
        // Background applies to the whole scroll area, including the safe-area inset
        // — the watch's chamfered top corners look cleaner with a full-bleed background.
        .background(
            ZStack {
                AppColors.bgDeep.ignoresSafeArea()
                // Two soft ambient orbs in opposite corners for atmosphere.
                AppGradients.ambientPurple
                    .frame(width: 180, height: 180)
                    .offset(x: 60, y: -120)
                AppGradients.ambientPink
                    .frame(width: 160, height: 160)
                    .offset(x: -70, y: 140)
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Mood8")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    /// Time-aware greeting, mirroring the Flutter `_greeting(hour)` helper.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case ..<5:  return "Late night"
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:    return "Good night"
        }
    }

    /// Small pill chip used for secondary nav. Local helper so HomeView stays self-contained.
    @ViewBuilder
    private func ghostChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(AppColors.inkSoft)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            ZStack {
                Capsule().fill(AppColors.bgCard.opacity(0.7))
                Capsule().strokeBorder(AppColors.purple.opacity(0.3), lineWidth: 1)
            }
        )
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(DataStore.shared)
    }
}
#endif
