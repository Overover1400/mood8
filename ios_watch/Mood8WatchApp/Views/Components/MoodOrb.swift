//
//  MoodOrb.swift
//  Mood8WatchApp
//
//  Animated radial-gradient orb — the visual centerpiece of the app.
//
//  Animation strategy: use `TimelineView(.animation)` so the orb keeps moving
//  even while the rest of the view is idle. We compute scale & glow from the
//  elapsed time, so there's no @State to update — cheaper for the watch's CPU.
//

import SwiftUI

@available(watchOS 10.0, *)
struct MoodOrb: View {

    /// Diameter in points. Tune per host view; HomeView uses ~96, MoodCheckIn uses ~80.
    var size: CGFloat = 96

    /// 0…1 — how "vibrant" the orb is. Drives glow intensity. Bind to the user's
    /// most recent composite mood score so the orb gets brighter as they feel better.
    var intensity: Double = 0.7

    var body: some View {
        // TimelineView re-evaluates `body` at the requested cadence — `.animation`
        // means "as fast as the system thinks is reasonable for animation", which on
        // watchOS throttles itself nicely when the wrist is down.
        TimelineView(.animation) { context in
            // Time since reference date as a continuous double — feed into sin/cos
            // for smooth, deterministic motion (no animation curves needed).
            let t = context.date.timeIntervalSinceReferenceDate

            // Slow breathing: ±4% scale every ~3.5s.
            let breathe = 1.0 + sin(t / 3.5 * .pi) * 0.04

            // Independent glow pulse, slightly out of phase, so it doesn't feel mechanical.
            let glow = 0.55 + (sin(t / 2.7 * .pi) + 1) / 2 * 0.35

            ZStack {
                // Outer glow halo — soft blur behind the orb. Opacity scales with `intensity`.
                Circle()
                    .fill(AppColors.pinkLight)
                    .frame(width: size * 1.35, height: size * 1.35)
                    .blur(radius: size * 0.25)
                    .opacity(glow * intensity)

                // The orb itself — radial gradient defined in Theme/Gradients.swift.
                Circle()
                    .fill(AppGradients.orb)
                    .frame(width: size, height: size)
                    // Subtle inner highlight ring (purple-light) — gives it dimensionality.
                    .overlay(
                        Circle()
                            .stroke(AppColors.purpleLight.opacity(0.25), lineWidth: 1)
                    )
                    .scaleEffect(breathe)
                    // Drop shadow keeps the orb feeling lifted off the dark background.
                    .shadow(color: AppColors.pink.opacity(0.45),
                            radius: 16, x: 0, y: 6)
            }
            // Compositing group merges the layers into one render pass before applying
            // shadow/blend — fixes flickering on smaller watch sizes (40/41mm).
            .compositingGroup()
        }
        // The TimelineView's intrinsic size is unbounded, so pin the frame here.
        .frame(width: size * 1.35, height: size * 1.35)
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview("Default") {
    ZStack {
        AppColors.bgDeep.ignoresSafeArea()
        MoodOrb(size: 96, intensity: 0.8)
    }
}
#endif
