#!/usr/bin/env bash
# ubuntu-care.sh — Keep Ubuntu tidy, updated, and happy.
# Usage:
#   sudo ./ubuntu-care.sh              # run with safe defaults
#   sudo ./ubuntu-care.sh --dry-run    # print what would happen
#   sudo ./ubuntu-care.sh --aggressive # add snap/flatpak cleanup

set -euo pipefail
IFS=$'\n\t'

LOG_DIR="/var/log/ubuntu-care"
LOG_FILE="${LOG_DIR}/$(date +%F).log"
DRY_RUN=0
MODE="normal"   # normal|aggressive

# ---------- helpers ----------
say() { echo -e "[*] $*"; }
run() { if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN: $*"; else eval "$@"; fi }
ensure_root() { [[ $EUID -eq 0 ]] || { echo "Please run as root (sudo)."; exit 1; } }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- parse args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift;;
    --aggressive) MODE="aggressive"; shift;;
    *) echo "Unknown arg: $1"; exit 2;;
  esac
done

# ---------- setup logging ----------
ensure_root
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

say "Ubuntu Care starting at $(date). Mode=${MODE}, DryRun=${DRY_RUN}"

# ---------- 1) apt: refresh + security + cleanup ----------
say "Updating apt metadata & upgrading packages…"
run "apt-get update -y"
# regular upgrades; leave distro-release to user discretion
run "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y"

say "Cleaning apt caches and unused deps…"
# autoremove removes orphaned deps; autoclean prunes old package files
run "apt-get autoremove -y --purge"
run "apt-get autoclean -y"
# avoid 'apt-get clean' unless you need the space; it nukes the whole cache

# ---------- 2) firmware (fwupd) ----------
if have fwupdmgr; then
  say "Refreshing LVFS metadata & checking firmware updates…"
  run "fwupdmgr refresh --force"
  run "fwupdmgr get-updates || true"
  # Uncomment to apply automatically (may require reboot on some devices):
  # run "fwupdmgr update -y"
else
  say "fwupdmgr not found; install with: apt-get install -y fwupd"
fi

# ---------- 3) journal/log size control ----------
# keep archived journal under 500MB OR last 14 days, whichever hits first
say "Vacuuming systemd-journald archives (<=500M or <=14d)…"
run "journalctl --vacuum-size=500M"
run "journalctl --vacuum-time=14d"
# Show current usage
run "journalctl --disk-usage"

# ---------- 4) SSD/TRIM ----------
# fstrim is typically scheduled weekly via systemd timer; run once now too.
if have fstrim; then
  say "Running fstrim (discard unused blocks on mounted filesystems)…"
  run "fstrim -Av"
  say "fstrim.timer status (should be active weekly):"
  run "systemctl status fstrim.timer || true"
else
  say "fstrim not found; install with: apt-get install -y util-linux"
fi

# ---------- 5) optional: snap/flatpak housekeeping ----------
if [[ "$MODE" == "aggressive" ]]; then
  # Snap: refresh metadata; remove disabled old revisions (keeps active)
  if have snap; then
    say "Refreshing snaps and pruning disabled old revisions…"
    run "snap refresh"
    # Remove disabled revisions only:
    run "snap list --all | awk '/disabled|désactivé/{print \$1, \$3}' | while read name rev; do snap remove \"\$name\" --revision=\"\$rev\"; done"
  fi

  # Flatpak: update + remove unused runtimes/extensions
  if have flatpak; then
    say "Updating Flatpaks and removing unused runtimes…"
    run "flatpak update -y"
    run "flatpak uninstall --unused -y"
    # Optional integrity pass:
    run "flatpak repair -y || true"
  fi
fi

# ---------- 6) SMART quick health (if disks & smartctl available) ----------
if have smartctl; then
  say "SMART quick health checks (non-destructive)…"
  for DEV in /dev/sd? /dev/nvme?n1; do
    [[ -e "$DEV" ]] || continue
    say "Device: $DEV"
    run "smartctl -H \"$DEV\" || true"
  done
else
  say "smartctl not found; install with: apt-get install -y smartmontools"
fi

# ---------- 7) show space & reboot-needed ----------
say "Disk usage summary:"
run "df -hT /"
if [[ -f /var/run/reboot-required ]]; then
  say "Reboot recommended (kernel/libc/firmware updates)."
fi

say "All done at $(date). Log saved to $LOG_FILE"
