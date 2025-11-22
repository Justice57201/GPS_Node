#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 2.0 -
#
# Complete GPS Node Installer for DTMF TG Control
# Installs enable/disable scripts and gps_sender.py with systemd service
#

# --- GitHub Raw URLs ---
ENABLE_SCRIPT_URL="https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_enable.sh"
DISABLE_SCRIPT_URL="https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_disable.sh"
GPS_PY_URL="https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_sender.py"
GPS_UNI_URL="https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_uninstall.sh"

RPTCONF="/etc/asterisk/rpt.conf"
INSTALL_DIR="/root/GPS"

echo ""
echo "--------------------"
echo "   GPS Installer"
echo "--------------------"
echo ""

# --- Create installation directory ---
mkdir -p "$INSTALL_DIR"

# --- Prompt for node number ---
read -p "Enter your node number (numbers only): " NODENUM

if ! [[ "$NODENUM" =~ ^[0-9]+$ ]]; then
    echo "Error: Node number must be numeric."
    exit 1
fi

FUNCTIONS="[functions$NODENUM]"

echo ""
echo "Downloading scripts..."

# --- Download scripts using curl ---
for FILE_URL in "$ENABLE_SCRIPT_URL" "$DISABLE_SCRIPT_URL" "$GPS_PY_URL" "$GPS_UNI_URL"; do
    FILE_NAME=$(basename "$FILE_URL")
    curl -fsSL "$FILE_URL" -o "$INSTALL_DIR/$FILE_NAME" || {
        echo "ERROR: Failed to download $FILE_NAME"
        exit 1
    }
done

# --- Make scripts executable ---
chmod +x "$INSTALL_DIR/gps_enable.sh"
chmod +x "$INSTALL_DIR/gps_disable.sh"
chmod +x "$INSTALL_DIR/gps_sender.py"
chmod +x "$INSTALL_DIR/gps_uninstall.sh"

echo "Scripts installed to $INSTALL_DIR"

echo ""
echo "Updating rpt.conf..."

# --- Clean existing entries for this node ---
sed -i "/\[functions$NODENUM\]/,/^\[/ s/.*gps_enable.*//" "$RPTCONF"
sed -i "/\[functions$NODENUM\]/,/^\[/ s/.*gps_disable.*//" "$RPTCONF"
sed -i "/\[functions$NODENUM\]/,/^\[/ s/^A50 *=.*//" "$RPTCONF"
sed -i "/\[functions$NODENUM\]/,/^\[/ s/^A51 *=.*//" "$RPTCONF"

# --- Insert DTMF commands ---
sed -i "/^\[functions$NODENUM\]/a \
A50 = cmd,$INSTALL_DIR/gps_enable.sh\nA51 = cmd,$INSTALL_DIR/gps_disable.sh" "$RPTCONF"

echo "rpt.conf updated for $FUNCTIONS"

echo ""
echo "Creating systemd service for gps_sender.py..."

SERVICE_FILE="/etc/systemd/system/gps_sender.service"

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=GPS Sender Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python2 $INSTALL_DIR/gps_sender.py
Restart=always
User=root
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

# --- Enable and start the service ---
systemctl daemon-reload
systemctl enable gps_sender.service
systemctl start gps_sender.service

echo "gps_sender.py service created and started."

echo ""
echo "Reloading Asterisk..."
asterisk -rx "reload" >/dev/null 2>&1

echo "Done."

# --- Delete installer if run directly as a file ---
if [[ "$0" == /* ]] || [[ "$0" == ./* ]]; then
    rm -- "$0"
fi
