import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var manager: LogGuardManager
    @State private var showingHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Reolink LogGuard").font(.largeTitle).bold()
                    Text("Keep runaway Reolink logs from filling your Mac.").foregroundStyle(.secondary)
                }
                Spacer()
                Label(manager.isRunning ? "Automatic cleanup active" : "Service not loaded", systemImage: manager.isRunning ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            }

            GroupBox("Log Storage") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text(manager.formattedSize).font(.title2).bold(); Spacer(); Text("Limit: \(manager.maxSizeGB, specifier: "%.1f") GB") }
                    ProgressView(value: manager.fractionUsed)
                    Text(manager.expandedLogDirectory).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }.padding(6)
            }

            GroupBox("Protection Settings") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow { Text("Maximum size"); HStack { TextField("2", value: $manager.maxSizeGB, format: .number).frame(width: 90); Text("GB") } }
                    GridRow { Text("Retention"); HStack { TextField("7", value: $manager.retentionDays, format: .number).frame(width: 90); Text("days") } }
                    GridRow { Text("Check every"); Picker("", selection: $manager.checkInterval) { Text("15 minutes").tag(900); Text("30 minutes").tag(1800); Text("1 hour").tag(3600); Text("2 hours").tag(7200); Text("6 hours").tag(21600); Text("12 hours").tag(43200); Text("24 hours").tag(86400) }.labelsHidden().frame(width: 160) }
                    GridRow { Text("Log directory"); TextField("Log directory", text: $manager.logDirectory).frame(minWidth: 330) }
                }.padding(6)
            }

            HStack {
                Button("Clean Now") { manager.runCleanup(dryRun: false) }.buttonStyle(.borderedProminent)
                Button("Dry Run") { manager.runCleanup(dryRun: true) }
                Button("Open Log Folder") { manager.openLogFolder() }
                Button("Activity Log") { manager.openActivityLog() }
                Button("Help") { showingHelp = true }
                Spacer()
                Button {
                    manager.updateApp()
                } label: {
                    if manager.isUpdating { ProgressView().controlSize(.small) } else { Label("Update Now", systemImage: "arrow.triangle.2.circlepath") }
                }
                .disabled(manager.isUpdating)
                Button("Save Settings") { manager.saveConfig() }
            }

            GroupBox("Activity") {
                ScrollView { Text(manager.activity).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    .frame(height: 70).padding(4)
            }

            HStack(spacing: 12) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Need monitoring beyond one Mac?").font(.headline)
                    Text("NodeVyu provides centralized monitoring for devices, services and infrastructure.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Learn about NodeVyu") {
                    if let url = URL(string: "https://nodevyu.com") { NSWorkspace.shared.open(url) }
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(24)
        .onAppear { manager.refresh() }
        .sheet(isPresented: $showingHelp) { HelpView() }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reolink LogGuard Help").font(.title2).bold()
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }.padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    helpSection("What LogGuard does", "LogGuard monitors the Reolink log directory and automatically removes old logs before they can consume excessive disk space.")
                    helpSection("Maximum size", "Sets the maximum disk space the monitored directory should consume. If it remains over the limit after retention cleanup, the oldest remaining files are removed until usage falls below the limit.")
                    helpSection("Retention", "Files older than the configured number of days are eligible for automatic removal.")
                    helpSection("Check every", "Controls how often the background LaunchAgent checks the log directory. The default is once per hour.")
                    helpSection("Clean Now", "Runs cleanup immediately using your current settings.")
                    helpSection("Dry Run", "Shows what cleanup would do without deleting files. Use this to verify your configuration safely.")
                    helpSection("Update Now", "Fetches the newest LogGuard source from GitHub, rebuilds the application, replaces the installed copy and reopens it. Your saved configuration is preserved.")
                    helpSection("Configuration", "Settings are stored in ~/.local/share/reolink-logguard/config.conf and are preserved when the application is updated.")
                    helpSection("Troubleshooting", "If the dashboard says Service not loaded, click Save Settings to rewrite and reload the background LaunchAgent. The Activity Log button opens the cleanup log for additional details.")
                    Divider()
                    Text("NodeVyu").font(.headline)
                    Text("For centralized monitoring of devices, services and infrastructure, visit NodeVyu.")
                    Button("Open nodevyu.com") {
                        if let url = URL(string: "https://nodevyu.com") { NSWorkspace.shared.open(url) }
                    }
                }.padding(20)
            }
        }
        .frame(width: 620, height: 600)
    }

    private func helpSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
