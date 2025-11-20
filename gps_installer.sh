#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 1.1 -
#
# Clean ASCII-only GitHub Installer for DTMF TG Control
# Prompts for node number and updates the correct functions stanza
#

GITURL="https://raw.githubusercontent.com/Justice57201/GPS_Node/main"

ENABLE_SCRIPT="gps_enable.sh"
DISABLE_SCRIPT="gps_disable.sh"
GPS_PY="gps_sender.py"

RPTCONF="/etc/asterisk/rpt.conf"

echo ""
echo "--------------------"
echo "   GPS Installer"
echo "--------------------"
echo ""

# Make sure /root/GPS exists
mkdir -p /root/GPS

read -p "Enter your node number (numbers only): " NODENUM

# Validate
if ! [[ "$NODENUM" =~ ^[0-9]+$ ]]; then
    echo "Error: Node number must be numbers only."
    exit 1
fi

FUNCTIONS="[functions$NODENUM]"

echo ""
echo "Downloading scripts..."

# Using curl -fsSL to download safely
curl -fsSL "$GITURL/$ENABLE_SCRIPT"  -o /root/GPS/$ENABLE_SCRIPT
curl -fsSL "$GITURL/$DISABLE_SCRIPT" -o /root/GPS/$DISABLE_SCRIPT
curl -fsSL "$GITURL/$GPS_PY"         -o /root/GPS/$GPS_PY

# Verify downloads were successful
if [[ $? -ne 0 ]] || \
   [ ! -s /root/GPS/$ENABLE_SCRIPT ] || \
   [ ! -s /root/GPS/$DISABLE_SCRIPT ] || \
   [ ! -s /root/GPS/$GPS_PY ]; then
    echo "Error: One or more downloads failed."
    exit 1
fi

chmod +x /root/GPS/$ENABLE_SCRIPT
chmod +x /root/GPS/$DISABLE_SCRIPT
chmod +x /root/GPS/$GPS_PY

echo "Scripts installed to /root/GPS"

echo ""
echo "Updating rpt.conf..."

# Remove any existing entries for this node
sed -i "/\[functions$NODENUM\]/,/^\[/ s/.*gps_enable.*//" $RPTCONF
sed -i "/\[functions$NODENUM\]/,/^\[/ s/.*gps_disable.*//" $RPTCONF
sed -i "/\[functions$NODENUM\]/,/^\[/ s/^A50 *=.*//" $RPTCONF
sed -i "/\[functions$NODENUM\]/,/^\[/ s/^A51 *=.*//" $RPTCONF

# Insert the DTMF commands immediately after the stanza header
sed -i "/^\[functions$NODENUM\]/a \
A50 = cmd,/root/GPS/gps_enable.sh\nA51 = cmd,/root/GPS/gps_disable.sh" $RPTCONF

echo "rpt.conf updated for [functions$NODENUM]"

echo ""
echo "Reloading Asterisk..."
asterisk -rx "reload" >/dev/null 2>&1

echo "Done."

# Delete installer only if it was run directly from a file
if [[ "$0" == /* ]] || [[ "$0" == ./* ]]; then
    rm -- "$0"
fi
