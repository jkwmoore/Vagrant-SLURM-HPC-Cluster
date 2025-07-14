#!/bin/bash

set -euo pipefail

echo "--- Setting up NFS Client ---"

sudo dnf install -y nfs-utils

sudo mkdir -p /home /opt/software /etc/slurm /var/spool/slurmctld /opt/site

cat <<EOF | sudo tee -a /etc/fstab
storage1:/export/home         /home           nfs rw,hard,intr,nosuid,nodev,rsize=1048576,wsize=1048576,timeo=600,retrans=2 0 0
storage1:/export/software     /opt/software   nfs rw,hard,intr,nosuid,nodev,rsize=1048576,wsize=1048576,timeo=600,retrans=2 0 0
storage1:/export/slurm_config /etc/slurm      nfs rw,hard,intr,nosuid,nodev,rsize=1048576,wsize=1048576,timeo=600,retrans=2 0 0
storage1:/export/site         /opt/site       nfs rw,hard,intr,nosuid,nodev,rsize=1048576,wsize=1048576,timeo=600,retrans=2 0 0
EOF

# Only mount slurmctld state on controller nodes
if [[ $(hostname) == slurmctld* ]]; then
    sudo mkdir -p /var/spool/slurmctld
    echo "storage1:/export/slurmctld_state /var/spool/slurmctld nfs defaults 0 0" | sudo tee -a /etc/fstab
fi

# A small delay to ensure NFS server is ready
sleep 10
sudo systemctl daemon-reload
sudo mount -a

echo "--- NFS Client Setup Complete ---"