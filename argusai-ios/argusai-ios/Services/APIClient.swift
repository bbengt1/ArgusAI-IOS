//
//  APIClient.swift
//  ArgusAI
//
//  HTTP client for mobile API requests.
//

import Foundation
import UIKit

actor APIClient {
    private let authService: AuthService
    private var retryCount = 0
    private let maxRetries = 3

    /// URLSession that respects SSL verification settings from DiscoveryService
    private var session: URLSession {
        DiscoveryService.shared.urlSession
    }

    init(authService: AuthService) {
        self.authService = authService
    }

    private var baseURL: String {
        DiscoveryService.shared.currentBaseURL
    }

    // MARK: - JSON Decoder

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try without timezone (assume UTC)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            // Try without timezone and without fractional seconds
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }
        return decoder
    }()

    // MARK: - Events

    func fetchEvents(
        cameraId: UUID? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> EventListResponse {
        var components = URLComponents(string: "\(baseURL)/api/v1/events")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        if let cameraId = cameraId {
            queryItems.append(URLQueryItem(name: "camera_id", value: cameraId.uuidString))
        }

        let formatter = ISO8601DateFormatter()
        if let startTime = startTime {
            queryItems.append(URLQueryItem(name: "start_time", value: formatter.string(from: startTime)))
        }
        if let endTime = endTime {
            queryItems.append(URLQueryItem(name: "end_time", value: formatter.string(from: endTime)))
        }

        components.queryItems = queryItems

        return try await authenticatedRequest(url: components.url!)
    }

    func fetchRecentEvents(limit: Int = 5) async throws -> RecentEventsResponse {
        var components = URLComponents(string: "\(baseURL)/api/v1/events/recent")!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        return try await authenticatedRequest(url: components.url!)
    }

    func fetchEventDetail(id: UUID) async throws -> EventDetail {
        let url = URL(string: "\(baseURL)/api/v1/events/\(id.uuidString.lowercased())")!
        return try await authenticatedRequest(url: url)
    }

    func fetchEventThumbnail(id: UUID) async throws -> Data {
        let url = URL(string: "\(baseURL)/api/v1/events/\(id.uuidString.lowercased())/thumbnail")!
        return try await authenticatedImageRequest(url: url)
    }

    func fetchThumbnail(path: String) async throws -> Data {
        // thumbnail_path may be full path like "api/v1/thumbnails/..." or relative "thumbnails/..."
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let urlPath = cleanPath.hasPrefix("api/") ? cleanPath : "api/v1/\(cleanPath)"
        let url = URL(string: "\(baseURL)/\(urlPath)")!
        print("[APIClient] Fetching thumbnail: \(url.absoluteString)")
        return try await authenticatedImageRequest(url: url)
    }

    // MARK: - Cameras

    func fetchCameras() async throws -> [Camera] {
        let url = URL(string: "\(baseURL)/api/v1/cameras")!
        // Server returns array directly, not wrapped in {"cameras": [...]}
        return try await authenticatedRequest(url: url)
    }

    func fetchCameraSnapshot(id: UUID) async throws -> Data {
        let url = URL(string: "\(baseURL)/api/v1/cameras/\(id.uuidString.lowercased())/snapshot")!
        return try await authenticatedImageRequest(url: url)
    }

    // MARK: - Private Request Methods

    private func authenticatedRequest<T: Decodable>(url: URL) async throws -> T {
        print("[APIClient] Request: \(url.absoluteString)")

        // Refresh token if needed before request
        try await authService.refreshTokenIfNeeded()

        guard let token = await authService.accessToken else {
            throw APIError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("[APIClient] Response (\(httpResponse.statusCode)): \(responseBody.prefix(500))")

            switch httpResponse.statusCode {
            case 200...299:
                retryCount = 0
                do {
                    return try decoder.decode(T.self, from: data)
                } catch let decodingError {
                    print("[APIClient] Decoding error: \(decodingError)")
                    throw decodingError
                }

            case 401:
                // Token expired, try to refresh once
                if retryCount < 1 {
                    retryCount += 1
                    if let refreshToken = KeychainService.shared.refreshToken {
                        try await authService.refreshToken(with: refreshToken)
                        return try await authenticatedRequest(url: url)
                    }
                }
                retryCount = 0
                throw APIError.sessionExpired

            case 404:
                throw APIError.notFound

            case 429:
                throw APIError.rateLimited

            case 500...599:
                throw APIError.serverError(httpResponse.statusCode)

            default:
                throw APIError.unexpectedStatus(httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            // Network errors - implement retry with exponential backoff
            if retryCount < maxRetries {
                retryCount += 1
                let delay = pow(2.0, Double(retryCount))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await authenticatedRequest(url: url)
            }
            retryCount = 0
            throw APIError.networkError(error)
        }
    }

    private func authenticatedImageRequest(url: URL) async throws -> Data {
        // Refresh token if needed before request
        try await authService.refreshTokenIfNeeded()

        guard let token = await authService.accessToken else {
            throw APIError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.sessionExpired
            } else if httpResponse.statusCode == 404 {
                throw APIError.notFound
            }
            throw APIError.unexpectedStatus(httpResponse.statusCode)
        }

        return data
    }

    private func unauthenticatedImageRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw APIError.notFound
            }
            throw APIError.unexpectedStatus(httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case notAuthenticated
    case sessionExpired
    case invalidResponse
    case notFound
    case rateLimited
    case serverError(Int)
    case unexpectedStatus(Int)
    case networkError(Error)
    case decodingError(DecodingError)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please pair your device."
        case .sessionExpired:
            return "Session expired. Please pair again."
        case .invalidResponse:
            return "Invalid server response"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please wait and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .unexpectedStatus(let code):
            return "Unexpected response (\(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        }
    }
}
