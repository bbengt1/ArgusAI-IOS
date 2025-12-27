//
//  EventListViewModel.swift
//  ArgusAI
//
//  View model for the event list.
//

import Foundation

@Observable
final class EventListViewModel {
    var events: [EventSummary] = []
    var isLoading = false
    var errorMessage: String?
    var hasMore = false
    private var currentOffset = 0
    private let pageSize = 20

    @MainActor
    func loadEvents(authService: AuthService) async {
        isLoading = true
        errorMessage = nil
        currentOffset = 0

        do {
            let client = APIClient(authService: authService)
            let response = try await client.fetchEvents(limit: pageSize, offset: 0)
            events = response.events
            hasMore = response.hasMore ?? false
            currentOffset = response.nextOffset ?? pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func loadMore(authService: AuthService) async {
        guard hasMore, !isLoading else { return }

        isLoading = true

        do {
            let client = APIClient(authService: authService)
            let response = try await client.fetchEvents(limit: pageSize, offset: currentOffset)
            events.append(contentsOf: response.events)
            hasMore = response.hasMore ?? false
            currentOffset = response.nextOffset ?? (currentOffset + pageSize)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Filtering

    @MainActor
    func loadEvents(forCamera cameraId: UUID, authService: AuthService) async {
        isLoading = true
        errorMessage = nil
        currentOffset = 0

        do {
            let client = APIClient(authService: authService)
            let response = try await client.fetchEvents(cameraId: cameraId, limit: pageSize, offset: 0)
            events = response.events
            hasMore = response.hasMore ?? false
            currentOffset = response.nextOffset ?? pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Helpers

    var isEmpty: Bool {
        events.isEmpty && !isLoading
    }

    var hasError: Bool {
        errorMessage != nil
    }

    func reset() {
        events = []
        isLoading = false
        errorMessage = nil
        hasMore = false
        currentOffset = 0
    }
}
