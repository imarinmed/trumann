import Core
import Foundation
import Generation
import ResumeParser
import Tracking

// MARK: - Automation Types

/// Automated workflow configuration
public struct AutomationWorkflow: Equatable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let triggers: [AutomationTrigger]
    public let actions: [AutomationAction]
    public let isActive: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        triggers: [AutomationTrigger],
        actions: [AutomationAction],
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.triggers = triggers
        self.actions = actions
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

/// Triggers for automation
public enum AutomationTrigger: Codable, Sendable {
    case jobMatch(minScore: Double)  // When job matches with score above threshold
    case applicationDeadline(hoursBefore: Int)  // Before application deadline
    case noResponse(daysAfter: Int)  // When no response after N days
    case interviewScheduled(daysBefore: Int)  // Before scheduled interview
    case custom(condition: String)  // Custom condition
}

/// Actions to perform when triggered
public enum AutomationAction: Codable, Sendable {
    case autoApply(profile: Profile, resume: ParsedResume)  // Auto-submit application
    case sendFollowUp(email: FollowUpEmail)  // Send follow-up email
    case scheduleReminder(title: String, message: String, delayHours: Int)  // Schedule reminder
    case updateApplicationStatus(status: ApplicationStatus)  // Update tracking status
    case generateThankYouNote(interviewDate: Date)  // Generate thank you note
}

/// Follow-up email configuration
public struct FollowUpEmail: Equatable, Codable, Sendable {
    public let subject: String
    public let body: String
    public let sendDelay: TimeInterval  // Hours after application

    public init(subject: String, body: String, sendDelay: TimeInterval) {
        self.subject = subject
        self.body = body
        self.sendDelay = sendDelay
    }
}

/// Automation execution result
public struct AutomationResult: Equatable, Sendable {
    public let workflowId: UUID
    public let trigger: AutomationTrigger
    public let actions: [AutomationAction]
    public let success: Bool
    public let executedAt: Date
    public let errorMessage: String?

    public init(
        workflowId: UUID,
        trigger: AutomationTrigger,
        actions: [AutomationAction],
        success: Bool,
        executedAt: Date = Date(),
        errorMessage: String? = nil
    ) {
        self.workflowId = workflowId
        self.trigger = trigger
        self.actions = actions
        self.success = success
        self.executedAt = executedAt
        self.errorMessage = errorMessage
    }
}

// MARK: - Automation Engine Protocol

public protocol AutomationEngine: Sendable {
    func createWorkflow(name: String, triggers: [AutomationTrigger], actions: [AutomationAction]) async throws -> AutomationWorkflow
    func executeWorkflow(_ workflow: AutomationWorkflow, for job: Job, profile: Profile) async throws -> AutomationResult
    func getActiveWorkflows() async throws -> [AutomationWorkflow]
    func deactivateWorkflow(id: UUID) async throws
    func processPendingAutomations() async throws -> [AutomationResult]
}

// MARK: - Live Implementation

extension AutomationEngine where Self == LiveAutomationEngine {
    public static var live: Self { LiveAutomationEngine() }
}

public struct LiveAutomationEngine: AutomationEngine {
    private let llmAdapter: any LLMAdapter
    private let resumeParser: any ResumeParser

    // In-memory storage for demo - in production, use persistent storage
    private var workflows: [UUID: AutomationWorkflow] = [:]
    private var pendingActions: [(workflowId: UUID, job: Job, profile: Profile, executeAt: Date)] = []

    public init(
        llmAdapter: any LLMAdapter = .live,
        resumeParser: any ResumeParser = .live
    ) {
        self.llmAdapter = llmAdapter
        self.resumeParser = resumeParser
    }

    public func createWorkflow(name: String, triggers: [AutomationTrigger], actions: [AutomationAction]) async throws -> AutomationWorkflow {
        let workflow = AutomationWorkflow(name: name, triggers: triggers, actions: actions)
        workflows[workflow.id] = workflow
        return workflow
    }

    public func executeWorkflow(_ workflow: AutomationWorkflow, for job: Job, profile: Profile) async throws -> AutomationResult {
        var executedActions: [AutomationAction] = []
        var success = true
        var errorMessage: String?

        for action in workflow.actions {
            do {
                try await executeAction(action, job: job, profile: profile)
                executedActions.append(action)
            } catch {
                success = false
                errorMessage = error.localizedDescription
                break
            }
        }

        return AutomationResult(
            workflowId: workflow.id,
            trigger: workflow.triggers.first ?? .custom(condition: "manual"),
            actions: executedActions,
            success: success,
            errorMessage: errorMessage
        )
    }

    public func getActiveWorkflows() async throws -> [AutomationWorkflow] {
        workflows.values.filter { $0.isActive }
    }

