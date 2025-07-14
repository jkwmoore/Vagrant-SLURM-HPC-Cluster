#!/bin/bash
set -euo pipefail

# Take args and establish the access IP address.
PRIVATE_NETWORK_IP_PREFIX="$1"
ACCESS_IP=$(ip -4 addr show | grep -oP "(?<=inet )${PRIVATE_NETWORK_IP_PREFIX//./\\.}[0-9]+" | head -n1)

# Get the major version of the OS
# This works for RHEL, CentOS Stream, AlmaLinux, Rocky Linux
OS_MAJOR_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2 | cut -d'.' -f1)

echo "Detected RHEL-based major version: $OS_MAJOR_VERSION"

case "$OS_MAJOR_VERSION" in
  8)
    echo "Applying configuration for EL8 family"
    dnf install -y https://yum.osc.edu/ondemand/4.0/ondemand-release-web-4.0-1.el8.noarch.rpm

    dnf module reset -y nodejs
    dnf module enable -y nodejs:20

    dnf module reset -y ruby
    dnf module enable -y ruby:3.3
    ;;
  9)
    echo "Applying configuration for EL9 family"
    dnf install -y https://yum.osc.edu/ondemand/4.0/ondemand-release-web-4.0-1.el9.noarch.rpm

    dnf module reset -y nodejs
    dnf module enable -y nodejs:20

    dnf module reset -y ruby
    dnf module enable -y ruby:3.3
    ;;
  *)
    echo "Unsupported or unrecognized RHEL-based version: $OS_MAJOR_VERSION"
    exit 1
    ;;
esac

# Install Open OnDemand package
dnf install -y ondemand

# We're going to use  PAM authentication for Open on Demand because this is a ephemeral testbed.
# Note that is is NOT A PRODUCTION CONFIG!
# DO NOT USE THIS AS A PRODUCTION CONFIG!

# Ensure mod_authnz_pam is installed
dnf install -y mod_authnz_pam

# Check if the module load line exists; add if missing
MOD_CONF="/etc/httpd/conf.modules.d/00-authnz-pam.conf"
if ! grep -q "^LoadModule authnz_pam_module" "$MOD_CONF" 2>/dev/null; then
  echo "LoadModule authnz_pam_module modules/mod_authnz_pam.so" | sudo tee "$MOD_CONF"
fi

# Copy the PAM config for SSH, but for Open on Demand
cp /etc/pam.d/sshd /etc/pam.d/ood

# Set ACL to allow Apache user read access to /etc/shadow for PAM authentication
setfacl -m u:apache:r /etc/shadow

# Enable and start Apache (httpd)
systemctl enable httpd
systemctl start httpd

# Generate self-signed SSL certificate and key for Open OnDemand portal
CERT_PATH="/etc/pki/tls/certs/ood-selfsigned.crt"
KEY_PATH="/etc/pki/tls/private/ood-selfsigned.key"
openssl req -newkey rsa:4096 -nodes -keyout "$KEY_PATH" -x509 -days 365 -out "$CERT_PATH" \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=$(hostname -f)"

# Open HTTP and HTTPS ports in the 'external' zone
firewall-cmd --permanent --zone=external --add-service=http
firewall-cmd --permanent --zone=external --add-service=https
firewall-cmd --reload

# Configure SELinux to allow Apache network connections and executable memory
setsebool -P httpd_can_network_connect on
setsebool -P httpd_execmem on

# Set Open OnDemand portal servername and configure PAM auth in ood_portal.yml
OOD_CONFIG="/etc/ood/config/ood_portal.yml"
cat > "$OOD_CONFIG" << EOF
servername: "${ACCESS_IP}"

auth:
  - 'AuthType Basic'
  - 'AuthName "Open OnDemand"'
  - 'AuthBasicProvider PAM'
  - 'AuthPAMService ood'
  - 'Require valid-user'

ssl:
  - "SSLCertificateFile $CERT_PATH"
  - "SSLCertificateKeyFile $KEY_PATH"

host_regex: 'compute\d+'
node_uri: '/node'
rnode_uri: '/rnode'
EOF

# Apply Open OnDemand portal config changes
/opt/ood/ood-portal-generator/sbin/update_ood_portal --force

# Define your cluster name - must match your Slurm config cluster name
CLUSTER_NAME="my_hpc_cluster"

CLUSTER_CONFIG_DIR="/etc/ood/config/clusters.d"
CLUSTER_CONFIG_FILE="${CLUSTER_CONFIG_DIR}/${CLUSTER_NAME}.yml"

mkdir -p "$CLUSTER_CONFIG_DIR"

cat > "$CLUSTER_CONFIG_FILE" <<EOF
---
v2:
  metadata:
    title: "Slurm Cluster"
    cluster: "$CLUSTER_NAME"
  login:
    host: "${ACCESS_IP}"
  job:
     adapter: "slurm"
     bin: "/usr/bin/"
     conf: "/etc/slurm/slurm.conf"
     copy_environment: false
  batch_connect:
    basic:
      script_wrapper: |
        module purge
        %s
    vnc:
      script_wrapper: |
        module purge
        export PATH="/opt/TurboVNC/bin/:$PATH"
        export WEBSOCKIFY_CMD="/usr/local/bin/websockify"
        %s
EOF

echo "Wrote Open OnDemand cluster config to $CLUSTER_CONFIG_FILE"
echo 
echo "Configured Open OnDemand Slurm app cluster name as '$CLUSTER_NAME'."

mkdir -p /etc/ood/config/apps/bc_desktop

cat > /etc/ood/config/apps/bc_desktop/my_hpc_cluster.yml <<EOF
---
title: "$CLUSTER_NAME XFCE Desktop"
cluster: "$CLUSTER_NAME"
attributes:
  desktop: "xfce"
EOF


# Restart Apache to load new config and SSL cert
systemctl restart httpd

echo "Open OnDemand installation and PAM authentication setup complete."
echo "Access the portal at the following URLs (HTTPS):"
ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | while read -r ipaddr; do
  echo "  https://$ipaddr/"
done