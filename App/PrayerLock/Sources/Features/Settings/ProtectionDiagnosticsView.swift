import PLDesign
import PLProtection
import SwiftUI
import UIKit
import UserNotifications

/// Development-build-only view of the protection state, for real-device testing
/// (docs/11-device-test-plan.md). Shows counts and events only — never app names,
/// tokens, prayer content, or moods.
struct ProtectionDiagnosticsView: View {
    @Environment(AppModel.self) private var model
    @State private var notificationStatus = "–"
    @State private var refreshID = UUID()

    var body: some View {
        let protection = model.env.protection
        let platform = protection.diagnostics()
        let settings = protection.settings
        let selection = protection.selection
        let grant = model.env.protectionState.grant()

        List {
            Section("State") {
                row("Status", "\(model.protectionStatus)")
                row("Authorization", protection.authorization.rawValue)
                row("App Group container", platform.appGroupAvailable ? "available" : "MISSING — check entitlements")
                row("Notifications", notificationStatus)
                row("iOS", UIDevice.current.systemVersion)
            }
            Section("Choices") {
                row("Selection", selection.countsDescription)
                row("Needs reselection", "\(model.env.protectionState.needsReselection)")
                row("Protection enabled", "\(settings.isEnabled)")
                row("Unlock duration", settings.unlockDuration.title)
                row("Current grant", grant.map { "until \($0.expiresAt.formatted(date: .omitted, time: .standard))" } ?? "none")
                row("Pending shield requests", "\(model.env.protectionState.pendingRequests(at: .now).count)")
            }
            Section("Operating system") {
                row("Shielded apps", "\(platform.shieldedApplications)")
                row("Shielded websites", "\(platform.shieldedWebDomains)")
                row("Category shield", platform.categoryShieldActive ? "on" : "off")
                row("Monitored activities", platform.monitoredActivities.isEmpty ? "none" : platform.monitoredActivities.joined(separator: "\n"))
            }
            Section("Recent events (newest first)") {
                ForEach(Array(protection.recentEvents.enumerated()), id: \.offset) { _, event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.kind.rawValue).font(.footnote.monospaced())
                        Text("\(event.date.formatted(date: .abbreviated, time: .standard))\(event.detail.map { " · \($0)" } ?? "")")
                            .font(.caption2)
                            .foregroundStyle(Color.plInkSecondary)
                    }
                }
            }
            Section {
                Button("Copy report") { UIPasteboard.general.string = report() }
                Button("Refresh") {
                    model.refreshProtectionStatus()
                    refreshID = UUID()
                }
            }
        }
        .id(refreshID)
        .navigationTitle("Protection diagnostics")
        .task {
            notificationStatus = switch await model.env.notifications.authorizationStatus() {
            case .authorized: "authorized"
            case .denied: "denied"
            case .notDetermined: "not determined"
            case .provisional: "provisional"
            case .ephemeral: "ephemeral"
            @unknown default: "unknown"
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value).font(.footnote.monospaced()).multilineTextAlignment(.trailing)
        }
    }

    private func report() -> String {
        let protection = model.env.protection
        let platform = protection.diagnostics()
        var lines = [
            "\(AppBrand.displayName) protection report — \(Date.now.formatted(.iso8601))",
            "iOS \(UIDevice.current.systemVersion)",
            "status=\(model.protectionStatus) authorization=\(protection.authorization.rawValue)",
            "appGroup=\(platform.appGroupAvailable) notifications=\(notificationStatus)",
            "selection=\(protection.selection.countsDescription) enabled=\(protection.settings.isEnabled) duration=\(protection.settings.unlockDuration.title)",
            "grant=\(model.env.protectionState.grant().map { $0.expiresAt.formatted(.iso8601) } ?? "none")",
            "shieldedApps=\(platform.shieldedApplications) shieldedSites=\(platform.shieldedWebDomains) categoryShield=\(platform.categoryShieldActive)",
            "activities=\(platform.monitoredActivities.joined(separator: ","))",
            "events:",
        ]
        lines += protection.recentEvents.map { "  \($0.date.formatted(.iso8601)) \($0.kind.rawValue) \($0.detail ?? "")" }
        return lines.joined(separator: "\n")
    }
}
