#!/usr/bin/env python2
# -*- coding: utf-8 -*-
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 7 - 12/25 -- Flag file + Auth
#

import serial, socket, time, json, os

DEVICE = '/dev/ttyACM0'
BAUDRATE = 4800
SERVER_HOST = 'gps.gmrs-link.com'
SERVER_PORT = 5008

#-----------------------------------------#
#               USER CONFIG               #
#-----------------------------------------#

CALLSIGN = 'YOUR-CALL-NODE'   # Callsign-Node#
ICON = 'marker_blue'          # See icon list
DEBUG = False                 # Debug output
SEND_INTERVAL = 120           # Seconds
INCLUDE_SPEED = False         # True / False
INCLUDE_TRAIL = False         # True / False
 
# ---- Credentials From Registration ---- #

AUTH_USER = "USERNAME"        # Username
AUTH_PASS = "PASSWORD"        # Password
                                
# --------------------------------------- #

FLAG_FILE = "/tmp/GPS.ENABLED"

def convert_to_decimal(value, direction, is_lon=False):
    try:
        if is_lon:
            deg = float(value[:3])
            minutes = float(value[3:])
        else:
            deg = float(value[:2])
            minutes = float(value[2:])
        dec = deg + minutes / 60.0
        if direction in ['S', 'W']:
            dec = -dec
        return round(dec, 5)
    except:
        return 0.0

def knots_to_mph(knots):
    try:
        return round(float(knots) * 1.15078, 1)
    except:
        return 0.0

# Open serial port
try:
    ser = serial.Serial(DEVICE, BAUDRATE, timeout=1)
    if DEBUG:
        print("[DEBUG] Serial port {} opened at {} baud".format(DEVICE, BAUDRATE))
except Exception as e:
    print("Error opening serial port:", e)
    raise SystemExit(1)

while True:
    try:
        if not os.path.exists(FLAG_FILE):
            time.sleep(1)
            continue

        line = ser.readline().strip()
        if not line:
            continue

        if DEBUG:
            print("[DEBUG] Raw GPS line: {}".format(line))

        if line.startswith('$GPRMC'):
            parts = line.split(',')

            if len(parts) > 6 and parts[2] == 'A':
                lat = convert_to_decimal(parts[3], parts[4], is_lon=False)
                lon = convert_to_decimal(parts[5], parts[6], is_lon=True)
                speed = knots_to_mph(parts[7]) if (INCLUDE_SPEED and len(parts) > 7) else 0.0

                msg = {
                    "node": CALLSIGN,
                    "lat": lat,
                    "lon": lon,
                    "icon": ICON,
                    "speed": speed if INCLUDE_SPEED else None,
                    "trail": True if INCLUDE_TRAIL else False
                }

                payload = json.dumps(msg) + "\n"

                if DEBUG:
                    print("[DEBUG] Sending JSON: {}".format(payload))

                try:
                    server_ip = socket.gethostbyname(SERVER_HOST)
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.connect((server_ip, SERVER_PORT))

                    auth_line = "AUTH {} {}\n".format(AUTH_USER, AUTH_PASS)
                    sock.sendall(auth_line.encode('utf-8'))

                    response = sock.recv(1024)
                    if DEBUG:
                        print("[DEBUG] Server response: {}".format(response))

                    if not response.startswith(b"OK"):
                        print("Server rejected authentication, skipping send")
                        sock.close()
                        continue

                    sock.sendall(payload.encode('utf-8'))

                    time.sleep(0.1)
                    sock.close()

                    if DEBUG:
                        print("[DEBUG] Sent successfully to {}:{}".format(server_ip, SERVER_PORT))

                except Exception as e:
                    print("Error sending data:", e)

                time.sleep(SEND_INTERVAL)

    except KeyboardInterrupt:
        print("\nExiting.")
        ser.close()
        break

    except Exception as e:
        print("Error:", e)
