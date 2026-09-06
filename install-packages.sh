#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
yay -S --needed - < packages.txt
