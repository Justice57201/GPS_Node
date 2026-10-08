#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 1.0 - 10/26
#
# GPS Node Tracking - Updater
#
# Usage:  /opt/GPS/gps_update.sh            update if GitHub has a newer version
#         /opt/GPS/gps_update.sh --force    reinstall even if the version is the same or older
#
# DTMF:   *A52 runs it in the background; the result goes to the log (journalctl -t GPS)
#

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

REPO_RAW="https://raw.githubusercontent.com/Justice57201/GPS_Node/main"
REPO_FOLDER="ASL3"
SOUNDS_FOLDER="Sounds"
INSTALL_DIR="/opt/GPS"
SOUND_DIR="$INSTALL_DIR/Sounds"
BACKUP_DIR="$INSTALL_DIR/backup"
KEEP_BACKUPS=3
PYTHON="python3"
SERVICE="gps_sender.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE"
LOCK_DIR="/tmp/gps_update.lock"

NODE_FILES="gps_sender.py gps_enable.sh gps_disable.sh gps_uninstall.sh gps_update.sh gps_sender.service"
SOUND_FILES="enabled.gsm disabled.gsm"

FORCE=0
[ "$1" = "--force" ] && FORCE=1

if [ ! -t 0 ] && [ -z "$GPS_UPDATE_BG" ]; then
    GPS_UPDATE_BG=1 setsid "$0" "$@" </dev/null >/dev/null 2>&1 &
    exit 0
fi

say() {
    echo "$*"
    logger -t GPS "update: $*"
}

fail() {
    say "FAILED: $*"
    exit 1
}

