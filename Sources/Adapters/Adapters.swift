import Core
import Dependencies
import Foundation

// MARK: - Job Source Adapter Protocol

public protocol JobSourceAdapter: Sendable {
    var source: JobSource { get }
    func searchJobs(query: JobQuery) async throws -> [Job]
}

// MARK: - Indeed Adapter

extension JobSourceAdapter where Self == IndeedAdapter {
    public static var live: Self { IndeedAdapter() }
}

public struct IndeedAdapter: JobSourceAdapter {
    public let source: JobSource = .indeed

    @Dependency(\.networkClient) var networkClient
    @Dependency(\.uuidGenerator) var uuidGenerator
    @Dependency(\.logger) var logger

    public init() {}

    public func searchJobs(query: JobQuery) async throws -> [Job] {
        // Indeed Publisher API (free tier)
        // Note: In production, you'd need a publisher number
        let publisher = "YOUR_PUBLISHER_NUMBER"  // Get from Indeed Publisher Center

        var components = URLComponents(string: "https://api.indeed.com/ads/apisearch")!
        components.queryItems = [
            URLQueryItem(name: "publisher", value: publisher),
            URLQueryItem(name: "q", value: query.keywords),
            URLQueryItem(name: "l", value: query.location ?? ""),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "radius", value: "25"),
            URLQueryItem(name: "st", value: ""),
            URLQueryItem(name: "jt", value: "fulltime"),
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "fromage", value: "30"),
            URLQueryItem(name: "filter", value: "1"),
            URLQueryItem(name: "latlong", value: "1"),
            URLQueryItem(name: "co", value: "us"),
            URLQueryItem(name: "chnl", value: ""),
            URLQueryItem(name: "userip", value: "1.2.3.4"),
            URLQueryItem(name: "useragent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"),
            URLQueryItem(name: "v", value: "2"),
            URLQueryItem(name: "format", value: "json")
        ]

        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        logger.log(level: .info, message: "Searching Indeed for jobs", metadata: [
            "query": query.keywords,
            "location": query.location ?? "any"
        ])

        let (data, _) = try await networkClient.data(for: request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let response = try decoder.decode(IndeedResponse.self, from: data)
        return response.results.map { result in
            Job(
                id: uuidGenerator.uuid(),
                title: result.jobtitle,
                company: result.company,
                description: result.snippet,
                location: result.formattedLocationFull,
                salary: parseSalary(result.snippet),
                postedDate: parseDate(result.date),
                url: result.url,
                source: .indeed
            )
        }
    }

    private func parseSalary(_ snippet: String) -> Salary? {
        // Simple salary parsing from job snippet
        let patterns = [
            "\\$([0-9,]+)\\s*-\\s*\\$([0-9,]+)",  // salary range like 50000 - 70000
            "\\$([0-9,]+)",                      // single salary like 50000
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: snippet, options: [], range: NSRange(location: 0, length: snippet.count)) {
                let minStr = (snippet as NSString).substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                if let min = Int(minStr) {
                    if match.numberOfRanges > 2 {
                        let maxStr = (snippet as NSString).substring(with: match.range(at: 2)).replacingOccurrences(of: ",", with: "")
                        if let max = Int(maxStr) {
                            return Salary(min: min, max: max, currency: "USD", period: .yearly)
                        }
                    }
                    return Salary(min: min, max: nil, currency: "USD", period: .yearly)
                }
            }
        }
        return nil
    }

    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "Mon, dd MMM yyyy HH:mm:ss Z"  // Indeed date format
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Indeed API Response Models

private struct IndeedResponse: Decodable {
    let results: [IndeedJobResult]
}

private struct IndeedJobResult: Decodable {
    let jobtitle: String
    let company: String
    let snippet: String
    let formattedLocationFull: String?
    let date: String
    let url: String
}

// MARK: - LinkedIn Adapter

extension JobSourceAdapter where Self == LinkedInAdapter {
    public static var live: Self { LinkedInAdapter() }
}

public struct LinkedInAdapter: JobSourceAdapter {
    public let source: JobSource = .linkedin

    @Dependency(\.networkClient) var networkClient
    @Dependency(\.uuidGenerator) var uuidGenerator
    @Dependency(\.logger) var logger
    @Dependency(\.keychainService) var keychainService

    public init() {}

    public func searchJobs(query: JobQuery) async throws -> [Job] {
        // LinkedIn Jobs API requires authentication
        // This is a simplified implementation - in production, you'd use OAuth2

        guard let accessToken = try await keychainService.get("linkedin_access_token") else {
            throw AdapterError.unauthenticated
        }

        var components = URLComponents(string: "https://api.linkedin.com/v2/jobSearch")!
        components.queryItems = [
            URLQueryItem(name: "keywords", value: query.keywords),
            URLQueryItem(name: "location", value: query.location ?? ""),
            URLQueryItem(name: "count", value: "25"),
            URLQueryItem(name: "sort", value: "DD")  // Date posted
        ]

        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        logger.log(level: .info, message: "Searching LinkedIn for jobs", metadata: [
            "query": query.keywords,
            "location": query.location ?? "any"
        ])

        let (data, _) = try await networkClient.data(for: request)

        let decoder = JSONDecoder()
        let response = try decoder.decode(LinkedInResponse.self, from: data)

        return response.elements.map { job in
            Job(
                id: uuidGenerator.uuid(),
                title: job.title,
                company: job.companyDetails?.companyName ?? "Unknown Company",
                description: job.description ?? "",
                location: job.locationDescription,
                salary: nil,  // LinkedIn API may provide salary in enterprise tier
                postedDate: parseLinkedInDate(job.postedDate),
                url: "https://linkedin.com/jobs/view/\(job.jobId)",
                source: .linkedin
            )
        }
    }

