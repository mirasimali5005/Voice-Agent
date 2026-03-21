// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VoiceDictation",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    ],
    targets: [
        // System library target wrapping the pre-built whisper.cpp static library
        .systemLibrary(
            name: "CWhisper",
            path: "Sources/CWhisper",
            pkgConfig: nil,
            providers: []
        ),

        // Main executable target
        .executableTarget(
            name: "VoiceDictation",
            dependencies: [
                "CWhisper",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/VoiceDictation",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "Libraries/lib",
                ]),
                .linkedLibrary("whisper_full"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Accelerate"),
                .linkedLibrary("c++"),
            ]
        ),

        // Test target
        .testTarget(
            name: "VoiceDictationTests",
            dependencies: ["VoiceDictation"],
            path: "Tests/VoiceDictationTests"
        ),

        // Transcription tests
        .testTarget(
            name: "TranscriptionTests",
            dependencies: ["VoiceDictation"],
            path: "Tests/TranscriptionTests"
        ),

        // Audio tests
        .testTarget(
            name: "AudioTests",
            dependencies: ["VoiceDictation"],
            path: "Tests/AudioTests"
        ),

        // Cleanup tests (LMStudioClient + TranscriptCleaner)
        .testTarget(
            name: "CleanupTests",
            dependencies: ["VoiceDictation"],
            path: "Tests/CleanupTests"
        ),

        // Hotkey tests (DoubleTapStateMachine)
        .testTarget(
            name: "HotkeyTests",
            dependencies: ["VoiceDictation"],
            path: "Tests/HotkeyTests"
        ),

        // Text injection tests
        .testTarget(
            name: "TextInjectionTests",
            dependencies: ["VoiceDictation"],
            path: "Tests/TextInjectionTests"
        ),

        // Storage tests (DatabaseManager + DictationEntry)
        .testTarget(
            name: "StorageTests",
            dependencies: [
                "VoiceDictation",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Tests/StorageTests"
        ),

        // Personalization tests (DiffEngine, PatternMatcher, RuleCompressor)
        .testTarget(
            name: "PersonalizationTests",
            dependencies: ["VoiceDictation"],
            path: "Tests/PersonalizationTests"
        ),
    ]
)
