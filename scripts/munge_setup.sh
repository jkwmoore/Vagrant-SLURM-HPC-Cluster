#!/bin/bash

set -euo pipefail

ROLE=$1
echo "--- Setting up Munge ---"

sudo dnf install -y munge

if [ "$ROLE" == "storage" ]; then
    echo "Generating new munge key"
    sudo /usr/sbin/create-munge-key -f
    sudo cp /etc/munge/munge.key /etc/slurm/munge.key
else
    echo "Waiting for munge key to be available..."
    while [ ! -f /etc/slurm/munge.key ]; do
        sleep 2
    done
fi

echo "Copying munge key from NFS share"
sudo cp /etc/slurm/munge.key /etc/munge/munge.key

sudo chown munge:munge /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key

sudo systemctl enable --now munge

echo "--- Munge Setup Complete ---"