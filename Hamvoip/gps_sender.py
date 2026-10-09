#!/usr/bin/env python2
# -*- coding: utf-8 -*-
#
# By -- WRQC343 -- www.gmrs-link.com
#
# Ver 8.0.3 - 10/26
#123
# GPS Node Tracking - Sender


from __future__ import print_function
import serial, socket, time, json, os, re

VERSION = "8.0.3"

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
# ----  Do Not Touch Below this Line  --- #
# --------------------------------------- #

FLAG_FILE = "/tmp/GPS.ENABLED"
GGA_MAX_AGE = 10              
SOCKET_TIMEOUT = 10
SERIAL_RETRY = 10  

RATES = {
    "MIN_INTERVAL": 10,
    "PARKED_SPEED": 3, "PARKED_INTERVAL": 300,
    "SLOW_SPEED": 20, "SLOW_INTERVAL": 60,
    "TOWN_SPEED": 45, "TOWN_INTERVAL": 30,
    "HIGHWAY_INTERVAL": 15,
    "TURN_ANGLE": 30,
    "STATE_CONFIRM": 5,
}


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


def _num(text, lo, hi):
    try:
        v = int(text)
    except (TypeError, ValueError):
        return None
    return v if lo <= v <= hi else None


def learn_rates(reply_text):
    """Server replies end with its reporting rates, e.g.
    MIN_INTERVAL=10 PARKED=3/300 SLOW=20/60 TOWN=45/30 HIGHWAY=15 TURN=30 CONFIRM=5"""
    new = {}
    for token in (reply_text or '').split():
        if '=' not in token:
            continue
        key, _, val = token.partition('=')
        a, _, b = val.partition('/')
        if key == "MIN_INTERVAL":
            new["MIN_INTERVAL"] = _num(a, 0, 3600)
        elif key in ("PARKED", "SLOW", "TOWN"):
            new[key + "_SPEED"] = _num(a, 0, 200)
            new[key + "_INTERVAL"] = _num(b, 1, 3600)
        elif key == "HIGHWAY":
            new["HIGHWAY_INTERVAL"] = _num(a, 1, 3600)
        elif key == "TURN":
            new["TURN_ANGLE"] = _num(a, 1, 180)
        elif key == "CONFIRM":
            new["STATE_CONFIRM"] = _num(a, 0, 120)
    changed = False
    for key, val in new.items():
        if val is not None and RATES.get(key) != val:
            RATES[key] = val
            changed = True
    if changed:
        debug("Reporting rates from server: {}".format(RATES))


def tier_interval(speed):
    if speed < RATES["SLOW_SPEED"]:
        return RATES["SLOW_INTERVAL"]
    if speed < RATES["TOWN_SPEED"]:
        return RATES["TOWN_INTERVAL"]
    return RATES["HIGHWAY_INTERVAL"]


def angle_diff(a, b):
    d = abs(a - b) % 360.0
    return 360.0 - d if d > 180.0 else d


class Reporter(object):
    """Decides when a position should be sent."""

    def __init__(self):
        self.reset()

    def reset(self):
        self.last_send = 0
        self.last_course = None
        self.moving = False
        self.change_since = None
        self.pending = None

    def due(self, fix, now):
        """Returns the reason to send now, or None."""
        speed = fix["speed"]
        parked_speed = RATES["PARKED_SPEED"]
        if not self.last_send:
            self.moving = speed >= parked_speed
            return "first fix"

        elapsed = now - self.last_send
        floor = RATES["MIN_INTERVAL"]

        moving_now = speed >= parked_speed
        if moving_now != self.moving:
            if self.change_since is None:
                self.change_since = now
            elif now - self.change_since >= RATES["STATE_CONFIRM"]:
                self.moving = moving_now
                self.change_since = None
                self.pending = "started moving" if moving_now else "stopped"
        else:
            self.change_since = None

        course = fix.get("course")
        if (self.moving and moving_now and course is not None and self.last_course is not None
                and angle_diff(course, self.last_course) >= RATES["TURN_ANGLE"]):
            self.pending = self.pending or "turn"

        if self.moving:
            interval = tier_interval(max(speed, parked_speed))
        else:
            interval = RATES["PARKED_INTERVAL"]
        interval = max(interval, floor)

        if elapsed >= interval:
            return self.pending or "interval"
        if self.pending and elapsed >= floor:
            return self.pending
        return None

    def sent(self, fix, now):
        self.last_send = now
        self.pending = None
        if fix.get("course") is not None:
            self.last_course = fix["course"]


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
        learn_rates(reply_text)
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
    reporter = Reporter()
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
                    reporter.reset()
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
            reason = reporter.due(fix, now)
            if reason:
                debug("Sending ({}, {} mph)".format(reason, fix["speed"]))
                fresh_gga = last_gga if (now - last_gga_time) <= GGA_MAX_AGE else None
                send_position(node_name, fix, fresh_gga)
                reporter.sent(fix, now)

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
            reporter.reset()

        except Exception as e:
            print("Error: {}".format(e))
            time.sleep(1)


if __name__ == "__main__":
    main()