    public func deactivateWorkflow(id: UUID) async throws {
        if var workflow = workflows[id] {
            workflow = AutomationWorkflow(
                id: workflow.id,
                name: workflow.name,
                triggers: workflow.triggers,
                actions: workflow.actions,
                isActive: false,
                createdAt: workflow.createdAt
            )
            workflows[id] = workflow
        }
    }

    public func processPendingAutomations() async throws -> [AutomationResult] {
        let now = Date()
        let dueActions = pendingActions.filter { $0.executeAt <= now }

        var results: [AutomationResult] = []

        for action in dueActions {
            if let workflow = workflows[action.workflowId] {
                let result = try await executeWorkflow(workflow, for: action.job, profile: action.profile)
                results.append(result)
            }
        }

        // Remove processed actions
        pendingActions.removeAll { dueActions.contains($0) }

        return results
    }

    private func executeAction(_ action: AutomationAction, job: Job, profile: Profile) async throws {
        switch action {
        case .autoApply(let profile, let resume):
            try await performAutoApply(job: job, profile: profile, resume: resume)

        case .sendFollowUp(let email):
            try await sendFollowUpEmail(job: job, email: email)

        case .scheduleReminder(let title, let message, let delayHours):
            scheduleReminder(job: job, title: title, message: message, delayHours: delayHours)

        case .updateApplicationStatus(let status):
            try await updateApplicationStatus(job: job, status: status)

        case .generateThankYouNote(let interviewDate):
            try await generateThankYouNote(job: job, profile: profile, interviewDate: interviewDate)
        }
    }

    private func performAutoApply(job: Job, profile: Profile, resume: ParsedResume) async throws {
        // Generate application materials
        let optimizedResume = try await resumeParser.optimizeForJob(resume, job: job)

        // In production, this would submit to job application systems
        // For now, just log the automation
        print("Auto-applying to \(job.title) at \(job.company)")
        print("Using optimized resume with \(optimizedResume.keywordMatches.count) matched keywords")
    }

    private func sendFollowUpEmail(job: Job, email: FollowUpEmail) async throws {
        // Generate personalized follow-up content
        let prompt = """
        Generate a professional follow-up email for a job application to \(job.company) for the \(job.title) position.

        Original application was sent \(Int(email.sendDelay)) hours ago.

        Keep it concise and professional.
        """

        let personalizedBody = try await llmAdapter.generate(prompt: prompt)

        // In production, integrate with email service
        print("Sending follow-up email: \(email.subject)")
        print("Body: \(personalizedBody)")
    }

    private func scheduleReminder(job: Job, title: String, message: String, delayHours: Int) {
        let reminderDate = Date().addingTimeInterval(TimeInterval(delayHours * 3600))
        print("Scheduled reminder '\(title)' for \(reminderDate)")
    }

    private func updateApplicationStatus(job: Job, status: ApplicationStatus) async throws {
        // In production, update tracking system
        print("Updated application status to \(status) for \(job.title)")
    }

    private func generateThankYouNote(job: Job, profile: Profile, interviewDate: Date) async throws {
        let prompt = """
        Generate a thank you note after an interview at \(job.company) for the \(job.title) position.

        Interview was on \(interviewDate.formatted()).

        Keep it professional and concise.
        """

        let thankYouNote = try await llmAdapter.generate(prompt: prompt)
        print("Generated thank you note: \(thankYouNote)")
    }
}

// MARK: - Predefined Workflows

extension AutomationEngine {
    /// Create a comprehensive auto-apply workflow
    public func createAutoApplyWorkflow() async throws -> AutomationWorkflow {
        let triggers: [AutomationTrigger] = [
            .jobMatch(minScore: 0.8)
        ]

        let actions: [AutomationAction] = [
            .autoApply(profile: Profile(name: "Default", email: "", summary: ""), resume: ParsedResume(contactInfo: ContactInfo(name: ""))),
            .scheduleReminder(title: "Follow up in 1 week", message: "Send follow-up email", delayHours: 168)
        ]

        return try await createWorkflow(name: "Auto Apply", triggers: triggers, actions: actions)
    }

    /// Create a follow-up workflow
    public func createFollowUpWorkflow() async throws -> AutomationWorkflow {
        let triggers: [AutomationTrigger] = [
            .noResponse(daysAfter: 7)
        ]

        let followUpEmail = FollowUpEmail(
            subject: "Following up on my application",
            body: "I wanted to follow up on my application...",
            sendDelay: 168  // 1 week
        )

        let actions: [AutomationAction] = [
            .sendFollowUp(email: followUpEmail)
        ]

        return try await createWorkflow(name: "Follow Up", triggers: triggers, actions: actions)
    }
}