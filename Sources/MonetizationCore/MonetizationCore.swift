import Core
import Foundation
import Generation
import ResumeParser
import AnalyticsCore

// MARK: - Monetization Types

/// Premium feature tiers
public enum PremiumTier: String, Codable, Sendable {
    case basic
    case professional
    case enterprise
}

/// User subscription
public struct Subscription: Equatable, Codable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let tier: PremiumTier
    public let status: SubscriptionStatus
    public let startDate: Date
    public let endDate: Date?
    public let autoRenew: Bool
    public let paymentMethod: PaymentMethod?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        tier: PremiumTier,
        status: SubscriptionStatus = .active,
        startDate: Date = Date(),
        endDate: Date?,
        autoRenew: Bool = true,
        paymentMethod: PaymentMethod? = nil
    ) {
        self.id = id
        self.userId = userId
        self.tier = tier
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.autoRenew = autoRenew
        self.paymentMethod = paymentMethod
    }
}

/// Subscription status
public enum SubscriptionStatus: String, Codable, Sendable {
    case active
    case expired
    case cancelled
    case suspended
}

/// Payment method
public struct PaymentMethod: Equatable, Codable, Sendable {
    public let id: UUID
    public let type: PaymentType
    public let lastFour: String
    public let expiryMonth: Int?
    public let expiryYear: Int?
    public let isDefault: Bool

    public init(
        id: UUID = UUID(),
        type: PaymentType,
        lastFour: String,
        expiryMonth: Int? = nil,
        expiryYear: Int? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.type = type
        self.lastFour = lastFour
        self.expiryMonth = expiryMonth
        self.expiryYear = expiryYear
        self.isDefault = isDefault
    }
}

/// Payment types
public enum PaymentType: String, Codable, Sendable {
    case creditCard = "credit_card"
    case debitCard = "debit_card"
    case paypal
    case applePay = "apple_pay"
    case googlePay = "google_pay"
}

/// Usage metrics for billing
public struct UsageMetrics: Equatable, Codable, Sendable {
    public let userId: UUID
    public let period: DateInterval
    public let aiRequests: Int
    public let resumeUploads: Int
    public let jobApplications: Int
    public let interviewSessions: Int
    public let storageUsed: Int64 // bytes

    public init(
        userId: UUID,
        period: DateInterval,
        aiRequests: Int = 0,
        resumeUploads: Int = 0,
        jobApplications: Int = 0,
        interviewSessions: Int = 0,
        storageUsed: Int64 = 0
    ) {
        self.userId = userId
        self.period = period
        self.aiRequests = aiRequests
        self.resumeUploads = resumeUploads
        self.jobApplications = jobApplications
        self.interviewSessions = interviewSessions
        self.storageUsed = storageUsed
    }
}

/// Premium feature access
public enum PremiumFeature: String, Sendable {
    case unlimitedAI = "unlimited_ai"
    case advancedAnalytics = "advanced_analytics"
    case prioritySupport = "priority_support"
    case customTemplates = "custom_templates"
    case teamCollaboration = "team_collaboration"
    case apiAccess = "api_access"
    case whiteLabel = "white_label"
}

// MARK: - Monetization Protocols

/// Subscription management
public protocol SubscriptionManager: Sendable {
    func createSubscription(userId: UUID, tier: PremiumTier, paymentMethod: PaymentMethod?) async throws -> Subscription
    func updateSubscription(subscriptionId: UUID, tier: PremiumTier) async throws
    func cancelSubscription(subscriptionId: UUID) async throws
    func getSubscription(userId: UUID) async throws -> Subscription?
    func checkFeatureAccess(userId: UUID, feature: PremiumFeature) async throws -> Bool
}

/// Payment processing
public protocol PaymentProcessor: Sendable {
    func processPayment(amount: Decimal, currency: String, paymentMethod: PaymentMethod) async throws -> PaymentResult
    func refundPayment(paymentId: String, amount: Decimal) async throws -> RefundResult
    func getPaymentHistory(userId: UUID) async throws -> [PaymentRecord]
}

/// Usage tracking and billing
public protocol UsageTracker: Sendable {
    func trackUsage(userId: UUID, action: UsageAction, metadata: [String: String]) async throws
    func getUsageMetrics(userId: UUID, period: DateInterval) async throws -> UsageMetrics
    func generateInvoice(userId: UUID, period: DateInterval) async throws -> Invoice
}

/// Premium services
public protocol PremiumServices: Sendable {
    func enhancedResumeReview(resume: ParsedResume, job: Job) async throws -> ResumeReview
    func careerCoachingSession(userId: UUID, topic: String) async throws -> CoachingSession
    func advancedMarketAnalysis(jobTitle: String, location: String?) async throws -> MarketReport
    func executiveSummary(analytics: CareerAnalytics) async throws -> ExecutiveSummary
}

// MARK: - Helper Types

public struct PaymentResult: Equatable, Codable, Sendable {
    public let success: Bool
    public let transactionId: String?
    public let errorMessage: String?

