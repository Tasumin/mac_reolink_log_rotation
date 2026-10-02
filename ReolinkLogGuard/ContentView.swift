import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var manager: LogGuardManager
    @State private var showingHelp = false
    @State private var showingNodeVyuPreview = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reolink LogGuard").font(.largeTitle).bold()
                    Text("Keep runaway Reolink logs from filling your Mac.").foregroundStyle(.secondary)
                }
                Spacer()
                Label(manager.isRunning ? "Automatic cleanup active" : "Service not loaded", systemImage: manager.isRunning ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 10)

            TabView(selection: $selectedTab) {
                DashboardTab(showNodeVyuPreview: $showingNodeVyuPreview)
                    .environmentObject(manager)
                    .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }
                    .tag(0)
                ConfigurationTab().environmentObject(manager).tabItem { Label("Configuration", systemImage: "slider.horizontal.3") }.tag(1)
                MaintenanceTab(showHelp: $showingHelp).environmentObject(manager).tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver") }.tag(2)
                AboutTab(showNodeVyuPreview: $showingNodeVyuPreview).tabItem { Label("NodeVyu", systemImage: "wave.3.right.circle") }.tag(3)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .frame(minWidth: 760, minHeight: 620)
        .onAppear { manager.refresh() }
        .sheet(isPresented: $showingHelp) { HelpView() }
        .sheet(isPresented: $showingNodeVyuPreview) { NodeVyuPreview() }
    }
}

struct DashboardTab: View {
    @EnvironmentObject var manager: LogGuardManager
    @Binding var showNodeVyuPreview: Bool
    private var limitText: String { "Limit: " + String(format: "%.1f", manager.maxSizeGB) + " GB" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    StatusCard(title: "Log Storage", value: manager.formattedSize, detail: limitText, icon: "internaldrive")
                    StatusCard(title: "Retention", value: "\(manager.retentionDays) days", detail: "Old logs automatically removed", icon: "calendar.badge.clock")
                    StatusCard(title: "Cleanup", value: manager.isRunning ? "Active" : "Stopped", detail: manager.isRunning ? "Background protection enabled" : "Service needs attention", icon: manager.isRunning ? "checkmark.shield" : "exclamationmark.shield")
                }
                GroupBox("Storage Protection") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(manager.formattedSize).font(.title2).bold(); Spacer(); Text("\(Int(manager.fractionUsed * 100))% of configured limit") }
                        ProgressView(value: manager.fractionUsed)
                        Text(manager.expandedLogDirectory).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        HStack { Button("Clean Now") { manager.runCleanup(dryRun: false) }.buttonStyle(.borderedProminent); Button("Dry Run") { manager.runCleanup(dryRun: true) }; Button("Open Log Folder") { manager.openLogFolder() }; Spacer(); Button("Refresh") { manager.refresh() } }
                    }.padding(6)
                }
                GroupBox("Recent Activity") { ScrollView { Text(manager.activity).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.frame(height: 80).padding(6) }
                NodeVyuPromotion(showPreview: $showNodeVyuPreview)
            }.padding(16)
        }
    }
}

struct StatusCard: View {
    let title: String; let value: String; let detail: String; let icon: String
    var body: some View { HStack(alignment: .top, spacing: 12) { Image(systemName: icon).font(.title2).frame(width: 28); VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title3).bold(); Text(detail).font(.caption2).foregroundStyle(.secondary) }; Spacer(minLength: 0) }.padding(14).frame(maxWidth: .infinity, minHeight: 92).background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10)) }
}

