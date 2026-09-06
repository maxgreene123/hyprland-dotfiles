#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
while IFS= read -r app; do
    [[ -z "$app" ]] || flatpak install --system -y flathub "$app"
done < flatpak-packages.txt
