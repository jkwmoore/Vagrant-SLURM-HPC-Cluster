#!/bin/bash
set -euo pipefail

# Install nmap-ncat
sudo dnf install -y nmap-ncat python3-pip

# Upgrade pip
sudo pip3 install --upgrade pip

# Install TurboVNC (adjust version as needed)
cd /tmp
curl -L -o turbovnc.rpm https://sourceforge.net/projects/turbovnc/files/2.2.7/turbovnc-2.2.7.x86_64.rpm/download
sudo dnf install -y ./turbovnc.rpm

# Install websockify
sudo pip3 install websockify

# Install XFCE and bits.
sudo dnf groupinstall -y "Xfce"
sudo dnf install -y xorg-x11-server-Xvfb dbus-x11 xfce4-session xfce4-settings xfce4-panel thunar firefox