[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    say "Another update is already running"
    exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP" "$LOCK_DIR"' EXIT

[ -f "$INSTALL_DIR/gps_sender.py" ] || fail "$INSTALL_DIR/gps_sender.py not found -- run the installer first"

get_version() {
    sed -n 's/^VERSION[[:space:]]*=[[:space:]]*["'"'"']\([^"'"'"']*\)["'"'"'].*/\1/p' "$1" | head -n1
}

say "Checking GitHub for updates..."
for F in $NODE_FILES; do
    curl -fsSL "$REPO_RAW/$REPO_FOLDER/$F" -o "$TMP/$F" || fail "could not download $REPO_FOLDER/$F"
done

OLD_VER=$(get_version "$INSTALL_DIR/gps_sender.py")
NEW_VER=$(get_version "$TMP/gps_sender.py")
[ -n "$NEW_VER" ] || fail "the gps_sender.py on GitHub has no VERSION line"
[ -n "$OLD_VER" ] || OLD_VER="unknown"

if [ "$FORCE" -eq 0 ]; then
    if [ "$OLD_VER" = "$NEW_VER" ]; then
        say "Already up to date (Ver $OLD_VER)"
        exit 0
    fi
    HIGHER=$(printf '%s\n%s\n' "$OLD_VER" "$NEW_VER" | sort -V | tail -n1)
    if [ "$OLD_VER" != "unknown" ] && [ "$HIGHER" = "$OLD_VER" ]; then
        say "Installed Ver $OLD_VER is newer than GitHub Ver $NEW_VER -- nothing to do (use --force to install it anyway)"
        exit 0
    fi
fi

say "Updating Ver $OLD_VER -> Ver $NEW_VER"

GOT_SOUNDS=""
for F in $SOUND_FILES; do
    if curl -fsSL "$REPO_RAW/$SOUNDS_FOLDER/$F" -o "$TMP/$F" 2>/dev/null; then
        GOT_SOUNDS="$GOT_SOUNDS $F"
    else
        rm -f "$TMP/$F"
    fi
done

cat > "$TMP/merge.py" <<'PYEOF'
import ast, re, sys

old_path, new_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
SKIP = ("VERSION", "SERVER_HOST", "SERVER_PORT")
BANNER = "Do Not Touch Below"
ASSIGN = re.compile(r'^([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$')

def split_comment(rest):
    """Split 'value   # comment' -> (value, comment_or_None), ignoring # inside quotes."""
    quote = None
    i = 0
    while i < len(rest):
        c = rest[i]
        if quote:
            if c == '\\':
                i += 1
            elif c == quote:
                quote = None
        elif c in ('"', "'"):
            quote = c
        elif c == '#':
            return rest[:i].rstrip(), rest[i:]
        i += 1
    return rest.rstrip(), None

def settings(lines, stop_at_banner):
    found = {}
    for line in lines:
        if stop_at_banner and BANNER in line:
            break
        m = ASSIGN.match(line.rstrip('\r\n'))
        if not m or m.group(1) in found:
            continue
        value, _ = split_comment(m.group(2))
        try:
            ast.literal_eval(value)
        except Exception:
            continue
        found[m.group(1)] = value
    return found

old_lines = open(old_path).readlines()
new_lines = open(new_path).readlines()
old = settings(old_lines, stop_at_banner=False)

out, kept, defaults = [], [], []
above = True
for line in new_lines:
    if BANNER in line:
        above = False
    m = ASSIGN.match(line.rstrip('\r\n')) if above else None
    if m and m.group(1) not in SKIP:
        key = m.group(1)
        new_value, comment = split_comment(m.group(2))
        if key in old:
            if old[key] != new_value:
                prefix = "%s = %s" % (key, old[key])
                if comment:
                    col = line.index(comment) if comment in line else len(prefix) + 1
                    prefix = prefix + " " * max(1, col - len(prefix)) + comment
                line = prefix + "\n"
            kept.append(key)
        else:
            defaults.append(key)
    out.append(line)

open(out_path, "w").write("".join(out))
print("KEPT " + " ".join(kept))
print("NEW " + " ".join(defaults))
PYEOF

MERGE_OUT=$("$PYTHON" -B "$TMP/merge.py" "$INSTALL_DIR/gps_sender.py" "$TMP/gps_sender.py" "$TMP/gps_sender.merged.py") \
    || fail "could not carry your settings into the new version"
mv "$TMP/gps_sender.merged.py" "$TMP/gps_sender.py"
NEW_SETTINGS=$(echo "$MERGE_OUT" | sed -n 's/^NEW //p')

mkdir -p "$TMP/check" && cp "$TMP/gps_sender.py" "$TMP/check/"
"$PYTHON" -B -c "import py_compile, sys; py_compile.compile(sys.argv[1], doraise=True)" "$TMP/check/gps_sender.py" 2>/dev/null \
    || fail "the new gps_sender.py has an error -- nothing was changed"

config_ok() { 
    "$PYTHON" -B - "$1" <<'PYEOF' >/dev/null 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import gps_sender as g
g.build_node_name()
if hasattr(g, "check_login_config"):
    g.check_login_config()
PYEOF
}
mkdir -p "$TMP/oldcheck" && cp "$INSTALL_DIR/gps_sender.py" "$TMP/oldcheck/"
if ! config_ok "$TMP/check"; then
    if config_ok "$TMP/oldcheck"; then
        fail "your settings don't pass the new version's checks -- nothing was changed"
    fi
    say "Note: CALLSIGN / login aren't set yet -- edit $INSTALL_DIR/gps_sender.py after the update"
fi

STAMP=$(date +%Y%m%d-%H%M%S)
BK="$BACKUP_DIR/Ver_${OLD_VER}_$STAMP"
[ -e "$BK" ] && BK="${BK}_$$"
mkdir -p "$BK"
for F in $NODE_FILES; do
    if [ "$F" = "gps_sender.service" ]; then
        [ -f "$SERVICE_FILE" ] && cp -p "$SERVICE_FILE" "$BK/$F"
    else
        [ -f "$INSTALL_DIR/$F" ] && cp -p "$INSTALL_DIR/$F" "$BK/$F"
    fi
done
for F in $SOUND_FILES; do
    [ -f "$SOUND_DIR/$F" ] && cp -p "$SOUND_DIR/$F" "$BK/$F"
done

ls -1dt "$BACKUP_DIR"/Ver_* 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | while read -r OLD; do rm -rf "$OLD"; done

restore() {
    say "Restoring the previous version from $BK"
    for F in $NODE_FILES; do
        [ -f "$BK/$F" ] || continue
        if [ "$F" = "gps_sender.service" ]; then
            cp -p "$BK/$F" "$SERVICE_FILE"
        else
            cp -p "$BK/$F" "$INSTALL_DIR/$F"
        fi
    done
    systemctl daemon-reload
    systemctl restart "$SERVICE"
}

SERVICE_CHANGED=0
if ! cmp -s "$TMP/gps_sender.service" "$SERVICE_FILE"; then
    SERVICE_CHANGED=1
fi

for F in gps_sender.py gps_enable.sh gps_disable.sh gps_uninstall.sh gps_update.sh; do
    chmod 755 "$TMP/$F"
    mv -f "$TMP/$F" "$INSTALL_DIR/$F"
done
mkdir -p "$SOUND_DIR"
for F in $GOT_SOUNDS; do
    chmod 644 "$TMP/$F"
    mv -f "$TMP/$F" "$SOUND_DIR/$F"
done
chmod 755 "$INSTALL_DIR" "$SOUND_DIR"
if [ "$SERVICE_CHANGED" -eq 1 ]; then
    chmod 644 "$TMP/gps_sender.service"
    mv -f "$TMP/gps_sender.service" "$SERVICE_FILE"
fi

systemctl daemon-reload
systemctl restart "$SERVICE"

sleep 8
if ! systemctl is-active --quiet "$SERVICE"; then
    restore
    fail "Ver $NEW_VER did not start -- Ver $OLD_VER was put back"
fi

say "Updated to Ver $NEW_VER (backup: $BK)"
[ -n "$NEW_SETTINGS" ] && say "New settings with default values: $NEW_SETTINGS"
exit 0
