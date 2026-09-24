import Foundation

enum EmberAPIConfig {
    /// Base44 Functions root for Ember VOD
    static let base44URL = URL(string: "https://embervod.base44.app/api/apps/691721b89e14bc8b401725d6/functions")!

    /// For login we also use the same functions host
    static let authBaseURL = base44URL
}