struct ConfigurationTab: View {
    @EnvironmentObject var manager: LogGuardManager
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 18) {
        Text("Protection Configuration").font(.title2).bold(); Text("Control when LogGuard cleans Reolink logs and how much disk space they are allowed to consume.").foregroundStyle(.secondary)
        GroupBox("Cleanup Policy") { Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 16) {
            GridRow { Text("Maximum size").bold(); HStack { TextField("2", value: $manager.maxSizeGB, format: .number).frame(width: 100); Text("GB") } }
            GridRow { Text("Retention").bold(); HStack { TextField("7", value: $manager.retentionDays, format: .number).frame(width: 100); Text("days") } }
            GridRow { Text("Check every").bold(); Picker("", selection: $manager.checkInterval) { Text("15 minutes").tag(900); Text("30 minutes").tag(1800); Text("1 hour").tag(3600); Text("2 hours").tag(7200); Text("6 hours").tag(21600); Text("12 hours").tag(43200); Text("24 hours").tag(86400) }.labelsHidden().frame(width: 180) }
        }.padding(10) }
        GroupBox("Monitored Location") { VStack(alignment: .leading, spacing: 8) { Text("Log directory").bold(); TextField("Log directory", text: $manager.logDirectory); Text("Default: ~/Library/Logs/reolink").font(.caption).foregroundStyle(.secondary) }.padding(10) }
        HStack { Text("Saving settings also reloads the background cleanup service so schedule changes take effect immediately.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Save Settings") { manager.saveConfig() }.buttonStyle(.borderedProminent) }
    }.padding(20) } }
}

struct MaintenanceTab: View {
    @EnvironmentObject var manager: LogGuardManager; @Binding var showHelp: Bool
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 18) {
        Text("Maintenance & Support").font(.title2).bold(); Text("Run manual maintenance, review activity, get help, and keep LogGuard current.").foregroundStyle(.secondary)
        GroupBox("Manual Maintenance") { VStack(alignment: .leading, spacing: 12) {
            HStack { Button("Clean Now") { manager.runCleanup(dryRun: false) }.buttonStyle(.borderedProminent); Text("Immediately apply your configured cleanup policy.").foregroundStyle(.secondary) }
            HStack { Button("Dry Run") { manager.runCleanup(dryRun: true) }; Text("Preview cleanup without deleting any files.").foregroundStyle(.secondary) }
            HStack { Button("Open Log Folder") { manager.openLogFolder() }; Text("Open the monitored Reolink log directory in Finder.").foregroundStyle(.secondary) }
            HStack { Button("Activity Log") { manager.openActivityLog() }; Text("Review LogGuard's cleanup activity and troubleshooting information.").foregroundStyle(.secondary) }
        }.padding(10) }
        GroupBox("Application") { VStack(alignment: .leading, spacing: 12) {
            HStack { Button { manager.updateApp() } label: { if manager.isUpdating { ProgressView().controlSize(.small) } else { Label("Update Now", systemImage: "arrow.triangle.2.circlepath") } }.buttonStyle(.borderedProminent).disabled(manager.isUpdating); Text("Fetch and install the newest LogGuard version from GitHub.").foregroundStyle(.secondary) }
            HStack { Button("Help") { showHelp = true }; Text("Open the built-in usage and troubleshooting guide.").foregroundStyle(.secondary) }
        }.padding(10) }
        GroupBox("Current Activity") { ScrollView { Text(manager.activity).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.frame(height: 110).padding(6) }
    }.padding(20) } }
}

struct AboutTab: View { @Binding var showNodeVyuPreview: Bool; var body: some View { ScrollView { NodeVyuPromotion(showPreview: $showNodeVyuPreview).padding(20) } } }

