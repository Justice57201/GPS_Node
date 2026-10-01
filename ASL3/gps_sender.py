#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 12.2 - 10/26
#
# GPS Node Tracking - Sender


from __future__ import print_function
import serial, socket, time, json, os, re

VERSION = "12.2"

DEVICE = '/dev/ttyACM0'
BAUDRATE = 4800
SERVER_HOST = 'gps.gmrs-link.com'
SERVER_PORT = 5008

#-----------------------------------------#
#               USER CONFIG               #
#-----------------------------------------#

CALLSIGN = 'YOUR_CALLSIGN'    # Your callsign only -- no dash or number
SSID = 1                      # 1 = callsign alone (WRQC343)
                              # 2 and up = extra units (WRQC343-2, WRQC343-3 ...)
ICON = 'pin_blue'             # See pin list
DEBUG = False                 # Debug output
SEND_INTERVAL = 60            # Seconds (the server sets the minimum, 30 by default)
INCLUDE_SPEED = False         # True / False
INCLUDE_TRAIL = False         # True / False

OVERRIDE_ALWAYS_RUN = False   # True = ignore flag file and always run

# ---- Map extras (all optional) ---- #

INCLUDE_HEADING = True        # Direction arrow on the map while moving
INCLUDE_GPS_INFO = True       # Altitude + satellite count in the popup
NODE_TYPE = ''                # 'mobile', 'base', 'repeater', 'portable' or '' for none
NETWORK = ''                  # Network name, e.g. 'T.G.L.N', 'G.F.N', 'N.E.G', '' for none (20 max limit)
NODE_LINK = ''                # Status page URL, e.g. 'https://...' -- '' for none

# ---- Credentials From Registration ---- #

AUTH_USER = "YOUR_USERNAME"   # Username
AUTH_PASS = "YOUR_PASSWORD"   # Password

# --------------------------------------- #

FLAG_FILE = "/tmp/GPS.ENABLED"
GGA_MAX_AGE = 10              # Seconds -- altitude/sats older than this aren't sent
SOCKET_TIMEOUT = 10           # Seconds to wait on the server
SERIAL_RETRY = 10             # Seconds between tries if the GPS is unplugged


def build_node_name():
    """CALLSIGN + SSID -> name shown on the map. The server decides which SSIDs it accepts."""
    call = str(CALLSIGN).strip().upper()
    if not call or call == 'YOUR_CALLSIGN':
        raise ValueError("Set CALLSIGN in the USER CONFIG section (your callsign only, e.g. 'WLMR400')")
    if not re.match(r'^[A-Z0-9]+$', call):
        raise ValueError("CALLSIGN must be letters and numbers only, e.g. 'WLMR400' "
                         "(put the unit number in SSID, not in CALLSIGN)")
    try:
        ssid = int(SSID)
    except (TypeError, ValueError):
        raise ValueError("SSID must be a whole number (1 = callsign alone)")
    if ssid == 1:
        return call
    return "{}-{}".format(call, ssid)


def check_login_config():
    """Catch the registration placeholders before they cause failed logins."""
    if AUTH_USER in ('', 'YOUR_USERNAME') or AUTH_PASS in ('', 'YOUR_PASSWORD'):
        raise ValueError("Set AUTH_USER and AUTH_PASS in the USER CONFIG section "
                         "(from your registration e-mail)")


def debug(msg):
    if DEBUG:
        print("[DEBUG] {}".format(msg))


def nmea_checksum_ok(line):
    if '*' not in line:
        return True
    body, _, cs = line[1:].partition('*')
    try:
        want = int(cs[:2], 16)
    except ValueError:
        return False
    calc = 0
    for ch in body:
        calc ^= ord(ch)
    return calc == want


def convert_to_decimal(value, direction, is_lon=False):
    try:
        d = 3 if is_lon else 2
        deg = float(value[:d])
        minutes = float(value[d:])
    except (ValueError, TypeError):
        return None
    dec = deg + minutes / 60.0
    if direction in ('S', 'W'):
        dec = -dec
    elif direction not in ('N', 'E'):
        return None
    return round(dec, 5)


def knots_to_mph(knots):
    try:
        return round(float(knots) * 1.15078, 1)
    except (ValueError, TypeError):
        return 0.0


def parse_rmc(line):
    if len(line) < 7 or line[0] != '$' or line[3:6] != 'RMC':
        return None
    if not nmea_checksum_ok(line):
        debug("Bad checksum: {}".format(line))
        return None
    parts = line.split('*')[0].split(',')
    if len(parts) < 8 or parts[2] != 'A': 
        return None
    lat = convert_to_decimal(parts[3], parts[4], is_lon=False)
    lon = convert_to_decimal(parts[5], parts[6], is_lon=True)
    if lat is None or lon is None:
        return None
    course = None
    if len(parts) > 8 and parts[8]:
        try:
            course = float(parts[8]) % 360.0
        except ValueError:
            course = None
    return {"lat": lat, "lon": lon, "speed": knots_to_mph(parts[7]), "course": course}


def parse_gga(line):
    if len(line) < 7 or line[0] != '$' or line[3:6] != 'GGA':
        return None
    if not nmea_checksum_ok(line):
        return None
    parts = line.split('*')[0].split(',')
    if len(parts) < 10 or parts[6] in ('', '0'):
        return None
    info = {}
    try:
        info["sats"] = int(parts[7])
    except ValueError:
        pass
    try:
        info["alt"] = round(float(parts[9]), 1) 
    except ValueError:
        pass
    return info or None


def read_line(ser):
    raw = ser.readline()
    if not raw:
        return ""
    if not isinstance(raw, str):  
        raw = raw.decode('ascii', 'ignore')
    return raw.strip()


