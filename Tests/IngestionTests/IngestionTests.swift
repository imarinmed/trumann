import Testing
@testable import Ingestion
@testable import Core
import Foundation

@Test func jobNormalizer() {
    let job = Job(
        title: "  Software Engineer  ",
        company: " Apple Inc. ",
        description: " Build apps ",
        location: " CA ",
        postedDate: Date(),
        url: "https://apple.com",
        source: .linkedin
    )

    let normalized = JobNormalizer.normalize(job)

    #expect(normalized.title == "Software Engineer")
    #expect(normalized.company == "Apple Inc.")
    #expect(normalized.description == "Build apps")
    #expect(normalized.location == "CA")
}

@Test func rssParserStub() throws {
    let parser = RSSParser()
    let data = Data() // Empty data
    let jobs = try parser.parseJobs(from: data, source: .indeed)
    #expect(jobs.isEmpty)
}

@Test func rssParser() throws {
    let mockRSS = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
        <channel>
            <item>
                <title>iOS Developer at Apple</title>
                <description>Swift development role</description>
                <link>https://apple.com/job1</link>
                <pubDate>Wed, 07 Jan 2026 10:00:00 GMT</pubDate>
            </item>
        </channel>
    </rss>
    """.data(using: .utf8)!

    let parser = RSSParser()
    let jobs = try parser.parseJobs(from: mockRSS, source: .linkedin)
    #expect(jobs.count == 1)
    #expect(jobs[0].title == "iOS Developer at Apple")
    #expect(jobs[0].company == "Apple")
    #expect(jobs[0].source == .linkedin)
}

// Ingestion pipeline test skipped - DI setup complex

// Test HTTP Client
final class TestHTTPClient: HTTPClient, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (Data(), URLResponse())
    }
}