    private func parseLinkedInDate(_ postedDate: LinkedInPostedDate?) -> Date {
        guard let postedDate else { return Date() }
        // LinkedIn uses milliseconds since epoch
        let interval = TimeInterval(postedDate.time / 1000)
        return Date(timeIntervalSince1970: interval)
    }
}

// MARK: - LinkedIn API Response Models

private struct LinkedInResponse: Decodable {
    let elements: [LinkedInJob]
}

private struct LinkedInJob: Decodable {
    let jobId: String
    let title: String
    let companyDetails: LinkedInCompany?
    let description: String?
    let locationDescription: String?
    let postedDate: LinkedInPostedDate?
}

private struct LinkedInCompany: Decodable {
    let companyName: String
}

private struct LinkedInPostedDate: Decodable {
    let time: Int64
}

// MARK: - Adapter Errors

public enum AdapterError: Error, LocalizedError {
    case unauthenticated
    case rateLimited
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Authentication required for this job source"
        case .rateLimited:
            return "Rate limit exceeded, please try again later"
        case .invalidResponse:
            return "Invalid response from job source API"
        }
    }
}

// MARK: - Job Repository Protocol

public protocol JobRepository: Sendable {
    func saveJobs(_ jobs: [Job]) async throws
    func loadJobs(query: JobQuery?) async throws -> [Job]
    func syncJobs(from adapters: [any JobSourceAdapter], query: JobQuery) async throws
}

// MARK: - Live Job Repository

extension JobRepository where Self == LiveJobRepository {
    public static var live: Self { LiveJobRepository() }
}

public struct LiveJobRepository: JobRepository {
    @Dependency(\.storage) var storage
    @Dependency(\.logger) var logger

    private let jobsKey = "cached_jobs"

    public init() {}

    public func saveJobs(_ jobs: [Job]) async throws {
        try await storage.save(jobs, forKey: jobsKey)
        logger.log(level: .info, message: "Saved \(jobs.count) jobs to local storage", metadata: [:])
    }

    public func loadJobs(query: JobQuery? = nil) async throws -> [Job] {
        let allJobs: [Job] = try await storage.load([Job].self, forKey: jobsKey) ?? []

        if let query {
            return allJobs.filter { job in
                let matchesKeywords = query.keywords.isEmpty ||
                    job.title.localizedCaseInsensitiveContains(query.keywords) ||
                    job.description.localizedCaseInsensitiveContains(query.keywords) ||
                    job.company.localizedCaseInsensitiveContains(query.keywords)

                let matchesLocation = query.location == nil ||
                    job.location?.localizedCaseInsensitiveContains(query.location!) == true

                let matchesRemote = !query.remote || job.location == nil

                let matchesSalary = query.salaryMin == nil ||
                    job.salary?.min ?? 0 >= query.salaryMin!

                return matchesKeywords && matchesLocation && matchesRemote && matchesSalary
            }
        }

        return allJobs
    }

    public func syncJobs(from adapters: [any JobSourceAdapter], query: JobQuery) async throws {
        var allJobs: [Job] = []

        for adapter in adapters {
            do {
                let jobs = try await adapter.searchJobs(query: query)
                allJobs.append(contentsOf: jobs)
            } catch {
                logger.log(level: .warning, message: "Failed to sync from \(adapter.source)", metadata: ["error": error.localizedDescription])
            }
        }

        let uniqueJobs = allJobs.reduce(into: [String: Job]()) { result, job in
            result[job.url] = job
        }.values

        try await saveJobs(Array(uniqueJobs))
        logger.log(level: .info, message: "Synced \(uniqueJobs.count) unique jobs", metadata: [:])
    }
}

// MARK: - Job Source Manager

public struct JobSourceManager: Sendable {
    private let adapters: [any JobSourceAdapter]

    public init(adapters: [any JobSourceAdapter] = [IndeedAdapter.live, LinkedInAdapter.live]) {
        self.adapters = adapters
    }

    public func searchAllSources(query: JobQuery) -> AsyncThrowingStream<Job, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for adapter in adapters {
                        do {
                            let jobs = try await adapter.searchJobs(query: query)
                            for job in jobs {
                                continuation.yield(job)
                            }
                        } catch {
                            // Log error but continue with other adapters
                            print("Error searching \(adapter.source): \(error)")
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}