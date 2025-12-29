#!/bin/bash
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 1.0 - 
#

touch /tmp/GPS.ENABLED

asterisk -rx "rpt localplay $NODE1 /root/GPS/Sounds/enabled"

echo "GPS ENABLED" | logger
