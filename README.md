# ubuntu-care.sh

**ubuntu-care.sh** is a Bash script to keep Ubuntu systems tidy, updated, and happy. It automates common maintenance tasks, including package upgrades, cache cleanup, firmware checks, log management, SSD TRIM, and optional Snap/Flatpak housekeeping.

## Features

- Updates and upgrades APT packages
- Cleans up unused dependencies and package caches
- Refreshes firmware metadata and checks for updates (fwupd)
- Vacuums systemd journal logs (size and age limits)
- Runs SSD TRIM on all mounted filesystems
- Optionally refreshes and prunes Snap/Flatpak packages (aggressive mode)
- Performs quick SMART health checks on disks
- Summarizes disk usage and notifies if a reboot is required
- Logs all actions to `/var/log/ubuntu-care/YYYY-MM-DD.log`

## Usage

Run as root (with `sudo`):

```sh
sudo ./ubuntu-care.sh              # run with safe defaults
sudo ./ubuntu-care.sh --dry-run    # print what would happen, no changes
sudo ./ubuntu-care.sh --aggressive # add Snap/Flatpak cleanup
```

## Arguments

- `--dry-run` Print commands without executing them
- `--aggressive` Enable Snap/Flatpak cleanup

## Requirements

- Ubuntu system
- Root privileges
- Optional: `fwupdmgr`, `fstrim`, `snap`, `flatpak`, `smartctl` (script will suggest install commands if missing)

## Logging

All output is logged to `/var/log/ubuntu-care/YYYY-MM-DD.log`.

## Notes

- The script is safe by default and avoids destructive operations.
- Aggressive mode adds Snap/Flatpak cleanup.
- For firmware updates and SMART checks, required tools must be installed.

## License

MIT License (see script header for details)
