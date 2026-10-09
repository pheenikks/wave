import QtQuick
import Quickshell.Hyprland

// Loaded lazily by shell.qml so Wave still starts on compositors (or
// Quickshell builds) without the Hyprland module.
QtObject {
    readonly property string focusedMonitor: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
}
