import Core
import Dependencies
import Foundation

// MARK: - HTTP Client Protocol

public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension HTTPClient where Self == LiveHTTPClient {
    public static var live: Self { LiveHTTPClient() }
}

public struct LiveHTTPClient: HTTPClient {
    @Dependency(\.networkClient) var networkClient

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await networkClient.data(for: request)
    }
}

// MARK: - RSS/Atom Parser

public protocol FeedParser: Sendable {
    func parseJobs(from data: Data, source: JobSource) throws -> [Job]
}

extension FeedParser where Self == RSSParser {
    public static var rss: Self { RSSParser() }
}

public struct RSSParser: FeedParser, Sendable {
    public func parseJobs(from data: Data, source: JobSource) throws -> [Job] {
        let parser = RSSXMLParser()
        parser.source = source
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()

        if let error = parser.error {
            throw error
        }

        return parser.jobs
    }
}

private class RSSXMLParser: NSObject, XMLParserDelegate {
    var jobs: [Job] = []
    var source: JobSource = .custom
    var error: Error?

    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentLink = ""
    private var currentPubDate = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" || elementName == "entry" { // RSS item or Atom entry
            currentTitle = ""
            currentDescription = ""
            currentLink = ""
            currentPubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            switch currentElement {
            case "title":
                currentTitle += trimmed
            case "description", "summary":
                currentDescription += trimmed
            case "link":
                if currentLink.isEmpty {
                    currentLink += trimmed
                }
            case "pubDate", "published", "updated":
                currentPubDate += trimmed
            default:
                break
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            if !currentTitle.isEmpty {
                let date = parseDate(currentPubDate)
                let job = Job(
                    title: currentTitle,
                    company: extractCompany(currentTitle, currentDescription),
                    description: currentDescription,
                    postedDate: date,
                    url: currentLink.isEmpty ? "https://example.com" : currentLink,
                    source: source
                )
                jobs.append(job)
            }
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = parseError
    }

    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z" // RSS pubDate
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // Atom
        if let date = formatter.date(from: dateString) {
            return date
        }
        return Date() // Fallback
    }

    private func extractCompany(_ title: String, _ description: String) -> String {
        // Simple heuristic: look for company patterns in title/description
        let text = title + " " + description
        let patterns = [
            #"(?i)at\s+([A-Z][a-zA-Z]+)(?:\s|$)"#, // "at Company"
            #"(?i)([A-Z][a-zA-Z]+)\s+(?:is\s+hiring|seeking|looking\s+for)"#, // "Company is hiring"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                if let range = Range(match.range(at: 1), in: text) {
                    return String(text[range]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return "Unknown Company"
    }
}

// MARK: - Job Ingestion Pipeline

public struct JobIngestionPipeline: Sendable {
    private let httpClient: any HTTPClient
    private let parser: any FeedParser
    private let storage: any Storage

    public init(
        httpClient: any HTTPClient = .live,
        parser: any FeedParser = .rss,
        storage: any Storage = .live
    ) {
        self.httpClient = httpClient
        self.parser = parser
        self.storage = storage
    }

    public func ingest(from urls: [URL], source: JobSource) -> AsyncThrowingStream<Job, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for url in urls {
                        let request = URLRequest(url: url)
                        let (data, _) = try await httpClient.data(for: request)
                        let jobs = try parser.parseJobs(from: data, source: source)

                        for job in jobs where try await !isDuplicate(job) {
                            try await storeFingerprint(job)
                            continuation.yield(job)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func isDuplicate(_ job: Job) async throws -> Bool {
        let key = fingerprintKey(job)
        return try await storage.load(Data.self, forKey: key) != nil
    }

    private func storeFingerprint(_ job: Job) async throws {
        let key = fingerprintKey(job)
        let fingerprint = fingerprintData(job)
        try await storage.save(fingerprint, forKey: key)
    }

    private func fingerprintKey(_ job: Job) -> String {
        "fingerprint_\(job.title.hashValue)_\(job.company.hashValue)"
    }

    private func fingerprintData(_ job: Job) -> Data {
        (job.title + job.company).data(using: .utf8)!
    }
}

// MARK: - Job Normalization

public struct JobNormalizer {
    public static func normalize(_ job: Job) -> Job {
        Job(
            id: job.id,
            title: normalizeTitle(job.title),
            company: normalizeCompany(job.company),
            description: normalizeDescription(job.description),
            location: job.location?.trimmingCharacters(in: .whitespacesAndNewlines),
            salary: job.salary,
            postedDate: job.postedDate,
            url: job.url,
            source: job.source
        )
    }

    private static func normalizeTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeCompany(_ company: String) -> String {
        company.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeDescription(_ description: String) -> String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
