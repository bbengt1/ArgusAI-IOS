//
//  DiscoveryService.swift
//  ArgusAI
//
//  Bonjour service discovery for local network access.
//

import Foundation
import Network

@Observable
final class DiscoveryService {
    static let shared = DiscoveryService()

    private static let serverHostKey = "argusai.server.host"
    private static let serverPortKey = "argusai.server.port"
    private static let serverUseHTTPSKey = "argusai.server.useHTTPS"
    private static let skipSSLVerificationKey = "argusai.server.skipSSLVerification"

    /// The current base URL to use for API requests
    /// Prefers local discovery, falls back to configured server
    var currentBaseURL: String {
        if let local = localEndpoint, isLocalAvailable {
            return local
        }
        return configuredServerURL ?? "https://argusai.example.com"
    }

    /// Whether local ArgusAI was discovered
    var isLocalAvailable = false

    /// The discovered local endpoint (e.g., "http://192.168.1.100:8000")
    var localEndpoint: String?

    /// Whether a server has been configured
    var isServerConfigured: Bool {
        serverHost != nil && !serverHost!.isEmpty
    }

    /// The configured server URL built from host, port, and protocol
    var configuredServerURL: String? {
        guard let host = serverHost, !host.isEmpty else { return nil }
        let scheme = useHTTPS ? "https" : "http"
        let portSuffix = serverPort != nil ? ":\(serverPort!)" : ""
        return "\(scheme)://\(host)\(portSuffix)"
    }

    /// Server host (persisted)
    var serverHost: String? {
        didSet {
            UserDefaults.standard.set(serverHost, forKey: Self.serverHostKey)
        }
    }

    /// Server port (persisted)
    var serverPort: Int? {
        didSet {
            if let port = serverPort {
                UserDefaults.standard.set(port, forKey: Self.serverPortKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.serverPortKey)
            }
        }
    }

    /// Whether to use HTTPS (persisted)
    var useHTTPS: Bool = true {
        didSet {
            UserDefaults.standard.set(useHTTPS, forKey: Self.serverUseHTTPSKey)
        }
    }

    /// Whether to skip SSL certificate verification (persisted)
    /// WARNING: Only use for development with self-signed certificates
    var skipSSLVerification: Bool = false {
        didSet {
            UserDefaults.standard.set(skipSSLVerification, forKey: Self.skipSSLVerificationKey)
            // Recreate the shared session when this changes
            _urlSession = nil
        }
    }

    private var browser: NWBrowser?
    private var isSearching = false

    /// Shared URLSession that respects SSL verification settings
    private var _urlSession: URLSession?
    var urlSession: URLSession {
        if let session = _urlSession {
            return session
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session: URLSession
        if skipSSLVerification {
            session = URLSession(configuration: config, delegate: SSLBypassDelegate.shared, delegateQueue: nil)
        } else {
            session = URLSession(configuration: config)
        }
        _urlSession = session
        return session
    }

    private init() {
        // Load persisted values
        serverHost = UserDefaults.standard.string(forKey: Self.serverHostKey)
        let storedPort = UserDefaults.standard.integer(forKey: Self.serverPortKey)
        serverPort = storedPort > 0 ? storedPort : nil
        useHTTPS = UserDefaults.standard.object(forKey: Self.serverUseHTTPSKey) as? Bool ?? true
        skipSSLVerification = UserDefaults.standard.bool(forKey: Self.skipSSLVerificationKey)
    }

    // MARK: - Discovery

    func startDiscovery() {
        guard !isSearching else { return }
        isSearching = true

        // Browse for ArgusAI service on local network
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_argusai._tcp", domain: "local.")
        browser = NWBrowser(for: descriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Bonjour browser ready")
            case .failed(let error):
                print("Bonjour browser failed: \(error)")
                self?.isSearching = false
            case .cancelled:
                print("Bonjour browser cancelled")
                self?.isSearching = false
            default:
                break
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleDiscoveryResults(results)
        }

        browser?.start(queue: .main)

        // Stop searching after 10 seconds if nothing found
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.localEndpoint == nil {
                self?.stopDiscovery()
            }
        }
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    func refreshDiscovery() {
        stopDiscovery()
        localEndpoint = nil
        isLocalAvailable = false
        startDiscovery()
    }

    private func handleDiscoveryResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                print("Found service: \(name).\(type).\(domain)")
                resolveService(result)
            default:
                break
            }
        }
    }

    private func resolveService(_ result: NWBrowser.Result) {
        let connection = NWConnection(to: result.endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // Get the resolved IP address and port
                if let path = connection.currentPath,
                   let endpoint = path.remoteEndpoint {
                    self?.extractEndpoint(from: endpoint)
                }
                connection.cancel()

            case .failed(let error):
                print("Connection failed: \(error)")
                connection.cancel()

            default:
                break
            }
        }

        connection.start(queue: .main)

        // Timeout after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if connection.state != .ready {
                connection.cancel()
            }
        }
    }

    private func extractEndpoint(from endpoint: NWEndpoint) {
        switch endpoint {
        case .hostPort(let host, let port):
            let hostString: String
            switch host {
            case .ipv4(let address):
                hostString = "\(address)"
            case .ipv6(let address):
                hostString = "[\(address)]"
            case .name(let name, _):
                hostString = name
            @unknown default:
                return
            }

            let url = "http://\(hostString):\(port)"
            print("Resolved ArgusAI at: \(url)")

            DispatchQueue.main.async { [weak self] in
                self?.localEndpoint = url
                self?.isLocalAvailable = true
                self?.stopDiscovery()
            }

        default:
            break
        }
    }

    // MARK: - Configuration

    func configureServer(host: String, port: Int?, useHTTPS: Bool, skipSSLVerification: Bool = false) {
        self.serverHost = host
        self.serverPort = port
        self.useHTTPS = useHTTPS
        self.skipSSLVerification = skipSSLVerification
    }

    func clearServerConfiguration() {
        serverHost = nil
        serverPort = nil
        useHTTPS = true
        skipSSLVerification = false
        _urlSession = nil
        UserDefaults.standard.removeObject(forKey: Self.serverHostKey)
        UserDefaults.standard.removeObject(forKey: Self.serverPortKey)
        UserDefaults.standard.removeObject(forKey: Self.serverUseHTTPSKey)
        UserDefaults.standard.removeObject(forKey: Self.skipSSLVerificationKey)
    }
}

// MARK: - SSL Bypass Delegate
/// URLSession delegate that bypasses SSL certificate verification
/// WARNING: Only use for development with self-signed certificates
final class SSLBypassDelegate: NSObject, URLSessionDelegate {
    static let shared = SSLBypassDelegate()

    private override init() {
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Accept any server certificate
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
