//
//  MoodEntry.swift
//  Mood8WatchApp
//
//  The atomic unit of self-tracking: one moment, three numbers.
//  Stored as JSON in UserDefaults via DataStore (see Services/DataStore.swift).
//

import Foundation

/// A single check-in. All sliders are normalized 0.0–1.0 so the UI can render
/// them as percentages, scores out of 10, or anything else without storage churn.
///
/// `Identifiable` enables `ForEach` lists; `Codable` enables JSON persistence;
/// `Hashable` lets the entry participate in `Set`s and `NavigationStack` paths.
struct MoodEntry: Identifiable, Codable, Hashable {

    /// Stable identifier so SwiftUI list diffing stays correct even after reorder.
    let id: UUID

    /// Wall-clock instant of the check-in. Timezone-naive — we only ever bucket by day.
    let date: Date

    /// 0.0 = worst possible, 1.0 = best possible. Normalized so the rendering layer
    /// is free to reformat without a migration.
    let mood: Double
    let energy: Double
    let focus: Double

    /// Convenience initializer that mints a fresh UUID. Tests can still pass an
    /// explicit `id` via the memberwise init.
    init(id: UUID = UUID(),
         date: Date = Date(),
         mood: Double,
         energy: Double,
         focus: Double) {
        self.id = id
        self.date = date
        self.mood = mood
        self.energy = energy
        self.focus = focus
    }

    /// Composite "wellbeing score" — straight average of the three sliders.
    /// Future versions may weight these (focus might matter more on workdays etc.),
    /// but for the MVP a flat mean is honest.
    var compositeScore: Double { (mood + energy + focus) / 3.0 }

    /// Score formatted for display: "7.2" out of 10. Matches the Flutter slider readout.
    var displayScore: String {
        String(format: "%.1f", compositeScore * 10)
    }
}