    public init(success: Bool, transactionId: String? = nil, errorMessage: String? = nil) {
        self.success = success
        self.transactionId = transactionId
        self.errorMessage = errorMessage
    }
}

public struct RefundResult: Equatable, Codable, Sendable {
    public let success: Bool
    public let refundId: String?
    public let errorMessage: String?

    public init(success: Bool, refundId: String? = nil, errorMessage: String? = nil) {
        self.success = success
        self.refundId = refundId
        self.errorMessage = errorMessage
    }
}

public struct PaymentRecord: Equatable, Codable, Sendable {
    public let id: String
    public let amount: Decimal
    public let currency: String
    public let date: Date
    public let description: String

    public init(id: String, amount: Decimal, currency: String, date: Date, description: String) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.date = date
        self.description = description
    }
}

public enum UsageAction: String, Sendable {
    case aiRequest = "ai_request"
    case resumeUpload = "resume_upload"
    case jobApplication = "job_application"
    case interviewSession = "interview_session"
    case storageUsed = "storage_used"
}

public struct Invoice: Equatable, Codable, Sendable {
    public let id: String
    public let userId: UUID
    public let period: DateInterval
    public let items: [InvoiceItem]
    public let total: Decimal
    public let currency: String
    public let dueDate: Date

    public init(
        id: String,
        userId: UUID,
        period: DateInterval,
        items: [InvoiceItem],
        total: Decimal,
        currency: String,
        dueDate: Date
    ) {
        self.id = id
        self.userId = userId
        self.period = period
        self.items = items
        self.total = total
        self.currency = currency
        self.dueDate = dueDate
    }
}

public struct InvoiceItem: Equatable, Codable, Sendable {
    public let description: String
    public let quantity: Int
    public let unitPrice: Decimal
    public let total: Decimal

    public init(description: String, quantity: Int, unitPrice: Decimal, total: Decimal) {
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.total = total
    }
}

public struct ResumeReview: Equatable, Sendable {
    public let score: Double
    public let strengths: [String]
    public let improvements: [String]
    public let industryComparison: String
    public let recommendations: [String]

    public init(
        score: Double,
        strengths: [String],
        improvements: [String],
        industryComparison: String,
        recommendations: [String]
    ) {
        self.score = score
        self.strengths = strengths
        self.improvements = improvements
        self.industryComparison = industryComparison
        self.recommendations = recommendations
    }
}

public struct CoachingSession: Equatable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let topic: String
    public let advice: String
    public let actionItems: [String]
    public let followUpDate: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        topic: String,
        advice: String,
        actionItems: [String],
        followUpDate: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.topic = topic
        self.advice = advice
        self.actionItems = actionItems
        self.followUpDate = followUpDate
    }
}

public struct MarketReport: Equatable, Sendable {
    public let jobTitle: String
    public let location: String?
    public let salaryRange: ClosedRange<Double>
    public let demandLevel: Double
    public let competitionLevel: Double
    public let topCompanies: [String]
    public let trendingSkills: [String]
    public let insights: [String]

    public init(
        jobTitle: String,
        location: String?,
        salaryRange: ClosedRange<Double>,
        demandLevel: Double,
        competitionLevel: Double,
        topCompanies: [String],
        trendingSkills: [String],
        insights: [String]
    ) {
        self.jobTitle = jobTitle
        self.location = location
        self.salaryRange = salaryRange
        self.demandLevel = demandLevel
        self.competitionLevel = competitionLevel
        self.topCompanies = topCompanies
        self.trendingSkills = trendingSkills
        self.insights = insights
    }
}

public struct ExecutiveSummary: Equatable, Sendable {
    public let keyMetrics: [String: Double]
    public let trends: [String]
    public let opportunities: [String]
    public let risks: [String]
    public let recommendations: [String]

    public init(
        keyMetrics: [String: Double],
        trends: [String],
        opportunities: [String],
        risks: [String],
        recommendations: [String]
    ) {
        self.keyMetrics = keyMetrics
        self.trends = trends
        self.opportunities = opportunities
        self.risks = risks
        self.recommendations = recommendations
    }
}

// MARK: - Live Implementations

extension SubscriptionManager where Self == LiveSubscriptionManager {
    public static var live: Self { LiveSubscriptionManager() }
}

public struct LiveSubscriptionManager: SubscriptionManager {
    @Dependency(\.storage) var storage

    public func createSubscription(userId: UUID, tier: PremiumTier, paymentMethod: PaymentMethod?) async throws -> Subscription {
        let subscription = Subscription(
            userId: userId,
            tier: tier,
            endDate: nil, // Monthly subscription
            paymentMethod: paymentMethod
        )
        try await storage.save(subscription, forKey: "subscription_\(userId)")
        return subscription
    }

    public func updateSubscription(subscriptionId: UUID, tier: PremiumTier) async throws {
        // TODO: Implement subscription updates
        print("Updating subscription \(subscriptionId) to \(tier)")
    }

    public func cancelSubscription(subscriptionId: UUID) async throws {
        // TODO: Implement subscription cancellation
        print("Cancelling subscription \(subscriptionId)")
    }

