#!/bin/sh
# Wave one-line installer.
#
#   curl -fsSL https://raw.githubusercontent.com/pheenikks/wave/main/get.sh | sh
#
# Downloads Wave to ~/.local/share/wave, sets it up, hooks it into Hyprland
# (autostart + SUPER+G) and starts it. Run it again any time to update.
# Nothing here needs root.
set -eu

REPO="${WAVE_REPO:-https://github.com/pheenikks/wave}"
DEST="${WAVE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/wave}"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1; }

for tool in git python3; do
    need "$tool" || { echo "Wave needs '$tool'. Install it with your package manager and run this again." >&2; exit 1; }
done

if [ -d "$DEST/.git" ]; then
    say "Updating Wave in $DEST"
    git -C "$DEST" pull --ff-only --quiet
else
    if [ -e "$DEST" ]; then
        echo "$DEST exists but is not a Wave checkout; move it away and run this again." >&2
        exit 1
    fi
    say "Downloading Wave to $DEST"
    mkdir -p "$(dirname "$DEST")"
    git clone --depth 1 --quiet "$REPO" "$DEST"
fi

"$DEST/install.sh" --yes

if need qs; then
    # (re)start it so the keybind works right away
    qs -c wave kill >/dev/null 2>&1 || true
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        "$DEST/bin/wave" start
        say "Wave is running. Press SUPER+G, or type: wave"
    fi
else
    . /etc/os-release 2>/dev/null || true
    say "One thing left: Wave runs on Quickshell, which is not installed yet."
    case "${ID:-} ${ID_LIKE:-}" in
        *gentoo*) cat <<'MSG'
  sudo eselect repository enable guru && sudo emaint sync -r guru
  echo "gui-apps/quickshell ~amd64" | sudo tee /etc/portage/package.accept_keywords/quickshell
  sudo emerge --ask gui-apps/quickshell
MSG
        ;;
        *)        echo "  Install it for your distro: https://quickshell.org/docs/guide/install-setup/" ;;
    esac
    echo "Then press SUPER+G."
fi
