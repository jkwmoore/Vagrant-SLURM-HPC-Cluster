#!/bin/bash

set -euo pipefail

# Define the user and known_hosts file
USER_HOME="/home/vagrant"
KNOWN_HOSTS="$USER_HOME/.ssh/known_hosts"

# Ensure .ssh directory exists
mkdir -p "$USER_HOME/.ssh"
touch "$KNOWN_HOSTS"
chmod 600 "$KNOWN_HOSTS"
chown vagrant:vagrant "$KNOWN_HOSTS"

# Read hostnames from /etc/hosts filtered by 192.168.56
HOSTS=$(grep 192.168.56 /etc/hosts | awk '{print $2}')

# Loop over each hostname and add its SSH key
for host in $HOSTS; do
  echo "Scanning $host..."
  ssh-keyscan -H "$host" >> "$KNOWN_HOSTS" 2>/dev/null
done

# Deduplicate entries (optional)
sort -u "$KNOWN_HOSTS" -o "$KNOWN_HOSTS"
chown vagrant:vagrant "$KNOWN_HOSTS"

echo "SSH host keys added to $KNOWN_HOSTS"