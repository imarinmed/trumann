// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "trumann",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "TrumannCore",
            targets: ["Core"]
        ),
        .library(
            name: "TrumannIngestion",
            targets: ["Ingestion"]
        ),
        .library(
            name: "TrumannRanking",
            targets: ["Ranking"]
        ),
        .library(
            name: "TrumannGeneration",
            targets: ["Generation"]
        ),
        .library(
            name: "TrumannTracking",
            targets: ["Tracking"]
        ),
        .library(
            name: "TrumannAdapters",
            targets: ["Adapters"]
        ),
        .library(
            name: "TrumannResumeParser",
            targets: ["ResumeParser"]
        ),
        .library(
            name: "TrumannSemanticMatcher",
            targets: ["SemanticMatcher"]
        ),
        .library(
            name: "TrumannInterviewCoach",
            targets: ["InterviewCoach"]
        ),
        .library(
            name: "TrumannAutomationEngine",
            targets: ["AutomationEngine"]
        ),
        .library(
            name: "TrumannAnalyticsCore",
            targets: ["AnalyticsCore"]
        ),
        .library(
            name: "TrumannSyncManager",
            targets: ["SyncManager"]
        ),
        .library(
            name: "TrumannEnterpriseCore",
            targets: ["EnterpriseCore"]
        ),
        .library(
            name: "TrumannMonetizationCore",
            targets: ["MonetizationCore"]
        ),
        .executable(
            name: "TrumannApp",
            targets: ["TrumannApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.0.0")
    ],
    targets: [
        // Shared/Core domain primitives
        .target(
            name: "Core",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ]
        ),

        // Ingestion adapters and pipelines
        .target(
            name: "Ingestion",
            dependencies: [
                "Core",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),

        // Ranking algorithms
        .target(
            name: "Ranking",
            dependencies: [
                "Core"
            ]
        ),

        // CV/Cover generation
        .target(
            name: "Generation",
            dependencies: [
                "Core"
            ]
        ),

        // Consent/tracking/ATS
        .target(
            name: "Tracking",
            dependencies: [
                "Core",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),

        // External API clients
        .target(
            name: "Adapters",
            dependencies: [
                "Core",
                "Ingestion",
                "Tracking"
            ]
        ),

        // Resume parsing and optimization
        .target(
            name: "ResumeParser",
            dependencies: [
                "Core",
                "Generation"
            ]
        ),

        // Semantic job matching
        .target(
            name: "SemanticMatcher",
            dependencies: [
                "Core",
                "Generation"
            ]
        ),

        // AI interview coaching
        .target(
            name: "InterviewCoach",
            dependencies: [
                "Core",
                "Generation",
                "SemanticMatcher"
            ]
        ),

        // Automated job application workflows
        .target(
            name: "AutomationEngine",
            dependencies: [
                "Core",
                "Generation",
                "ResumeParser",
                "Tracking"
            ]
        ),

        // Career analytics and insights
        .target(
            name: "AnalyticsCore",
            dependencies: [
                "Core",
                "Tracking"
            ]
        ),

        // Cross-platform synchronization
        .target(
            name: "SyncManager",
            dependencies: [
                "Core"
            ]
        ),

        // Enterprise features and compliance
        .target(
            name: "EnterpriseCore",
            dependencies: [
                "Core",
                "Tracking",
                "AnalyticsCore"
            ]
        ),

        // Monetization and premium features
        .target(
            name: "MonetizationCore",
            dependencies: [
                "Core",
                "Generation",
                "ResumeParser",
                "AnalyticsCore"
            ]
        ),

        // Shared UI Framework
        .target(
            name: "TrumannUI",
            dependencies: [
                "Core",
                "Ingestion",
                "Ranking",
                "Generation",
                "Tracking",
                "Adapters",
                "ResumeParser",
                "SemanticMatcher",
                "InterviewCoach",
                "AutomationEngine",
                "AnalyticsCore",
                "SyncManager",
                "EnterpriseCore",
                "MonetizationCore"
            ]
        ),

        // iOS App
        .executableTarget(
            name: "TrumannApp-iOS",
            dependencies: ["TrumannUI"],
            path: "Sources/TrumannApp-iOS"
        ),

        // macOS App
        .executableTarget(
            name: "TrumannApp-macOS",
            dependencies: ["TrumannUI"],
            path: "Sources/TrumannApp-macOS"
        ),

        // watchOS App
        .executableTarget(
            name: "TrumannApp-watchOS",
            dependencies: ["TrumannUI"],
            path: "Sources/TrumannApp-watchOS"
        ),

        // tvOS App
        .executableTarget(
            name: "TrumannApp-tvOS",
            dependencies: ["TrumannUI"],
            path: "Sources/TrumannApp-tvOS"
        ),

        // Tests
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "IngestionTests",
            dependencies: ["Ingestion"]
        ),
        .testTarget(
            name: "RankingTests",
            dependencies: ["Ranking"]
        ),
        .testTarget(
            name: "GenerationTests",
            dependencies: ["Generation"]
        ),
        .testTarget(
            name: "TrackingTests",
            dependencies: ["Tracking"]
        ),
        .testTarget(
            name: "AdaptersTests",
            dependencies: ["Adapters"]
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "Core",
                "Ingestion",
                "Ranking",
                "Generation",
                "Tracking",
                "Adapters"
            ]
        ),
        .testTarget(
            name: "ResumeParserTests",
            dependencies: ["ResumeParser"]
        ),
        .testTarget(
            name: "SemanticMatcherTests",
            dependencies: ["SemanticMatcher"]
        ),
        .testTarget(
            name: "InterviewCoachTests",
            dependencies: ["InterviewCoach"]
        ),
        .testTarget(
            name: "AutomationEngineTests",
            dependencies: ["AutomationEngine"]
        ),
        .testTarget(
            name: "AnalyticsCoreTests",
            dependencies: ["AnalyticsCore"]
        ),
        .testTarget(
            name: "SyncManagerTests",
            dependencies: ["SyncManager"]
        ),
        .testTarget(
            name: "EnterpriseCoreTests",
            dependencies: ["EnterpriseCore"]
        ),
        .testTarget(
            name: "MonetizationCoreTests",
            dependencies: ["MonetizationCore"]
        ),
    ]
)
