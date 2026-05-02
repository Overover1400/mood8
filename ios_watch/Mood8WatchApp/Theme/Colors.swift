//
//  Colors.swift
//  Mood8WatchApp
//
//  Mirror of the Flutter app's color palette (lib/theme/app_theme.dart).
//  Keep these in sync if the Flutter palette changes.
//
//  Naming follows the Flutter source verbatim so cross-platform discussions stay 1:1.
//

import SwiftUI

// MARK: - Hex initializer
//
// SwiftUI's Color initializer doesn't accept hex strings out of the box.
// This extension parses 6-digit (#RRGGBB) and 8-digit (#AARRGGBB) hex.
// It tolerates a leading "#" and ignores case.
@available(watchOS 10.0, *)
extension Color {
    init(hex: String) {
        // Strip "#" if present, normalize case for the scanner.
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }

        // Default ARGB if parsing fails: opaque magenta — loud, so bugs are obvious.
        var rgb: UInt64 = 0xFFFF00FF
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let a, r, g, b: Double
        switch sanitized.count {
        case 6: // #RRGGBB — assume fully opaque
            a = 1
            r = Double((rgb & 0xFF0000) >> 16) / 255
            g = Double((rgb & 0x00FF00) >> 8) / 255
            b = Double(rgb & 0x0000FF) / 255
        case 8: // #AARRGGBB
            a = Double((rgb & 0xFF000000) >> 24) / 255
            r = Double((rgb & 0x00FF0000) >> 16) / 255
            g = Double((rgb & 0x0000FF00) >> 8) / 255
            b = Double(rgb & 0x000000FF) / 255
        default:
            a = 1; r = 1; g = 0; b = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - App palette
//
// All colors live under `AppColors` so call sites read like the Flutter equivalent
// (`AppColors.purple`) and grep across both codebases easily.
@available(watchOS 10.0, *)
enum AppColors {
    // Backgrounds — deepest in front, secondary behind, cards on top.
    static let bgDeep   = Color(hex: "#0A0612") // main scaffold background
    static let bg       = Color(hex: "#110821") // secondary surfaces
    static let bgCard   = Color(hex: "#1F1338") // glass cards & inactive slider track

    // Brand
    static let purple       = Color(hex: "#A855F7") // primary
    static let purpleLight  = Color(hex: "#C084FC") // hover/light accent
    static let pink         = Color(hex: "#EC4899") // secondary
    static let pinkLight    = Color(hex: "#F472B6") // soft accent / glow
    static let blueAccent   = Color(hex: "#818CF8") // tertiary

    // Text — "ink" mirrors the Flutter naming so CSS variables and Swift constants line up.
    static let ink       = Color(hex: "#FAF5FF") // primary text
    static let inkSoft   = Color(hex: "#E9D5FF") // secondary
    static let inkDim    = Color(hex: "#A78BB8") // tertiary
    static let inkFaint  = Color(hex: "#6B5680") // disabled
}