def flush_input(ser):
    try:
        if hasattr(ser, 'reset_input_buffer'):
            ser.reset_input_buffer() 
        else:
            ser.flushInput()           
    except Exception:
        pass


def open_serial():
    while True:
        try:
            ser = serial.Serial(DEVICE, BAUDRATE, timeout=1)
            debug("Serial port {} opened at {} baud".format(DEVICE, BAUDRATE))
            return ser
        except Exception as e:
            print("Error opening serial port {}: {} (retry in {}s)".format(DEVICE, e, SERIAL_RETRY))
            time.sleep(SERIAL_RETRY)


SERVER_MIN_INTERVAL = 0 


def learn_min_interval(reply_text):
    """Server replies end with MIN_INTERVAL=<seconds>; never send faster than that."""
    global SERVER_MIN_INTERVAL
    m = re.search(r'MIN_INTERVAL=(\d+)', reply_text or '')
    if not m:
        return
    new_min = int(m.group(1))
    if new_min != SERVER_MIN_INTERVAL:
        SERVER_MIN_INTERVAL = new_min
        if SEND_INTERVAL < new_min:
            print("SEND_INTERVAL {}s is below the server minimum -- using {}s".format(SEND_INTERVAL, new_min))


def send_interval():
    return max(SEND_INTERVAL, SERVER_MIN_INTERVAL)


def gps_enabled():
    return OVERRIDE_ALWAYS_RUN or os.path.exists(FLAG_FILE)


def send_position(node_name, fix, gga=None):
    msg = {
        "node": node_name,
        "lat": fix["lat"],
        "lon": fix["lon"],
        "icon": ICON,
        "trail": bool(INCLUDE_TRAIL)
    }
    if INCLUDE_SPEED:
        msg["speed"] = fix["speed"]
    if INCLUDE_HEADING and fix.get("course") is not None:
        msg["course"] = round(fix["course"])
        msg["course_speed"] = fix["speed"]
    if INCLUDE_GPS_INFO and gga:
        msg.update(gga)
    if NODE_TYPE:
        msg["type"] = NODE_TYPE
    net = str(NETWORK or '').strip()
    if net:
        msg["network"] = net
    if NODE_LINK:
        msg["link"] = NODE_LINK

    payload = json.dumps(msg) + "\n"
    debug("Sending JSON: {}".format(payload.strip()))

    sock = None
    try:
        sock = socket.create_connection((SERVER_HOST, SERVER_PORT), SOCKET_TIMEOUT)
        sock.settimeout(SOCKET_TIMEOUT)

        auth_line = "AUTH {} {}\n".format(AUTH_USER, AUTH_PASS)
        sock.sendall(auth_line.encode('utf-8'))

        response = sock.recv(1024)
        debug("Server response: {!r}".format(response))

        if not response.startswith(b"OK"):
            print("Server rejected authentication: {}".format(
                response.decode('utf-8', 'ignore').strip()))
            return False

        sock.sendall(payload.encode('utf-8'))
        try:
            sock.shutdown(socket.SHUT_WR)
        except Exception:
            pass

        try:
            reply = sock.recv(1024)
        except socket.timeout:
            reply = b""
        reply_text = reply.decode('utf-8', 'ignore').strip()
        learn_min_interval(reply_text)
        if reply_text.startswith("ERROR"):
            print("Server rejected position: {}".format(reply_text))
            return False
        if reply_text.startswith("WARNING"):
            print("Server warning: {}".format(reply_text))
        debug("Server reply: {!r}".format(reply_text))

        debug("Sent successfully to {}:{}".format(SERVER_HOST, SERVER_PORT))
        return True

    except Exception as e:
        print("Error sending data: {}".format(e))
        return False

    finally:
        if sock is not None:
            try:
                sock.close()
            except Exception:
                pass


def main():
    try:
        node_name = build_node_name()
        check_login_config()
    except ValueError as e:
        print("CONFIG ERROR in gps_sender.py: {}".format(e))
        print("Fix the USER CONFIG section and restart.")
        time.sleep(30)
        raise SystemExit(1)

    print("GPS Sender Ver {} starting for {}".format(VERSION, node_name))
    if OVERRIDE_ALWAYS_RUN:
        debug("Override enabled - ignoring flag file")

    ser = open_serial()
    next_send = 0
    was_enabled = None
    last_gga = None
    last_gga_time = 0

    while True:
        try:
            enabled = gps_enabled()
            if enabled != was_enabled:
                print("GPS {}".format("enabled" if enabled else "disabled (waiting for flag file)"))
                was_enabled = enabled
                if enabled:
                    flush_input(ser)
                    next_send = 0 
            if not enabled:
                time.sleep(1)
                continue

            line = read_line(ser)
            if not line:
                continue

            debug("Raw GPS line: {}".format(line))

            gga = parse_gga(line)
            if gga is not None:
                last_gga = gga
                last_gga_time = time.time()
                continue

            fix = parse_rmc(line)
            if fix is None:
                continue

            now = time.time()
            if now >= next_send:
                fresh_gga = last_gga if (now - last_gga_time) <= GGA_MAX_AGE else None
                send_position(node_name, fix, fresh_gga)
                next_send = now + send_interval()

        except KeyboardInterrupt:
            print("\nExiting.")
            ser.close()
            break

        except serial.SerialException as e:
            print("Serial error: {} (reconnecting)".format(e))
            try:
                ser.close()
            except Exception:
                pass
            time.sleep(SERIAL_RETRY)
            ser = open_serial()
            next_send = 0

        except Exception as e:
            print("Error: {}".format(e))
            time.sleep(1)


if __name__ == "__main__":
    main()
