//
//  StreakComplication.swift
//  Mood8WatchApp
//
//  WidgetKit-based complication for the watch face. Shows the current streak.
//
//  Architecture (watchOS 10+):
//    - The old ClockKit (CLKComplicationDataSource) is deprecated.
//    - Modern complications are WidgetKit widgets with the
//      `.accessoryCircular`, `.accessoryRectangular`, `.accessoryCorner`,
//      and `.accessoryInline` families.
//    - The widget reads from the same UserDefaults the main app writes to,
//      so we get free data sharing without WatchConnectivity.
//
//  IMPORTANT: For the widget to read app data, both the main app target and the
//  widget extension target must share an App Group entitlement
//  (e.g. `group.com.mood8.shared`). See README.md → "Setting up complications".
//
//  This file is intended to live in a separate Widget Extension target in Xcode,
//  but it's grouped with the main app source for now so the structure is one place.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline entry

@available(watchOS 10.0, *)
struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
}

// MARK: - Provider

@available(watchOS 10.0, *)
struct StreakProvider: TimelineProvider {

    /// Shown in the widget gallery / while loading. Uses a sample number.
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: 47)
    }

    /// Snapshot for transient previews (e.g. quick switcher). Real data preferred,
    /// but if the store can't load we fall back to the placeholder.
    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: Date(), streak: currentStreak()))
    }

    /// One entry now, plus a refresh request at the next midnight so the streak
    /// rolls over without the user having to launch the app.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let now = Date()
        let entry = StreakEntry(date: now, streak: currentStreak())

        // Compute next local midnight — that's when the streak number could change.
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let nextMidnight = calendar.startOfDay(for: tomorrow)

        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }

    /// Pull the streak count by re-running the same algorithm DataStore uses.
    /// We inline it here (rather than calling DataStore.shared) because widget
    /// extensions are a separate process — the singleton wouldn't be the same instance.
    private func currentStreak() -> Int {
        guard let data = UserDefaults.standard.data(forKey: "mood8.entries.v1"),
              let entries = try? JSONDecoder().decode([MoodEntry].self, from: data) else {
            return 0
        }
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var count = 0
        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }
        while days.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }
}

// MARK: - Views per family

@available(watchOS 10.0, *)
struct StreakComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        // Each family needs its own layout — a single view that "just scales"
        // looks bad on inline (which is text-only) and wastes space on rectangular.
        switch family {

        case .accessoryCircular:
            // Tiny ring + number. Best for the corner of a modular face.
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Text("\(entry.streak)")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .italic()
                    Text("days")
                        .font(.system(size: 8, weight: .semibold))
                }
            }

        case .accessoryRectangular:
            // Full label — fits two lines comfortably in a modular slot.
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .bold))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(entry.streak) day streak")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .italic()
                    Text("Mood8")
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.7)
                }
            }

        case .accessoryInline:
            // Single-line text only — appears at the top of the watch face.
            // No custom view chrome allowed; system styles it.
            Text("🔥 \(entry.streak) day streak")

        case .accessoryCorner:
            // Curved corner-of-screen layout (Ultra & GPS faces).
            Text("\(entry.streak)")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .italic()
                .widgetLabel("day streak")

        @unknown default:
            // Future-proof: render *something* sensible if Apple adds a new family.
            Text("\(entry.streak)d")
        }
    }
}

// MARK: - Widget definition

@available(watchOS 10.0, *)
struct StreakComplication: Widget {
    let kind: String = "Mood8StreakComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakComplicationView(entry: entry)
                // `containerBackground` is required on watchOS 10+ — it tells the
                // system what to render when the face is in always-on / dimmed mode.
                .containerBackground(for: .widget) {
                    AppColors.bgDeep
                }
        }
        .configurationDisplayName("Mood8 Streak")
        .description("Your current consecutive-day streak.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

// MARK: - Widget bundle
//
// In Xcode, the Widget Extension target needs a `@main` WidgetBundle.
// Uncomment this when you create the extension target (see README.md).
//
// @main
// @available(watchOS 10.0, *)
// struct Mood8WidgetBundle: WidgetBundle {
//     var body: some Widget {
//         StreakComplication()
//     }
// }