struct NodeVyuPromotion: View {
    @Binding var showPreview: Bool; private let imageURL = URL(string: "https://nodevyu.com/og-image.png")!
    var body: some View { VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) { Image(systemName: "wave.3.right.circle.fill").font(.system(size: 34)).foregroundStyle(.blue); VStack(alignment: .leading, spacing: 4) { Text("Take monitoring beyond your Mac with NodeVyu").font(.title3).bold(); Text("Know what's online, what's failing, and where attention is needed — from one monitoring platform.").foregroundStyle(.secondary) } }
        HStack(spacing: 18) { Label("Device & service monitoring", systemImage: "network"); Label("Centralized visibility", systemImage: "rectangle.3.group"); Label("Fast issue detection", systemImage: "exclamationmark.triangle") }.font(.caption)
        AsyncImage(url: imageURL) { phase in switch phase { case .success(let image): image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary)).onTapGesture { showPreview = true }.help("Click to enlarge the NodeVyu platform preview"); case .failure: platformPlaceholder; case .empty: ZStack { platformPlaceholder; ProgressView() }; @unknown default: platformPlaceholder } }.frame(maxWidth: .infinity, minHeight: 160, maxHeight: 260)
        HStack { Text("Monitor infrastructure, endpoints and services without waiting for users to tell you something is down.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("See NodeVyu") { if let url = URL(string: "https://nodevyu.com") { NSWorkspace.shared.open(url) } }.buttonStyle(.borderedProminent) }
    }.padding(16).background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12)) }
    private var platformPlaceholder: some View { ZStack { RoundedRectangle(cornerRadius: 8).fill(.quaternary); VStack(spacing: 8) { Image(systemName: "rectangle.3.group").font(.system(size: 34)).foregroundStyle(.secondary); Text("NodeVyu Platform Preview").font(.headline); Text("Visit NodeVyu to see the monitoring platform.").font(.caption).foregroundStyle(.secondary) } }.contentShape(Rectangle()).onTapGesture { if let url = URL(string: "https://nodevyu.com") { NSWorkspace.shared.open(url) } } }
}

struct NodeVyuPreview: View {
    @Environment(\.dismiss) private var dismiss; private let imageURL = URL(string: "https://nodevyu.com/og-image.png")!
    var body: some View { VStack(spacing: 12) { HStack { VStack(alignment: .leading) { Text("NodeVyu Monitoring Platform").font(.title2).bold(); Text("Centralized visibility for devices, services and infrastructure.").foregroundStyle(.secondary) }; Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.cancelAction) }; AsyncImage(url: imageURL) { phase in if case .success(let image) = phase { image.resizable().scaledToFit() } else { ProgressView("Loading NodeVyu preview…") } }.frame(maxWidth: .infinity, maxHeight: .infinity); HStack { Text("See what needs attention before it becomes a bigger problem.").foregroundStyle(.secondary); Spacer(); Button("Visit nodevyu.com") { if let url = URL(string: "https://nodevyu.com") { NSWorkspace.shared.open(url) } }.buttonStyle(.borderedProminent) } }.padding(20).frame(minWidth: 900, minHeight: 620) }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { VStack(spacing: 0) { HStack { Text("Reolink LogGuard Help").font(.title2).bold(); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }.padding(); Divider(); ScrollView { VStack(alignment: .leading, spacing: 16) { helpSection("Dashboard", "Shows current Reolink log usage, protection status, retention policy, quick cleanup actions and recent activity."); helpSection("Configuration", "Set the maximum log size, retention period, cleanup interval and monitored directory. Save Settings reloads the background service."); helpSection("Maintenance", "Run cleanup or a dry run, open logs, view activity, access help and install application updates."); helpSection("Maximum size", "Sets the maximum disk space the monitored directory should consume. If it remains over the limit after retention cleanup, the oldest remaining files are removed until usage falls below the limit."); helpSection("Dry Run", "Shows what cleanup would do without deleting files. Use this to verify your configuration safely."); helpSection("Update Now", "Fetches the newest LogGuard source from GitHub, rebuilds the application, replaces the installed copy and reopens it. Your saved configuration is preserved."); helpSection("Configuration file", "Settings are stored in ~/.local/share/reolink-logguard/config.conf and are preserved when the application is updated."); helpSection("Troubleshooting", "If the dashboard says Service not loaded, open Configuration and click Save Settings to rewrite and reload the background LaunchAgent.") }.padding(20) } }.frame(width: 620, height: 600) }
    private func helpSection(_ title: String, _ text: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) } }
}
