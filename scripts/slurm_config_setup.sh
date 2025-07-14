#!/bin/bash

set -euo pipefail

echo "--- Configuring SLURM ---"

cp -R /vagrant/scripts/slurm/* /etc/slurm/

sudo chmod 655 /etc/slurm/slurm.conf
sudo chmod 600 /etc/slurm/slurmdbd.conf
sudo chmod 655 /etc/slurm/cgroup.conf

echo "--- SLURM Configuration Complete ---"