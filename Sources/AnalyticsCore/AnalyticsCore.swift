import Core
import Foundation
import Tracking

// MARK: - Analytics Types

/// Career analytics dashboard data
public struct CareerAnalytics: Equatable, Sendable {
    public let applicationMetrics: ApplicationMetrics
    public let marketInsights: MarketInsights
    public let performanceTrends: PerformanceTrends
    public let recommendations: [String]
    public let generatedAt: Date

    public init(
        applicationMetrics: ApplicationMetrics,
        marketInsights: MarketInsights,
        performanceTrends: PerformanceTrends,
        recommendations: [String],
        generatedAt: Date = Date()
    ) {
        self.applicationMetrics = applicationMetrics
        self.marketInsights = marketInsights
        self.performanceTrends = performanceTrends
        self.recommendations = recommendations
        self.generatedAt = generatedAt
    }
}

/// Application success metrics
public struct ApplicationMetrics: Equatable, Codable, Sendable {
    public let totalApplications: Int
    public let responseRate: Double  // percentage
    public let interviewRate: Double // percentage
    public let offerRate: Double     // percentage
    public let averageResponseTime: TimeInterval // days
    public let applicationsByStatus: [String: Int]

    public init(
        totalApplications: Int,
        responseRate: Double,
        interviewRate: Double,
        offerRate: Double,
        averageResponseTime: TimeInterval,
        applicationsByStatus: [ApplicationStatus: Int]
    ) {
        self.totalApplications = totalApplications
        self.responseRate = responseRate
        self.interviewRate = interviewRate
        self.offerRate = offerRate
        self.averageResponseTime = averageResponseTime
        self.applicationsByStatus = applicationsByStatus
    }
}

/// Market intelligence data
public struct MarketInsights: Equatable, Codable, Sendable {
    public let salaryRanges: [String: SalaryRange] // job title -> range
    public let demandTrends: [String: Double]     // skill -> demand score
    public let competitionLevel: Double           // 0-1 scale
    public let topCompanies: [String]             // most active companies
    public let emergingSkills: [String]           // trending skills

    public init(
        salaryRanges: [String: SalaryRange],
        demandTrends: [String: Double],
        competitionLevel: Double,
        topCompanies: [String],
        emergingSkills: [String]
    ) {
        self.salaryRanges = salaryRanges
        self.demandTrends = demandTrends
        self.competitionLevel = competitionLevel
        self.topCompanies = topCompanies
        self.emergingSkills = emergingSkills
    }
}

/// Performance trends over time
public struct PerformanceTrends: Equatable, Codable, Sendable {
    public let weeklyApplications: [Date: Int]
    public let monthlyResponseRate: [Date: Double]
    public let skillEffectiveness: [String: Double] // skill -> success rate
    public let industrySuccess: [String: Double]    // industry -> success rate

    public init(
        weeklyApplications: [Date: Int],
        monthlyResponseRate: [Date: Double],
        skillEffectiveness: [String: Double],
        industrySuccess: [String: Double]
    ) {
        self.weeklyApplications = weeklyApplications
        self.monthlyResponseRate = monthlyResponseRate
        self.skillEffectiveness = skillEffectiveness
        self.industrySuccess = industrySuccess
    }
}

/// Salary range data
public struct SalaryRange: Equatable, Codable, Sendable {
    public let min: Double
    public let max: Double
    public let median: Double
    public let currency: String

    public init(min: Double, max: Double, median: Double, currency: String) {
        self.min = min
        self.max = max
        self.median = median
        self.currency = currency
    }
}

// MARK: - Analytics Engine Protocol

public protocol AnalyticsEngine: Sendable {
    func generateCareerAnalytics(applications: [Application]) async throws -> CareerAnalytics
    func analyzeApplicationSuccess(applications: [Application]) async throws -> ApplicationMetrics
    func getMarketInsights(jobTitle: String, location: String?) async throws -> MarketInsights
    func trackPerformanceTrends(applications: [Application]) async throws -> PerformanceTrends
    func generatePersonalizedRecommendations(analytics: CareerAnalytics) async throws -> [String]
}

// MARK: - Live Implementation

extension AnalyticsEngine where Self == LiveAnalyticsEngine {
    public static var live: Self { LiveAnalyticsEngine() }
}

public struct LiveAnalyticsEngine: AnalyticsEngine {
    public func generateCareerAnalytics(applications: [Application]) async throws -> CareerAnalytics {
        let metrics = try await analyzeApplicationSuccess(applications: applications)
        let market = try await getMarketInsights(jobTitle: "Software Engineer", location: "San Francisco")
        let trends = try await trackPerformanceTrends(applications: applications)
        let recommendations = try await generatePersonalizedRecommendations(
            analytics: CareerAnalytics(
                applicationMetrics: metrics,
                marketInsights: market,
                performanceTrends: trends,
                recommendations: []
            )
        )

        return CareerAnalytics(
            applicationMetrics: metrics,
            marketInsights: market,
            performanceTrends: trends,
            recommendations: recommendations
        )
    }

