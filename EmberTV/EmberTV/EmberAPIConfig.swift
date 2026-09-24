import Foundation

enum EmberAPIConfig {
    /// The Ember TV web app. Every /v2 route lives under it, and viewers
    /// approve this TV at `<apiBaseURL>/activate`.
    static let apiBaseURL = URL(string: "https://app.emberstreaming.com")!

    /// Supabase project, used only to refresh the sign-in session
    /// (POST /auth/v1/token?grant_type=refresh_token).
    static let supabaseURL = URL(string: "https://bqdoxfeuhfzljvddpjbd.supabase.co")!

    /// Supabase publishable key. Public by design (the website ships the
    /// same one); it identifies the project, it does not grant access.
    static let supabasePublishableKey = "sb_publishable_dDyGlDF2w0gvX1bJbz_knw_xVt4U6Lp"

    /// Sent as `client` on activation, playback and progress.
    static let client = "tvos"

    /// Where viewers rent films. Shown on screen, so no scheme.
    static let websiteDisplayName = "app.emberstreaming.com"
}
