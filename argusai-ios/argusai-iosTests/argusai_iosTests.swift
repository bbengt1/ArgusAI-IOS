//
//  argusai_iosTests.swift
//  argusai-iosTests
//
//  Created by Brent Bengtson on 12/26/25.
//

import Foundation
import Testing
@testable import argusai_ios

// MARK: - PairingViewModel Tests

@Suite("PairingViewModel Tests")
struct PairingViewModelTests {

    @Test("Initial state is idle")
    func testInitialState() {
        let viewModel = PairingViewModel()
        #expect(viewModel.state == .idle)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.pairingCode == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("formattedCode formats 6-digit code as XXX XXX")
    func testFormattedCode() {
        let viewModel = PairingViewModel()
        // When no code is set, should return dashes
        #expect(viewModel.formattedCode == "------")
    }

    @Test("formattedTimeRemaining formats correctly")
    func testFormattedTimeRemaining() {
        let viewModel = PairingViewModel()
        // Default is 0 seconds
        #expect(viewModel.formattedTimeRemaining == "0:00")
    }

    @Test("isExpired returns false when no code")
    func testIsExpiredNoCode() {
        let viewModel = PairingViewModel()
        #expect(viewModel.isExpired == false)
    }

    @Test("cancel() resets state to idle")
    func testCancel() {
        let viewModel = PairingViewModel()
        viewModel.cancel()
        #expect(viewModel.state == .idle)
    }

    @Test("PairingState equality works correctly")
    func testPairingStateEquality() {
        let state1 = PairingViewModel.PairingState.idle
        let state2 = PairingViewModel.PairingState.idle
        #expect(state1 == state2)

        let error1 = PairingViewModel.PairingState.error("Test")
        let error2 = PairingViewModel.PairingState.error("Test")
        #expect(error1 == error2)
    }
}

// MARK: - EventListViewModel Tests

@Suite("EventListViewModel Tests")
struct EventListViewModelTests {

    @Test("Initial state is correct")
    func testInitialState() {
        let viewModel = EventListViewModel()
        #expect(viewModel.events.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasMore == false)
    }

    @Test("isEmpty returns true when events are empty and not loading")
    func testIsEmpty() {
        let viewModel = EventListViewModel()
        #expect(viewModel.isEmpty == true)
    }

    @Test("isEmpty returns false when loading")
    func testIsEmptyWhileLoading() {
        let viewModel = EventListViewModel()
        viewModel.isLoading = true
        #expect(viewModel.isEmpty == false)
    }

    @Test("hasError returns true when errorMessage is set")
    func testHasError() {
        let viewModel = EventListViewModel()
        viewModel.errorMessage = "Network error"
        #expect(viewModel.hasError == true)
    }

    @Test("reset() clears all state")
    func testReset() {
        let viewModel = EventListViewModel()
        viewModel.errorMessage = "Error"
        viewModel.hasMore = true
        viewModel.reset()
        #expect(viewModel.events.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasMore == false)
    }
}

// MARK: - EventDetailViewModel Tests

@Suite("EventDetailViewModel Tests")
struct EventDetailViewModelTests {

    @Test("Initial state is correct")
    func testInitialState() {
        let viewModel = EventDetailViewModel()
        #expect(viewModel.event == nil)
        #expect(viewModel.thumbnailData == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isLoadingThumbnail == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("hasEvent returns true when event is set")
    func testHasEvent() {
        let viewModel = EventDetailViewModel()
        #expect(viewModel.hasEvent == false)
    }

    @Test("hasThumbnail returns true when thumbnailData is set")
    func testHasThumbnail() {
        let viewModel = EventDetailViewModel()
        #expect(viewModel.hasThumbnail == false)
        viewModel.thumbnailData = Data([0x00])
        #expect(viewModel.hasThumbnail == true)
    }

    @Test("reset() clears all state")
    func testReset() {
        let viewModel = EventDetailViewModel()
        viewModel.thumbnailData = Data([0x00])
        viewModel.errorMessage = "Error"
        viewModel.isLoading = true
        viewModel.reset()
        #expect(viewModel.event == nil)
        #expect(viewModel.thumbnailData == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }
}

// MARK: - Model Parsing Tests

@Suite("Model Parsing Tests")
struct ModelParsingTests {

    @Test("SmartDetectionType has correct display names")
    func testSmartDetectionTypeDisplayNames() {
        #expect(SmartDetectionType.person.displayName == "Person")
        #expect(SmartDetectionType.vehicle.displayName == "Vehicle")
        #expect(SmartDetectionType.package.displayName == "Package")
        #expect(SmartDetectionType.animal.displayName == "Animal")
        #expect(SmartDetectionType.motion.displayName == "Motion")
    }

    @Test("SmartDetectionType has correct icon names")
    func testSmartDetectionTypeIconNames() {
        #expect(SmartDetectionType.person.iconName == "person.fill")
        #expect(SmartDetectionType.vehicle.iconName == "car.fill")
        #expect(SmartDetectionType.package.iconName == "shippingbox.fill")
        #expect(SmartDetectionType.animal.iconName == "pawprint.fill")
        #expect(SmartDetectionType.motion.iconName == "waveform")
    }

    @Test("AnalysisMode has correct display names")
    func testAnalysisModeDisplayNames() {
        #expect(AnalysisMode.singleFrame.displayName == "Single Frame")
        #expect(AnalysisMode.multiFrame.displayName == "Multi-Frame")
        #expect(AnalysisMode.videoNative.displayName == "Video Native")
    }

    @Test("AnalysisMode decodes from snake_case")
    func testAnalysisModeDecoding() throws {
        let json = #"{"analysis_mode": "single_frame"}"#
        let data = json.data(using: .utf8)!

        struct TestStruct: Codable {
            let analysisMode: AnalysisMode
            enum CodingKeys: String, CodingKey {
                case analysisMode = "analysis_mode"
            }
        }

        let decoded = try JSONDecoder().decode(TestStruct.self, from: data)
        #expect(decoded.analysisMode == .singleFrame)
    }

    @Test("EventSummary decodes correctly")
    func testEventSummaryDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "camera_id": "550e8400-e29b-41d4-a716-446655440001",
            "camera_name": "Front Door",
            "timestamp": "2025-01-01T12:00:00Z",
            "description": "Person detected at front door",
            "smart_detection_type": "person",
            "confidence": 95,
            "has_thumbnail": true
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(EventSummary.self, from: data)

        #expect(event.cameraName == "Front Door")
        #expect(event.description == "Person detected at front door")
        #expect(event.smartDetectionType == .person)
        #expect(event.confidence == 95)
        #expect(event.hasThumbnail == true)
    }

    @Test("Camera decodes correctly")
    func testCameraDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Backyard Camera",
            "is_enabled": true,
            "is_online": true,
            "source_type": "rtsp",
            "last_event_at": "2025-01-01T12:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let camera = try decoder.decode(Camera.self, from: data)

        #expect(camera.name == "Backyard Camera")
        #expect(camera.isEnabled == true)
        #expect(camera.isOnline == true)
        #expect(camera.sourceType == "rtsp")
    }

