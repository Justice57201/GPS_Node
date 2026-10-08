#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 3.1 - 10/26
#
# GPS Node Tracking - Installer (HamVoIP + ASL3)
#

REPO_RAW="https://raw.githubusercontent.com/Justice57201/GPS_Node/main"
HAMVOIP_FOLDER="Hamvoip" 
ASL3_FOLDER="ASL3"
SOUNDS_FOLDER="Sounds"

NODE_FILES="gps_sender.py gps_enable.sh gps_disable.sh gps_uninstall.sh gps_update.sh gps_sender.service"
SOUND_FILES="enabled.gsm disabled.gsm"

RPTCONF="/etc/asterisk/rpt.conf"
SERVICE_FILE="/etc/systemd/system/gps_sender.service"

echo ""
echo "------------------------------------"
echo "   GPS Node Tracking Installer"
echo "------------------------------------"
echo ""

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

detect_system() {
    if [ -f /usr/local/etc/allstar.env ] || [ -f /etc/arch-release ]; then
        echo "hamvoip"
    elif [ -f /etc/debian_version ]; then
        echo "asl3"
    else
        echo "unknown"
    fi
}

SYSTEM=$(detect_system)

if [ "$SYSTEM" = "unknown" ]; then
    echo "Could not tell if this is HamVoIP or ASL3."
else
    [ "$SYSTEM" = "hamvoip" ] && NAME="HamVoIP" || NAME="ASL3"
    read -p "Detected: $NAME. Is that right? (Y/n): " OK
    [[ "$OK" =~ ^[Nn]$ ]] && SYSTEM="unknown"
fi

if [ "$SYSTEM" = "unknown" ]; then
    echo "  1) HamVoIP"
    echo "  2) ASL3"
    read -p "Choose 1 or 2: " PICK
    case "$PICK" in
        1) SYSTEM="hamvoip" ;;
        2) SYSTEM="asl3" ;;
        *) echo "Cancelled."; exit 1 ;;
    esac
fi

if [ "$SYSTEM" = "hamvoip" ]; then
    NAME="HamVoIP"
    FOLDER="$HAMVOIP_FOLDER"
    INSTALL_DIR="/root/GPS"
    PYTHON="python2"
    UPDATE_CMD="$INSTALL_DIR/gps_update.sh"
else
    NAME="ASL3"
    FOLDER="$ASL3_FOLDER"
    INSTALL_DIR="/opt/GPS"
    PYTHON="python3"
    UPDATE_CMD="sudo -n $INSTALL_DIR/gps_update.sh" 
fi
SOUND_DIR="$INSTALL_DIR/Sounds"

echo ""
echo "Installing the $NAME version to $INSTALL_DIR"

find_node() {
    if [ -n "$NODE1" ]; then echo "$NODE1"; return; fi
    if [ -f /usr/local/etc/allstar.env ]; then
        . /usr/local/etc/allstar.env >/dev/null 2>&1
        if [ -n "$NODE1" ]; then echo "$NODE1"; return; fi
    fi
    asterisk -rx "rpt localnodes" 2>/dev/null \
        | grep -E '^[[:space:]]*[0-9]+[[:space:]]*$' | head -n1 | tr -d '[:space:]'
}

FOUND_NODE=$(find_node)
echo ""
if [ -n "$FOUND_NODE" ]; then
    read -p "Enter your node number [$FOUND_NODE]: " NODENUM
    NODENUM=${NODENUM:-$FOUND_NODE}
else
    read -p "Enter your node number (numbers only): " NODENUM
fi

if ! [[ "$NODENUM" =~ ^[0-9]+$ ]]; then
    echo "Error: Node number must be numeric."
    exit 1
fi

echo ""
echo "Checking Python..."

if ! command -v "$PYTHON" >/dev/null 2>&1; then
    echo "ERROR: $PYTHON was not found. Is this really $NAME?"
    exit 1
fi

if ! "$PYTHON" -c "import serial" >/dev/null 2>&1; then
    if [ "$SYSTEM" = "asl3" ]; then
        echo "Installing python3-serial..."
        apt-get update -qq && apt-get install -y -qq python3-serial || {
            echo "ERROR: Could not install python3-serial"
            exit 1
        }
    else
        echo "WARNING: pyserial for Python 2 is missing -- the sender can't read the GPS until it's installed."
    fi
fi

echo ""
echo "Downloading files..."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for F in $NODE_FILES; do
    curl -fsSL "$REPO_RAW/$FOLDER/$F" -o "$TMP/$F" || {
        echo "ERROR: Failed to download $FOLDER/$F"
        exit 1
    }
done

for F in $SOUND_FILES; do
    curl -fsSL "$REPO_RAW/$SOUNDS_FOLDER/$F" -o "$TMP/$F" || {
        echo "ERROR: Failed to download $SOUNDS_FOLDER/$F"
        exit 1
    }
done

systemctl stop gps_sender.service >/dev/null 2>&1

mkdir -p "$SOUND_DIR"

if [ -f "$INSTALL_DIR/gps_sender.py" ]; then
    cp "$INSTALL_DIR/gps_sender.py" "$INSTALL_DIR/gps_sender.py.bak"
    echo "Old gps_sender.py saved as gps_sender.py.bak (your previous settings)"
fi

