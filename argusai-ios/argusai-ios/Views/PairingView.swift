//
//  PairingView.swift
//  ArgusAI
//
//  Device pairing view that displays a 6-digit code for web dashboard confirmation.
//

import SwiftUI

struct PairingView: View {
    @Environment(AuthService.self) private var authService
    @Environment(DiscoveryService.self) private var discoveryService
    @State private var viewModel = PairingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Logo and title
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("ArgusAI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                // Content based on state
                switch viewModel.state {
                case .idle, .generatingCode:
                    loadingView

                case .waitingForConfirmation:
                    codeDisplayView

                case .confirmed, .exchangingTokens:
                    confirmingView

                case .completed:
                    completedView

                case .error:
                    errorView
                }

                Spacer()

                // Connection status
                VStack(spacing: 4) {
                    ConnectionStatusView()

                    // Show configured server URL for debugging
                    if let serverURL = discoveryService.configuredServerURL {
                        Text(serverURL)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.cancel()
                        discoveryService.clearServerConfiguration()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task {
                await viewModel.startPairing(authService: authService)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            if case .idle = viewModel.state {
                // Idle state after cancel - show start button
                Text("Tap below to generate a pairing code")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.startPairing(authService: authService)
                        }
                    } label: {
                        Text("Start Pairing")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        discoveryService.clearServerConfiguration()
                    } label: {
                        Text("Change Server Settings")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            } else {
                // Generating code state
                ProgressView()
                    .scaleEffect(1.5)

                Text("Generating pairing code...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 40)
    }

    // MARK: - Code Display View

    private var codeDisplayView: some View {
        VStack(spacing: 24) {
            Text("Enter this code in your ArgusAI web dashboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Large code display
            HStack(spacing: 12) {
                ForEach(Array((viewModel.pairingCode ?? "------").enumerated()), id: \.offset) { index, char in
                    CodeDigitView(digit: String(char), isActive: false)
                }
            }
            .padding(.horizontal)

            // Timer
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundStyle(viewModel.timeRemaining < 60 ? .red : .secondary)

                Text("Expires in \(viewModel.formattedTimeRemaining)")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.timeRemaining < 60 ? .red : .secondary)
            }

            // Waiting indicator
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)

                Text("Waiting for confirmation...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // Cancel button
            Button("Cancel") {
                viewModel.cancel()
            }
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
    }

    // MARK: - Confirming View

    private var confirmingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Code confirmed!")
                .font(.title2)
                .fontWeight(.semibold)

            ProgressView()
                .padding(.top)

            Text("Completing pairing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Completed View

    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Pairing complete!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your device is now connected to ArgusAI")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                // Force UI refresh - ContentView will see isAuthenticated is true
                // and transition to MainTabView
            } label: {
                Text("Continue")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 16)
        }
        .padding(.vertical, 40)
        .onAppear {
            // Auto-transition after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Trigger view refresh
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Pairing Failed")
                .font(.title2)
                .fontWeight(.semibold)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.retry(authService: authService)
                    }
                } label: {
                    Text("Try Again")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    discoveryService.clearServerConfiguration()
                } label: {
                    Text("Change Server Settings")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Code Digit View
struct CodeDigitView: View {
    let digit: String?
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 48, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )

            if let digit = digit {
                Text(digit)
                    .font(.title)
                    .fontWeight(.bold)
            }
        }
    }
}

// MARK: - Connection Status View
struct ConnectionStatusView: View {
    @Environment(DiscoveryService.self) private var discoveryService

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(discoveryService.isLocalAvailable ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        if discoveryService.isLocalAvailable {
            return "Local ArgusAI found"
        } else {
            return "Using cloud relay"
        }
    }
}

#Preview {
    PairingView()
        .environment(AuthService())
        .environment(DiscoveryService.shared)
}
