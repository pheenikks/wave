
# Wave 🌊

## **REQUIREMENTS**

**Requires Hyprland and Quickshell. Support for other setups is planned.**

--- 

**This is a performance-based application launcher that I made.**

<img width="1799" height="1027" alt="image" src="https://github.com/user-attachments/assets/456af05b-263d-47d8-ae71-596ddd24461e" />

**Wave features customization and keeps a minimalistic approach to maintain performance, ease-of-use, and to have a compact design.**

<img width="1920" height="1080" alt="screenshot-1791578141" src="https://github.com/user-attachments/assets/02b65c23-0bf0-4a0d-8446-27d83c3f8bce" />


<img width="1778" height="1023" alt="image" src="https://github.com/user-attachments/assets/28c9bbf2-7eb1-441f-9816-b9b9b24672b7" />

# Install


```
curl -fsSL https://raw.githubusercontent.com/pheenikks/wave/main/get.sh | sh
```

**If the icon doesn't show in your app launcher, restart the launcher.**

**NOTE:** Wave launches on startup, to disable this, run `sed -i '/^exec-once/d' ~/.config/wave/hyprland.conf`.

**NOTE:** If you've disabled Wave launching on startup and would like to enable it again, run `echo 'exec-once = ~/.local/bin/wave start' >> ~/.config/wave/hyprland.conf`.

---

# How to use it.

**Use SUPER + G to open it, or from your app launcher.**

**Click Add in the side panel (or press N), then pick an app, type a command, or browse to the game’s file.**

---

# Updating / Uninstalling

**To update Wave, use `wave update`.**

**To uninstall Wave, use `wave uninstall`.**

---

# Compatibility

Wave can launch anything that starts with a command or a file: Steam games, prism launcher, emulators, native games, and Windows games through Wine. Launchers like Heroic should work by adding the game’s launch command, but I haven’t tested them yet.

---

# Performance

Wave was built using Quickshell and uses three different coding languages, these include QML, JavaScript, and Python.

One major thing that I noticed with most application launchers is the overconsumption of memory, with this in mind I designed Wave to be super lightweight. When you open Wave, its interface is built, and when you close it, it is thrown away. It uses 0% CPU while hidden, and games without cover art are drawn immediately instead of being stored.

I have tested Wave's performance, here are the outputs I was given.

### Just started, never opened.

```
Memory    53.0 MB   (its own: 33.1 MB, with shared libraries counted in full: 132.4 MB)
CPU        1.5 %    (averaged over 2 seconds)
```

The 1.5% is Wave still starting up; it drops to 0% within seconds.

---

### Open on screen, idle.

```
Memory    70.9 MB   (its own: 45.0 MB, with shared libraries counted in full: 158.2 MB)
CPU        2.0 %    (averaged over 2 seconds)
```

---

### Hidden again, after being opened.

```
Memory    75.5 MB   (its own: 49.7 MB, with shared libraries counted in full: 160.4 MB)
CPU        0.0 %    (averaged over 2 seconds)
```
**Tested on Gentoo with Hyprland 0.56.2 and Quickshell 0.3.1. Intel Core i5, 16 GB DDR5, RTX 4050.**

---

# Credits.

**Built on Quickshell; fonts are open-licensed and listed in assets/fonts.**

# License

**MIT license, see [LICENSE](LICENSE).**
