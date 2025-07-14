#!/bin/bash

set -euo pipefail

SLURM_VERSION=$1
PRIVATE_NETWORK_IP_PREFIX=$2

echo "--- Setting up Storage Node ---"

# Install NFS server, web server and Slurm RPM build requirements
sudo dnf install -y nfs-utils nginx createrepo rpm-build rpm-sign gpg lua lua-devel hwloc hwloc-devel numactl numactl-devel jansson-devel jansson libyaml libyaml-devel

# Create shared directories
sudo mkdir -p /export/{home,software,slurm_config,slurmctld_state,slurm_repo,site,site/profile.d/live,site/profile.d/test}
sudo chmod -R 755 /export

# Configure NFS exports
cat <<EOF | sudo tee /etc/exports
/export/home           ${PRIVATE_NETWORK_IP_PREFIX}0/24(rw,sync,no_root_squash)
/export/software       ${PRIVATE_NETWORK_IP_PREFIX}0/24(rw,sync,no_root_squash)
/export/slurm_config   ${PRIVATE_NETWORK_IP_PREFIX}0/24(rw,sync,no_root_squash)
/export/slurm_repo     ${PRIVATE_NETWORK_IP_PREFIX}0/24(ro,sync,no_root_squash)
/export/slurmctld_state ${PRIVATE_NETWORK_IP_PREFIX}12(rw,sync,no_root_squash) ${PRIVATE_NETWORK_IP_PREFIX}13(rw,sync,no_root_squash)
/export/site     ${PRIVATE_NETWORK_IP_PREFIX}0/24(rw,sync,no_root_squash)
EOF

# Start and enable NFS server
sudo systemctl enable --now nfs-server

# Create GPG key for signing
gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Name-Real: Slurm RPM Signing
Name-Email: slurm-signing@example.com
Expire-Date: 0
%commit
EOF

# Export the public and private key
GPG_KEY_ID=$(gpg --list-keys --with-colons | awk -F: '/^pub/ {print $5; exit}')
gpg --export --armor "$GPG_KEY_ID" > /export/slurm_config/RPM-GPG-KEY-SLURM.pub
gpg --export-secret-keys --armor "$GPG_KEY_ID" > /export/slurm_config/RPM-GPG-KEY-SLURM.priv

# Set appropriate permissions
chmod 644 /export/slurm_config/RPM-GPG-KEY-SLURM.pub
chmod 600 /export/slurm_config/RPM-GPG-KEY-SLURM.priv

# Import public key into RPM DB
rpm --import /export/slurm_config/RPM-GPG-KEY-SLURM.pub

# Configure ~/.rpmmacros to enable GPG signing
cat > ~/.rpmmacros <<EOF
%_signature gpg
%_gpg_name $GPG_KEY_ID
%_gpg_path ~/.gnupg
%__gpg_check_password_cmd /bin/true
%__gpg /usr/bin/gpg
EOF

# Build SLURM from source
echo "--- Building SLURM v${SLURM_VERSION} ---"
mkdir -p /root/slurm_build
cd /root/slurm_build
wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2
# https://slurm.schedmd.com/cgroup_v2.html#requirements
# https://slurm.schedmd.com/quickstart_admin.html#prereqs
sudo dnf install -y mariadb-devel munge-devel openssl-devel pam-devel readline-devel lua readline-devel autoconf automake perl kernel-headers dbus-devel
rpmbuild -ta slurm-${SLURM_VERSION}.tar.bz2 > /root/slurm_build/build_slurm_${SLURM_VERSION}.log

# Copy RPMs to repo and create repository
sudo cp /root/rpmbuild/RPMS/x86_64/*.rpm /export/slurm_repo

# Sign the Slurm RPMs
for rpm in /export/slurm_repo/*.rpm; do
    rpm --addsign "$rpm"
done

# Create repository
sudo createrepo /export/slurm_repo

# Configure nginx to serve the repo
cat <<EOF | sudo tee /etc/nginx/conf.d/slurm-repo.conf
server {
    listen 80;
    server_name storage1;
    root /export/slurm_repo;
    location / {
        autoindex on;
    }
}
EOF
sudo systemctl enable --now nginx

echo "--- Storage Node Setup Complete ---"