import Dependencies
import Foundation
import AppTrackingTransparency

// MARK: - Consent State

/// Represents the current state of user consent for tracking and data collection.
public enum ConsentState: String, Equatable, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case unavailable  // For platforms without ATT (macOS < 12.0, iOS < 14.5)

    public init(from status: ATTrackingManager.AuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .authorized
        @unknown default: self = .denied
        }
    }

    public var allowsTracking: Bool {
        self == .authorized
    }
}

// MARK: - Consent Service Protocol

public protocol ConsentService: Sendable {
    func requestTrackingAuthorization() async -> ConsentState
    func currentTrackingAuthorization() -> ConsentState
    func resetTrackingAuthorization()  // For testing only
}

// MARK: - Live Implementation

extension ConsentService where Self == LiveConsentService {
    public static var live: Self { LiveConsentService() }
}

public final class LiveConsentService: ConsentService, @unchecked Sendable {
    private let lock = NSLock()
    private var _cachedStatus: ConsentState?

    public init() {}

    public func requestTrackingAuthorization() async -> ConsentState {
        if #available(iOS 14.5, macOS 11.3, *) {
            let status = await ATTrackingManager.requestTrackingAuthorization()
            let consent = ConsentState(from: status)
            lock.withLock { _cachedStatus = consent }
            return consent
        } else {
            let consent: ConsentState = .unavailable
            lock.withLock { _cachedStatus = consent }
            return consent
        }
    }

    public func currentTrackingAuthorization() -> ConsentState {
        if let cached = lock.withLock({ _cachedStatus }) {
            return cached
        }

        if #available(iOS 14.5, macOS 11.3, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            let consent = ConsentState(from: status)
            lock.withLock { _cachedStatus = consent }
            return consent
        } else {
            return .unavailable
        }
    }

    public func resetTrackingAuthorization() {
        lock.withLock { _cachedStatus = nil }
    }
}

// MARK: - Test Implementation

extension ConsentService where Self == TestConsentService {
    public static func test(initialStatus: ConsentState = .notDetermined) -> Self {
        TestConsentService(initialStatus: initialStatus)
    }
}

public final class TestConsentService: ConsentService, @unchecked Sendable {
    private var status: ConsentState

    public init(initialStatus: ConsentState = .notDetermined) {
        self.status = initialStatus
    }

    public func requestTrackingAuthorization() async -> ConsentState {
        // Simulate user interaction delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        status = .authorized  // Assume user grants permission in tests
        return status
    }

    public func currentTrackingAuthorization() -> ConsentState {
        status
    }

    public func resetTrackingAuthorization() {
        status = .notDetermined
    }
}

// MARK: - Dependencies Integration

extension DependencyValues {
    public var consentService: any ConsentService {
        get { self[ConsentServiceKey.self] }
        set { self[ConsentServiceKey.self] = newValue }
    }
}

private enum ConsentServiceKey: DependencyKey {
    static let liveValue: any ConsentService = LiveConsentService()
}