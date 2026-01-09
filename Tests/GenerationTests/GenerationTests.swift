import Testing
@testable import Generation
@testable import Core
import Foundation

@Test func templateEngineCoverLetter() async throws {
    let engine = TemplateEngine(adapter: .offline)
    let profile = Profile(
        name: "John Doe",
        email: "john@example.com",
        summary: "Experienced developer",
        experience: [Experience(title: "Developer", company: "TechCo", startDate: Date(), description: "Built apps")],
        skills: ["Swift", "iOS"]
    )
    let job = Job(
        title: "iOS Developer",
        company: "Apple",
        description: "Develop iOS apps",
        postedDate: Date(),
        url: "https://apple.com",
        source: .linkedin
    )

    let letter = try await engine.generateCoverLetter(profile: profile, job: job)
    #expect(letter.contains("Dear Hiring Manager"))
    #expect(letter.contains("[Your Name]")) // Stub response
    #expect(!letter.contains("john@example.com")) // Redacted
}

@Test func templateEngineCV() async throws {
    let engine = TemplateEngine(adapter: .offline)
    let profile = Profile(
        name: "Jane Smith",
        email: "jane@example.com",
        summary: "Senior engineer",
        experience: [Experience(title: "Engineer", company: "Google", startDate: Date(), description: "Engineered systems")],
        skills: ["Java", "Kotlin"]
    )

    let cv = try await engine.generateCV(profile: profile)
    #expect(cv.contains("Dear Hiring Manager")) // Stub response
    #expect(cv.contains("[Your Name]"))
    #expect(!cv.contains("jane@example.com")) // Redacted
}

@Test func contentValidators() {
    let shortContent = "Hello world"
    #expect(ContentValidator.validateLength(shortContent))
    #expect(ContentValidator.validateATSCompliance(shortContent))
    #expect(ContentValidator.checkForBannedTerms(shortContent))

    let longContent = String(repeating: "a", count: 6000)
    #expect(!ContentValidator.validateLength(longContent, maxLength: 5000))

    let bannedContent = "This is confidential information"
    #expect(!ContentValidator.checkForBannedTerms(bannedContent))
}

@Test func llmAdapters() async throws {
    let live: any LLMAdapter = .live
    let offline: any LLMAdapter = .offline

    let liveResult = try await live.generate(prompt: "test")
    let offlineResult = try await offline.generate(prompt: "test")

    #expect(liveResult.contains("Applicant"))
    #expect(offlineResult.contains("[Your Name]"))
}
