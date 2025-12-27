//
//  EventDetailViewModel.swift
//  ArgusAI
//
//  View model for the event detail view.
//

import Foundation

@Observable
final class EventDetailViewModel {
    var event: EventDetail?
    var thumbnailData: Data?
    var isLoading = false
    var isLoadingThumbnail = false
    var errorMessage: String?

    @MainActor
    func loadEvent(id: UUID, authService: AuthService) async {
        isLoading = true
        errorMessage = nil

        do {
            let client = APIClient(authService: authService)
            event = try await client.fetchEventDetail(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func loadThumbnail(authService: AuthService) async {
        guard thumbnailData == nil else { return }
        guard let thumbnailPath = event?.thumbnailPath else { return }

        isLoadingThumbnail = true

        do {
            let client = APIClient(authService: authService)
            thumbnailData = try await client.fetchThumbnail(path: thumbnailPath)
        } catch {
            print("Failed to load thumbnail: \(error)")
        }

        isLoadingThumbnail = false
    }

    // MARK: - Helpers

    var hasEvent: Bool {
        event != nil
    }

    var hasThumbnail: Bool {
        thumbnailData != nil
    }

    var hasError: Bool {
        errorMessage != nil
    }

    func reset() {
        event = nil
        thumbnailData = nil
        isLoading = false
        isLoadingThumbnail = false
        errorMessage = nil
    }
}
