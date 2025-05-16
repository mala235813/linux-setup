#!/bin/bash
# Setup script for EndeavourOS with Btrfs, Timeshift, autosnap, and GRUB integration
# Intended to be used after a fresh install

set -euo pipefail

### DRY RUN, VIRTUALIZATION, AND ENVIRONMENT OPTIONS
DRYRUN=false
VMWARE=false
FORCE=false

for arg in "$@"; do
  case $arg in
  --dry-run)
    DRYRUN=true
    echo "🔎 Running in dry-run mode. No changes will be made."
    ;;
  --virt=vmware)
    VMWARE=true
    echo "🖥️ VMware guest configuration will be applied."
    ;;
  --help | -h)
    echo "Usage: $0 [OPTIONS]"
    echo "\nOptions:"
    echo "  --dry-run       Show the commands that would be run without executing them"
    echo "  --virt=vmware   Enable open-vm-tools and related services"
    echo "  --force         Bypass UEFI detection (for BIOS setups)"
    echo "  --help, -h      Show this help message"
    exit 0
    ;;
  --force)
    FORCE=true
    ;;
  esac
  shift || true
done

### UEFI Detection
if [ ! -d /sys/firmware/efi ]; then
  if ! $FORCE; then
    echo "❌ BIOS mode detected. This script assumes UEFI for proper GRUB snapshot integration."
    echo "Use --force to override."
    exit 1
  else
    echo "⚠️ BIOS mode detected. Proceeding due to --force."
  fi
else
  echo "✅ UEFI mode detected."
fi

run() {
  if $DRYRUN; then
    echo "+ $*"
  else
    eval "$*"
  fi
}

### Variables
DEVICE="/dev/sda2" # Adjust to your root Btrfs partition
timeshift_cfg="/etc/timeshift/timeshift.json"

### 1. Install core tools
run "sudo pacman -Syu --noconfirm"
run "sudo pacman -S --noconfirm timeshift inotify-tools grub-btrfs kitty"
if $VMWARE; then
  run "sudo pacman -S --noconfirm open-vm-tools"
  run "sudo systemctl enable --now vmtoolsd.service"
fi

### 2. Configure Timeshift for Btrfs
run "sudo mkdir -p /etc/timeshift"
run "sudo tee \"$timeshift_cfg\" > /dev/null <<EOF
{
  \"snapshot_device\" : \"$DEVICE\",
  \"snapshot_type\" : \"BTRFS\",
  \"backup_device\" : \"$DEVICE\",
  \"backup_device_uuid\" : \"$(blkid -s UUID -o value $DEVICE)\",
  \"parent_device_uuid\" : \"\",
  \"do_first_run\" : \"false\",
  \"btrfs_mode\" : \"true\",
  \"include_btrfs_home_for_backup\" : \"false\",
  \"include_btrfs_home_for_restore\" : \"false\",
  \"stop_cron_emails\" : \"true\",
  \"schedule_monthly\" : \"false\",
  \"schedule_weekly\" : \"false\",
  \"schedule_daily\" : \"false\",
  \"schedule_hourly\" : \"false\",
  \"schedule_boot\" : \"false\",
  \"count_monthly\" : \"2\",
  \"count_weekly\" : \"3\",
  \"count_daily\" : \"5\",
  \"count_hourly\" : \"6\",
  \"count_boot\" : \"5\",
  \"date_format\" : \"%Y-%m-%d %H:%M:%S\",
  \"exclude\" : [],
  \"exclude-apps\" : []
}
EOF"

### 3. Mount top-level Btrfs volume for GRUB snapshot visibility
run "sudo mkdir -p /timeshift-btrfs"
if ! grep -q "/timeshift-btrfs" /etc/fstab; then
  run "echo \"$DEVICE  /timeshift-btrfs  btrfs  subvolid=5,defaults,noatime  0 0\" | sudo tee -a /etc/fstab"
fi
run "sudo mount /timeshift-btrfs"

### 4. Setup GRUB Btrfs Watcher with inotify
run "sudo tee /usr/local/bin/watch-grub-btrfs.sh > /dev/null <<'EOF'
#!/bin/bash
WATCHDIR=\"/timeshift-btrfs/timeshift-btrfs/snapshots\"
/usr/bin/inotifywait -m -e create -e moved_to --format '%f' \"\$WATCHDIR\" | while read SNAPSHOT; do
  logger \"grub-btrfs triggered by snapshot: \$SNAPSHOT\"
  /etc/grub.d/41_snapshots-btrfs
done
EOF"

run "sudo chmod +x /usr/local/bin/watch-grub-btrfs.sh"

run "sudo tee /etc/systemd/system/watch-grub-btrfs.service > /dev/null <<EOF
[Unit]
Description=Watch Timeshift Snapshots and Update GRUB
After=local-fs.target
ConditionPathExists=/timeshift-btrfs/timeshift-btrfs/snapshots

[Service]
ExecStart=/usr/local/bin/watch-grub-btrfs.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF"

run "sudo systemctl daemon-reexec"
run "sudo systemctl daemon-reload"
run "sudo systemctl enable --now watch-grub-btrfs.service"

### 5. Create pacman hook for autosnap
run "sudo mkdir -p /etc/pacman.d/hooks"
run "sudo tee /etc/pacman.d/hooks/timeshift-autosnap.hook > /dev/null <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Create Timeshift snapshot before pacman transaction...
When = PreTransaction
Exec = /usr/bin/timeshift-autosnap
EOF"

# Create the helper script
run "sudo tee /usr/bin/timeshift-autosnap > /dev/null <<'EOF'
#!/bin/bash
comment=\"{timeshift-autosnap} {created before upgrade}\"
timeshift --create --comments \"$comment\" --scripted
EOF"

run "sudo chmod +x /usr/bin/timeshift-autosnap"

### 6. yay integration (ensure pacman hooks run)
run "sudo mkdir -p /etc/yay"
run "sudo tee /etc/yay/config.json > /dev/null <<EOF
{
  \"sudoPacman\": true
}
EOF"

### Done!
echo "✅ System is now configured with Btrfs + Timeshift autosnap + GRUB snapshot boot entries."
if $DRYRUN; then
  echo "🧪 Dry-run complete. No changes were made."
fi
