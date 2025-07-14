#!/bin/bash

set -euo pipefail

# Define the target path for the script
PROFILE_D_FILE="/etc/profile.d/site_profile.sh"

# Use a heredoc to write the script content directly to the file
cat << 'EOF' | sudo tee "$PROFILE_D_FILE" > /dev/null
#!/bin/bash

# Define the directory for custom profile scripts
SITE_PROFILE_DIR="/opt/site/profile.d/live"

# Source scripts from /opt/site/profile.d if the directory exists
if [ -d "$SITE_PROFILE_DIR" ]; then
  # Loop through all .sh files and source them in lexicographical order
  for script in "$SITE_PROFILE_DIR"/*.sh; do
    # Ensure the file is a regular file and readable before sourcing
    [ -f "$script" ] && [ -r "$script" ] && . "$script"
  done
fi
EOF

# Make the script executable
sudo chmod +x "$PROFILE_D_FILE"

echo "--- Site Script Loader Setup Complete ---"