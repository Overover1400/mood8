//
//  GlowSlider.swift
//  Mood8WatchApp
//
//  Custom slider for the watch — operated primarily via the Digital Crown
//  because finger-dragging on a 40mm screen is fiddly.
//
//  Visual: gradient-filled track with soft glow, mirrors the Flutter GlowSlider
//  in lib/widgets/glow_slider.dart.
//

import SwiftUI
import WatchKit

@available(watchOS 10.0, *)
struct GlowSlider: View {

    /// Slider label — "Mood", "Energy", "Focus".
    let label: String

    /// SF Symbol shown next to the label. Use `heart.fill`, `bolt.fill`, etc.
    let systemImage: String

    /// Two-way binding into the parent's state. Range 0…1 (matches MoodEntry's
    /// normalized storage so there's no conversion at the edges).
    @Binding var value: Double

    /// Tracks whether the crown is currently focused on this slider.
    /// On watchOS only one view can own the crown at a time, so callers are
    /// expected to manage focus themselves (e.g. via `.focused()` chains).
    @FocusState private var isFocused: Bool

    /// Last whole-tenth haptic'd at, so we don't fire haptics on every micro-change
    /// from the crown (which would be both noisy and battery-hungry).
    @State private var lastHapticTenth: Int = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // ── Label row ─────────────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.inkSoft)

                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.inkSoft)

                Spacer()

                // Score readout: serif italic for the number, dim sans for "/10".
                // Matches the Flutter slider's elegant numeric display.
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", value * 10))
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(AppColors.ink)
                    Text("/10")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppColors.inkDim)
                }
            }

            // ── Track ─────────────────────────────────────────────────────
            // GeometryReader lets us draw the active fill at exactly value × width.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Inactive base track.
                    Capsule()
                        .fill(AppColors.bgCard)
                        .frame(height: 6)

                    // Active gradient fill.
                    Capsule()
                        .fill(AppGradients.button)
                        .frame(width: max(6, geo.size.width * value), height: 6)
                        // Soft glow under the fill — uses the same gradient blurred.
                        .shadow(color: AppColors.pink.opacity(0.55),
                                radius: 6, x: 0, y: 0)

                    // Thumb — small white dot with gradient ring.
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle().stroke(AppGradients.button, lineWidth: 2)
                        )
                        .shadow(color: AppColors.pinkLight.opacity(0.7),
                                radius: 4)
                        // Position: subtract half the thumb width so it stays centered.
                        .offset(x: max(0, geo.size.width * value - 5))
                }
            }
            .frame(height: 14) // enough room for thumb + glow
            // Crown control: rotates value 0…1 with a sensible step.
            // `from: 0, through: 1, by: 0.05` gives 20 stops — fine enough for a
            // 1–10 score, coarse enough for haptic feedback to feel discrete.
            .focusable(true)
            .focused($isFocused)
            .digitalCrownRotation(
                $value,
                from: 0.0,
                through: 1.0,
                by: 0.01,           // smooth scrub; haptic gating handled below
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
            // Manual haptic gating — fire a tiny "click" each time the value
            // crosses a tenth. Avoids the system's chatter while keeping tactile feedback.
            .onChange(of: value) { _, newValue in
                let tenth = Int((newValue * 10).rounded())
                if tenth != lastHapticTenth {
                    lastHapticTenth = tenth
                    WKInterfaceDevice.current().play(.click)
                }
            }
        }
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview {
    StatefulPreviewWrapper(0.65) { binding in
        ZStack {
            AppColors.bgDeep.ignoresSafeArea()
            GlowSlider(label: "Mood", systemImage: "heart.fill", value: binding)
                .padding()
        }
    }
}

/// Preview helper — `#Preview` blocks can't hold `@State`, so we wrap.
@available(watchOS 10.0, *)
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content
    init(_ initial: Value, @ViewBuilder _ content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }
    var body: some View { content($value) }
}
#endif
