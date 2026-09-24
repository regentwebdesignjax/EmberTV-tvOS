import Foundation

// Shapes from the Ember TV API v2 (docs/API-v2.md in the web app repo).
// Keys are snake_case on the wire; the decoder converts them.

// MARK: - Errors

struct APIErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
    }
    let error: Body
}

// MARK: - Activation (sign in with a code)

struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: URL
    let verificationUriComplete: URL
    let expiresIn: Int
    let interval: Int
}

struct DeviceTokenResponse: Decodable {
    let status: String
    let interval: Int?
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
}

/// Supabase's refresh_token grant response (only the fields we keep).
struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

/// The stored sign-in. Refreshed about a minute before `expiresAt`.
struct AuthSession: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

// MARK: - Library

struct EntitlementSummary: Decodable, Hashable {
    let id: String
    let filmId: String
    let type: String            // "rental" | "public_performance"
    let status: String          // "active" | "expired" | …
    let startsAt: Date?
    let expiresAt: Date?
    let secondsRemaining: Int?
}

struct LibraryFilm: Decodable, Hashable {
    let id: String
    let slug: String
    let title: String
    let thumbnailUrl: URL?      // portrait poster
    let bannerImageUrl: URL?    // wide background art
    let durationMinutes: Int?
    let rating: String?
    let releaseYear: Int?

    var posterURL: URL? { thumbnailUrl ?? bannerImageUrl }
    var backdropURL: URL? { bannerImageUrl ?? thumbnailUrl }
}

struct ScreeningInfo: Decodable, Hashable {
    let venueName: String?
    let screeningDate: String?  // YYYY-MM-DD, the venue's local date
}

struct ResumePoint: Decodable, Hashable {
    let positionSeconds: Int
    let at: Date?
    let client: String?
}

/// One row of GET /v2/library: a rental (or screening licence) and its film.
struct Rental: Decodable, Hashable, Identifiable {
    let entitlement: EntitlementSummary
    let film: LibraryFilm
    let screening: ScreeningInfo?
    let resume: ResumePoint?

    var id: String { entitlement.id }
    var expiresAt: Date? { entitlement.expiresAt }
    var isScreening: Bool { entitlement.type == "public_performance" }

    /// Not yet started: a screening licence whose window opens later.
    func isUpcoming(at now: Date = Date()) -> Bool {
        guard let start = entitlement.startsAt else { return false }
        return start > now
    }

    /// Playable right now, judged by the clock (playback re-checks on the server).
    func isWatchable(at now: Date = Date()) -> Bool {
        guard entitlement.status == "active", !isUpcoming(at: now) else { return false }
        guard let end = entitlement.expiresAt else { return true }
        return end > now
    }
}

struct LibraryResponse: Decodable {
    let items: [Rental]
}

// MARK: - Film detail (descriptions and genres for the detail screen)

struct FilmDetail: Decodable {
    let id: String
    let shortDescription: String?
    let longDescription: String?
    let genres: [String]
}

struct FilmDetailResponse: Decodable {
    let film: FilmDetail
}

// MARK: - Playback

struct PlaybackResponse: Decodable {
    struct Playback: Decodable {
        let type: String        // "hls" for TV clients
        let url: URL
        let expiresAt: Date?
    }
    let playback: Playback
}
