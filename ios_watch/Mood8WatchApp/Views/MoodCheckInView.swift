//
//  MoodCheckInView.swift
//  Mood8WatchApp
//
//  Quick log screen — three sliders + save. Designed to be completable in
//  under 3 seconds: defaults are pre-filled to the user's last entry (or 0.5
//  baseline) so often the user just taps "Save".
//

import SwiftUI
import WatchKit

@available(watchOS 10.0, *)
struct MoodCheckInView: View {

    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    // Slider values. Initialised in `onAppear` from the latest entry so check-ins
    // start from "where you were last time" — most people change in small deltas.
    @State private var mood: Double = 0.6
    @State private var energy: Double = 0.6
    @State private var focus: Double = 0.6

    /// Brief confirmation overlay after save, before auto-dismiss.
    @State private var showSavedFlash = false

    var body: some View {
        ZStack {
            // Background
            AppColors.bgDeep.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    GlowSlider(label: "Mood",
                               systemImage: "heart.fill",
                               value: $mood)
                    GlowSlider(label: "Energy",
                               systemImage: "bolt.fill",
                               value: $energy)
                    GlowSlider(label: "Focus",
                               systemImage: "scope",
                               value: $focus)

                    QuickButton(title: "Save",
                                systemImage: "checkmark.circle.fill") {
                        save()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }

            // Saved confirmation — fades in then out, view dismisses afterward.
            // Lives at the ZStack root so it covers the sliders fully.
            if showSavedFlash {
                ZStack {
                    AppColors.bgDeep.opacity(0.92).ignoresSafeArea()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(AppGradients.button)
                        Text("Saved")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundStyle(AppColors.ink)
                    }
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Check-in")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: prefillFromLatest)
    }

    // MARK: - Actions

    /// Seed the sliders from the most recent entry. Falls back to 0.6 — slightly
    /// optimistic so the orb starts warm even on a blank slate.
    private func prefillFromLatest() {
        guard let latest = store.latest else { return }
        mood = latest.mood
        energy = latest.energy
        focus = latest.focus
    }

    /// Persist + haptic + confirmation flash + dismiss.
    private func save() {
        store.record(mood: mood, energy: energy, focus: focus)

        // Heavier haptic for the commit action than the per-tick clicks.
        WKInterfaceDevice.current().play(.notification)

        withAnimation(.easeInOut(duration: 0.2)) {
            showSavedFlash = true
        }

        // Pop back to home after a short beat so the user sees the confirmation.
        // 700ms feels like acknowledgement without dragging the interaction past 3s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            dismiss()
        }
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview {
    NavigationStack {
        MoodCheckInView()
            .environmentObject(DataStore.shared)
    }
}
#endif
