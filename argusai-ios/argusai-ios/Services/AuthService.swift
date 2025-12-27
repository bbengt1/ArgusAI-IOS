//
//  AuthService.swift
//  ArgusAI
//
//  Authentication and pairing service.
//

import Foundation
import UIKit

@Observable
final class AuthService {
    private let keychain = KeychainService.shared

    /// URLSession that respects SSL verification settings from DiscoveryService
    private var session: URLSession {
        DiscoveryService.shared.urlSession
    }

    /// Stored property to trigger observation when auth state changes
    private(set) var isAuthenticated: Bool = false

    var deviceName: String? {
        keychain.deviceName
    }

    var deviceId: String {
        if let existing = keychain.deviceId {
            return existing
        }
        let newId = UUID().uuidString
        keychain.deviceId = newId
        return newId
    }

    init() {
        // Check initial auth state from keychain
        isAuthenticated = keychain.accessToken != nil
    }

    /// Update authentication state (call after storing/clearing tokens)
    private func updateAuthState() {
        isAuthenticated = keychain.accessToken != nil
    }

    // MARK: - Pairing Flow

    /// Generate a pairing code from the backend
    func generatePairingCode() async throws -> PairResponse {
        let request = PairRequest(
            deviceId: deviceId,
            deviceName: UIDevice.current.name,
            deviceModel: UIDevice.current.model,
            platform: "ios"
        )

        let baseURL = DiscoveryService.shared.currentBaseURL
        let urlString = "\(baseURL)/api/v1/mobile/auth/pair"
        print("[AuthService] Attempting to pair with URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw AuthError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            print("[AuthService] Pair response status: \(httpResponse.statusCode)")
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("[AuthService] Pair response body: \(responseBody)")

            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(PairResponse.self, from: data)
            } else if httpResponse.statusCode == 429 {
                throw AuthError.rateLimited
            } else {
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
                print("[AuthService] Pair error response: \(responseBody)")
                throw AuthError.serverError(errorResponse?.detail ?? "Server error (\(httpResponse.statusCode))")
            }
        } catch let error as AuthError {
            throw error
        } catch let error as URLError {
            print("[AuthService] URL error: \(error.code) - \(error.localizedDescription)")
            throw AuthError.networkError(error)
        } catch {
            print("[AuthService] Unexpected error: \(error)")
            throw AuthError.networkError(error)
        }
    }

    /// Check the status of a pairing code
    func checkPairingStatus(_ code: String) async throws -> PairingStatusResponse {
        let baseURL = DiscoveryService.shared.currentBaseURL
        let urlString = "\(baseURL)/api/v1/mobile/auth/status/\(code)"
        guard let url = URL(string: urlString) else {
            throw AuthError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
        print("[AuthService] Status check response (\(httpResponse.statusCode)): \(responseBody)")

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PairingStatusResponse.self, from: data)
        } else if httpResponse.statusCode == 404 {
            throw AuthError.invalidCode("Pairing code not found or expired")
        } else if httpResponse.statusCode == 429 {
            throw AuthError.rateLimited
        } else {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw AuthError.serverError(error?.detail ?? "Unknown error")
        }
    }

    /// Exchange a confirmed pairing code for tokens
    func exchangeCodeForTokens(_ code: String) async throws {
        let request = ExchangeRequest(code: code, deviceId: deviceId)

        let baseURL = DiscoveryService.shared.currentBaseURL
        let urlString = "\(baseURL)/api/v1/mobile/auth/exchange"
        print("[AuthService] Exchanging code at URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw AuthError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
        print("[AuthService] Exchange response (\(httpResponse.statusCode)): \(responseBody)")

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            do {
                let tokens = try decoder.decode(TokenResponse.self, from: data)

                print("[AuthService] Token received - expiresIn: \(tokens.expiresIn) seconds")

                // Store tokens in Keychain
                keychain.storeTokens(
                    accessToken: tokens.accessToken,
                    refreshToken: tokens.refreshToken,
                    expiresIn: tokens.expiresIn
                )
                print("[AuthService] Tokens stored - expiresAt: \(String(describing: keychain.tokenExpiresAt))")

                keychain.deviceName = UIDevice.current.name
                updateAuthState()
            } catch {
                print("[AuthService] Token decode error: \(error)")
                throw error
            }

        } else if httpResponse.statusCode == 400 {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw AuthError.codeNotConfirmed(error?.detail ?? "Pairing code not yet confirmed")
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 404 {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw AuthError.invalidCode(error?.detail ?? "Invalid or expired pairing code")
        } else if httpResponse.statusCode == 429 {
            throw AuthError.rateLimited
        } else {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw AuthError.serverError(error?.detail ?? "Unknown error")
        }
    }

    // MARK: - Token Refresh

    func refreshTokenIfNeeded() async throws {
        print("[AuthService] Checking if refresh needed...")
        print("[AuthService] needsRefresh: \(keychain.needsRefresh)")
        print("[AuthService] tokenExpiresAt: \(String(describing: keychain.tokenExpiresAt))")
        if let expiresAt = keychain.tokenExpiresAt {
            print("[AuthService] Time until expiry: \(expiresAt.timeIntervalSinceNow) seconds")
        }

        guard keychain.needsRefresh else {
            print("[AuthService] No refresh needed")
            return
        }
        guard let token = keychain.refreshToken else {
            print("[AuthService] No refresh token available")
            throw AuthError.notAuthenticated
        }

        print("[AuthService] Attempting to refresh token...")
        try await refreshToken(with: token)
    }

    func refreshToken(with token: String) async throws {
        let request = RefreshRequest(refreshToken: token, deviceId: deviceId)

        let baseURL = DiscoveryService.shared.currentBaseURL
        let urlString = "\(baseURL)/api/v1/mobile/auth/refresh"
        print("[AuthService] Refreshing token at URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw AuthError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
        print("[AuthService] Refresh response (\(httpResponse.statusCode)): \(responseBody)")

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let tokens = try decoder.decode(TokenResponse.self, from: data)

            // Store new tokens (rotation)
            keychain.storeTokens(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresIn: tokens.expiresIn
            )
        } else if httpResponse.statusCode == 401 {
            // Refresh token expired, need to re-authenticate
            keychain.clearAll()
            updateAuthState()
            throw AuthError.sessionExpired
        } else {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw AuthError.serverError(error?.detail ?? "Token refresh failed")
        }
    }

    // MARK: - Logout

    func logout() {
        keychain.clearAll()
        updateAuthState()
    }

    // MARK: - Access Token for Requests

    var accessToken: String? {
        keychain.accessToken
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidCode(String)
    case codeNotConfirmed(String)
    case codeExpired
    case serverError(String)
    case rateLimited
    case notAuthenticated
    case sessionExpired
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidCode(let message):
            return message
        case .codeNotConfirmed(let message):
            return message
        case .codeExpired:
            return "Pairing code expired. Please generate a new one."
        case .serverError(let message):
            return message
        case .rateLimited:
            return "Too many requests. Please wait and try again."
        case .notAuthenticated:
            return "Not authenticated"
        case .sessionExpired:
            return "Session expired. Please pair again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
