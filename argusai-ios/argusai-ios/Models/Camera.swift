//
//  Camera.swift
//  ArgusAI
//
//  Camera model matching the mobile API schema.
//

import Foundation

// MARK: - Camera Summary
struct Camera: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: String?
    let isEnabled: Bool?
    let sourceType: String?
    let isDoorbell: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case isEnabled = "is_enabled"
        case sourceType = "source_type"
        case isDoorbell = "is_doorbell"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Convenience computed properties with defaults
    var enabled: Bool { isEnabled ?? true }
    var online: Bool { true } // Server doesn't provide online status, assume online
    var doorbell: Bool { isDoorbell ?? false }

    // Display the source type or fall back to type
    var displayType: String {
        sourceType ?? type ?? "Unknown"
    }
}
