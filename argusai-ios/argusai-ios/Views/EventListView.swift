//
//  EventListView.swift
//  ArgusAI
//
//  Event list view with thumbnails and pull-to-refresh.
//

import SwiftUI

struct EventListView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = EventListViewModel()
    @State private var selectedEventId: UUID?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.events.isEmpty {
                ProgressView("Loading events...")
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task { await viewModel.loadEvents(authService: authService) }
                }
            } else if viewModel.events.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "bell.slash",
                    description: Text("No events have been detected yet.")
                )
            } else {
                eventList
            }
        }
        .navigationTitle("Events")
        .navigationDestination(item: $selectedEventId) { eventId in
            EventDetailView(eventId: eventId)
        }
        .task {
            await viewModel.loadEvents(authService: authService)
        }
        .refreshable {
            await viewModel.loadEvents(authService: authService)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToEvent)) { notification in
            if let eventId = notification.userInfo?["eventId"] as? UUID {
                selectedEventId = eventId
            }
        }
    }

    private var eventList: some View {
        List {
            ForEach(viewModel.events) { event in
                Button {
                    selectedEventId = event.id
                } label: {
                    EventRowView(event: event, authService: authService)
                }
                .buttonStyle(.plain)
            }

            if viewModel.hasMore && !viewModel.isLoading {
                Button("Load More") {
                    Task { await viewModel.loadMore(authService: authService) }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            if viewModel.isLoading && !viewModel.events.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Event Row View
struct EventRowView: View {
    let event: EventSummary
    let authService: AuthService
    @State private var thumbnailData: Data?
    @State private var isLoadingThumbnail = false

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView
                .frame(width: 80, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let detectionType = event.smartDetectionType {
                        Image(systemName: detectionType.iconName)
                            .foregroundStyle(.blue)
                    }

                    Text(event.cameraName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(event.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(event.description)
                    .font(.subheadline)
                    .lineLimit(2)

                if let detectionType = event.smartDetectionType {
                    HStack {
                        Text(detectionType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())

                        if let confidence = event.confidence {
                            Text("\(confidence)%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let data = thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if isLoadingThumbnail {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
        } else {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
        }
    }

    private func loadThumbnail() async {
        guard let thumbnailPath = event.thumbnailPath, thumbnailData == nil else { return }

        isLoadingThumbnail = true
        defer { isLoadingThumbnail = false }

        do {
            let client = APIClient(authService: authService)
            thumbnailData = try await client.fetchThumbnail(path: thumbnailPath)
        } catch {
            print("Failed to load thumbnail: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        EventListView()
            .environment(AuthService())
    }
}
