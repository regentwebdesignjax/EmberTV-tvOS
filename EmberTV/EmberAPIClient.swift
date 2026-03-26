//
//  EmberAPIClient.swift
//  EmberTV
//

import Foundation
import Combine

@MainActor
final class EmberAPIClient: ObservableObject {

    // MARK: - Nested Types
    struct LoginBody: Encodable { let email: String; let password: String }
    struct AuthUser: Decodable { let id: String; let email: String; let name: String? }
    struct AuthResponse: Decodable { let token: String }
    enum LoginError: Error { case invalidCredentials; case serverError }
    struct PlaybackBody: Encodable { let film_id: String }

    // MARK: - Singleton
    static let shared = EmberAPIClient()

    // MARK: - Published auth state
    @Published var token: String?
    private let tokenKey = "EmberAuthToken"

    // MARK: - Init
    private init() {
        self.token = UserDefaults.standard.string(forKey: tokenKey)
    }

    // MARK: - Core Request Builder
    private func makeRequest(path: String, method: String = "GET", body: Encodable? = nil, useAuthAPI: Bool = false) throws -> URLRequest {
        let base = useAuthAPI ? EmberAPIConfig.authBaseURL : EmberAPIConfig.base44URL
        let url = base.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    /// JSON decoder helper
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Standard ISO8601 (no fractions)
            let standardFormatter = ISO8601DateFormatter()
            standardFormatter.formatOptions = [.withInternetDateTime]
            if let date = standardFormatter.date(from: dateString) { return date }
            
            // ISO8601 with Milliseconds
            standardFormatter.formatOptions.insert(.withFractionalSeconds)
            if let date = standardFormatter.date(from: dateString) { return date }
            
            // 🛠️ FIX: Fallback for Microseconds (6 decimal places)
            let microsecondFormatter = DateFormatter()
            microsecondFormatter.locale = Locale(identifier: "en_US_POSIX")
            microsecondFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            if let date = microsecondFormatter.date(from: dateString) { return date }
            
            print("❌ SWIFT DATE PARSING FAILED FOR: \(dateString)")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }
        
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Auth
    func login(email: String, password: String) async throws {
        self.token = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)

        let body = LoginBody(email: email, password: password)
        let request = try makeRequest(path: "authLogin", method: "POST", body: body, useAuthAPI: true)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw LoginError.serverError }

        switch http.statusCode {
        case 200:
            let auth = try decode(AuthResponse.self, from: data)
            self.token = auth.token
            UserDefaults.standard.set(auth.token, forKey: tokenKey)
        case 401:
            throw LoginError.invalidCredentials
        default:
            throw LoginError.serverError
        }
    }

    func logout() {
        token = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    // MARK: - Films
    func fetchFilms() async throws -> [Film] {
        let request = try makeRequest(path: "films", useAuthAPI: true)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let result = try decode(PaginatedFilmsResponse.self, from: data)
        return result.data
    }

    // MARK: - Rentals
    func fetchMyRentals() async throws -> [Rental] {
        let request = try makeRequest(path: "apiMyRentals", useAuthAPI: false)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Console Debugging
        let responseString = String(data: data, encoding: .utf8) ?? "<invalid utf-8>"
        print("🌍 API RESPONSE [HTTP \(http.statusCode)]:")
        print(responseString)

        if http.statusCode == 401 {
            logout()
            throw URLError(.userAuthenticationRequired)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        do {
            let rentalsResponse = try decode(RentalsResponse.self, from: data)
            return rentalsResponse.data
        } catch {
            print("❌ SWIFT DECODING ERROR: \(error)")
            throw error
        }
    }

    // MARK: - Playback
    func fetchPlayback(for filmID: String) async throws -> PlaybackResponse {
        let body = PlaybackBody(film_id: filmID)
        let request = try makeRequest(path: "apiPlayback", method: "POST", body: body, useAuthAPI: false)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try decode(PlaybackResponse.self, from: data)
    }
}
