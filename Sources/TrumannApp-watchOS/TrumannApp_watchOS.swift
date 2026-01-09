import SwiftUI
import TrumannUI
import Core

@main
struct TrumannApp_watchOS: App {
    @WKApplicationDelegateAdaptor(TrumannAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            NavigationContainer {
                ContentView()
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "job_alert")
    }
}

class TrumannAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        // Initialize watch-specific services
        setupWatchConnectivity()
        scheduleComplications()
    }

    private func setupWatchConnectivity() {
        // Watch connectivity for iPhone sync
    }

    private func scheduleComplications() {
        // Schedule background updates for watch complications showing job counts
    }
}

struct ContentView: View {
    @StateObject private var viewModel = TrumannViewModel()

    var body: some View {
        TabView {
            JobsView()
                .tabItem {
                    Label("Jobs", systemImage: "briefcase")
                }

            ApplicationsView()
                .tabItem {
                    Label("Apps", systemImage: "doc.text")
                }

            AnalyticsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
    }
}

// MARK: - Watch-Specific Views

struct WatchJobsView: View {
    @StateObject private var viewModel = TrumannViewModel()

    var body: some View {
        List(viewModel.jobs) { job in
            JobCard(job: job) {
                // Quick apply or view details
                WKInterfaceDevice.current().play(.click)
            }
        }
        .navigationTitle("Jobs")
    }
}

struct WatchApplicationsView: View {
    @StateObject private var viewModel = TrumannViewModel()

    var body: some View {
        List(viewModel.applications) { application in
            HStack {
                VStack(alignment: .leading) {
                    Text(application.jobId.uuidString.prefix(8))
                        .font(.caption)
                    ApplicationStatusBadge(status: application.status)
                }
                Spacer()
                Text(application.appliedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Applications")
    }
}

struct WatchAnalyticsView: View {
    var body: some View {
        VStack {
            Text("Applications: 12")
            Text("Response Rate: 75%")
            Text("Interviews: 3")
        }
        .navigationTitle("Analytics")
    }
}

// MARK: - Complications

struct JobComplication: View {
    let entry: Provider.Entry

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))

            VStack {
                Text("\(entry.jobsCount)")
                    .font(.title3)
                Text("jobs")
                    .font(.caption2)
            }
        }
    }
}

struct Provider: TimelineProvider {
    typealias Entry = JobEntry

    func placeholder(in context: Context) -> JobEntry {
        JobEntry(date: Date(), jobsCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (JobEntry) -> ()) {
        let entry = JobEntry(date: Date(), jobsCount: 5) // Mock data
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = JobEntry(date: Date(), jobsCount: 5)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct JobEntry: TimelineEntry {
    let date: Date
    let jobsCount: Int
}

// MARK: - Notifications

class NotificationController: WKUserNotificationInterfaceController {
    override func didReceive(_ notification: UNNotification) {
        // Handle job alert notifications
    }
}

// MARK: - Watch Connectivity

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from iPhone
    }
}