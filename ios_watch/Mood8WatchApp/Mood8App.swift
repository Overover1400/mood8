//
//  Mood8App.swift
//  Mood8WatchApp
//
//  App entry point. Sets up the navigation stack and injects the shared DataStore.
//
//  Why @main on a struct conforming to App?
//   That's the standard SwiftUI app lifecycle (replaces the old WKApplicationDelegate
//   pattern). watchOS 10+ supports it fully.
//

import SwiftUI

@main
@available(watchOS 10.0, *)
struct Mood8App: App {

    /// Shared data store — `@StateObject` so SwiftUI keeps it alive for the
    /// life of the app and propagates updates to any view that observes it.
    @StateObject private var store = DataStore.shared

    var body: some Scene {
        WindowGroup {
            // NavigationStack (watchOS 9+) — gives us push navigation with the
            // chevron back button. Wraps HomeView so child views get free routing.
            NavigationStack {
                HomeView()
            }
            // Tint cascades to NavigationLink chrome, button accents, etc. Pinning
            // it to our brand purple keeps the system UI on-brand.
            .tint(AppColors.purpleLight)
            // Inject the store so any descendant view can `@EnvironmentObject` it.
            .environmentObject(store)
            // Force dark color scheme — the design assumes the dark palette.
            .preferredColorScheme(.dark)
        }
    }
}
