import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: LogGuardManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
                Spacer()
                Button("Save Settings") { manager.saveConfig() }
            }

            GroupBox("Activity") {
                ScrollView { Text(manager.activity).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    .frame(height: 80).padding(4)
            }
        }
        .padding(24)
        .onAppear { manager.refresh() }
    }
}
