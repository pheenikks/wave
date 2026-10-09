#!/bin/sh
# Links this checkout into Quickshell's config directory and creates your
# personal config in ~/.config/wave. Safe to run again; it never overwrites
# your files.
#
#   --yes           add the Hyprland line without asking
#   --no-hyprland   leave hyprland.conf alone
set -eu
auto=ask
for arg in "$@"; do
    case "$arg" in
        --yes|-y) auto=yes ;;
        --no-hyprland) auto=no ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done
here="$(cd "$(dirname "$0")" && pwd)"
conf="${XDG_CONFIG_HOME:-$HOME/.config}"
state="${XDG_STATE_HOME:-$HOME/.local/state}"

mkdir -p "$conf/quickshell" "$conf/wave/covers" "$conf/wave/themes" "$state/wave" "$HOME/.local/bin"

link="$conf/quickshell/wave"
if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "error: $link exists and is not a symlink; move it away and run this again." >&2
    exit 1
fi
ln -sfn "$here" "$link"
ln -sfn "$here/bin/wave" "$HOME/.local/bin/wave"

[ -e "$conf/wave/config.json" ] || cp "$here/examples/config.json" "$conf/wave/config.json"
[ -e "$conf/wave/games.json" ] || printf '[]\n' > "$conf/wave/games.json"   # the shelf starts empty
[ -e "$conf/wave/hyprland.conf" ] || cp "$here/hyprland/wave.conf" "$conf/wave/hyprland.conf"

# Show up as an app: menu entry plus icon, so launchers (rofi, wofi, fuzzel...) list Wave.
data="${XDG_DATA_HOME:-$HOME/.local/share}"
for size in 48 64 128 256 512; do
    mkdir -p "$data/icons/hicolor/${size}x${size}/apps"
    cp "$here/assets/icon/wave-$size.png" "$data/icons/hicolor/${size}x${size}/apps/wave.png"
done
mkdir -p "$data/applications"
cat > "$data/applications/wave.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Wave
GenericName=Game Launcher
Comment=Your games on a shelf
Exec=$HOME/.local/bin/wave show
Icon=wave
Categories=Game;
Keywords=games;launcher;steam;
Terminal=false
StartupNotify=false
DESKTOP
# No icon cache in the user folder: a cache built here can hide the icon from
# launchers that trust it, while a folder without one is simply scanned.
rm -f "$data/icons/hicolor/icon-theme.cache"
touch "$data/icons/hicolor"
# Launchers look icons up through the "hicolor" theme. If the system has no
# such theme installed, describe ours so the lookup still works.
if [ ! -e /usr/share/icons/hicolor/index.theme ] && [ ! -e "$data/icons/hicolor/index.theme" ]; then
    cat > "$data/icons/hicolor/index.theme" <<THEME
[Icon Theme]
Name=Hicolor
Comment=Fallback icon theme
Directories=48x48/apps,64x64/apps,128x128/apps,256x256/apps,512x512/apps

[48x48/apps]
Size=48
Context=Applications
Type=Threshold

[64x64/apps]
Size=64
Context=Applications
Type=Threshold

[128x128/apps]
Size=128
Context=Applications
Type=Threshold

[256x256/apps]
Size=256
Context=Applications
Type=Threshold

[512x512/apps]
Size=512
Context=Applications
Type=Threshold
THEME
fi
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$data/applications" 2>/dev/null || true

"$here/bin/wave" scan 2>/dev/null || true   # find installed Steam games for the add screen

# Hook into Hyprland: one 'source' line, added only if you say yes.
hypr="$conf/hypr/hyprland.conf"
line="source = $conf/wave/hyprland.conf"
hooked=no
if [ -f "$hypr" ]; then
    if grep -qF "wave/hyprland.conf" "$hypr"; then
        hooked=yes
    elif [ "$auto" = yes ]; then
        printf '\n# Wave game launcher\n%s\n' "$line" >> "$hypr"; hooked=yes
    elif [ "$auto" = ask ] && [ -t 0 ]; then
        printf 'Add Wave (autostart + SUPER+G) to %s? [Y/n] ' "$hypr"
        read -r answer
        case "$answer" in
            ""|y|Y|yes) printf '\n# Wave game launcher\n%s\n' "$line" >> "$hypr"; hooked=yes ;;
        esac
    fi
fi

cat <<MSG
Wave is installed.

  Wave is in your app launcher, or:
  wave                               open or close the shelf
  wave add "Title" --exec "command"  put a game on it
  wave --help                        everything else

  Games:     $conf/wave/games.json
  Settings:  $conf/wave/config.json
  Keybind:   $conf/wave/hyprland.conf  (SUPER+G by default)
MSG

if [ "$hooked" = yes ]; then
    echo "Hyprland is set up: SUPER+G opens Wave, and it starts by itself at login."
else
    printf '\nTo finish, add this line to %s:\n\n  %s\n' "$hypr" "$line"
fi
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) printf '\nNote: ~/.local/bin is not on your PATH, so type ~/.local/bin/wave or add it to PATH.\n' ;;
esac
