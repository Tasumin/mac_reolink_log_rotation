# Reolink LogGuard Help

Reolink LogGuard protects your Mac from runaway Reolink client log files consuming excessive disk space.

## Dashboard

**Log Storage** shows the current size of the configured Reolink log directory and compares it with your configured maximum size.

**Automatic cleanup active** means the macOS LaunchAgent is loaded and LogGuard will check the directory automatically at the configured interval.

## Protection Settings

- **Maximum size** — Maximum amount of disk space the Reolink log directory should consume. If the directory remains larger than this after retention cleanup, LogGuard removes the oldest files until it is below the limit.
- **Retention** — Log files older than this number of days are eligible for removal.
- **Check every** — How frequently the background service checks the log directory.
- **Log directory** — Directory LogGuard monitors. The default is `~/Library/Logs/reolink`.
- **Save Settings** — Saves your settings and reloads the background cleanup service.

## Actions

- **Clean Now** — Runs cleanup immediately.
- **Dry Run** — Shows what LogGuard would remove without deleting files.
- **Open Log Folder** — Opens the monitored directory in Finder.
- **Activity Log** — Opens the LogGuard activity log.
- **Update Now** — Downloads the latest version from GitHub, rebuilds LogGuard, replaces the installed application and reopens it. Your configuration is preserved.

## Default Settings

- Log directory: `~/Library/Logs/reolink`
- Retention: 7 days
- Maximum size: 2 GB
- Check interval: 1 hour

## Configuration

Your active configuration is stored at:

`~/.local/share/reolink-logguard/config.conf`

Application updates do not replace this file.

## Troubleshooting

If **Service not loaded** appears, save your settings to reload the LaunchAgent. You can also verify it from Terminal with:

`~/.local/bin/logguard status`

If the app cannot update itself, use the recovery update from the cloned repository:

```bash
cd ~/mac_reolink_log_rotation
git fetch origin
git reset --hard origin/main
chmod +x *.sh
./install.sh
```

## About NodeVyu

Need monitoring beyond one Mac? NodeVyu is a monitoring platform for keeping visibility on devices, services and infrastructure from one place.

Visit **https://nodevyu.com** to learn more.

## Disclaimer

Reolink LogGuard is an independent open-source utility and is not affiliated with or endorsed by Reolink.
