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
            .overlay(alignment: .topTrailing) {
                if EmberAPIConfig.isStaging { StagingBadge() }
            }
        }
    }
}

/// Shown on every screen of the Staging build so it is never mistaken for
/// the store app.
private struct StagingBadge: View {
    var body: some View {
        Text("STAGING")
            .font(EmberTheme.bodySemibold(22))
            .tracking(2)
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.yellow, in: Capsule())
            .padding(.top, 30)
            .padding(.trailing, 60)
            .allowsHitTesting(false)
            .accessibilityLabel("Staging build")
    }
}
