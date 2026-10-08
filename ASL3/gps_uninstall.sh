#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 1.2 - 10/26
#
# GPS Node Tracking - Uninstaller 

RPTCONF="/etc/asterisk/rpt.conf"
INSTALL_DIR="/opt/GPS"
SOUND_DIR="$INSTALL_DIR/Sounds"
SERVICE_FILE="/etc/systemd/system/gps_sender.service"
FLAG_FILE="/tmp/GPS.ENABLED"

echo ""
echo "------------------------------------"
echo "   GPS Node Tracking Uninstaller"
echo "------------------------------------"
echo ""

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

read -p "Remove GPS Node from this system? (y/N): " ANSWER
[[ "$ANSWER" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

echo ""
echo "Stopping GPS service..."

if systemctl is-active --quiet gps_sender.service; then
    systemctl stop gps_sender.service
fi

systemctl disable gps_sender.service >/dev/null 2>&1
rm -f "$SERVICE_FILE"
systemctl daemon-reload
rm -f "$FLAG_FILE"

echo "GPS service removed."

echo ""
echo "Cleaning rpt.conf..."

if [ -f "$RPTCONF" ]; then
    BACKUP="$RPTCONF.gps-backup.$(date +%Y%m%d%H%M%S)"
    cp "$RPTCONF" "$BACKUP"
    sed -i -E '/^[[:space:]]*A5[012][[:space:]]*=.*\/GPS\/gps_(enable|disable|update)\.sh/d' "$RPTCONF"
    echo "rpt.conf cleaned (backup: $BACKUP)"
else
    echo "rpt.conf not found, skipped"
fi

echo ""
echo "Removing GPS files..."

for f in gps_enable.sh gps_disable.sh gps_sender.py gps_sender.py.bak gps_sender.service \
         gps_uninstall.sh gps_update.sh README.md VERSION; do
    rm -f "$INSTALL_DIR/$f"
done

rm -rf "$INSTALL_DIR/backup"
rm -f /etc/sudoers.d/gps_update

rm -rf "$SOUND_DIR"
rmdir "$INSTALL_DIR" 2>/dev/null

echo "Files removed."

echo ""
echo "Reloading Asterisk..."
asterisk -rx "rpt reload" >/dev/null 2>&1

echo ""
echo "GPS Node Tracking uninstalled successfully."
echo "Done."

exit 0
