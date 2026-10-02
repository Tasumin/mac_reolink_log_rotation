# Reolink LogGuard for macOS

[![Latest Release](https://img.shields.io/github/v/release/Tasumin/mac_reolink_log_rotation?display_name=tag&sort=semver)](https://github.com/Tasumin/mac_reolink_log_rotation/releases/latest)
[![Latest Release Downloads](https://img.shields.io/github/downloads/Tasumin/mac_reolink_log_rotation/latest/total?label=latest%20release%20downloads)](https://github.com/Tasumin/mac_reolink_log_rotation/releases/latest)
[![Total Downloads](https://img.shields.io/github/downloads/Tasumin/mac_reolink_log_rotation/total?label=total%20downloads)](https://github.com/Tasumin/mac_reolink_log_rotation/releases)

A native macOS utility that prevents runaway Reolink client logs from consuming your SSD. It was created after a Reolink installation accumulated more than 350 GB under `~/Library/Logs/reolink`, which macOS reported as System Data.

## Native app

**Reolink LogGuard.app** is distributed as a standalone macOS DMG. Normal users do not need Git, Terminal, or the source repository. On first launch, LogGuard automatically installs its per-user background cleanup service.

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
- Update Now

## Default protection

- Log directory: `~/Library/Logs/reolink`
- Retention: 7 days
- Maximum size: 2 GB
- Check interval: 1 hour

Cleanup runs once when the LaunchAgent loads and then at the configured interval. Files older than the retention period are removed first. If the directory still exceeds its size limit, the oldest remaining files are removed until it is below the limit.

## Requirements

- macOS 13 or later
- Apple Silicon Mac for the current release

## Installation

1. Download the latest `Reolink-LogGuard-*.dmg` from [GitHub Releases](https://github.com/Tasumin/mac_reolink_log_rotation/releases/latest).
2. Open the DMG.
3. Drag **Reolink LogGuard** into **Applications**.
4. Launch Reolink LogGuard from Applications, Launchpad, or Spotlight.
5. LogGuard automatically configures its background cleanup service.

No source checkout or separate installer is required.

## Updating Reolink LogGuard

After installation, the normal update method is directly from the app:

1. Open **Reolink LogGuard**.
2. Select **Maintenance**.
3. Click **Update Now**.
4. LogGuard retrieves the latest GitHub Release DMG, installs the new application, and reopens itself.

Your LogGuard configuration is stored outside the application at:

```text
~/.local/share/reolink-logguard/config.conf
```

Settings such as maximum log size, retention period, log directory, and cleanup interval are preserved during updates.

### Source / development installation

Developers who want to build LogGuard from source can clone the repository:

```bash
cd ~
git clone https://github.com/Tasumin/mac_reolink_log_rotation.git
cd mac_reolink_log_rotation
chmod +x *.sh
./install.sh
```

### Manual recovery update

For source-based installations, or if you are developing/testing LogGuard locally:

```bash
cd ~/mac_reolink_log_rotation
git fetch origin
git reset --hard origin/main
chmod +x *.sh
./install.sh
```

Application settings are unaffected because they are stored outside the repository.

### Verify the update

The **Maintenance** tab displays the currently installed application version and build number.

To verify the background cleanup service from Terminal:

```bash
~/.local/bin/logguard status
```

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

## Download statistics

GitHub tracks downloads for release assets. The badges at the top of this README show downloads for the latest release and cumulative downloads across all published release assets.

Release-specific download counts are also available from the [GitHub Releases](https://github.com/Tasumin/mac_reolink_log_rotation/releases) API and release metadata.

## Uninstall

Source installations can use:

```bash
./uninstall.sh
```

For standalone installations, quit LogGuard and remove **Reolink LogGuard.app** from Applications. LogGuard support files live under `~/.local/share/reolink-logguard` and its LaunchAgent under `~/Library/LaunchAgents`.

## Disclaimer

This is an independent open-source utility and is not affiliated with or endorsed by Reolink.
