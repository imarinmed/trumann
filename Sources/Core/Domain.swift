import Foundation

// MARK: - Domain Types

/// Represents a job posting from a job board.
///
/// A job contains all the essential information about a job opportunity,
/// including title, company, description, location, salary, and posting details.
/// All jobs are uniquely identified and can be safely shared across concurrent contexts.
public struct Job: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let company: String
    public let description: String
    public let location: String?
    public let salary: Salary?
    public let postedDate: Date
    public let url: String
    public let source: JobSource

    public init(
        id: UUID = UUID(),
        title: String,
        company: String,
        description: String,
        location: String? = nil,
        salary: Salary? = nil,
        postedDate: Date,
        url: String,
        source: JobSource
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.description = description
        self.location = location
        self.salary = salary
        self.postedDate = postedDate
        self.url = url
        self.source = source
    }
}

/// Salary information for a job.
public struct Salary: Equatable, Codable, Sendable {
    public let min: Int?
    public let max: Int?
    public let currency: String
    public let period: SalaryPeriod

    public init(min: Int?, max: Int?, currency: String = "USD", period: SalaryPeriod = .yearly) {
        self.min = min
        self.max = max
        self.currency = currency
        self.period = period
    }
}

public enum SalaryPeriod: String, Equatable, Codable, Sendable {
    case hourly, daily, weekly, monthly, yearly
}

/// Source of the job posting.
public enum JobSource: String, Equatable, Codable, Sendable {
    case linkedin, indeed, glassdoor, monster, custom
}

/// Query parameters for job search.
public struct JobQuery: Equatable, Sendable {
    public let keywords: String
    public let location: String?
    public let remote: Bool
    public let salaryMin: Int?

    public init(keywords: String, location: String? = nil, remote: Bool = false, salaryMin: Int? = nil) {
        self.keywords = keywords
        self.location = location
        self.remote = remote
        self.salaryMin = salaryMin
    }
}

/// User profile for CV generation.
public struct Profile: Equatable, Codable, Sendable {
    public let name: String
    public let email: String
    public let phone: String?
    public let location: String?
    public let summary: String
    public let experience: [Experience]
    public let education: [Education]
    public let skills: [String]

    public init(
        name: String,
        email: String,
        phone: String? = nil,
        location: String? = nil,
        summary: String,
        experience: [Experience] = [],
        education: [Education] = [],
        skills: [String] = []
    ) {
        self.name = name
        self.email = email
        self.phone = phone
        self.location = location
        self.summary = summary
        self.experience = experience
        self.education = education
        self.skills = skills
    }
}

public struct Experience: Equatable, Codable, Sendable {
    public let title: String
    public let company: String
    public let startDate: Date
    public let endDate: Date?
    public let description: String

    public init(title: String, company: String, startDate: Date, endDate: Date? = nil, description: String) {
        self.title = title
        self.company = company
        self.startDate = startDate
        self.endDate = endDate
        self.description = description
    }
}

public struct Education: Equatable, Codable, Sendable {
    public let degree: String
    public let institution: String
    public let graduationDate: Date?

    public init(degree: String, institution: String, graduationDate: Date? = nil) {
        self.degree = degree
        self.institution = institution
        self.graduationDate = graduationDate
    }
}

/// Application to a job.
public struct Application: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let jobId: UUID
    public let appliedDate: Date
    public let status: ApplicationStatus
    public let notes: String?

    public init(
        id: UUID = UUID(),
        jobId: UUID,
        appliedDate: Date = Date(),
        status: ApplicationStatus = .applied,
        notes: String? = nil
    ) {
        self.id = id
        self.jobId = jobId
        self.appliedDate = appliedDate
        self.status = status
        self.notes = notes
    }
}

public enum ApplicationStatus: String, Equatable, Sendable {
    case applied, interviewing, rejected, accepted
}

/// Analytics event.
public struct Event: Equatable, Sendable {
    public let id: UUID
    public let type: EventType
    public let timestamp: Date
    public let properties: [String: String]

    public init(type: EventType, properties: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.properties = properties
    }
}

public enum EventType: String, Equatable, Sendable {
    case jobViewed = "job_viewed"
    case jobApplied = "job_applied"
    case searchPerformed = "search_performed"
    case cvGenerated = "cv_generated"
}

/// Ranked job result.
public struct RankedJob: Identifiable, Equatable, Hashable, Sendable {
    public let job: Job
    public let score: Double
    public let explanation: String

    public var id: UUID { job.id }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public init(job: Job, score: Double, explanation: String) {
        self.job = job
        self.score = score
        self.explanation = explanation
    }
}

// MARK: - Domain Errors

/// Domain-specific errors. No throws for control flow - use Result types.
public enum DomainError: Equatable, Sendable {
    case invalidJobData(String)
    case networkError(String)
    case parsingError(String)
    case storageError(String)
    case consentRequired
    case rateLimited
}