import ResumeParser
import Core
import Foundation
import Testing

@Test("Resume parsing from text")
func testResumeParsing() async throws {
    let parser = LiveResumeParser()

    let resumeText = """
    John Doe
    john@example.com
    San Francisco, CA

    Summary: Experienced iOS developer with 5 years of Swift experience.

    Experience:
    Senior iOS Developer at Tech Corp (2020-Present)
    Built scalable iOS applications using Swift and SwiftUI.

    Education:
    BS Computer Science, Stanford University

    Skills: Swift, iOS, SwiftUI, Core Data
    """

    let data = resumeText.data(using: .utf8)!
    let parsed = try await parser.parseResume(from: data, fileName: "resume.txt")

    #expect(parsed.contactInfo.name == "John Doe")
    #expect(parsed.contactInfo.email == "john@example.com")
    #expect(parsed.summary?.contains("iOS developer") == true)
    #expect(parsed.experience.count > 0)
    #expect(parsed.skills.contains("Swift"))
}

@Test("ATS compatibility analysis")
func testATSAnalysis() async throws {
    let parser = LiveResumeParser()

    let resume = ParsedResume(
        contactInfo: ContactInfo(name: "John Doe", email: "john@example.com"),
        summary: "iOS developer",
        skills: ["Swift", "iOS"]
    )

    let jobDesc = "Looking for Swift iOS developer with experience in UIKit and SwiftUI"

    let analysis = try await parser.analyzeATSCompatibility(resume, jobDescription: jobDesc)

    #expect(analysis.score >= 0 && analysis.score <= 100)
    #expect(analysis.keywords.count >= 0)
}

@Test("Resume optimization for job")
func testResumeOptimization() async throws {
    let parser = LiveResumeParser()

    let resume = ParsedResume(
        contactInfo: ContactInfo(name: "John Doe"),
        skills: ["Swift", "Python"]
    )

    let job = Job(
        title: "iOS Developer",
        company: "Apple",
        description: "Build iOS apps with Swift and UIKit",
        postedDate: Date(),
        url: "https://apple.com/job",
        source: .linkedin
    )

    let optimized = try await parser.optimizeForJob(resume, job: job)

    #expect(optimized.original.contactInfo.name == "John Doe")
    #expect(optimized.job.title == "iOS Developer")
    #expect(optimized.optimizedContent.count > 0)
}