//
//  QuickButton.swift
//  Mood8WatchApp
//
//  Reusable gradient pill button with built-in haptic.
//
//  Two styles:
//   - .primary  — full gradient fill, used for the headline action ("Save check-in")
//   - .ghost    — outlined, used for secondary actions ("View streak")
//

import SwiftUI
import WatchKit

@available(watchOS 10.0, *)
struct QuickButton: View {

    enum Style { case primary, ghost }

    let title: String
    var systemImage: String? = nil
    var style: Style = .primary

    /// Haptic to play on tap. Defaults to `.success` for primary and `.click` for ghost
    /// — overridable via the initializer for one-off use cases.
    var haptic: WKHapticType? = nil

    let action: () -> Void

    var body: some View {
        Button {
            // Always feel the tap. Default haptic depends on style.
            let h = haptic ?? (style == .primary ? .success : .click)
            WKInterfaceDevice.current().play(h)
            action()
        } label: {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8) // shrink a little on 40mm rather than truncate
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(background)
            .clipShape(Capsule())
            // Glow shadow makes the button feel "lit" against the dark scaffold.
            .shadow(color: AppColors.pink.opacity(style == .primary ? 0.55 : 0),
                    radius: 10, x: 0, y: 4)
        }
        // Strip the system button chrome — we draw our own background.
        .buttonStyle(.plain)
    }

    /// Background view varies by style. Computed property keeps the body readable.
    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            AppGradients.button
        case .ghost:
            // 1pt gradient stroke over a near-transparent fill — looks etched.
            ZStack {
                Capsule().fill(AppColors.bgCard.opacity(0.6))
                Capsule().strokeBorder(AppGradients.primary, lineWidth: 1)
            }
        }
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview {
    VStack(spacing: 10) {
        QuickButton(title: "Save check-in", systemImage: "checkmark.circle.fill") {}
        QuickButton(title: "View streak", systemImage: "flame", style: .ghost) {}
    }
    .padding()
    .background(AppColors.bgDeep)
}
#endif
