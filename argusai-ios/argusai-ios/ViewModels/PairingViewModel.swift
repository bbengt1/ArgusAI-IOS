//
//  PairingViewModel.swift
//  ArgusAI
//
//  View model for the pairing flow.
//

import Foundation

@Observable
final class PairingViewModel {
    // MARK: - State

    enum PairingState: Equatable {
        case idle
        case generatingCode
        case waitingForConfirmation(code: String, expiresAt: Date)
        case confirmed
        case exchangingTokens
        case completed
        case error(String)
    }

    private(set) var state: PairingState = .idle
    private(set) var timeRemaining: TimeInterval = 0

    private var pollingTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var currentCode: String?

    // MARK: - Computed Properties

    var isLoading: Bool {
        switch state {
        case .generatingCode, .exchangingTokens:
            return true
        default:
            return false
        }
    }

    var pairingCode: String? {
        switch state {
        case .waitingForConfirmation(let code, _):
            return code
        default:
            return nil
        }
    }

    var formattedCode: String {
        guard let code = pairingCode else { return "------" }
        // Format as "XXX XXX" for readability
        let index = code.index(code.startIndex, offsetBy: min(3, code.count))
        return "\(code[..<index]) \(code[index...])"
    }

    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var errorMessage: String? {
        if case .error(let message) = state {
            return message
        }
        return nil
    }

    var isExpired: Bool {
        timeRemaining <= 0 && pairingCode != nil
    }

    // MARK: - Lifecycle

    deinit {
        stopPolling()
    }

    // MARK: - Public Methods

    /// Start the pairing flow by generating a code
    @MainActor
    func startPairing(authService: AuthService) async {
        stopPolling()
        state = .generatingCode

        do {
            let response = try await authService.generatePairingCode()
            currentCode = response.code

            let expiresAt = response.expiresAt
            timeRemaining = expiresAt.timeIntervalSinceNow

            state = .waitingForConfirmation(code: response.code, expiresAt: expiresAt)

            // Start polling for confirmation
            startPolling(code: response.code, authService: authService)

            // Start countdown timer
            startTimer(expiresAt: expiresAt)

        } catch let error as AuthError {
            state = .error(error.localizedDescription)
        } catch {
            state = .error("Failed to generate pairing code")
        }
    }

    /// Retry pairing after an error or expiration
    @MainActor
    func retry(authService: AuthService) async {
        await startPairing(authService: authService)
    }

    /// Cancel the current pairing attempt
    func cancel() {
        stopPolling()
        state = .idle
        currentCode = nil
    }

    // MARK: - Private Methods

    private func startPolling(code: String, authService: AuthService) {
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                // Check if code expired
                if self.timeRemaining <= 0 {
                    self.state = .error("Pairing code expired")
                    self.stopPolling()
                    break
                }

                do {
                    let status = try await authService.checkPairingStatus(code)

                    if status.confirmed {
                        // Code confirmed, exchange for tokens
                        self.state = .confirmed
                        // Stop timer but don't cancel polling task yet (we're inside it)
                        self.timerTask?.cancel()
                        self.timerTask = nil
                        await self.exchangeTokens(code: code, authService: authService)
                        self.pollingTask = nil
                        return
                    } else if status.expired {
                        self.state = .error("Pairing code expired")
                        self.stopPolling()
                        return
                    }
                    // Still pending, continue polling
                } catch let error as AuthError {
                    // Don't stop on transient errors, just log
                    print("Status check error: \(error.localizedDescription)")
                } catch {
                    print("Status check error: \(error.localizedDescription)")
                }

                // Poll every 2 seconds
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @MainActor
    private func exchangeTokens(code: String, authService: AuthService) async {
        state = .exchangingTokens

        do {
            try await authService.exchangeCodeForTokens(code)
            state = .completed
            // AuthService will update isAuthenticated
        } catch let error as AuthError {
            state = .error(error.localizedDescription)
        } catch {
            state = .error("Failed to complete pairing")
        }
    }

    private func startTimer(expiresAt: Date) {
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                let remaining = expiresAt.timeIntervalSinceNow
                self.timeRemaining = max(0, remaining)

                if remaining <= 0 {
                    break
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        timerTask?.cancel()
        timerTask = nil
    }
}
