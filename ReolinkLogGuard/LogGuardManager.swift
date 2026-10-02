import Foundation
import AppKit

final class LogGuardManager: ObservableObject {
    @Published var sizeBytes: Int64 = 0
    @Published var maxSizeGB: Double = 2
    @Published var retentionDays: Int = 7
    @Published var checkInterval: Int = 3600
    @Published var logDirectory: String = "~/Library/Logs/reolink"
    @Published var activity = "Ready"
    @Published var isRunning = false
    @Published var isUpdating = false

    private var installDir: String { NSHomeDirectory() + "/.local/share/reolink-logguard" }
    private var configPath: String { installDir + "/config.conf" }
    private var scriptPath: String { installDir + "/logguard.sh" }
    private var plistPath: String { NSHomeDirectory() + "/Library/LaunchAgents/com.reolink.logguard.plist" }
    private var repoDir: String { NSHomeDirectory() + "/mac_reolink_log_rotation" }

    init() { loadConfig(); refresh() }

    var expandedLogDirectory: String {
        if logDirectory.hasPrefix("~/") { return NSHomeDirectory() + String(logDirectory.dropFirst()) }
        return logDirectory
    }

    var formattedSize: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
    var maxBytes: Double { maxSizeGB * 1024 * 1024 * 1024 }
    var fractionUsed: Double { guard maxBytes > 0 else { return 0 }; return min(Double(sizeBytes) / maxBytes, 1) }

    func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let bytes = self.directorySize(self.expandedLogDirectory)
            let loaded = self.launchAgentLoaded()
            DispatchQueue.main.async { self.sizeBytes = bytes; self.isRunning = loaded }
        }
    }

    func loadConfig() {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return }
        for raw in text.split(separator: "\n") {
            let line = String(raw)
            if line.hasPrefix("LOG_DIR=") { logDirectory = value(line) }
            if line.hasPrefix("RETENTION_DAYS=") { retentionDays = Int(value(line)) ?? 7 }
            if line.hasPrefix("MAX_SIZE_GB=") { maxSizeGB = Double(value(line)) ?? 2 }
            if line.hasPrefix("CHECK_INTERVAL=") { checkInterval = Int(value(line)) ?? 3600 }
        }
    }

    func saveConfig() {
        let dir = logDirectory.replacingOccurrences(of: NSHomeDirectory(), with: "$HOME")
        let text = """
        # Reolink Log Rotation Configuration
        LOG_DIR=\"\(dir)\"
        RETENTION_DAYS=\(retentionDays)
        MAX_SIZE_GB=\(maxSizeGB)
        CHECK_INTERVAL=\(checkInterval)
        LOGGUARD_LOG=\"$HOME/Library/Logs/reolink-logguard.log\"
        """
        do {
            try FileManager.default.createDirectory(atPath: installDir, withIntermediateDirectories: true)
            try text.write(toFile: configPath, atomically: true, encoding: .utf8)
            rebuildLaunchAgent()
            activity = "Settings saved and background service restarted."
            refresh()
        } catch { activity = "Could not save settings: \(error.localizedDescription)" }
    }

    func runCleanup(dryRun: Bool) {
        guard FileManager.default.fileExists(atPath: scriptPath) else { activity = "Cleanup script is not installed."; return }
        activity = dryRun ? "Running dry run…" : "Cleaning logs…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.run("/bin/zsh", [self.scriptPath] + (dryRun ? ["--dry-run"] : []))
            DispatchQueue.main.async { self.activity = result.isEmpty ? "Cleanup finished." : result; self.refresh() }
        }
    }

    func updateApp() {
        guard !isUpdating else { return }
        guard FileManager.default.fileExists(atPath: repoDir + "/.git") else {
            activity = "Update source was not found at ~/mac_reolink_log_rotation. Reinstall from GitHub first."
            return
        }
        isUpdating = true
        activity = "Checking GitHub and installing the latest version…"
        DispatchQueue.global(qos: .userInitiated).async {
            let updater = """
            set -e
            cd \(self.shellQuote(self.repoDir))
            /usr/bin/git fetch origin
            /usr/bin/git reset --hard origin/main
            /bin/chmod +x ./*.sh
            nohup /bin/zsh ./install.sh > \"$HOME/Library/Logs/reolink-logguard-update.log\" 2>&1 &
            """
            let result = self.run("/bin/zsh", ["-c", updater])
            DispatchQueue.main.async {
                self.activity = result.isEmpty ? "Update started. LogGuard will close and reopen when installation completes." : result
                self.isUpdating = false
            }
        }
    }

    func openLogFolder() { NSWorkspace.shared.open(URL(fileURLWithPath: expandedLogDirectory)) }
    func openActivityLog() {
        let path = NSHomeDirectory() + "/Library/Logs/reolink-logguard.log"
        if !FileManager.default.fileExists(atPath: path) { FileManager.default.createFile(atPath: path, contents: nil) }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func value(_ line: String) -> String {
        var v = String(line.split(separator: "=", maxSplits: 1).last ?? "")
        v = v.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        v = v.replacingOccurrences(of: "$HOME", with: NSHomeDirectory())
        return v
    }

    private func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func directorySize(_ path: String) -> Int64 {
        let output = run("/usr/bin/du", ["-sk", path])
        guard let first = output.split(whereSeparator: { $0 == "\t" || $0 == " " }).first, let kb = Int64(first) else { return 0 }
        return kb * 1024
    }

    private func launchAgentLoaded() -> Bool {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl"); p.arguments = ["print", "gui/\(getuid())/com.reolink.logguard"]
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus == 0 } catch { return false }
    }

    private func rebuildLaunchAgent() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>Label</key><string>com.reolink.logguard</string>
        <key>ProgramArguments</key><array><string>\(scriptPath)</string></array>
        <key>StartInterval</key><integer>\(checkInterval)</integer>
        <key>RunAtLoad</key><true/>
        </dict></plist>
        """
        try? xml.write(toFile: plistPath, atomically: true, encoding: .utf8)
        _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())", plistPath])
        _ = run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistPath])
    }

    @discardableResult private func run(_ executable: String, _ args: [String]) -> String {
        let p = Process(); let pipe = Pipe(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = args; p.standardOutput = pipe; p.standardError = pipe
        do { try p.run(); p.waitUntilExit(); return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" } catch { return error.localizedDescription }
    }
}
