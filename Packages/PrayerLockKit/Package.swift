// swift-tools-version: 6.0
// PrayerLockKit — all platform-independent product logic for Prayer Lock.
//
// Layering (lower layers never import higher ones):
//   PLCore            → foundation utilities (ids, storage, logging, config)
//   PLFaith           → faith / tradition / source taxonomy, spiritual profile
//   PLContent         → content model, provenance, catalog, validation, selection
//   PLCalendar        → religious calendar rules and devotional associations
//   PLHabits          → prayer sessions, streaks, insights
//   PLProtection      → app-shield domain logic + Screen Time adapters (iOS only)
//   PLMonetization    → products, subscription state, entitlements, StoreKit 2
//   PLScripture       → bundled scripture editions, reader policy, daily verse
//   PLCompanion       → companion chat: verified-text markers, server transport, context
//   PLAssistant       → AI assistant pipeline (router → context → retrieval → generation → validation)
//   PLBrand           → brand color tokens (UIKit-only; safe for tiny extensions)
//   PLDesign          → SwiftUI design tokens and shared components
import PackageDescription

let package = Package(
    name: "PrayerLockKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PLCore", targets: ["PLCore"]),
        .library(name: "PLFaith", targets: ["PLFaith"]),
        .library(name: "PLContent", targets: ["PLContent"]),
        .library(name: "PLCalendar", targets: ["PLCalendar"]),
        .library(name: "PLHabits", targets: ["PLHabits"]),
        .library(name: "PLProtection", targets: ["PLProtection"]),
        .library(name: "PLMonetization", targets: ["PLMonetization"]),
        .library(name: "PLScripture", targets: ["PLScripture"]),
        .library(name: "PLCompanion", targets: ["PLCompanion"]),
        .library(name: "PLAssistant", targets: ["PLAssistant"]),
        .library(name: "PLBrand", targets: ["PLBrand"]),
        .library(name: "PLDesign", targets: ["PLDesign"]),
    ],
    targets: [
        .target(name: "PLCore"),
        .target(name: "PLFaith", dependencies: ["PLCore"], resources: [.process("Resources")]),
        .target(name: "PLContent", dependencies: ["PLCore", "PLFaith"], resources: [.process("Resources")]),
        .target(name: "PLCalendar", dependencies: ["PLCore", "PLFaith"], resources: [.process("Resources")]),
        .target(name: "PLHabits", dependencies: ["PLCore", "PLFaith", "PLContent"]),
        .target(name: "PLProtection", dependencies: ["PLCore"]),
        .target(name: "PLMonetization", dependencies: ["PLCore"], resources: [.process("Resources")]),
        .target(name: "PLScripture", dependencies: ["PLCore", "PLFaith", "PLContent"], resources: [.process("Resources")]),
        .target(name: "PLCompanion", dependencies: ["PLCore", "PLFaith", "PLContent", "PLScripture"]),
        .target(name: "PLAssistant", dependencies: ["PLCore", "PLFaith", "PLContent", "PLCalendar"]),
        .target(name: "PLBrand"),
        .target(name: "PLDesign", dependencies: ["PLBrand", "PLContent", "PLFaith"], resources: [.process("Resources")]),

        .testTarget(name: "PLCoreTests", dependencies: ["PLCore"]),
        .testTarget(name: "PLFaithTests", dependencies: ["PLFaith"]),
        .testTarget(name: "PLContentTests", dependencies: ["PLContent", "PLFaith"]),
        .testTarget(name: "PLCalendarTests", dependencies: ["PLCalendar", "PLFaith"]),
        .testTarget(name: "PLHabitsTests", dependencies: ["PLHabits"]),
        .testTarget(name: "PLProtectionTests", dependencies: ["PLProtection", "PLCore"]),
        .testTarget(name: "PLMonetizationTests", dependencies: ["PLMonetization"]),
        .testTarget(name: "PLAssistantTests", dependencies: ["PLAssistant", "PLContent", "PLFaith"]),
        .testTarget(name: "PLBrandTests", dependencies: ["PLBrand"]),
        .testTarget(name: "PLCompanionTests", dependencies: ["PLCompanion", "PLScripture", "PLContent", "PLFaith"]),
        .testTarget(name: "PLScriptureTests", dependencies: ["PLScripture", "PLContent", "PLFaith", "PLCore"]),
    ]
)
