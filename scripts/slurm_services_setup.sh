#!/bin/bash

set -euo pipefail

NODE_TYPE=$1
echo "--- Starting SLURM services for ${NODE_TYPE} ---"

# Wait for slurm.conf to exist
while [ ! -f /etc/slurm/slurm.conf ]; do
    sleep 5
done

case "$NODE_TYPE" in
    controller)
        sudo systemctl enable --now slurmctld
        ;;
    dbd)
        sudo systemctl enable --now slurmdbd
        ;;
    compute)
        sudo systemctl enable --now slurmd
        ;;
    *)
        echo "Invalid node type for service setup"
        ;;
esac

echo "--- SLURM Services Started ---"