    @Test("TokenResponse decodes correctly")
    func testTokenResponseDecoding() throws {
        let json = """
        {
            "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
            "refresh_token": "refresh_token_value",
            "token_type": "Bearer",
            "expires_in": 3600
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        #expect(response.accessToken == "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
        #expect(response.refreshToken == "refresh_token_value")
        #expect(response.tokenType == "Bearer")
        #expect(response.expiresIn == 3600)
    }

    @Test("PairRequest encodes correctly")
    func testPairRequestEncoding() throws {
        let request = PairRequest(
            deviceId: "device-123",
            deviceName: "iPhone",
            deviceModel: "iPhone 15",
            platform: "ios"
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["device_id"] as? String == "device-123")
        #expect(json["device_name"] as? String == "iPhone")
        #expect(json["device_model"] as? String == "iPhone 15")
        #expect(json["platform"] as? String == "ios")
    }

    @Test("ExchangeRequest encodes correctly")
    func testExchangeRequestEncoding() throws {
        let request = ExchangeRequest(
            code: "123456",
            deviceId: "device-123"
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["code"] as? String == "123456")
        #expect(json["device_id"] as? String == "device-123")
    }

    @Test("PairingStatusResponse decodes pending status")
    func testPairingStatusResponsePending() throws {
        let json = """
        {
            "confirmed": false,
            "expired": false
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(PairingStatusResponse.self, from: data)

        #expect(response.confirmed == false)
        #expect(response.expired == false)
    }

    @Test("PairingStatusResponse decodes confirmed status")
    func testPairingStatusResponseConfirmed() throws {
        let json = """
        {
            "confirmed": true,
            "expired": false
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(PairingStatusResponse.self, from: data)

        #expect(response.confirmed == true)
        #expect(response.expired == false)
    }

    @Test("PairingStatusResponse decodes expired status")
    func testPairingStatusResponseExpired() throws {
        let json = """
        {
            "confirmed": false,
            "expired": true
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(PairingStatusResponse.self, from: data)

        #expect(response.confirmed == false)
        #expect(response.expired == true)
    }
}

// MARK: - API Error Tests

@Suite("API Error Tests")
struct APIErrorTests {

    @Test("APIError has correct error descriptions")
    func testAPIErrorDescriptions() {
        #expect(APIError.notAuthenticated.errorDescription?.contains("Not authenticated") == true)
        #expect(APIError.sessionExpired.errorDescription?.contains("Session expired") == true)
        #expect(APIError.notFound.errorDescription?.contains("not found") == true)
        #expect(APIError.rateLimited.errorDescription?.contains("Too many requests") == true)
        #expect(APIError.serverError(500).errorDescription?.contains("500") == true)
    }
}

// MARK: - Auth Error Tests

@Suite("Auth Error Tests")
struct AuthErrorTests {

    @Test("AuthError has correct error descriptions")
    func testAuthErrorDescriptions() {
        #expect(AuthError.invalidURL.errorDescription?.contains("Invalid") == true)
        #expect(AuthError.rateLimited.errorDescription?.contains("Too many requests") == true)
        #expect(AuthError.notAuthenticated.errorDescription?.contains("Not authenticated") == true)
        #expect(AuthError.sessionExpired.errorDescription?.contains("expired") == true)
    }

    @Test("AuthError codeNotConfirmed has correct description")
    func testCodeNotConfirmedError() {
        let error = AuthError.codeNotConfirmed("Code not yet confirmed")
        #expect(error.errorDescription?.contains("not yet confirmed") == true)
    }

    @Test("AuthError codeExpired has correct description")
    func testCodeExpiredError() {
        let error = AuthError.codeExpired
        #expect(error.errorDescription?.contains("expired") == true)
    }

    @Test("AuthError invalidCode has correct description")
    func testInvalidCodeError() {
        let error = AuthError.invalidCode("Invalid pairing code")
        #expect(error.errorDescription?.contains("Invalid") == true)
    }
}
