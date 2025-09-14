#!/bin/bash

# Add Flathub repository if not already added
echo "Adding Flathub repository if not already added..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak install -y flathub com.github.tchx84.Flatseal

flatpak install -y flathub org.vinegarhq.Sober

flatpak install -y flathub com.usebottles.bottles
# Display success message
echo "flatpak packages installed successfully!"
