#!/bin/bash
set -euo pipefail

ROLE="$1"                    # e.g., login, controller, dbd, compute, storage
PRIVATE_NET_PREFIX="$2"      # e.g., 192.168.56.
INTERNAL_NET="${PRIVATE_NET_PREFIX}0/24"

echo "🛡️  Configuring firewall for role: $ROLE"
echo "🔐 Internal cluster network: $INTERNAL_NET"

# Install and enable firewalld if not installed
if ! rpm -q firewalld > /dev/null 2>&1; then
  echo "Installing firewalld..."
  dnf install -y firewalld
fi

systemctl enable --now firewalld

# Create zones
# external zone already exists, no need to create
#firewall-cmd --permanent --new-zone=external
firewall-cmd --permanent --new-zone=cluster

# Set default zone fallback
firewall-cmd --set-default-zone=external

# === Detect interfaces ===

# Get all active IPv4 interfaces except loopback
all_interfaces=$(ip -o -4 addr show up scope global | awk '{print $2}' | sort -u)

internal_ifaces=()
external_ifaces=()

for iface in $all_interfaces; do
  ip_addr=$(ip -o -4 addr show dev "$iface" | awk '{print $4}' | cut -d/ -f1)
  if [[ $ip_addr == ${PRIVATE_NET_PREFIX}* ]]; then
    internal_ifaces+=("$iface")
  else
    external_ifaces+=("$iface")
  fi
done

if [ ${#internal_ifaces[@]} -eq 0 ]; then
  echo "❌ Error: No internal interfaces found with IP in $PRIVATE_NET_PREFIX"
  exit 1
fi

if [ ${#external_ifaces[@]} -eq 0 ]; then
  echo "⚠️ Warning: No external interfaces found."
fi

# Bind internal interfaces to cluster zone
for intf in "${internal_ifaces[@]}"; do
  firewall-cmd --permanent --zone=cluster --change-interface="$intf"
  echo "Bound internal interface $intf to cluster zone"
done

# Bind external interfaces to external zone
for extf in "${external_ifaces[@]}"; do
  firewall-cmd --permanent --zone=external --change-interface="$extf"
  echo "Bound external interface $extf to external zone"
done

# === Common rules ===

# SSH allowed from anywhere on both zones
firewall-cmd --permanent --zone=external --add-service=ssh
firewall-cmd --permanent --zone=cluster  --add-service=ssh

# ICMP (ping) allowed from anywhere on both zones
firewall-cmd --permanent --zone=external --add-icmp-block-inversion
firewall-cmd --permanent --zone=cluster  --add-icmp-block-inversion

# === Role-specific rules on internal zone only ===
case "$ROLE" in
  login|compute)
    # Allow all traffic from the internal cluster network on login and compute nodes.
    firewall-cmd --permanent --zone=cluster --add-rich-rule="rule family='ipv4' source address='${INTERNAL_NET}' accept"
    ;;

  controller)
    # Allow Slurm controller ports 6817 and 6818 only from internal network.
    firewall-cmd --permanent --zone=cluster --add-rich-rule="rule family='ipv4' source address='${INTERNAL_NET}' port port='6817' protocol='tcp' accept"
    firewall-cmd --permanent --zone=cluster --add-rich-rule="rule family='ipv4' source address='${INTERNAL_NET}' port port='6818' protocol='tcp' accept"
    ;;

  dbd)
    # Allow SlurmDBD port 6819 from cluster
    firewall-cmd --permanent --zone=cluster --add-rich-rule="rule family='ipv4' source address='${INTERNAL_NET}' port port='6819' protocol='tcp' accept"
    # The MariaDB service is local!
    ;;

  storage)
    # Allow NFS-related ports only from internal network.
    firewall-cmd --permanent --zone=cluster --add-service=mountd
    firewall-cmd --permanent --zone=cluster --add-rich-rule="rule family='ipv4' source address='${INTERNAL_NET}' port port='2049' protocol='tcp' accept"
    firewall-cmd --permanent --zone=cluster --add-rich-rule="rule family='ipv4' source address='${INTERNAL_NET}' port port='111' protocol='tcp' accept"
    # Allow repo related ports only from internal network.
    firewall-cmd --permanent --zone=cluster --add-rich-rule="rule family='ipv4' source address='${INTERNAL_NET}' port port='80' protocol='tcp' accept"
    firewall-cmd --permanent --zone=cluster --add-rich-rule="rule family='ipv4' source address='${INTERNAL_NET}' port port='443' protocol='tcp' accept"
    ;;

  *)
    echo "❌ Unknown role: $ROLE"
    exit 1
    ;;
esac


firewall-cmd --reload

echo "✅ Firewall configured for role: $ROLE"
