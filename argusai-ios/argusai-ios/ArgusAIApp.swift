//
//  ArgusAIApp.swift
//  ArgusAI
//
//  Created by ArgusAI Development Team
//  Copyright 2025 ArgusAI. All rights reserved.
//

import SwiftUI
import UserNotifications

@main
struct ArgusAIApp: App {
    @State private var authService = AuthService()
    @State private var pushService = PushService()
    @State private var discoveryService = DiscoveryService.shared

    init() {
        // Request push notification permission on launch
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(pushService)
                .environment(discoveryService)
                .onAppear {
                    // Start Bonjour discovery for local ArgusAI
                    discoveryService.startDiscovery()
                }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error = error {
                print("Push notification permission error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Content View Router
struct ContentView: View {
    @Environment(AuthService.self) private var authService
    @Environment(DiscoveryService.self) private var discoveryService

    var body: some View {
        Group {
            if !discoveryService.isServerConfigured {
                ServerConfigView()
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                PairingView()
            }
        }
        .animation(.easeInOut, value: discoveryService.isServerConfigured)
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                EventListView()
            }
            .tabItem {
                Label("Events", systemImage: "bell.fill")
            }

            NavigationStack {
                CameraListView()
            }
            .tabItem {
                Label("Cameras", systemImage: "video.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

// MARK: - Settings View (Minimal)
struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @Environment(DiscoveryService.self) private var discoveryService
    @State private var showingLogoutConfirmation = false
    @State private var showingServerChange = false

    var body: some View {
        List {
            Section("Server") {
                if let serverURL = discoveryService.configuredServerURL {
                    HStack {
                        Text("Server")
                        Spacer()
                        Text(serverURL)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if discoveryService.isLocalAvailable, let localEndpoint = discoveryService.localEndpoint {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundStyle(.green)
                        Text("Local: \(localEndpoint)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Change Server") {
                    showingServerChange = true
                }
            }

            Section("Account") {
                if let deviceName = authService.deviceName {
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(deviceName)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Logout", role: .destructive) {
                    showingLogoutConfirmation = true
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0 (Prototype)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Logout", isPresented: $showingLogoutConfirmation) {
            Button("Logout", role: .destructive) {
                authService.logout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to logout? You'll need to pair again to reconnect.")
        }
        .confirmationDialog("Change Server", isPresented: $showingServerChange) {
            Button("Change Server", role: .destructive) {
                authService.logout()
                discoveryService.clearServerConfiguration()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Changing the server will log you out and require re-pairing.")
        }
    }
}

// MARK: - Camera List View (Minimal)
struct CameraListView: View {
    @Environment(AuthService.self) private var authService
    @State private var cameras: [Camera] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading cameras...")
            } else if let error = error {
                ErrorView(message: error) {
                    Task { await loadCameras() }
                }
            } else if cameras.isEmpty {
                ContentUnavailableView("No Cameras", systemImage: "video.slash", description: Text("No cameras are configured."))
            } else {
                List(cameras) { camera in
                    CameraRowView(camera: camera)
                }
            }
        }
        .navigationTitle("Cameras")
        .task {
            await loadCameras()
        }
        .refreshable {
            await loadCameras()
        }
    }

    private func loadCameras() async {
        isLoading = true
        error = nil

        do {
            let apiClient = APIClient(authService: authService)
            cameras = try await apiClient.fetchCameras()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

struct CameraRowView: View {
    let camera: Camera

    var body: some View {
        HStack {
            Circle()
                .fill(camera.online ? .green : .gray)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading) {
                Text(camera.name)
                    .font(.headline)

                Text(camera.displayType.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !camera.enabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
