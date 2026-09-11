#!/usr/bin/env bash
# Deep System Daily Cleanup Script
# Log file: /var/log/daily-cleanup.log

LOG_FILE="/var/log/daily-cleanup.log"
TARGET_USER="avrlln"
USER_HOME="/home/${TARGET_USER}"

echo "==========================================" >> "$LOG_FILE"
echo "Daily Cleanup started at $(date)" >> "$LOG_FILE"

# 1. Clean Pacman cache (keep latest 1 version of installed packages, remove all uninstalled package caches)
if command -v paccache &> /dev/null; then
    echo "[+] Running paccache..." >> "$LOG_FILE"
    paccache -rk1 >> "$LOG_FILE" 2>&1
    paccache -ruk0 >> "$LOG_FILE" 2>&1
else
    echo "[+] Cleaning pacman cache via pacman -Sc..." >> "$LOG_FILE"
    pacman -Sc --noconfirm >> "$LOG_FILE" 2>&1
fi

# 2. Remove orphaned packages if any
ORPHANS=$(pacman -Qtdq 2>/dev/null)
if [ -n "$ORPHANS" ]; then
    echo "[+] Removing orphan packages: $ORPHANS" >> "$LOG_FILE"
    pacman -Rns $ORPHANS --noconfirm >> "$LOG_FILE" 2>&1
else
    echo "[+] No orphan packages found." >> "$LOG_FILE"
fi

# 3. Clean systemd journal logs (keep 3 days / 200MB max)
echo "[+] Vacuuming systemd logs..." >> "$LOG_FILE"
journalctl --vacuum-time=3d >> "$LOG_FILE" 2>&1
journalctl --vacuum-size=200M >> "$LOG_FILE" 2>&1

# 4. Clean user caches for user avrlln
echo "[+] Cleaning user caches for $TARGET_USER..." >> "$LOG_FILE"
if [ -d "$USER_HOME/.cache" ]; then
    rm -rf "$USER_HOME/.cache/thumbnails/"* >> "$LOG_FILE" 2>&1
    rm -rf "$USER_HOME/.cache/spotify/"* >> "$LOG_FILE" 2>&1
    rm -rf "$USER_HOME/.cache/mozilla/firefox/"*/cache2/* >> "$LOG_FILE" 2>&1
    rm -rf "$USER_HOME/.cache/go-build/"* >> "$LOG_FILE" 2>&1
    rm -rf "$USER_HOME/.cache/node-gyp/"* >> "$LOG_FILE" 2>&1
    rm -rf "$USER_HOME/.cache/pip/"* >> "$LOG_FILE" 2>&1
    rm -rf "$USER_HOME/.cache/vscode-cpptools/"* >> "$LOG_FILE" 2>&1
    rm -rf "$USER_HOME/.cache/pnpm/"* >> "$LOG_FILE" 2>&1
    rm -rf "$USER_HOME/.cache/serpantinum-installer/"* >> "$LOG_FILE" 2>&1
fi

# 5. Empty Trash for target user
if [ -d "$USER_HOME/.local/share/Trash" ]; then
    echo "[+] Emptying trash..." >> "$LOG_FILE"
    rm -rf "$USER_HOME/.local/share/Trash/"* >> "$LOG_FILE" 2>&1
fi

echo "Daily Cleanup completed at $(date)" >> "$LOG_FILE"
echo "Current Root Usage: $(df -h / | awk "NR==2 {print \$3 \"/\" \$2 \" (\" \$5 \")\"}")" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"
