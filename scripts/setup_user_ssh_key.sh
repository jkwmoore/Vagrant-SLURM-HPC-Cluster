#!/bin/bash

set -euo pipefail

USERNAME=$1
SSH_DIR="/home/$USERNAME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519" # Changed: Key file name for ED25519
AUTH_KEYS_PATH="$SSH_DIR/authorized_keys"

# Exit on first error
set -euo pipefail

# Check if a username argument was provided
[ -z "$USERNAME" ] && { echo "ERROR: Usage: $0 <username>"; exit 1; }

# Ensure user exists
id "$USERNAME" &>/dev/null || { echo "ERROR: User '$USERNAME' not found."; exit 1; }

# Create .ssh directory and set permissions if it doesn't exist
mkdir -p "$SSH_DIR"
chown "$USERNAME":"$USERNAME" "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Generate key if not present
if [ ! -f "$KEY_PATH" ]; then
    # Changed: Key type from rsa to ed25519; -b (bits) is not used for ed25519
    su - "$USERNAME" -c "ssh-keygen -t ed25519 -f '$KEY_PATH' -N '' -q -C '${USERNAME}@$(hostname)'"
fi

# Add public key to authorized_keys and set permissions
touch "$AUTH_KEYS_PATH"
chown "$USERNAME":"$USERNAME" "$AUTH_KEYS_PATH"
grep -qF "$(cat "${KEY_PATH}.pub")" "$AUTH_KEYS_PATH" || cat "${KEY_PATH}.pub" >> "$AUTH_KEYS_PATH"
chmod 600 "$AUTH_KEYS_PATH"

echo "SSH key setup complete for user '$USERNAME'."