#!/bin/bash

set -euo pipefail

ALMA_VERSION=$1
NUM_COMPUTE_NODES=$2
PRIVATE_NETWORK_IP_PREFIX=$3

echo "--- Running Common Setup ---"

# Get the major version of the OS
# This works for RHEL, CentOS Stream, AlmaLinux, Rocky Linux
OS_MAJOR_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2 | cut -d'.' -f1)

# Disable root login
sudo passwd -l root

# Create pam_admin user
sudo useradd -m -s /bin/bash pam_admin
echo "vagrant ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/vagrant

# Install EPEL Release
echo "Installing EPEL Release for EL$OS_MAJOR_VERSION..."
if [ "$OS_MAJOR_VERSION" -eq 8 ]; then
    # For EL8, install epel-release from the AppStream repository
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    if [ $? -ne 0 ]; then
        echo "Error installing EPEL for EL8. Please check your internet connection and repository configuration."
        exit 1
    fi
    echo "EPEL release for EL8 installed successfully."
elif [ "$OS_MAJOR_VERSION" -eq 9 ]; then
    # For EL9, install epel-release from the AppStream repository
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    if [ $? -ne 0 ]; then
        echo "Error installing EPEL for EL9. Please check your internet connection and repository configuration."
        exit 1
    fi
    echo "EPEL release for EL9 installed successfully."
else
    echo "Unsupported OS Major Version: EL$OS_MAJOR_VERSION. This script supports EL8 and EL9 only."
    exit 1
fi

# Enable CRB / PowerTools repository
echo "Enabling CRB/PowerTools repository..."
if [ "$OS_MAJOR_VERSION" -eq 8 ]; then
    # For EL8, the repository is called 'powertools'
    dnf config-manager --set-enabled powertools
    if [ $? -ne 0 ]; then
        echo "Error enabling powertools repository for EL8."
        exit 1
    fi
    echo "PowerTools repository enabled for EL8."
elif [ "$OS_MAJOR_VERSION" -eq 9 ]; then
    # For EL9, the repository is called 'crb'
    dnf config-manager --set-enabled crb
    if [ $? -ne 0 ]; then
        echo "Error enabling crb repository for EL9."
        exit 1
    fi
    echo "CRB repository enabled for EL9."
fi

# Update system and install base packages
sudo dnf install -y wget gcc make munge nano vim hwloc hwloc-devel numactl numactl-devel jansson-devel jansson libyaml libyaml-devel python3 python3-pip

# Configure /etc/hosts
cat <<EOF | sudo tee -a /etc/hosts
${PRIVATE_NETWORK_IP_PREFIX}10 login1
${PRIVATE_NETWORK_IP_PREFIX}11 storage1
${PRIVATE_NETWORK_IP_PREFIX}12 slurmctld1
${PRIVATE_NETWORK_IP_PREFIX}13 slurmctld2
${PRIVATE_NETWORK_IP_PREFIX}14 slurmdbd1
EOF

# Add compute nodes to /etc/hosts also
for ((i=1; i<=NUM_COMPUTE_NODES; i++)); do
    compute_ip="${PRIVATE_NETWORK_IP_PREFIX}$((20 + i))"
    echo "${compute_ip} compute${i}" | sudo tee -a /etc/hosts
done

# Disable SELinux
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# Time synchronization
sudo dnf install -y chrony
sudo systemctl start chronyd
sudo systemctl enable chronyd

echo "--- Common Setup Complete ---"