#!/bin/bash
set -euo pipefail

# Only run if not already enabled
if ! grep -q 'systemd.unified_cgroup_hierarchy=1' /etc/default/grub; then
  echo "[INFO] Enabling cgroup v2 via GRUB..."
  sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1 /' /etc/default/grub
  grub2-mkconfig -o /boot/grub2/grub.cfg
  touch /var/run/vagrant-reboot-required
else
  echo "[INFO] cgroup v2 already enabled"
fi