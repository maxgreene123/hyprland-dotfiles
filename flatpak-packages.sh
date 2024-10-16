#!/bin/bash

# Add Flathub repository if not already added
echo "Adding Flathub repository if not already added..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install SyncThingy package
echo "Installing SyncThingy..."
flatpak install -y flathub com.github.zocker_160.SyncThingy

# Install Flatseal package
echo "Installing Flatseal..."
flatpak install -y flathub com.github.tchx84.Flatseal

# Display success message
echo "flatpak packages installed successfully!"
