import AnalyticsCore
import Core
import Tracking
import Testing

@Test("Generate career analytics from applications")
func testCareerAnalytics() async throws {
    let engine = LiveAnalyticsEngine()

    let applications = [
        Application(jobId: UUID(), status: .applied),
        Application(jobId: UUID(), status: .responded),
        Application(jobId: UUID(), status: .interviewed),
        Application(jobId: UUID(), status: .offered)
    ]

    let analytics = try await engine.generateCareerAnalytics(applications: applications)

    #expect(analytics.applicationMetrics.totalApplications == 4)
    #expect(analytics.marketInsights.demandTrends.count > 0)
    #expect(analytics.recommendations.count > 0)
}

@Test("Analyze application success metrics")
func testApplicationMetrics() async throws {
    let engine = LiveAnalyticsEngine()

    let applications = [
        Application(jobId: UUID(), status: .applied, createdAt: Date().addingTimeInterval(-86400)),
        Application(jobId: UUID(), status: .responded, createdAt: Date().addingTimeInterval(-86400), updatedAt: Date()),
        Application(jobId: UUID(), status: .interviewed, createdAt: Date().addingTimeInterval(-86400), updatedAt: Date()),
        Application(jobId: UUID(), status: .offered, createdAt: Date().addingTimeInterval(-86400), updatedAt: Date())
    ]

    let metrics = try await engine.analyzeApplicationSuccess(applications: applications)

    #expect(metrics.totalApplications == 4)
    #expect(metrics.responseRate == 75.0) // 3 out of 4 responded
    #expect(metrics.interviewRate == 66.7) // 2 out of 3 interviewed
    #expect(metrics.offerRate == 50.0) // 1 out of 2 offered
}

@Test("Get market insights")
func testMarketInsights() async throws {
    let engine = LiveAnalyticsEngine()

    let insights = try await engine.getMarketInsights(jobTitle: "Software Engineer", location: "San Francisco")

    #expect(insights.salaryRanges.count > 0)
    #expect(insights.demandTrends.count > 0)
    #expect(insights.competitionLevel >= 0 && insights.competitionLevel <= 1)
    #expect(insights.topCompanies.count > 0)
}

@Test("Generate personalized recommendations")
func testPersonalizedRecommendations() async throws {
    let engine = LiveAnalyticsEngine()

    let analytics = CareerAnalytics(
        applicationMetrics: ApplicationMetrics(
            totalApplications: 10,
            responseRate: 30.0,
            interviewRate: 50.0,
            offerRate: 25.0,
            averageResponseTime: 21.0,
            applicationsByStatus: ["applied": 7, "interviewing": 3]
        ),
        marketInsights: MarketInsights(
            salaryRanges: [:],
            demandTrends: ["Swift": 0.9],
            competitionLevel: 0.5,
            topCompanies: [],
            emergingSkills: []
        ),
        performanceTrends: PerformanceTrends(
            weeklyApplications: [:],
            monthlyResponseRate: [:],
            skillEffectiveness: [:],
            industrySuccess: [:]
        ),
        recommendations: []
    )

    let recommendations = try await engine.generatePersonalizedRecommendations(analytics: analytics)

    #expect(recommendations.count > 0)
    #expect(recommendations.contains { $0.contains("response rate") })
}