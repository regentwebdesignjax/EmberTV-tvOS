//
//  EmberAPIClient.swift
//  EmberTV
//
//  Talks to the Ember TV API v2 (the web app's /v2 routes). Sign-in is by
//  activation code: the TV shows a short code, the viewer approves it at
//  app.emberstreaming.com/activate, and the TV receives a normal session
//  (access + refresh token) that it keeps in the keychain and refreshes.
//

import Foundation
import Combine

enum EmberAPIError: LocalizedError {
    case signedOut
    case network
    case server(status: Int, code: String?, message: String?)

    var code: String? {
        if case let .server(_, code, _) = self { return code }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .signedOut:
            return "Please sign in again."
        case .network:
            return "Can't reach Ember TV. Check your internet connection and try again."
        case let .server(_, _, message):
            return message ?? "Something went wrong. Please try again in a moment."
        }
    }
}

/// Result of one activation poll.
enum ActivationPoll {
    /// Not approved yet: poll again after `interval` seconds.
    case pending(interval: Int)
    /// Approved: the session is stored and `isSignedIn` is now true.
    case approved
    /// The code expired, was already used or is unknown: get a new one.
    case restart
}

@MainActor
final class EmberAPIClient: ObservableObject {

    static let shared = EmberAPIClient()

    /// Drives the root view: activation screen vs library.
    @Published private(set) var isSignedIn: Bool

    /// Stable per install; identifies this TV for playback and resume.
    let deviceID: String

    private var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?

    private static let sessionAccount = "session"
    private static let deviceIDKey = "EmberDeviceID"

    private init() {
        // Sign-in token from the old Base44 backend; it is not valid here.
        UserDefaults.standard.removeObject(forKey: "EmberAuthToken")

        if let id = UserDefaults.standard.string(forKey: Self.deviceIDKey) {
            deviceID = id
        } else {
            let id = UUID().uuidString.lowercased()
            UserDefaults.standard.set(id, forKey: Self.deviceIDKey)
            deviceID = id
        }

        if let data = Keychain.data(for: Self.sessionAccount),
           let stored = try? JSONDecoder().decode(AuthSession.self, from: data) {
            session = stored
        }
        isSignedIn = session != nil
    }

    // MARK: - Activation

    func startActivation() async throws -> DeviceCodeResponse {
        let body: [String: Any] = ["client": EmberAPIConfig.client, "device_id": deviceID]
        let (data, http) = try await send(apiRequest("v2/device/code", method: "POST", body: body))
        guard http.statusCode == 200 else { throw Self.serverError(data, http) }
        return try Self.decode(DeviceCodeResponse.self, from: data)
    }

    func pollActivation(deviceCode: String) async throws -> ActivationPoll {
        let body: [String: Any] = ["device_code": deviceCode]
        let (data, http) = try await send(apiRequest("v2/device/token", method: "POST", body: body))
        switch http.statusCode {
        case 200:
            let token = try Self.decode(DeviceTokenResponse.self, from: data)
            guard let access = token.accessToken, let refresh = token.refreshToken else {
                throw EmberAPIError.server(status: 200, code: nil, message: nil)
            }
            store(AuthSession(
                accessToken: access,
                refreshToken: refresh,
                expiresAt: Date().addingTimeInterval(TimeInterval(token.expiresIn ?? 3600))
            ))
            return .approved
        case 202:
            let pending = try? Self.decode(DeviceTokenResponse.self, from: data)
            return .pending(interval: pending?.interval ?? 5)
        case 400, 409, 410:
            return .restart
        default:
            throw Self.serverError(data, http)
        }
    }

    // MARK: - Sign out

