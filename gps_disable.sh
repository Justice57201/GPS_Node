#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 1.0 - 
#

rm -f /tmp/GPS.ENABLED

asterisk -rx "rpt localplay $NODE1 /root/GPS/Sound/disabled"

echo "GPS DISABLED" | logger
