#!/bin/bash

set -euo pipefail

NODE_TYPE=$1
echo "--- Installing SLURM packages for ${NODE_TYPE} ---"

# Create the Slurm user for Slurm Daemons
sudo useradd -m slurm
sudo chown -R slurm:slurm /var/spool/slurmctld /etc/slurm

echo "--- SLURM Configuration Complete ---"

case "$NODE_TYPE" in
    controller)
        sudo dnf install -y slurm slurm-devel slurm-slurmctld
        ;;
    dbd)
        sudo dnf install -y slurm slurm-slurmdbd
        ;;
    compute)
        sudo dnf install -y slurm slurm-slurmd #slurm-pam_slurm
        sudo slurmd -C | head -n1 >> /etc/slurm/slurm.conf
        sudo scontrol reconfigure
        ;;
    client)
        sudo dnf install -y slurm 
        ;;
    *)
        echo "Invalid node type"
        exit 1
        ;;
esac

# Create the log dir for Slurm Daemons
sudo mkdir /var/log/slurm
sudo chown slurm /var/log/slurm
sudo chmod 700 /var/log/slurm

# Create the runtime PID file for Slurm Daemons
sudo mkdir /var/run/slurm
sudo chown slurm /var/run/slurm
sudo chmod 700 /var/run/slurm

# Create the spool for Slurmd Daemons
sudo mkdir /var/spool/slurmd
sudo chown slurm /var/spool/slurmd
sudo chmod 700 /var/spool/slurmd

echo "--- SLURM Installation Complete ---"