for F in gps_sender.py gps_enable.sh gps_disable.sh gps_uninstall.sh gps_update.sh; do
    mv "$TMP/$F" "$INSTALL_DIR/$F"
    chmod 755 "$INSTALL_DIR/$F"
done

for F in $SOUND_FILES; do
    mv "$TMP/$F" "$SOUND_DIR/$F"
    chmod 644 "$SOUND_DIR/$F"
done

chmod 755 "$INSTALL_DIR" "$SOUND_DIR"

echo "Files installed to $INSTALL_DIR"

if [ "$SYSTEM" = "asl3" ]; then
    SUDOERS="/etc/sudoers.d/gps_update"
    echo "asterisk ALL=(root) NOPASSWD: $INSTALL_DIR/gps_update.sh" > "$SUDOERS.tmp"
    chmod 440 "$SUDOERS.tmp"
    if command -v visudo >/dev/null 2>&1 && ! visudo -cf "$SUDOERS.tmp" >/dev/null 2>&1; then
        rm -f "$SUDOERS.tmp"
        echo "WARNING: could not set up DTMF updates (*A52) -- run $INSTALL_DIR/gps_update.sh by hand instead"
    else
        mv "$SUDOERS.tmp" "$SUDOERS"
    fi
fi

echo ""
echo "Updating rpt.conf..."

find_functions_stanza() {
    local name
    name=$(awk -v n="$NODENUM" '
        /^\[/ { insec = (index($0, "[" n "]") == 1) }
        insec && /^[[:space:]]*functions[[:space:]]*=/ {
            sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:];].*$/, ""); print; exit
        }' "$RPTCONF")
    for cand in "$name" "functions$NODENUM" "functions"; do
        [ -n "$cand" ] && grep -q "^\[$cand\]" "$RPTCONF" && { echo "$cand"; return; }
    done
}

LINE50="A50 = cmd,$INSTALL_DIR/gps_enable.sh"
LINE51="A51 = cmd,$INSTALL_DIR/gps_disable.sh"
LINE52="A52 = cmd,$UPDATE_CMD"
RPT_DONE=0

if [ ! -f "$RPTCONF" ]; then
    echo "WARNING: $RPTCONF not found"
else
    STANZA=$(find_functions_stanza)
    if [ -z "$STANZA" ]; then
        echo "WARNING: Could not find the functions section for node $NODENUM"
    else
        BACKUP="$RPTCONF.gps-backup.$(date +%Y%m%d%H%M%S)"
        cp "$RPTCONF" "$BACKUP"

        sed -i -E '/^[[:space:]]*A5[012][[:space:]]*=.*\/GPS\/gps_(enable|disable|update)\.sh/d' "$RPTCONF"

        OTHER=$(awk -v hdr="[$STANZA]" '
            /^\[/ { insec = (index($0, hdr) == 1) }
            insec && /^[[:space:]]*A5[012][[:space:]]*=/' "$RPTCONF")

        GO=1
        if [ -n "$OTHER" ]; then
            echo ""
            echo "A50 / A51 / A52 are already used in [$STANZA]:"
            echo "$OTHER" | sed 's/^/    /'
            read -p "Replace them with the GPS commands? (y/N): " REPLACE
            if [[ "$REPLACE" =~ ^[Yy]$ ]]; then
                awk -v hdr="[$STANZA]" '
                    /^\[/ { insec = (index($0, hdr) == 1) }
                    !(insec && /^[[:space:]]*A5[012][[:space:]]*=/)' "$RPTCONF" > "$TMP/rpt.new" \
                    && cat "$TMP/rpt.new" > "$RPTCONF"
            else
                GO=0
            fi
        fi

        if [ "$GO" = "1" ]; then
            awk -v hdr="[$STANZA]" -v l1="$LINE50" -v l2="$LINE51" -v l3="$LINE52" '
                { print }
                !done && index($0, hdr) == 1 { print l1; print l2; print l3; done = 1 }' "$RPTCONF" > "$TMP/rpt.new" \
                && cat "$TMP/rpt.new" > "$RPTCONF"
            RPT_DONE=1
            echo "rpt.conf updated in [$STANZA] (backup: $BACKUP)"
        fi
    fi
fi

if [ "$RPT_DONE" = "0" ]; then
    echo ""
    echo "Add these lines to your node's functions section in $RPTCONF by hand:"
    echo "    $LINE50"
    echo "    $LINE51"
    echo "    $LINE52"
fi

echo ""
echo "Setting up the gps_sender service..."

mv "$TMP/gps_sender.service" "$SERVICE_FILE"
chmod 644 "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable gps_sender.service >/dev/null 2>&1
systemctl restart gps_sender.service

echo "Service installed and started."

echo ""
echo "Reloading Asterisk..."
asterisk -rx "rpt reload" >/dev/null 2>&1

echo ""
echo "------------------------------------"
echo "   Done -- $NAME version installed"
echo "------------------------------------"
echo ""
echo "Next steps:"
echo "  1. Edit your settings:   nano $INSTALL_DIR/gps_sender.py"
echo "  2. Restart the service:  systemctl restart gps_sender.service"
echo "  3. Turn tracking on:     *A50   (off: *A51)"
echo "  4. Watch the log:        journalctl -u gps_sender -f"
echo "  5. Update later:         $INSTALL_DIR/gps_update.sh   (or *A52)"
echo ""

if [[ "$0" == /* ]] || [[ "$0" == ./* ]]; then
    rm -- "$0"
fi
