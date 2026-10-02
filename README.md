# mac_reolink_log_rotation

Automatic retention and disk-size protection for Reolink macOS client logs.

This utility was created after the Reolink macOS client accumulated hundreds of gigabytes under `~/Library/Logs/reolink`, which macOS can report as System Data.

## Features

- Deletes logs older than a configurable retention period
- Enforces a configurable maximum log-directory size
- Deletes oldest files first when the size limit is exceeded
- Runs automatically with a macOS LaunchAgent
- Dry-run mode
- No root privileges required for normal user-owned logs
- Safety checks prevent operation on dangerous paths
- Preserves Reolink configuration and recordings outside the configured log directory

## Defaults

- Directory: `~/Library/Logs/reolink`
- Retention: 7 days
- Maximum size: 2 GB
- Check interval: 1 hour

## Install

```bash
git clone https://github.com/Tasumin/mac_reolink_log_rotation.git
cd mac_reolink_log_rotation
chmod +x install.sh uninstall.sh logguard.sh
./install.sh
```

Add the command directory to your shell PATH if necessary:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Commands

```bash
logguard status
logguard dry-run
logguard run
logguard config
logguard logs
```

Run `logguard dry-run` first if you want to preview cleanup without deleting files.

## Configuration

After installation the active configuration is stored at:

`~/.local/share/reolink-logguard/config.conf`

Defaults:

```bash
LOG_DIR="$HOME/Library/Logs/reolink"
RETENTION_DAYS=7
MAX_SIZE_GB=2
CHECK_INTERVAL=3600
LOGGUARD_LOG="$HOME/Library/Logs/reolink-logguard.log"
```

The installer preserves an existing installed configuration during upgrades.

## Cleanup behavior

LogGuard first removes files older than `RETENTION_DAYS`. It then checks the total directory size. If the directory is still larger than `MAX_SIZE_GB`, it removes the oldest remaining files until the projected size is below the limit.

This protects the Mac even when Reolink produces enough logs to exceed the configured maximum before the normal retention period expires.

## Uninstall

```bash
./uninstall.sh
```

Uninstalling LogGuard does not delete Reolink's logs.

## Disclaimer

This is an independent utility and is not affiliated with or endorsed by Reolink.
