#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
command -v yay >/dev/null || { echo 'Install yay first, or run python3 scripts/install.py.' >&2; exit 1; }
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
mkdir -p -- "$state_dir"
missing_file="$state_dir/missing-packages.txt"
: > "$missing_file"
packages=()
while IFS= read -r package || [[ -n "$package" ]]; do
    [[ -z "$package" || "$package" == \#* || "$package" == *-debug ]] && continue
    pacman -Qq "$package" >/dev/null 2>&1 && continue
    if yay -Si "$package" >/dev/null 2>&1; then
        packages+=("$package")
    else
        printf '%s\n' "$package" | tee -a "$missing_file" >&2
    fi
done < packages.txt
if ((${#packages[@]})); then
    yay -S --needed "${packages[@]}" || exit 1
fi
if [[ -s "$missing_file" ]]; then
    echo "Unavailable packages (install the rest first, then review): $missing_file" >&2
    exit 2
fi
