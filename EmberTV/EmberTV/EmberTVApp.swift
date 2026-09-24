//
//  EmberTVApp.swift
//  EmberTV
//

import SwiftUI

@main
struct EmberTVApp: App {
    // Shared API client (holds token + user)
    @StateObject private var apiClient = EmberAPIClient.shared

    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(apiClient)
        }
    }

    /// Chooses the initial screen based on whether the user is authenticated.
    @ViewBuilder
    private var rootView: some View {
        if apiClient.token != nil {
            // ✅ User is logged in → show main EmberTV interface
            //
            // If you have a MainTabView with more screens, keep this.
            // If EmberTV is only MyRentals, you can swap this for MyRentalsView().
            MyRentalsView()
                .environmentObject(apiClient)
        } else {
            // 🚪 No token → show login screen
            LoginView()
                .environmentObject(apiClient)
        }
    }
}
