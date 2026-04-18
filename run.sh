#!/usr/bin/env bash
# ============================================================================
# run.sh — Build and launch the Hollow Knight Assembly Demo on Linux/Ubuntu
# Usage: ./run.sh
# ============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Hollow Knight — Assembly Demo ==="
echo

# ---- Check for missing dependencies ----
MISSING=()
for cmd in nasm gcc make; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING+=("$cmd")
    fi
done

# X11 headers
if [ ! -f /usr/include/X11/Xlib.h ]; then
    MISSING+=("libx11-dev")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Missing dependencies: ${MISSING[*]}"
    echo
    echo "Install them with:"
    echo "    sudo apt-get update"
    echo "    sudo apt-get install -y nasm gcc make libx11-dev"
    echo
    read -rp "Install now? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        sudo apt-get update
        sudo apt-get install -y nasm gcc make libx11-dev
    else
        echo "Aborting."
        exit 1
    fi
fi

# ---- Check DISPLAY (need an X server) ----
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "Warning: no DISPLAY environment variable set."
    echo "You need a running graphical session (X11 or Wayland with XWayland)."
    echo "If you are on a headless server, try:"
    echo "    Xvfb :99 -screen 0 640x480x24 &"
    echo "    DISPLAY=:99 ./run.sh"
    exit 1
fi

# ---- Build ----
echo "Building..."
make

# ---- Run ----
echo
echo "Launching hollow_knight..."
echo "Controls: WASD = move, Space = jump, Left Click = attack, Right Click = dash, Esc = quit"
echo
exec ./hollow_knight
