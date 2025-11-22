#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 1.1 - 11/25
#
# GPS Node Uninstaller
#

INSTALL_DIR="/root/GPS"
RPTCONF="/etc/asterisk/rpt.conf"

echo ""
echo "--------------------"
echo "  GPS Uninstaller"
echo "--------------------"
echo ""

read -p "Enter your node number to remove (numbers only): " NODENUM

if ! [[ "$NODENUM" =~ ^[0-9]+$ ]]; then
    echo "Error: Node number must be numeric."
    exit 1
fi

FUNCTIONS="[functions$NODENUM]"

# --- Stop and disable systemd service ---
if systemctl list-units --all | grep -q gps_sender.service; then
    echo "Stopping gps_sender.service..."
    systemctl stop gps_sender.service
    systemctl disable gps_sender.service
    rm -f /etc/systemd/system/gps_sender.service
    systemctl daemon-reload
    echo "Service removed."
else
    echo "No gps_sender.service found."
fi

# --- Remove scripts + full GPS folder ---
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing entire $INSTALL_DIR directory..."
    rm -rf "$INSTALL_DIR"
    echo "Directory removed."
fi

# --- Remove DTMF commands ---
if [ -f "$RPTCONF" ]; then
    echo "Cleaning rpt.conf..."
    sed -i "/\[functions$NODENUM\]/,/^\[/ s/.*gps_enable.*//" "$RPTCONF"
    sed -i "/\[functions$NODENUM\]/,/^\[/ s/.*gps_disable.*//" "$RPTCONF"
    sed -i "/\[functions$NODENUM\]/,/^\[/ s/^A50 *=.*//" "$RPTCONF"
    sed -i "/\[functions$NODENUM\]/,/^\[/ s/^A51 *=.*//" "$RPTCONF"
fi

echo "Reloading Asterisk..."
asterisk -rx "reload" >/dev/null 2>&1

echo "GPS Node $NODENUM uninstalled successfully."

# --- Self-delete ---
SCRIPT_PATH="$0"
(
  sleep 1
  rm -- "$SCRIPT_PATH"
) &

exit 0
