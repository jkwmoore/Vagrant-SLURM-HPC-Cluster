#!/bin/bash

set -euo pipefail

# Define the target directory and script path
SITE_PROFILE_DIR="/opt/site/profile.d/live"

# Check if the target directory exists. If not, print an error and exit.
if [ ! -d "$SITE_PROFILE_DIR" ]; then
  echo "Error: Directory '$SITE_PROFILE_DIR' does not exist. Please create it first. Exiting."
  exit 1
fi

cp -R /vagrant/scripts/site-scripts/* ${SITE_PROFILE_DIR}


echo "--- Site Script Setup Complete ---"