//
//  ServerConfigView.swift
//  ArgusAI
//
//  Server configuration view for entering ArgusAI server details.
//

import SwiftUI

struct ServerConfigView: View {
    @Environment(DiscoveryService.self) private var discoveryService

    @State private var host: String = ""
    @State private var port: String = ""
    @State private var useHTTPS: Bool = true
    @State private var skipSSLVerification: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var connectionError: String?
    @State private var connectionSuccess: Bool = false

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

                    Text("Enter your ArgusAI server details")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Server configuration form
                VStack(spacing: 16) {
                    // Host field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Host")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("e.g., argusai.local or 192.168.1.100", text: $host)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onChange(of: host) { _, newValue in
                                connectionError = nil
                                connectionSuccess = false
                                // Auto-extract port if user enters host:port format
                                parseHostAndPort(newValue)
                            }
                    }

                    // Port field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Port (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("e.g., 8000", text: $port)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .onChange(of: port) { _, _ in
                                connectionError = nil
                                connectionSuccess = false
                            }
                    }

                    // HTTPS toggle
                    Toggle("Use HTTPS", isOn: $useHTTPS)
                        .onChange(of: useHTTPS) { _, _ in
                            connectionError = nil
                            connectionSuccess = false
                        }

                    // SSL Verification toggle (only shown when HTTPS is enabled)
                    if useHTTPS {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Skip SSL Verification", isOn: $skipSSLVerification)
                                .onChange(of: skipSSLVerification) { _, _ in
                                    connectionError = nil
                                    connectionSuccess = false
                                }

                            Text("Enable for self-signed certificates (development only)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.horizontal)

                // Preview URL
                if !host.isEmpty {
                    Text(previewURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // Status messages
                if let error = connectionError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal)
                }

                if connectionSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connection successful!")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal)
                }

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        if isTestingConnection {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(host.isEmpty || isTestingConnection)

                    Button {
                        saveConfiguration()
                    } label: {
                        Text("Continue")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(host.isEmpty)
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load existing configuration if any
                if let existingHost = discoveryService.serverHost {
                    host = existingHost
                }
                if let existingPort = discoveryService.serverPort {
                    port = String(existingPort)
                }
                useHTTPS = discoveryService.useHTTPS
                skipSSLVerification = discoveryService.skipSSLVerification
            }
        }
    }

    private var previewURL: String {
        let scheme = useHTTPS ? "https" : "http"
        let portSuffix = port.isEmpty ? "" : ":\(port)"
        return "\(scheme)://\(host)\(portSuffix)"
    }

    private var parsedPort: Int? {
        guard !port.isEmpty else { return nil }
        return Int(port)
    }

    /// Parse host:port format and extract port if present
    private func parseHostAndPort(_ value: String) {
        // Remove any protocol prefix if user pasted a URL
        var cleanValue = value
        if cleanValue.hasPrefix("https://") {
            cleanValue = String(cleanValue.dropFirst(8))
            useHTTPS = true
        } else if cleanValue.hasPrefix("http://") {
            cleanValue = String(cleanValue.dropFirst(7))
            useHTTPS = false
        }

        // Check for host:port format
        if let colonIndex = cleanValue.lastIndex(of: ":") {
            let potentialPort = String(cleanValue[cleanValue.index(after: colonIndex)...])
            // Make sure it's actually a port number (not part of IPv6)
            if let portNum = Int(potentialPort), portNum > 0 && portNum <= 65535 {
                let hostPart = String(cleanValue[..<colonIndex])
                // Only update if we actually changed something to avoid infinite loop
                if host != hostPart {
                    host = hostPart
                    port = potentialPort
                }
            }
        }
    }

    private func testConnection() async {
        isTestingConnection = true
        connectionError = nil
        connectionSuccess = false

        let scheme = useHTTPS ? "https" : "http"
        let portSuffix = port.isEmpty ? "" : ":\(port)"
        let urlString = "\(scheme)://\(host)\(portSuffix)/api/v1/mobile/health"

        guard let url = URL(string: urlString) else {
            connectionError = "Invalid URL"
            isTestingConnection = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        // Create session with or without SSL bypass
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session: URLSession
        if skipSSLVerification && useHTTPS {
            session = URLSession(configuration: config, delegate: SSLBypassDelegate.shared, delegateQueue: nil)
        } else {
            session = URLSession(configuration: config)
        }

        do {
            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 500 {
                    // Any response (even 404) means server is reachable
                    connectionSuccess = true
                } else {
                    connectionError = "Server returned status \(httpResponse.statusCode)"
                }
            }
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                connectionError = "No internet connection"
            case .timedOut:
                connectionError = "Connection timed out"
            case .cannotFindHost:
                connectionError = "Cannot find host"
            case .cannotConnectToHost:
                connectionError = "Cannot connect to host"
            case .secureConnectionFailed:
                connectionError = "SSL/TLS connection failed. Try enabling 'Skip SSL Verification'."
            case .serverCertificateUntrusted:
                connectionError = "Server certificate not trusted. Try enabling 'Skip SSL Verification'."
            default:
                connectionError = "Connection failed: \(error.localizedDescription)"
            }
        } catch {
            connectionError = "Connection failed: \(error.localizedDescription)"
        }

        isTestingConnection = false
    }

    private func saveConfiguration() {
        discoveryService.configureServer(
            host: host,
            port: parsedPort,
            useHTTPS: useHTTPS,
            skipSSLVerification: skipSSLVerification
        )
    }
}

#Preview {
    ServerConfigView()
        .environment(DiscoveryService.shared)
}
