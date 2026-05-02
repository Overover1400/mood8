//
//  Gradients.swift
//  Mood8WatchApp
//
//  Reusable gradients matching the Flutter palette in lib/theme/app_theme.dart.
//
//  Flutter's `Alignment.topLeft → Alignment.bottomRight` maps to SwiftUI's
//  `.topLeading → .bottomTrailing` (SwiftUI uses leading/trailing for RTL safety).
//

import SwiftUI

@available(watchOS 10.0, *)
enum AppGradients {

    /// Primary brand gradient — purple → pink → pink-light, diagonal.
    /// Used for hero text, the mood orb stroke, and glow effects.
    static let primary = LinearGradient(
        colors: [AppColors.purple, AppColors.pink, AppColors.pinkLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Button gradient — left-to-right sweep through the brand stops.
    /// Slightly lighter than `primary` to read well under the glossy watch face.
    static let button = LinearGradient(
        colors: [AppColors.purpleLight, AppColors.pinkLight, AppColors.blueAccent],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Soft 15%-opacity gradient — pill chips, secondary surfaces.
    /// Computed lazily because `Color.opacity` returns a non-`const` value.
    static let soft = LinearGradient(
        colors: [
            AppColors.purple.opacity(0.15),
            AppColors.pink.opacity(0.15),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Radial gradient for the mood orb — center is highlight, edge is deep purple.
    /// Stops mirror the Flutter version exactly so both platforms look identical.
    static let orb = RadialGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: "#F472B6"), location: 0.00), // hot center
            .init(color: Color(hex: "#C084FC"), location: 0.40),
            .init(color: Color(hex: "#A855F7"), location: 0.75),
            .init(color: Color(hex: "#6B21A8"), location: 1.00), // cold edge
        ]),
        center: UnitPoint(x: 0.4, y: 0.35), // off-center highlight feels more alive
        startRadius: 0,
        endRadius: 90
    )

    /// Background ambience — two large, low-opacity blobs behind the home view.
    /// Defined as separate values so the home view can position them independently.
    static let ambientPurple = RadialGradient(
        colors: [AppColors.purple.opacity(0.30), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 90
    )
    static let ambientPink = RadialGradient(
        colors: [AppColors.pink.opacity(0.25), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 80
    )
}
