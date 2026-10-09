
# Wave 🌊

## **REQUIREMENTS** ‼️ ‼️

**This requires Hyprland and Quickshell until future installation files are made.**

--- 

**This is a performance-based application launcher that I made.**

<img width="1799" height="1027" alt="image" src="https://github.com/user-attachments/assets/456af05b-263d-47d8-ae71-596ddd24461e" />

**Wave features customization and keeps a minimalistic approach to maintain performance, ease-of-use, and to have a compact design.**

<img width="1920" height="1080" alt="screenshot-1791578141" src="https://github.com/user-attachments/assets/02b65c23-0bf0-4a0d-8446-27d83c3f8bce" />


<img width="1778" height="1023" alt="image" src="https://github.com/user-attachments/assets/28c9bbf2-7eb1-441f-9816-b9b9b24672b7" />

# How to use it.

**Use SUPER + G to open it, or launch from the app directory.**

**To update Wave, use `wave update`.**

**To uninstall Wave, use `wave uninstall`.**

---

# Compatibility

**So far, Wave works with Steam, 

---

**Wave was built using Quickshell and uses three different coding languages, these include QML, JavaScript, and Python.**

**One major thing that I noticed with most application launchers is the overconsumption of memory, with this in mind I designed Wave to be super lightweight. When you open Wave, its interface is built, and when you close it, it is thrown away. It uses 0% CPU while hidden, and all the art is drawn immediately instead of being stored.**

**I have tested Wave's performance, here are the outputs I was given.**

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
**Tested on 16 GB DDR5, RTX 4050, and Intel Core i5.**

---

# Credits.

**Built on Quickshell; fonts are open-licensed and listed in assets/fonts.**

# License

**MIT license, see [LICENSE](/../main/LICENSE).**
