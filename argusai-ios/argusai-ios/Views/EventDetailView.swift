//
//  EventDetailView.swift
//  ArgusAI
//
//  Event detail view with full description and metadata.
//

import SwiftUI

struct EventDetailView: View {
    let eventId: UUID

    @Environment(AuthService.self) private var authService
    @State private var viewModel = EventDetailViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Loading event...")
                    .padding(.top, 100)
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task { await viewModel.loadEvent(id: eventId, authService: authService) }
                }
                .padding(.top, 100)
            } else if let event = viewModel.event {
                eventContent(event)
            }
        }
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEvent(id: eventId, authService: authService)
        }
    }

    @ViewBuilder
    private func eventContent(_ event: EventDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Thumbnail
            if let data = viewModel.thumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if viewModel.isLoadingThumbnail {
                ProgressView()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)

                Text(event.description)
                    .font(.body)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Metadata
            VStack(alignment: .leading, spacing: 12) {
                Text("Details")
                    .font(.headline)

                detailRow("Camera", value: event.cameraName)
                detailRow("Time", value: formattedDate(event.timestamp))

                if let detectionType = event.smartDetectionType {
                    detailRow("Detection Type", value: detectionType.displayName)
                }

                if let confidence = event.confidence {
                    detailRow("Confidence", value: "\(confidence)%")
                }

                if let objects = event.objectsDetected, !objects.isEmpty {
                    detailRow("Objects", value: objects.joined(separator: ", "))
                }

                if event.isDoorbellRing == true {
                    detailRow("Doorbell", value: "Ring detected")
                }

                if let carrier = event.deliveryCarrier {
                    detailRow("Delivery", value: carrier)
                }

                if let sourceType = event.sourceType {
                    detailRow("Source", value: sourceType.capitalized)
                }

                if let provider = event.providerUsed {
                    detailRow("AI Provider", value: provider)
                }

                if let analysisMode = event.analysisMode {
                    detailRow("Analysis Mode", value: analysisMode.displayName)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .task {
            await viewModel.loadThumbnail(authService: authService)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        EventDetailView(eventId: UUID())
            .environment(AuthService())
    }
}
