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

    init() {
        bootstrapIfNeeded()
        loadConfig()
        refresh()
    }

    var expandedLogDirectory: String {
        if logDirectory.hasPrefix("~/") { return NSHomeDirectory() + String(logDirectory.dropFirst()) }
        return logDirectory
    }
    var formattedSize: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
    var maxBytes: Double { maxSizeGB * 1024 * 1024 * 1024 }
    var fractionUsed: Double { guard maxBytes > 0 else { return 0 }; return min(Double(sizeBytes) / maxBytes, 1) }

    private func bootstrapIfNeeded() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: installDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: NSHomeDirectory() + "/Library/LaunchAgents", withIntermediateDirectories: true)

            if let bundledScript = Bundle.main.url(forResource: "logguard", withExtension: "sh") {
                // Always refresh the engine from the installed app, while preserving user config.
                if fm.fileExists(atPath: scriptPath) { try fm.removeItem(atPath: scriptPath) }
                try fm.copyItem(at: bundledScript, to: URL(fileURLWithPath: scriptPath))
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            }
            if !fm.fileExists(atPath: configPath), let bundledConfig = Bundle.main.url(forResource: "config", withExtension: "conf") {
                try fm.copyItem(at: bundledConfig, to: URL(fileURLWithPath: configPath))
            }
            // Read interval directly for bootstrap before normal config loading.
            var interval = 3600
            if let text = try? String(contentsOfFile: configPath, encoding: .utf8) {
                for line in text.split(separator: "\n") where line.hasPrefix("CHECK_INTERVAL=") {
                    interval = Int(line.split(separator: "=", maxSplits: 1).last ?? "3600") ?? 3600
                }
            }
            writeLaunchAgent(interval: interval)
        } catch {
            activity = "First-run setup failed: \(error.localizedDescription)"
        }
    }

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
            writeLaunchAgent(interval: checkInterval)
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

    // Public installs update from the newest DMG attached to the latest GitHub Release.
    // No source checkout, Git installation, or build tools are required on the user's Mac.
    func updateApp() {
        guard !isUpdating else { return }
        isUpdating = true
        activity = "Checking the latest GitHub release…"

        let helperPath = "/tmp/reolink-logguard-release-update-\(getpid()).sh"
        let updateLog = NSHomeDirectory() + "/Library/Logs/reolink-logguard-update.log"
        let helper = """
        #!/bin/zsh
        set -u
        exec >> \(shellQuote(updateLog)) 2>&1
        echo "=== LogGuard release update started $(date) ==="
        API="https://api.github.com/repos/Tasumin/mac_reolink_log_rotation/releases/latest"
        WORK="$(/usr/bin/mktemp -d /tmp/reolink-logguard-update.XXXXXX)" || exit 1
        JSON="$WORK/release.json"
        DMG="$WORK/update.dmg"
        MOUNT="$WORK/mount"
        /bin/mkdir -p "$MOUNT"

        /usr/bin/curl -fL --retry 2 -H 'Accept: application/vnd.github+json' "$API" -o "$JSON" || exit 20
        URL=$(/usr/bin/python3 - "$JSON" <<'PY'
        import json,sys
        d=json.load(open(sys.argv[1]))
        assets=d.get('assets',[])
        dmgs=[a for a in assets if a.get('name','').lower().endswith('.dmg')]
        print(dmgs[0].get('browser_download_url','') if dmgs else '')
        PY
        )
        [[ -n "$URL" ]] || { echo "No DMG asset found on latest GitHub release"; exit 21; }
        echo "Downloading: $URL"
        /usr/bin/curl -fL --retry 2 "$URL" -o "$DMG" || exit 22
        /usr/bin/hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT" || exit 23
        NEWAPP="$MOUNT/Reolink LogGuard.app"
        [[ -d "$NEWAPP" ]] || { echo "DMG does not contain Reolink LogGuard.app"; /usr/bin/hdiutil detach "$MOUNT"; exit 24; }
        /usr/bin/codesign --verify --deep --strict "$NEWAPP" || { echo "Downloaded app failed signature verification"; /usr/bin/hdiutil detach "$MOUNT"; exit 25; }

        sleep 2
        DEST="/Applications/Reolink LogGuard.app"
        BACKUP="$WORK/Reolink LogGuard.old.app"
        [[ -d "$DEST" ]] && /bin/mv "$DEST" "$BACKUP"
        if /bin/cp -R "$NEWAPP" "$DEST"; then
          /usr/bin/hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
          /usr/bin/open -n "$DEST"
          sleep 2
          /bin/rm -rf "$BACKUP" "$WORK" "$0"
          exit 0
        fi
        echo "Install failed; restoring previous app"
        /bin/rm -rf "$DEST"
        [[ -d "$BACKUP" ]] && /bin/mv "$BACKUP" "$DEST"
        /usr/bin/hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
        exit 26
        """

        do {
            try helper.write(toFile: helperPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperPath)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [helperPath]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            activity = "Installing the latest release… LogGuard will close and reopen automatically."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { NSApplication.shared.terminate(nil) }
        } catch {
            isUpdating = false
            activity = "Could not start update: \(error.localizedDescription)"
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
        return v.replacingOccurrences(of: "$HOME", with: NSHomeDirectory())
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
    private func writeLaunchAgent(interval: Int) {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>Label</key><string>com.reolink.logguard</string>
        <key>ProgramArguments</key><array><string>\(scriptPath)</string></array>
        <key>StartInterval</key><integer>\(interval)</integer>
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
