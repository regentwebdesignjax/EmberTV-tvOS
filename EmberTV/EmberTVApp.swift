//
//  EmberTVApp.swift
//  EmberTV
//

import SwiftUI

@main
struct EmberTVApp: App {
    // Shared API client (holds the sign-in session)
    @StateObject private var apiClient = EmberAPIClient.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if apiClient.isSignedIn {
                    MyRentalsView()
                } else {
                    ActivationView()
                }
            }
            .environmentObject(apiClient)
        }
    }
}
