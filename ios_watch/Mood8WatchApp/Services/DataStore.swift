//
//  DataStore.swift
//  Mood8WatchApp
//
//  Local persistence for mood entries.
//
//  Why not @AppStorage on each entry?
//   @AppStorage is great for primitives but awkward for arrays of structs — you
//   end up encoding/decoding by hand anyway. So we use UserDefaults directly,
//   wrap it in an ObservableObject, and publish the array.
//
//  Why UserDefaults instead of CoreData/SwiftData?
//   Watch storage is precious; entries are tiny (~80 bytes JSON each); 10k days
//   ≈ 800KB which fits comfortably. CoreData would be overkill.
//

import Foundation
import Combine

/// Single source of truth for mood data on the watch.
/// Inject via `.environmentObject(DataStore.shared)` from the App entry.
@MainActor
@available(watchOS 10.0, *)
final class DataStore: ObservableObject {

    /// Shared singleton — there's only one user on a watch, and SwiftUI previews
    /// still get their own instances by constructing `DataStore()` directly.
    static let shared = DataStore()

    /// Storage key. Versioned so a future schema change can migrate cleanly
    /// without colliding with old data.
    private static let storageKey = "mood8.entries.v1"

    /// All entries, newest last (insertion order). Published so SwiftUI redraws
    /// when a new check-in lands.
    @Published private(set) var entries: [MoodEntry] = []

    init() {
        load()
    }

    // MARK: - Public API

    /// Appends a new entry and persists. Called from MoodCheckInView.
    func add(_ entry: MoodEntry) {
        entries.append(entry)
        persist()
    }

    /// Convenience: build an entry from raw slider values and store it.
    /// Returns the created entry so callers can show a "saved at HH:mm" toast.
    @discardableResult
    func record(mood: Double, energy: Double, focus: Double) -> MoodEntry {
        let entry = MoodEntry(mood: mood, energy: energy, focus: focus)
        add(entry)
        return entry
    }

    /// The most recent entry, or `nil` if the user has never checked in.
    /// Used by HomeView to seed the orb's color and the streak chip's "today" state.
    var latest: MoodEntry? { entries.last }

    /// Number of consecutive days (counting back from today) that include
    /// at least one entry. The "🔥 47 day streak" number.
    ///
    /// Algorithm: walk backwards from today; if today's bucket is empty, the
    /// streak is whatever ended yesterday — we don't reset until the user
    /// misses a *full* day (so a late-night log still counts).
    var currentStreak: Int {
        let calendar = Calendar.current
        // Group entry dates into a Set of day-truncated dates for O(1) lookup.
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var count = 0
        var cursor = calendar.startOfDay(for: Date())

        // If today has no entry, start checking from yesterday — grace period.
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }

        while days.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = prev
        }
        return count
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        // If decoding fails (corrupt data or schema change), we silently start fresh
        // rather than crashing — losing two weeks of mood data is bad, but a crash loop
        // on the watch face is worse.
        if let decoded = try? JSONDecoder().decode([MoodEntry].self, from: data) {
            entries = decoded
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
