# Reolink LogGuard for macOS

A native macOS utility that prevents runaway Reolink client logs from consuming your SSD. It was created after a Reolink installation accumulated more than 350 GB under `~/Library/Logs/reolink`, which macOS reported as System Data.

## Native app

The installer builds **Reolink LogGuard.app** with SwiftUI and installs it in `/Applications`, making it available from Applications, Launchpad and Spotlight.

The dashboard provides:

- Current Reolink log-directory usage
- Configured maximum size
- Automatic-cleanup service status
- Configurable retention days
- Configurable maximum size
- Configurable cleanup interval
- Configurable log directory
- Clean Now
- Dry Run
- Open Log Folder
- Activity Log

## Default protection

- Log directory: `~/Library/Logs/reolink`
- Retention: 7 days
- Maximum size: 2 GB
- Check interval: 1 hour

Cleanup runs once when the LaunchAgent loads and then at the configured interval. Files older than the retention period are removed first. If the directory still exceeds its size limit, the oldest remaining files are removed until it is below the limit.

## Requirements

- macOS 13 or later
- Apple Command Line Developer Tools / Swift compiler (`xcode-select --install` if needed)

## Install

```bash
git clone https://github.com/Tasumin/mac_reolink_log_rotation.git
cd mac_reolink_log_rotation
chmod +x *.sh
./install.sh
```

The installer sets up the background LaunchAgent, builds the native SwiftUI application, installs it as `/Applications/Reolink LogGuard.app`, and opens it.

If `/Applications` requires elevated permissions, the installer will request your administrator password for that copy step.

## Updating an existing installation

```bash
cd mac_reolink_log_rotation
git pull
./install.sh
```

Your installed `config.conf` is preserved.

## CLI

The UI is the primary interface, but the command-line helper remains available:

```bash
~/.local/bin/logguard status
~/.local/bin/logguard dry-run
~/.local/bin/logguard run
~/.local/bin/logguard config
~/.local/bin/logguard logs
```

## Active configuration

`~/.local/share/reolink-logguard/config.conf`

```bash
LOG_DIR="$HOME/Library/Logs/reolink"
RETENTION_DAYS=7
MAX_SIZE_GB=2
CHECK_INTERVAL=3600
LOGGUARD_LOG="$HOME/Library/Logs/reolink-logguard.log"
```

Saving settings from the app updates this configuration and reloads the LaunchAgent so interval changes take effect immediately.

## Uninstall

```bash
./uninstall.sh
```

This removes the application, LaunchAgent and LogGuard support files. Existing Reolink logs are intentionally left alone.

## Disclaimer

This is an independent open-source utility and is not affiliated with or endorsed by Reolink.
