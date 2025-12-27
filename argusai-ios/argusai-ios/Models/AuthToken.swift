//
//  AuthToken.swift
//  ArgusAI
//
//  Authentication token models for mobile API.
//

import Foundation

// MARK: - Pairing Request
struct PairRequest: Codable {
    let deviceId: String
    let deviceName: String
    let deviceModel: String?
    let platform: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case platform
    }
}

// MARK: - Pairing Response
struct PairResponse: Codable {
    let code: String
    let expiresIn: Int
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case code
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
    }
}

// MARK: - Pairing Status Response
struct PairingStatusResponse: Codable {
    let confirmed: Bool
    let expired: Bool
}

// MARK: - Exchange Request
struct ExchangeRequest: Codable {
    let code: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case code
        case deviceId = "device_id"
    }
}

// MARK: - Token Response
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// MARK: - Refresh Request
struct RefreshRequest: Codable {
    let refreshToken: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case deviceId = "device_id"
    }
}

// MARK: - Push Registration Request
struct PushRegisterRequest: Codable {
    let deviceToken: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case deviceId = "device_id"
    }
}

// MARK: - Push Registration Response
struct PushRegisterResponse: Codable {
    let id: UUID
    let registeredAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case registeredAt = "registered_at"
    }
}

// MARK: - Error Response
struct ErrorResponse: Codable {
    let detail: String
}
