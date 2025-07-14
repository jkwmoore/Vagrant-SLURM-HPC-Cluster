#!/bin/bash

set -euo pipefail

USERNAME=$1
HOME_PATH_USER="/home/${USERNAME}"
SKEL_DIR="/etc/skel"

# Check if a username argument was provided
[ -z "$USERNAME" ] && { echo "ERROR: Usage: $0 <username>"; exit 1; }

# Ensure user exists
id "$USERNAME" &>/dev/null || { echo "ERROR: User '$USERNAME' not found."; exit 1; }

# Create, set ownership, and permissions for the home directory
mkdir -p "$HOME_PATH_USER"
chown "$USERNAME":"users" "$HOME_PATH_USER"
chmod 700 "$HOME_PATH_USER"

echo "Home directory '$HOME_PATH_USER' created and configured for user '$USERNAME'."

echo "Copying .bash_profile, .bashrc, and .bash_logout from $SKEL_DIR to $HOME_PATH_USER for user '$USERNAME'..."

# Define files to copy
FILES_TO_COPY=(".bash_profile" ".bashrc" ".bash_logout")

for FILE in "${FILES_TO_COPY[@]}"; do
    if [ -f "$SKEL_DIR/$FILE" ]; then
        cp -f "$SKEL_DIR/$FILE" "$HOME_PATH_USER/"
        chown "$USERNAME":"$USERNAME" "$HOME_PATH_USER/$FILE"
        chmod 644 "$HOME_PATH_USER/$FILE"
        echo "  - Copied and configured $FILE"
    else
        echo "  - Warning: $FILE not found in $SKEL_DIR. Skipping."
    fi
done

echo "Bash configuration files copied and configured for user '$USERNAME'."