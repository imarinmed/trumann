import SwiftUI
import Core

// MARK: - Platform Detection

enum Platform {
    case iOS, macOS, watchOS, tvOS, visionOS

    static var current: Platform {
        #if os(iOS)
        return .iOS
        #elseif os(macOS)
        return .macOS
        #elseif os(watchOS)
        return .watchOS
        #elseif os(tvOS)
        return .tvOS
        #elseif os(visionOS)
        return .visionOS
        #else
        return .iOS // fallback
        #endif
    }
}

// MARK: - Shared View Models

@MainActor
class TrumannViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var applications: [Application] = []
    @Published var profile: Profile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Dependency(\.storage) private var storage
    @Dependency(\.networkClient) private var networkClient

    init() {
        loadInitialData()
    }

    private func loadInitialData() {
        // Load cached data
        Task {
            do {
                // Load profile, jobs, applications
                profile = try await storage.load(Profile.self, forKey: "user_profile")
                jobs = try await storage.load([Job].self, forKey: "cached_jobs") ?? []
                applications = try await storage.load([Application].self, forKey: "applications") ?? []
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func refreshJobs() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Simulate job refresh
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            // In real app, would fetch from APIs
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared Components

struct JobCard: View {
    let job: Job
    let onTap: () -> Void

    var body: some View {
        #if os(watchOS)
        watchOSJobCard
        #elseif os(tvOS)
        tvOSJobCard
        #else
        defaultJobCard
        #endif
    }

    private var defaultJobCard: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(job.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(job.company)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let location = job.location {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let salary = job.salary {
                    Text(salary.displayString)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var watchOSJobCard: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(job.company)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .buttonStyle(.plain)
    }

    private var tvOSJobCard: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.title)
                        .font(.title2)

                    Text(job.company)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if let location = job.location {
                        Text(location)
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .focusable()
        }
        .buttonStyle(.card)
    }
}

struct ApplicationStatusBadge: View {
    let status: ApplicationStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .clipShape(Capsule())
    }
}

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let error: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)

            Text("Something went wrong")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Liquid Glass Design System

struct LiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Color(.systemBackground)
                    Color.white.opacity(0.1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
    }
}

extension View {
    func liquidGlass() -> some View {
        modifier(LiquidGlassModifier())
    }
}

// MARK: - Shared Navigation

struct NavigationContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView()
        } detail: {
            content
        }
        #elseif os(iOS)
        NavigationStack {
            content
        }
        #elseif os(watchOS)
        TabView {
            content
        }
        #elseif os(tvOS)
        NavigationStack {
            content
        }
        #else
        content
        #endif
    }
}

struct SidebarView: View {
    var body: some View {
        List {
            NavigationLink(destination: JobsView()) {
                Label("Jobs", systemImage: "briefcase")
            }
            NavigationLink(destination: ApplicationsView()) {
                Label("Applications", systemImage: "doc.text")
            }
            NavigationLink(destination: AnalyticsView()) {
                Label("Analytics", systemImage: "chart.bar")
            }
            NavigationLink(destination: ProfileView()) {
                Label("Profile", systemImage: "person")
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Shared Views (Placeholders for now)

struct JobsView: View {
    @StateObject private var viewModel = TrumannViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(message: "Finding jobs...")
            } else if let error = viewModel.errorMessage {
                ErrorView(error: error) {
                    Task { await viewModel.refreshJobs() }
                }
            } else {
                List(viewModel.jobs) { job in
                    JobCard(job: job) {
                        // Navigate to job detail
                    }
                }
                .refreshable {
                    await viewModel.refreshJobs()
                }
            }
        }
        .navigationTitle("Jobs")
    }
}

struct ApplicationsView: View {
    @StateObject private var viewModel = TrumannViewModel()

    var body: some View {
        List(viewModel.applications) { application in
            VStack(alignment: .leading) {
                Text(application.jobId.uuidString) // Should show job title
                ApplicationStatusBadge(status: application.status)
            }
        }
        .navigationTitle("Applications")
    }
}

struct AnalyticsView: View {
    var body: some View {
        Text("Analytics Dashboard")
            .navigationTitle("Analytics")
    }
}

struct ProfileView: View {
    var body: some View {
        Text("User Profile")
            .navigationTitle("Profile")
    }
}

// MARK: - Extensions

extension ApplicationStatus {
    var displayName: String {
        switch self {
        case .applied: return "Applied"
        case .interviewing: return "Interviewing"
        case .rejected: return "Rejected"
        case .accepted: return "Accepted"
        }
    }

    var color: Color {
        switch self {
        case .applied: return .blue
        case .interviewing: return .orange
        case .rejected: return .red
        case .accepted: return .green
        }
    }
}

extension Salary {
    var displayString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        let minStr = formatter.string(from: NSNumber(value: min)) ?? "\(min)"
        if let max = max {
            let maxStr = formatter.string(from: NSNumber(value: max)) ?? "\(max)"
            return "\(minStr) - \(maxStr)"
        } else {
            return minStr
        }
    }
}