#!/bin/bash

set -euo pipefail

echo "--- Setting up MariaDB on SlurmDBD Node ---"

sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb

# Secure installation and create database
sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE slurm_acct_db;
CREATE USER 'slurm'@'localhost' IDENTIFIED BY 'slurm_password';
GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'localhost';
FLUSH PRIVILEGES;
EXIT
MYSQL_SCRIPT

echo "--- MariaDB Setup Complete ---"