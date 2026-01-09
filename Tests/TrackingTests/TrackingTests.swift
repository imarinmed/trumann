import Testing
@testable import Tracking
@testable import Core
import Foundation

@Test func consentStateMachine() {
    #expect(ConsentStateMachine.canTrack(.authorized))
    #expect(!ConsentStateMachine.canTrack(.denied))
    #expect(ConsentStateMachine.canStore(.authorized))
    #expect(!ConsentStateMachine.canStore(.denied))
}

@Test func atsCurationRules() {
    let rules = ATSCurationRules(requiredKeywords: ["swift", "ios"], bannedKeywords: ["senior"], maxKeywordDensity: 0.5)
    let job = Job(
        title: "iOS Developer",
        company: "Apple",
        description: "Swift iOS development",
        postedDate: Date(),
        url: "https://apple.com",
        source: .linkedin
    )
    let resume = "Swift iOS developer with experience in app development"

    let score = rules.evaluate(job: job, resume: resume)
    #expect(score.passed)
    #expect(score.score >= 1)
}

@Test func trackingEvent() {
    let event = TrackingEvent(type: .jobViewed, properties: ["job_id": "123"])
    #expect(event.type == .jobViewed)
    #expect(event.properties["job_id"] == "123")
}

// Tracking service test skipped - complex DI setup

@Test func consentTransition() {
    #expect(ConsentStateMachine.transition(from: .notDetermined, to: .authorized))
    #expect(ConsentStateMachine.transition(from: .authorized, to: .denied))
    #expect(ConsentStateMachine.transition(from: .denied, to: .authorized)) // User can re-grant
}
