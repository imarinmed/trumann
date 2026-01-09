import Core
import Dependencies
import Foundation

// MARK: - Consent State Machine

public enum ConsentStateMachine {
    public static func canTrack(_ state: ConsentState) -> Bool {
        state == .authorized
    }

    public static func canStore(_ state: ConsentState) -> Bool {
        state == .authorized
    }

    public static func transition(from state: ConsentState, to newState: ConsentState) -> Bool {
        // Only allow authorized -> denied, or notDetermined -> any
        switch (state, newState) {
        case (.notDetermined, _): return true
        case (.authorized, .denied): return true
        case (.authorized, .authorized): return true
        case (.denied, .authorized): return true // User can re-grant
        default: return false
        }
    }
}

// MARK: - Tracking Events

public struct TrackingEvent: Equatable, Codable, Sendable {
    public let id: UUID
    public let type: EventType
    public let timestamp: Date
    public let properties: [String: String]
    public let userId: UUID?  // Pseudonymized

    public init(type: EventType, properties: [String: String] = [:], userId: UUID? = nil) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.properties = properties
        self.userId = userId
    }

    public enum EventType: String, Codable, Sendable {
        case consentGranted = "consent_granted"
        case consentDenied = "consent_denied"
        case jobViewed = "job_viewed"
        case jobApplied = "job_applied"
        case searchPerformed = "search_performed"
        case cvGenerated = "cv_generated"
        case errorOccurred = "error_occurred"
    }
}

// MARK: - ATS Curation Rules

public struct ATSCurationRules: Sendable {
    public let requiredKeywords: [String]
    public let bannedKeywords: [String]
    public let maxKeywordDensity: Double
    public let minKeywordMatches: Int

    public init(
        requiredKeywords: [String] = [],
        bannedKeywords: [String] = [],
        maxKeywordDensity: Double = 0.1,
        minKeywordMatches: Int = 1
    ) {
        self.requiredKeywords = requiredKeywords
        self.bannedKeywords = bannedKeywords
        self.maxKeywordDensity = maxKeywordDensity
        self.minKeywordMatches = minKeywordMatches
    }

    public func evaluate(job: Job, resume: String) -> ATSScore {
        let jobTokens = tokenize(job.description + " " + job.title)
        let resumeTokens = tokenize(resume)

        var score = 0
        var matches: [String] = []

        // Check required keywords
        for keyword in requiredKeywords {
            if jobTokens.contains(where: { $0.lowercased().contains(keyword.lowercased()) }) &&
               resumeTokens.contains(where: { $0.lowercased().contains(keyword.lowercased()) }) {
                score += 1
                matches.append(keyword)
            }
        }

        // Check banned keywords
        let hasBanned = bannedKeywords.contains { keyword in
            jobTokens.contains(where: { $0.lowercased().contains(keyword.lowercased()) })
        }

        // Keyword density
        let density = Double(matches.count) / Double(resumeTokens.count)

        return ATSScore(
            score: score,
            matches: matches,
            density: density,
            passed: score >= minKeywordMatches && !hasBanned && density <= maxKeywordDensity
        )
    }

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 } // Filter short words
    }
}

public struct ATSScore: Equatable, Sendable {
    public let score: Int
    public let matches: [String]
    public let density: Double
    public let passed: Bool
}

// MARK: - Audit Logger

public protocol AuditLogger: Sendable {
    func log(event: TrackingEvent) async
    func query(from: Date, to: Date) async -> [TrackingEvent]
}

extension AuditLogger where Self == LiveAuditLogger {
    public static var live: Self { LiveAuditLogger() }
}

public final class LiveAuditLogger: AuditLogger, @unchecked Sendable {
    private let storage: any Storage
    private let logger: any Logger

    public init(storage: any Storage = .live, logger: any Logger = .live) {
        self.storage = storage
        self.logger = logger
    }

    public func log(event: TrackingEvent) async {
        // Store in secure storage
        do {
            try await storage.save(event, forKey: "audit_\(event.id)")
        } catch {
            logger.log(level: .error, message: "Failed to store audit event: \(error.localizedDescription)", metadata: [:])
        }

        // Log redacted version
        logger.log(
            level: .info,
            message: "Audit: \(event.type.rawValue)",
            metadata: event.properties.mapValues { redact($0) }
        )
    }

    public func query(from: Date, to: Date) async -> [TrackingEvent] {
        // In real impl, query database with date range
        // For now, return empty
        []
    }

    private func redact(_ value: String) -> String {
        // Redact PII from metadata
        value.replacingOccurrences(of: #"\b\d{3}-\d{2}-\d{4}\b"#, with: "[REDACTED_SSN]", options: .regularExpression)
    }
}

// MARK: - Tracking Service

public final class TrackingService: Sendable {
    private let consentService: any ConsentService
    private let auditLogger: any AuditLogger

    public init(consentService: any ConsentService = .live, auditLogger: any AuditLogger = .live) {
        self.consentService = consentService
        self.auditLogger = auditLogger
    }

    public func track(event: TrackingEvent) async {
        guard ConsentStateMachine.canTrack(consentService.currentTrackingAuthorization()) else {
            return // Silently drop if no consent
        }

        await auditLogger.log(event: event)
    }

    public func grantConsent() async {
        let state = await consentService.requestTrackingAuthorization()
        let event = TrackingEvent(
            type: state == .authorized ? .consentGranted : .consentDenied,
            properties: ["result": state.rawValue]
        )
        await track(event: event)
    }

    public func revokeConsent() async {
        // Note: ATT doesn't allow programmatic revocation, but we can track intent
        let event = TrackingEvent(type: .consentDenied, properties: ["method": "user_initiated"])
        await track(event: event)
    }
}

// MARK: - Dependencies Integration

extension DependencyValues {
    public var auditLogger: any AuditLogger {
        get { self[AuditLoggerKey.self] }
        set { self[AuditLoggerKey.self] = newValue }
    }
}

private enum AuditLoggerKey: DependencyKey {
    static let liveValue: any AuditLogger = LiveAuditLogger()
}
