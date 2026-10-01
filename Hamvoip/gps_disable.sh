#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 1.2 - 10/26
#
# GPS Node Tracking - Disable 

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

FLAG_FILE="/tmp/GPS.ENABLED"
SOUND="/root/GPS/Sounds/disabled"

get_node() {
    if [ -n "$NODE1" ]; then echo "$NODE1"; return; fi
    if [ -f /usr/local/etc/allstar.env ]; then
        . /usr/local/etc/allstar.env >/dev/null 2>&1
        if [ -n "$NODE1" ]; then echo "$NODE1"; return; fi
    fi
    asterisk -rx "rpt localnodes" 2>/dev/null \
        | grep -E '^[[:space:]]*[0-9]+[[:space:]]*$' | head -n1 | tr -d '[:space:]'
}

rm -f "$FLAG_FILE"

NODE=$(get_node)
if [ -n "$NODE" ]; then
    asterisk -rx "rpt localplay $NODE $SOUND" >/dev/null 2>&1
else
    logger -t GPS "Could not find the node number - no announcement played"
fi

logger -t GPS "GPS DISABLED"
