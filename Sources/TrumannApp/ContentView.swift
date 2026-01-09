import SwiftUI
import Core
import Ingestion
import Ranking
import Generation
import Tracking

struct ContentView: View {
    @State private var searchQuery = ""
    @State private var jobs: [RankedJob] = []
    @State private var isLoading = false
    @State private var selectedJob: RankedJob?
    @State private var showConsent = false
    @State private var consentGranted = false

    let ranker = JobRanker()
    let ingestion = JobIngestionPipeline()

    var body: some View {
        if consentGranted {
            NavigationSplitView {
                // Sidebar: Search and job list
                VStack {
                    HStack {
                        TextField("Search jobs...", text: $searchQuery)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(searchJobs)
                        Button(action: searchJobs) {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()

                    if isLoading {
                        ProgressView("Searching jobs...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(jobs, selection: $selectedJob) { job in
                            VStack(alignment: .leading) {
                                Text(job.job.title)
                                    .font(.headline)
                                Text(job.job.company)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Score: \(String(format: "%.2f", job.score))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.inset)
                    }
                }
                .frame(minWidth: 300)
            } detail: {
                // Detail view
                if let job = selectedJob {
                    JobDetailView(job: job)
                } else {
                    Text("Select a job to view details")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Trumann - Job Search")
        } else {
            ConsentView(granted: $consentGranted)
        }
    }

    private func searchJobs() {
        guard !searchQuery.isEmpty else { return }
        isLoading = true

        Task {
            // Mock jobs (RSS parser tested separately)
            let mockJobs = [
                Job(title: "iOS Developer at Apple", company: "Apple", description: "Swift development role", postedDate: Date(), url: "https://apple.com/job1", source: .linkedin),
                Job(title: "Software Engineer at Google", company: "Google", description: "Engineering position", postedDate: Date(), url: "https://google.com/job2", source: .indeed)
            ]

            let ranked = ranker.rank(jobs: mockJobs, query: JobQuery(keywords: searchQuery))
            jobs = ranked
            isLoading = false
        }
    }
}

struct JobDetailView: View {
    let job: RankedJob
    @State private var showApplySheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(job.job.title)
                    .font(.largeTitle)
                    .bold()

                Text(job.job.company)
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text(job.job.description)
                    .font(.body)

                HStack {
                    Text("Posted: \(job.job.postedDate.formatted())")
                    Spacer()
                    Text("Score: \(String(format: "%.2f", job.score))")
                        .foregroundColor(.green)
                }
                .font(.caption)

                Button("Apply Now") {
                    showApplySheet = true
                }
                .buttonStyle(.borderedProminent)
                .sheet(isPresented: $showApplySheet) {
                    ApplyView(job: job.job)
                }
            }
            .padding()
        }
    }
}

struct ConsentView: View {
    @Binding var granted: Bool
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Privacy Consent")
                .font(.largeTitle)
                .bold()

            Text("Trumann needs your permission to track usage for personalized job recommendations.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if isRequesting {
                ProgressView("Requesting permission...")
            } else {
                Button("Grant Permission") {
                    requestConsent()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Deny") {
                    // For demo, allow denial
                    granted = false
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: 400)
    }

    private func requestConsent() {
        isRequesting = true
        Task {
            let consentService = LiveConsentService()
            let state = await consentService.requestTrackingAuthorization()
            granted = state == .authorized
            isRequesting = false
        }
    }
}

struct ApplyView: View {
    let job: Job
    @State private var name = "John Doe"
    @State private var email = "john@example.com"
    @State private var summary = "Developer"
    @State private var generatedCV = ""
    @State private var isGenerating = false
    @Environment(\.dismiss) private var dismiss

    let generator = TemplateEngine()

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                    TextField("Summary", text: $summary)
                }

                Section("Generated CV") {
                    if isGenerating {
                        ProgressView("Generating CV...")
                    } else {
                        TextEditor(text: $generatedCV)
                            .frame(height: 200)
                        Button("Generate CV") {
                            generateCV()
                        }
                        Button("Apply") {
                            // Stub: apply to job
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Apply to \(job.title)")
            .toolbar {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private func generateCV() {
        isGenerating = true
        let profile = Profile(name: name, email: email, summary: summary)
        Task {
            generatedCV = try await generator.generateCV(profile: profile)
            isGenerating = false
        }
    }
}