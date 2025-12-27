//
//  Event.swift
//  ArgusAI
//
//  Event model matching the mobile API schema.
//

import Foundation

// MARK: - Event Summary (for lists)
struct EventSummary: Codable, Identifiable, Equatable {
    let id: UUID
    let cameraId: UUID
    let cameraName: String
    let timestamp: Date
    let description: String
    let smartDetectionType: SmartDetectionType?
    let confidence: Int?
    let hasThumbnail: Bool?
    let thumbnailPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cameraId = "camera_id"
        case cameraName = "camera_name"
        case timestamp
        case description
        case smartDetectionType = "smart_detection_type"
        case confidence
        case hasThumbnail = "has_thumbnail"
        case thumbnailPath = "thumbnail_path"
    }
}

// MARK: - Event Detail (full response)
struct EventDetail: Codable, Identifiable, Equatable {
    let id: UUID
    let cameraId: UUID
    let cameraName: String
    let timestamp: Date
    let description: String
    let smartDetectionType: SmartDetectionType?
    let confidence: Int?
    let objectsDetected: [String]?
    let isDoorbellRing: Bool?
    let sourceType: String?
    let providerUsed: String?
    let analysisMode: AnalysisMode?
    let deliveryCarrier: String?
    let thumbnailUrl: String?
    let thumbnailPath: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case cameraId = "camera_id"
        case cameraName = "camera_name"
        case timestamp
        case description
        case smartDetectionType = "smart_detection_type"
        case confidence
        case objectsDetected = "objects_detected"
        case isDoorbellRing = "is_doorbell_ring"
        case sourceType = "source_type"
        case providerUsed = "provider_used"
        case analysisMode = "analysis_mode"
        case deliveryCarrier = "delivery_carrier"
        case thumbnailUrl = "thumbnail_url"
        case thumbnailPath = "thumbnail_path"
        case createdAt = "created_at"
    }
}

// MARK: - Smart Detection Type
enum SmartDetectionType: String, Codable, CaseIterable {
    case person
    case vehicle
    case package
    case animal
    case motion
    case manualTrigger = "manual_trigger"
    case unknown

    var displayName: String {
        switch self {
        case .person: return "Person"
        case .vehicle: return "Vehicle"
        case .package: return "Package"
        case .animal: return "Animal"
        case .motion: return "Motion"
        case .manualTrigger: return "Manual"
        case .unknown: return "Event"
        }
    }

    var iconName: String {
        switch self {
        case .person: return "person.fill"
        case .vehicle: return "car.fill"
        case .package: return "shippingbox.fill"
        case .animal: return "pawprint.fill"
        case .motion: return "waveform"
        case .manualTrigger: return "hand.tap.fill"
        case .unknown: return "exclamationmark.circle"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = SmartDetectionType(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - Analysis Mode
enum AnalysisMode: String, Codable {
    case singleFrame = "single_frame"
    case multiFrame = "multi_frame"
    case videoNative = "video_native"

    var displayName: String {
        switch self {
        case .singleFrame: return "Single Frame"
        case .multiFrame: return "Multi-Frame"
        case .videoNative: return "Video Native"
        }
    }
}

// MARK: - Event List Response
struct EventListResponse: Codable {
    let events: [EventSummary]
    let totalCount: Int?
    let hasMore: Bool?
    let nextOffset: Int?

    enum CodingKeys: String, CodingKey {
        case events
        case totalCount = "total_count"
        case hasMore = "has_more"
        case nextOffset = "next_offset"
    }
}

// MARK: - Recent Events Response
struct RecentEventsResponse: Codable {
    let events: [EventSummary]
}
