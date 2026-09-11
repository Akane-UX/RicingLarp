#  RicingLarp

Welcome to my personal Linux ricing and automation setup! 

This repo holds all the secret sauce for my daily driver, including custom widgets (like a slick lyrics display and a desktop pet roaming around), **Serpantinum** UI themes, and some hardcore system maintenance scripts to keep everything running buttery smooth.

##  Heads Up (The "It Works on My Machine" Disclaimer)
Just a quick heads up: this setup is daily-driven and heavily optimized for **Arch Linux**, specifically built around the **Serpantinum** ecosystem. A lot of these scripts and QML widgets play super nice out-of-the-box on Arch, but if you're rocking a different distro, you might need to tweak a few things under the hood to get 'em working right. 

---

## Porting to Other Distros (The Basics)

If you're pulling this into Ubuntu, Fedora, or something else, don't sweat it. Most of the logic is universal. Here's a quick cheat sheet on how to port this setup to your flavor of Linux.

### 1. Serpantinum Configs & Widgets
The good news? User-space configs don't care about your distro. 
Everything inside `.config/serpantinum/` and `.local/share/serpantinum/` (including `PetFace.qml` and `LyricsFace.qml`) will drop right into the exact same directories on Debian, Fedora, or whatever else you're running. As long as you have the Serpantinum shell installed, the widgets will just work.

### 2. The Daily Cleanup Script (`system-cleanup/`)
I've included an automated system cleanup script (`daily-cleanup.sh`) paired with some systemd timers to take out the trash at midnight. 

**If you're NOT on Arch, you gotta tweak this script!**
The script uses `paccache` and `pacman` hooks which are strictly Arch-only. 
- **Debian/Ubuntu folks**: Open `daily-cleanup.sh` and swap out the pacman commands for `sudo apt autoremove --purge -y` and `sudo apt clean`.
- **Fedora folks**: Swap 'em for `sudo dnf clean all` and `sudo dnf autoremove`.
- The cache clearing for apps (like npm, spotify, pip) works globally, so you can leave those parts exactly as they are.

**Setting up the Systemd Timer (Universal):**
To get the automated cleanup running on *any* systemd-based distro, run:
```bash
# 1. Copy the script and make it executable
sudo cp system-cleanup/daily-cleanup.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/daily-cleanup.sh

# 2. Copy the timer and service to systemd
sudo cp system-cleanup/systemd/daily-cleanup.* /etc/systemd/system/

# 3. Reload the daemon and enable the timer
sudo systemctl daemon-reload
sudo systemctl enable --now daily-cleanup.timer
```

### 3. Custom Scripts (`.local/bin/`)
Scripts like `sreload` are meant to be dropped into `~/.local/bin/`. Just make sure that directory is in your system's `$PATH` (usually defined in your `~/.bashrc` or `~/.zshrc`). 

```bash
cp .local/bin/sreload ~/.local/bin/
chmod +x ~/.local/bin/sreload
```

---

*Stay frosty and happy ricing!* 🐧🔥