    public func analyzeApplicationSuccess(applications: [Application]) async throws -> ApplicationMetrics {
        let total = applications.count
        let responded = applications.filter { $0.status != .applied }.count
        let interviewed = applications.filter { $0.status == .interviewing }.count
        let accepted = applications.filter { $0.status == .accepted }.count

        let responseRate = total > 0 ? Double(responded) / Double(total) * 100 : 0
        let interviewRate = responded > 0 ? Double(interviewed) / Double(responded) * 100 : 0
        let offerRate = interviewed > 0 ? Double(accepted) / Double(interviewed) * 100 : 0

        // Calculate average response time (mock - assume 7 days for responded apps)
        let responseTimes = applications.filter { $0.status != .applied }.map { _ in TimeInterval(7 * 24 * 3600) }
        let averageResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)

        // Count by status
        var statusCounts: [String: Int] = [:]
        for app in applications {
            let statusKey = app.status.rawValue
            statusCounts[statusKey, default: 0] += 1
        }

        return ApplicationMetrics(
            totalApplications: total,
            responseRate: responseRate,
            interviewRate: interviewRate,
            offerRate: offerRate,
            averageResponseTime: averageResponseTime / (24 * 3600), // Convert to days
            applicationsByStatus: statusCounts
        )
    }

    public func getMarketInsights(jobTitle: String, location: String?) async throws -> MarketInsights {
        // Mock market data - in production, integrate with salary APIs
        let salaryRanges = [
            "Software Engineer": SalaryRange(min: 100000, max: 180000, median: 140000, currency: "USD"),
            "Senior Software Engineer": SalaryRange(min: 130000, max: 220000, median: 170000, currency: "USD"),
            "iOS Developer": SalaryRange(min: 110000, max: 190000, median: 150000, currency: "USD")
        ]

        let demandTrends = [
            "Swift": 0.9,
            "iOS": 0.8,
            "Python": 0.7,
            "React": 0.8,
            "AI/ML": 0.95
        ]

        return MarketInsights(
            salaryRanges: salaryRanges,
            demandTrends: demandTrends,
            competitionLevel: 0.7,
            topCompanies: ["Google", "Apple", "Microsoft", "Amazon", "Meta"],
            emergingSkills: ["SwiftUI", "Combine", "Swift Concurrency", "AI Integration"]
        )
    }

    public func trackPerformanceTrends(applications: [Application]) async throws -> PerformanceTrends {
        // Group applications by week
        var weeklyApps: [Date: Int] = [:]
        var monthlyResponse: [Date: Double] = [:]

        let calendar = Calendar.current

        for app in applications {
            let week = calendar.startOfWeek(for: app.appliedDate)
            weeklyApps[week, default: 0] += 1

            // Mock monthly response - assume responded apps took 7 days
            if app.status != .applied {
                let month = calendar.startOfMonth(for: app.appliedDate)
                monthlyResponse[month, default: 0] += 1.0
            }
        }

        // Calculate skill effectiveness (mock data)
        let skillEffectiveness = [
            "Swift": 0.85,
            "iOS": 0.80,
            "Python": 0.75,
            "React": 0.70
        ]

        let industrySuccess = [
            "Technology": 0.75,
            "Finance": 0.65,
            "Healthcare": 0.70,
            "E-commerce": 0.80
        ]

        return PerformanceTrends(
            weeklyApplications: weeklyApps,
            monthlyResponseRate: monthlyResponse,
            skillEffectiveness: skillEffectiveness,
            industrySuccess: industrySuccess
        )
    }

    public func generatePersonalizedRecommendations(analytics: CareerAnalytics) async throws -> [String] {
        var recommendations: [String] = []

        let metrics = analytics.applicationMetrics

        if metrics.responseRate < 50 {
            recommendations.append("Improve your application materials - only \(String(format: "%.1f", metrics.responseRate))% response rate")
        }

        if metrics.averageResponseTime > 14 {
            recommendations.append("Follow up sooner - average response time is \(String(format: "%.1f", metrics.averageResponseTime)) days")
        }

        if let topSkill = analytics.marketInsights.demandTrends.max(by: { $0.value < $1.value }) {
            recommendations.append("Focus on high-demand skill: \(topSkill.key)")
        }

        if recommendations.isEmpty {
            recommendations.append("Great job! Your application strategy is working well.")
            recommendations.append("Consider targeting high-demand skills for even better results.")
        }

        return recommendations
    }
}

// MARK: - Helper Extensions

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    func startOfMonth(for date: Date) -> Date {
        let components = self.dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}