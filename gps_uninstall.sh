#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# GPS Node Uninstaller
#

RPTCONF="/etc/asterisk/rpt.conf"
INSTALL_DIR="/root/GPS"
SOUND_DIR="/root/GPS/Sounds"
SERVICE_FILE="/etc/systemd/system/gps_sender.service"

echo ""
echo "------------------------"
echo "   GPS Uninstaller"
echo "------------------------"
echo ""

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

read -p "Enter your node number to REMOVE (numbers only): " NODENUM

if ! [[ "$NODENUM" =~ ^[0-9]+$ ]]; then
    echo "Error: Node number must be numeric."
    exit 1
fi

echo ""
echo "Stopping GPS service..."

if systemctl is-active --quiet gps_sender.service; then
    systemctl stop gps_sender.service
fi

systemctl disable gps_sender.service >/dev/null 2>&1
rm -f "$SERVICE_FILE"
systemctl daemon-reload

echo "GPS service removed."

echo ""
echo "Cleaning rpt.conf..."

sed -i "/^\[functions$NODENUM\]/,/^\[/ {
    /^A50 *=/d
    /^A51 *=/d
}" "$RPTCONF"

echo "rpt.conf cleaned for functions$NODENUM"

echo ""
echo "Removing GPS files..."

rm -f "$INSTALL_DIR/gps_enable.sh"
rm -f "$INSTALL_DIR/gps_disable.sh"
rm -f "$INSTALL_DIR/gps_sender.py"
rm -f "$INSTALL_DIR/gps_uninstall.sh"

rm -rf "$SOUND_DIR"

rmdir "$INSTALL_DIR" 2>/dev/null

echo "Files removed."

echo ""
echo "Reloading Asterisk..."
asterisk -rx "rpt reload" >/dev/null 2>&1

echo ""
echo "GPS Node uninstalled successfully."
echo "Done."

exit 0

