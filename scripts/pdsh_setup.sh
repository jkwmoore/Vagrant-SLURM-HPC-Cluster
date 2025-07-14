#!/bin/bash

set -euo pipefail

NUM_COMPUTE_NODES=$1

echo "--- Installing pdsh packages ---"
sudo dnf install -y pdsh pdsh-mod-genders pdsh-rcmd-ssh

echo "--- Setting up pdsh genders file ---"

sudo tee /etc/genders > /dev/null <<EOF
login1 login,all
storage1 storage,all
slurmctld[1-2] slurmctld,all
slurmdbd1 slurmdbd,all
compute[1-${NUM_COMPUTE_NODES}] compute,all
EOF
echo "--- pdsh genders file setup complete ---"

# Define config file and content
PDSH_CONFIG="/etc/profile.d/pdsh_ssh.sh"
PDSH_EXPORT="export PDSH_RCMD_TYPE=ssh"

# Write config and set permissions
echo "# Set PDSH_RCMD_TYPE for parallel commands" | sudo tee "$PDSH_CONFIG" >/dev/null
echo "$PDSH_EXPORT" | sudo tee -a "$PDSH_CONFIG" >/dev/null
sudo chmod +x "$PDSH_CONFIG"

echo "PDSH configured for SSH. Relog for effect. Ensure SSH keys are set up."