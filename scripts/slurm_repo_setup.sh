#!/bin/bash

set -euo pipefail

echo "--- Configuring SLURM Repo ---"

cat <<EOF | sudo tee /etc/yum.repos.d/slurm.repo
[slurm]
name=SLURM Local Repo
baseurl=http://storage1/
enabled=1
gpgcheck=1
gpgkey=file:///etc/slurm/RPM-GPG-KEY-SLURM.pub
EOF

sudo dnf clean all

echo "--- SLURM Repo Configured ---"