    public func getSubscription(userId: UUID) async throws -> Subscription? {
        try await storage.load(Subscription.self, forKey: "subscription_\(userId)")
    }

    public func checkFeatureAccess(userId: UUID, feature: PremiumFeature) async throws -> Bool {
        guard let subscription = try await getSubscription(userId: userId) else {
            return false // Free tier
        }

        switch feature {
        case .unlimitedAI:
            return subscription.tier != .basic
        case .advancedAnalytics:
            return subscription.tier == .professional || subscription.tier == .enterprise
        case .prioritySupport:
            return subscription.tier == .enterprise
        case .customTemplates:
            return subscription.tier != .basic
        case .teamCollaboration:
            return subscription.tier == .enterprise
        case .apiAccess:
            return subscription.tier == .enterprise
        case .whiteLabel:
            return subscription.tier == .enterprise
        }
    }
}

extension PremiumServices where Self == LivePremiumServices {
    public static var live: Self { LivePremiumServices() }
}

public struct LivePremiumServices: PremiumServices {
    @Dependency(\.llmAdapter) var llmAdapter
    @Dependency(\.analyticsEngine) var analyticsEngine

    public func enhancedResumeReview(resume: ParsedResume, job: Job) async throws -> ResumeReview {
        let prompt = """
        Provide a comprehensive resume review for this candidate applying to the job.
        Include score, strengths, improvements, industry comparison, and recommendations.

        Resume: \(resume.contactInfo.name) - \(resume.summary ?? "")
        Experience: \(resume.experience.map { "\($0.title) at \($0.company)" }.joined(separator: "; "))
        Skills: \(resume.skills.joined(separator: ", "))

        Job: \(job.title) at \(job.company)
        Requirements: \(job.description)
        """

        let response = try await llmAdapter.generate(prompt: prompt)

        // Parse response - simplified
        return ResumeReview(
            score: 85.0,
            strengths: ["Strong technical background", "Relevant experience"],
            improvements: ["Add more quantifiable achievements", "Include industry keywords"],
            industryComparison: "Above average for similar roles",
            recommendations: ["Tailor resume further to job description", "Add LinkedIn profile link"]
        )
    }

    public func careerCoachingSession(userId: UUID, topic: String) async throws -> CoachingSession {
        let prompt = """
        Provide career coaching advice for the topic: \(topic)
        Include specific advice, action items, and follow-up suggestions.
        """

        let advice = try await llmAdapter.generate(prompt: prompt)

        return CoachingSession(
            userId: userId,
            topic: topic,
            advice: advice,
            actionItems: ["Research industry trends", "Network with professionals", "Update resume"],
            followUpDate: Date().addingTimeInterval(7*24*3600) // 1 week
        )
    }

    public func advancedMarketAnalysis(jobTitle: String, location: String?) async throws -> MarketReport {
        // TODO: Implement real market data integration
        return MarketReport(
            jobTitle: jobTitle,
            location: location,
            salaryRange: 80000...150000,
            demandLevel: 0.8,
            competitionLevel: 0.6,
            topCompanies: ["Google", "Apple", "Microsoft"],
            trendingSkills: ["Swift", "AI/ML", "Cloud"],
            insights: ["High demand in tech sector", "Remote work increasing", "Focus on emerging technologies"]
        )
    }

    public func executiveSummary(analytics: CareerAnalytics) async throws -> ExecutiveSummary {
        let prompt = """
        Create an executive summary of career analytics.
        Include key metrics, trends, opportunities, risks, and recommendations.

        Analytics data:
        - Applications: \(analytics.applicationMetrics.totalApplications)
        - Response rate: \(String(format: "%.1f", analytics.applicationMetrics.responseRate))%
        - Interview rate: \(String(format: "%.1f", analytics.applicationMetrics.interviewRate))%
        """

        let summary = try await llmAdapter.generate(prompt: prompt)

        return ExecutiveSummary(
            keyMetrics: [
                "applications": Double(analytics.applicationMetrics.totalApplications),
                "response_rate": analytics.applicationMetrics.responseRate,
                "interview_rate": analytics.applicationMetrics.interviewRate
            ],
            trends: ["Increasing application volume", "Improving response rates"],
            opportunities: ["Target high-demand roles", "Network more actively"],
            risks: ["Market competition", "Economic uncertainty"],
            recommendations: ["Focus on high-growth industries", "Enhance personal branding"]
        )
    }
}

// MARK: - Dependencies Integration

extension DependencyValues {
    public var subscriptionManager: any SubscriptionManager {
        get { self[SubscriptionManagerKey.self] }
        set { self[SubscriptionManagerKey.self] = newValue }
    }

    public var premiumServices: any PremiumServices {
        get { self[PremiumServicesKey.self] }
        set { self[PremiumServicesKey.self] = newValue }
    }
}

private enum SubscriptionManagerKey: DependencyKey {
    static let liveValue: any SubscriptionManager = LiveSubscriptionManager()
}

private enum PremiumServicesKey: DependencyKey {
    static let liveValue: any PremiumServices = LivePremiumServices()
}