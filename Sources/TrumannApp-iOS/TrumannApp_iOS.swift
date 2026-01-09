import SwiftUI
import TrumannUI
import Core

@main
struct TrumannApp_iOS: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            NavigationContainer {
                MainTabView()
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        setupAppearance()
        return true
    }

    private func setupAppearance() {
        // Configure Liquid Glass appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            JobsView()
                .tabItem {
                    Label("Jobs", systemImage: "briefcase")
                }
                .tag(0)

            ApplicationsView()
                .tabItem {
                    Label("Applications", systemImage: "doc.text")
                }
                .tag(1)

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .onChange(of: selectedTab) { oldValue, newValue in
            // Haptic feedback on tab change
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - Enhanced iOS Views

struct EnhancedJobsView: View {
    @StateObject private var viewModel = TrumannViewModel()
    @State private var searchText = ""
    @State private var selectedFilter = JobFilter.all
    @State private var showingFilters = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: "Discovering opportunities...")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredJobs) { job in
                                EnhancedJobCard(job: job) {
                                    // Navigate with haptic feedback
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refreshJobs()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            }
            .navigationTitle("Discover Jobs")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search jobs, companies, or skills")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                JobFiltersView(selectedFilter: $selectedFilter)
                    .presentationDetents([.medium])
            }
        }
        .liquidGlass()
    }

    private var filteredJobs: [Job] {
        viewModel.jobs.filter { job in
            let matchesSearch = searchText.isEmpty ||
                job.title.localizedCaseInsensitiveContains(searchText) ||
                job.company.localizedCaseInsensitiveContains(searchText)

            let matchesFilter = selectedFilter == .all ||
                (selectedFilter == .remote && job.location?.localizedCaseInsensitiveContains("remote") == true)

            return matchesSearch && matchesFilter
        }
    }
}

struct EnhancedJobCard: View {
    let job: Job
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var showingDetails = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(job.company)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                if let location = job.location {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let salary = job.salary {
                    Label(salary.displayString, systemImage: "dollarsign.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                HStack {
                    Text("Posted \(job.postedDate.relativeFormatted())")
                        .font(.caption2)
                        .foregroundColor(.tertiary)
                    Spacer()
                    Text("Apply")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .gesture(
            LongPressGesture(minimumDuration: 0.1)
                .onEnded { _ in
                    withAnimation {
                        isPressed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isPressed = false
                        }
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
        )
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTap()
                }
        )
    }
}

struct JobFiltersView: View {
    @Binding var selectedFilter: JobFilter

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(JobFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.inline)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

enum JobFilter: String, CaseIterable {
    case all = "All Jobs"
    case remote = "Remote Only"
    case recent = "Posted Today"
    case highSalary = "High Salary"

    var displayName: String { rawValue }
}

// MARK: - Advanced Analytics View

struct EnhancedAnalyticsView: View {
    @StateObject private var viewModel = TrumannViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Key Metrics Cards
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        MetricCard(
                            title: "Applications",
                            value: "\(viewModel.applications.count)",
                            trend: "+12%",
                            color: .blue
                        )

                        MetricCard(
                            title: "Response Rate",
                            value: "75%",
                            trend: "+5%",
                            color: .green
                        )

                        MetricCard(
                            title: "Interviews",
                            value: "3",
                            trend: "+2",
                            color: .orange
                        )

                        MetricCard(
                            title: "Offers",
                            value: "1",
                            trend: "New",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)

                    // Charts Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Application Trends")
                            .font(.title2)
                            .bold()

                        // Mock chart - would use SwiftUI Charts in production
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                            .frame(height: 200)
                            .overlay(
                                Text("Weekly Application Chart")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .padding(.horizontal)

                    // Recommendations
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI Recommendations")
                            .font(.title2)
                            .bold()

                        RecommendationCard(
                            icon: "target",
                            title: "Improve Response Rate",
                            description: "Follow up within 3 days of application",
                            action: "View Tips"
                        )

                        RecommendationCard(
                            icon: "briefcase",
                            title: "Target Tech Companies",
                            description: "75% of responses come from tech sector",
                            action: "Explore Jobs"
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Career Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
        .liquidGlass()
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let trend: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title)
                .bold()
                .foregroundColor(color)

            Text(trend)
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct RecommendationCard: View {
    let icon: String
    let title: String
    let description: String
    let action: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(action)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Extensions

extension Date {
    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}