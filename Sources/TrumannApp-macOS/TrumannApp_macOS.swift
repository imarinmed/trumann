import SwiftUI
import TrumannUI
import Core

@main
struct TrumannApp_macOS: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Trumann", id: "main") {
            NavigationContainer {
                MainSplitView()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .commands {
            SidebarCommands()
            JobCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupAppearance()
        setupNotifications()
    }

    private func setupAppearance() {
        // Configure Swift Glass appearance
        NSApp.appearance = NSAppearance(named: .darkAqua) // Or system appearance
    }

    private func setupNotifications() {
        // Request notification permissions for job alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
}

struct MainSplitView: View {
    @StateObject private var viewModel = TrumannViewModel()
    @State private var selectedJob: Job?
    @State private var sidebarVisible = true

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedJob: $selectedJob)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            if let job = selectedJob {
                JobDetailView(job: job, viewModel: viewModel)
            } else {
                WelcomeView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    sidebarVisible.toggle()
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                } label: {
                    Image(systemName: "sidebar.leading")
                }
            }
        }
        .background(Color(.windowBackgroundColor).opacity(0.95))
        .glassBackgroundEffect()
    }
}

struct SidebarView: View {
    @Binding var selectedJob: Job?
    @StateObject private var viewModel = TrumannViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: JobFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Trumann")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    Task { await viewModel.refreshJobs() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(.controlBackgroundColor).opacity(0.8))

            // Search and Filters
            VStack(spacing: 12) {
                SearchBar(text: $searchText)
                    .padding(.horizontal)

                FilterPicker(selectedFilter: $selectedFilter)
                    .padding(.horizontal)
            }
            .padding(.vertical)

            // Jobs List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredJobs) { job in
                        JobRow(job: job, isSelected: selectedJob?.id == job.id)
                            .onTapGesture {
                                selectedJob = job
                            }
                            .contextMenu {
                                Button("Apply Now") {
                                    // Quick apply
                                }
                                Button("Save for Later") {
                                    // Save job
                                }
                                Divider()
                                Button("Open in Browser") {
                                    if let url = URL(string: job.url) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(minWidth: 280)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .glassBackgroundEffect()
    }

    private var filteredJobs: [Job] {
        viewModel.jobs.filter { job in
            let matchesSearch = searchText.isEmpty ||
                job.title.localizedCaseInsensitiveContains(searchText) ||
                job.company.localizedCaseInsensitiveContains(searchText)

            return matchesSearch && matchesFilter(job, filter: selectedFilter)
        }
    }

    private func matchesFilter(_ job: Job, filter: JobFilter) -> Bool {
        switch filter {
        case .all: return true
        case .remote: return job.location?.localizedCaseInsensitiveContains("remote") == true
        case .recent: return job.postedDate > Date().addingTimeInterval(-86400) // Last 24 hours
        case .highSalary: return job.salary?.min ?? 0 > 100000
        }
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search jobs...", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
}

struct FilterPicker: View {
    @Binding var selectedFilter: JobFilter

    var body: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(JobFilter.allCases, id: \.self) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

struct JobRow: View {
    let job: Job
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(job.company)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let location = job.location {
                    Text(location)
                        .font(.system(size: 10))
                        .foregroundColor(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let salary = job.salary {
                Text(salary.displayString)
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

struct JobDetailView: View {
    let job: Job
    let viewModel: TrumannViewModel

    @State private var showingApplySheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.title)
                        .font(.system(size: 28, weight: .bold))

                    Text(job.company)
                        .font(.title2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        if let location = job.location {
                            Label(location, systemImage: "location")
                        }

                        if let salary = job.salary {
                            Label(salary.displayString, systemImage: "dollarsign.circle")
                        }

                        Label(job.postedDate.formatted(date: .abbreviated, time: .omitted),
                              systemImage: "calendar")
                    }
                    .foregroundColor(.secondary)
                }

                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("Job Description")
                        .font(.title3)
                        .bold()

                    Text(job.description)
                        .textSelection(.enabled)
                        .lineSpacing(4)
                }

                // Actions
                HStack(spacing: 12) {
                    Button("Apply Now") {
                        showingApplySheet = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Save Job") {
                        // Save job
                    }
                    .buttonStyle(.bordered)

                    Button("Open in Browser") {
                        if let url = URL(string: job.url) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(32)
        }
        .navigationTitle(job.title)
        .sheet(isPresented: $showingApplySheet) {
            ApplySheet(job: job)
        }
        .background(Color(.windowBackgroundColor))
        .glassBackgroundEffect()
    }
}

struct ApplySheet: View {
    let job: Job
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Apply for \(job.title)")
                .font(.title2)
                .bold()

            Text("at \(job.company)")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Apply")
                    .font(.headline)

                Text("Upload your resume or use AI-generated application materials.")
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Apply") {
                    // TODO: Implement application submission
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 400, height: 300)
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "briefcase")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                Text("Welcome to Trumann")
                    .font(.system(size: 32, weight: .bold))

                Text("Your AI-powered career management platform")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Text("Get started by:")
                    .font(.headline)

                Text("• Searching for jobs")
                    .foregroundColor(.secondary)

                Text("• Managing applications")
                    .foregroundColor(.secondary)

                Text("• Analyzing your progress")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .glassBackgroundEffect()
    }
}

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoRefresh") private var autoRefresh = true

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            NotificationSettingsView(notificationsEnabled: $notificationsEnabled)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("theme") private var theme = "system"
    @AppStorage("autoRefresh") private var autoRefresh = true

    var body: some View {
        Form {
            Picker("Appearance", selection: $theme) {
                Text("Light").tag("light")
                Text("Dark").tag("dark")
                Text("System").tag("system")
            }

            Toggle("Auto-refresh jobs", isOn: $autoRefresh)

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct NotificationSettingsView: View {
    @Binding var notificationsEnabled: Bool

    var body: some View {
        Form {
            Toggle("Enable Notifications", isOn: $notificationsEnabled)

            Section("Notification Types") {
                Toggle("Job Alerts", isOn: .constant(true))
                Toggle("Application Updates", isOn: .constant(true))
                Toggle("Interview Reminders", isOn: .constant(false))
            }
        }
        .formStyle(.grouped)
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section("Data Collection") {
                Toggle("Analytics", isOn: .constant(false))
                Toggle("Crash Reports", isOn: .constant(true))
            }

            Section("Data Export") {
                Button("Export My Data") {
                    // TODO: Implement data export
                }
                Button("Delete My Account") {
                    // TODO: Implement account deletion
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Commands

struct SidebarCommands: Commands {
    var body: some Commands {
        SidebarCommands()
    }
}

struct JobCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Refresh Jobs") {
                // Refresh logic
            }
            .keyboardShortcut("R", modifiers: .command)
        }
    }
}

// MARK: - Extensions

extension View {
    func glassBackgroundEffect() -> some View {
        self.background(
            ZStack {
                Color(.windowBackgroundColor)
                Color.white.opacity(0.05)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}