    func signOut() {
        if let token = session?.accessToken {
            // Best effort: revoke this TV's refresh token on the server.
            var request = URLRequest(url: EmberAPIConfig.supabaseURL
                .appending(path: "auth/v1/logout")
                .appending(queryItems: [URLQueryItem(name: "scope", value: "local")]))
            request.httpMethod = "POST"
            request.setValue(EmberAPIConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            Task { _ = try? await URLSession.shared.data(for: request) }
        }
        session = nil
        refreshTask = nil
        Keychain.remove(Self.sessionAccount)
        isSignedIn = false
    }

    // MARK: - Library, films, playback, progress

    func fetchLibrary() async throws -> [Rental] {
        let (data, http) = try await authorized("v2/library")
        guard http.statusCode == 200 else { throw Self.serverError(data, http) }
        return try Self.decode(LibraryResponse.self, from: data).items
    }

    /// Public film details (descriptions, genres). No token needed.
    func fetchFilm(slug: String) async throws -> FilmDetail {
        let (data, http) = try await send(apiRequest("v2/films/\(slug)"))
        guard http.statusCode == 200 else { throw Self.serverError(data, http) }
        return try Self.decode(FilmDetailResponse.self, from: data).film
    }

    /// A fresh signed HLS URL for this device. Request one on every play;
    /// it is bound to this TV's IP and expires after the film's length.
    func startPlayback(filmID: String) async throws -> URL {
        let body: [String: Any] = ["client": EmberAPIConfig.client, "device_id": deviceID]
        let (data, http) = try await authorized("v2/playback/\(filmID)", method: "POST", body: body)
        guard http.statusCode == 200 else { throw Self.serverError(data, http) }
        return try Self.decode(PlaybackResponse.self, from: data).playback.url
    }

    /// Resume position, shared across the viewer's devices. Failures are
    /// ignored: progress is a convenience and must never interrupt playback.
    func reportProgress(filmID: String, seconds: Double) async {
        guard seconds.isFinite, seconds >= 0 else { return }
        let body: [String: Any] = [
            "film_id": filmID,
            "device_id": deviceID,
            "client": EmberAPIConfig.client,
            "position_seconds": Int(seconds),
        ]
        _ = try? await authorized("v2/progress", method: "POST", body: body)
    }

    // MARK: - Session

    private func store(_ newSession: AuthSession) {
        session = newSession
        if let data = try? JSONEncoder().encode(newSession) {
            Keychain.set(data, for: Self.sessionAccount)
        }
        isSignedIn = true
    }

    private func validAccessToken() async throws -> String {
        guard let session else { throw EmberAPIError.signedOut }
        if session.expiresAt.timeIntervalSinceNow > 60 { return session.accessToken }
        return try await refreshSession().accessToken
    }

    /// One refresh at a time: Supabase rotates refresh tokens, so two
    /// concurrent refreshes with the same token would sign the TV out.
    private func refreshSession() async throws -> AuthSession {
        if let refreshTask { return try await refreshTask.value }
        guard let refreshToken = session?.refreshToken else { throw EmberAPIError.signedOut }

        let task = Task { try await Self.performRefresh(refreshToken: refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let fresh = try await task.value
            store(fresh)
            return fresh
        } catch EmberAPIError.signedOut {
            signOut()
            throw EmberAPIError.signedOut
        }
    }

    private static func performRefresh(refreshToken: String) async throws -> AuthSession {
        var request = URLRequest(url: EmberAPIConfig.supabaseURL
            .appending(path: "auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(EmberAPIConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw EmberAPIError.network   // offline: keep the session, try later
        }
        guard let http = response as? HTTPURLResponse else { throw EmberAPIError.network }
        switch http.statusCode {
        case 200:
            let r = try decode(RefreshResponse.self, from: data)
            return AuthSession(
                accessToken: r.accessToken,
                refreshToken: r.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(r.expiresIn))
            )
        case 400, 401, 403:
            throw EmberAPIError.signedOut   // revoked or expired: sign in again
        default:
            throw EmberAPIError.server(status: http.statusCode, code: nil, message: nil)
        }
    }

    // MARK: - Requests

    /// Sends with the access token; on a 401, refreshes once and retries.
    private func authorized(
        _ path: String, method: String = "GET", body: [String: Any]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let token = try await validAccessToken()
        let first = try await send(apiRequest(path, method: method, body: body, token: token))
        guard first.1.statusCode == 401 else { return first }

        let fresh = try await refreshSession()
        let second = try await send(apiRequest(path, method: method, body: body, token: fresh.accessToken))
        if second.1.statusCode == 401 {
            signOut()
            throw EmberAPIError.signedOut
        }
        return second
    }

    private func apiRequest(
        _ path: String, method: String = "GET", body: [String: Any]? = nil, token: String? = nil
    ) -> URLRequest {
        var request = URLRequest(url: EmberAPIConfig.apiBaseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            if (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw EmberAPIError.network
        }
        guard let http = response as? HTTPURLResponse else { throw EmberAPIError.network }
        return (data, http)
    }

    // MARK: - Decoding

    private static func serverError(_ data: Data, _ http: HTTPURLResponse) -> EmberAPIError {
        let envelope = try? decode(APIErrorEnvelope.self, from: data)
        return .server(status: http.statusCode, code: envelope?.error.code, message: envelope?.error.message)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = EmberDates.parse(string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
            }
            return date
        }
        return try decoder.decode(T.self, from: data)
    }
}

/// ISO 8601 timestamps as the API sends them: "2026-09-25T04:00:00Z",
/// with milliseconds ("…00.123Z") or Postgres microseconds ("…00.123456+00:00").
enum EmberDates {
    nonisolated static func parse(_ string: String) -> Date? {
        var base = string
        var fraction: TimeInterval = 0
        if let dot = string.firstIndex(of: "."),
           let zone = string[dot...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) {
            fraction = TimeInterval("0" + string[dot..<zone]) ?? 0
            base = String(string[..<dot]) + String(string[zone...])
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: base)?.addingTimeInterval(fraction)
    }
}
