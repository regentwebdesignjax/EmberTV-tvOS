import Foundation

struct AuthResponse: Decodable {
    let token: String
    let user: User
}

struct User: Decodable {
    let id: Int
    let email: String
    let name: String?
}

struct Film: Identifiable, Decodable, Hashable {
    let id: Int
    let slug: String
    let title: String
    let description: String
    let genre: String?
    let runtimeMinutes: Int?
    let posterURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, description, genre
        case runtimeMinutes = "runtime_minutes"
        case posterURL = "poster_url"
    }
}

struct PaginatedFilmsResponse: Decodable {
    let data: [Film]
}

struct RentalFilmSummary: Decodable, Hashable {
    let id: String
    let slug: String?
    let title: String
    let posterURL: URL?
    let hlsURL: URL?

    // Detailed Metadata
    let description: String?     // Short description
    let longDescription: String? // Expanded description
    let durationMinutes: Int?
    let genre: String?
    let rating: String?          // e.g. "PG-13", "R"

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case title
        // FIXED: This now explicitly looks for the "short_description" key from your API
        case description = "short_description"
        case rating
        case genre
        case posterURL = "poster_url"
        case hlsURL = "hls_url"
        case longDescription = "long_description"
        case durationMinutes = "duration_minutes"
    }
}

struct Rental: Decodable, Hashable {
    let film: RentalFilmSummary

    let status: String?
    let purchasedAt: Date?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case film
        case status
        case purchasedAt = "purchased_at"
        case expiresAt = "expires_at"
    }

    var filmID: String { film.id }
}

struct RentalsResponse: Decodable {
    let data: [Rental]
}

struct EntitlementResponse: Decodable {
    let hasAccess: Bool
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case hasAccess = "has_access"
        case expiresAt = "expires_at"
    }
}

struct PlaybackResponse: Decodable {
    let hasAccess: Bool
    let playbackURL: URL?
    let hlsURL: URL?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case hasAccess = "has_access"
        case playbackURL = "playback_url"
        case hlsURL = "hls_url"
        case expiresAt = "expires_at"
    }

    var streamURL: URL? {
        hlsURL ?? playbackURL
    }
}
