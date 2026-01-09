import MonetizationCore
import Core
import Testing

@Test("Subscription management")
func testSubscriptionManagement() async throws {
    let manager = LiveSubscriptionManager()

    let paymentMethod = PaymentMethod(type: .creditCard, lastFour: "1234")
    let subscription = try await manager.createSubscription(
        userId: UUID(),
        tier: .professional,
        paymentMethod: paymentMethod
    )

    #expect(subscription.tier == .professional)
    #expect(subscription.status == .active)
}

@Test("Premium feature access")
func testFeatureAccess() async throws {
    let manager = LiveSubscriptionManager()

    // Test free user
    let freeAccess = try await manager.checkFeatureAccess(userId: UUID(), feature: .unlimitedAI)
    #expect(!freeAccess)

    // Create subscription first
    let paymentMethod = PaymentMethod(type: .creditCard, lastFour: "1234")
    let subscription = try await manager.createSubscription(
        userId: UUID(),
        tier: .professional,
        paymentMethod: paymentMethod
    )

    let proAccess = try await manager.checkFeatureAccess(userId: subscription.userId, feature: .unlimitedAI)
    #expect(proAccess)
}

@Test("Premium services")
func testPremiumServices() async throws {
    let services = LivePremiumServices()

    let resume = ParsedResume(contactInfo: ContactInfo(name: "Test User"))
    let job = Job(title: "Developer", company: "Test Co", description: "Test", postedDate: Date(), url: "test", source: .linkedin)

    let review = try await services.enhancedResumeReview(resume: resume, job: job)
    #expect(review.score >= 0 && review.score <= 100)

    let coaching = try await services.careerCoachingSession(userId: UUID(), topic: "Career Transition")
    #expect(coaching.topic == "Career Transition")
    #expect(!coaching.advice.isEmpty)
}

@Test("Market analysis")
func testMarketAnalysis() async throws {
    let services = LivePremiumServices()

    let report = try await services.advancedMarketAnalysis(jobTitle: "Software Engineer", location: "San Francisco")

    #expect(report.jobTitle == "Software Engineer")
    #expect(report.demandLevel >= 0 && report.demandLevel <= 1)
    #expect(report.competitionLevel >= 0 && report.competitionLevel <= 1)
}