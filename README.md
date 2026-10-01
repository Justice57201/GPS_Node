![Logo](https://gmrs-link.com/map/Node-tracking.png)

![Release Version](https://img.shields.io/badge/Version-v8.0.0-blue?color=blue)
![OS Version](https://img.shields.io/badge/OS-Linux_*_Hamvoip-red?color=red)
![OS Version](https://img.shields.io/badge/OS-Linux_*_ASL3-purple?color=purple)

# GMRS-Link GPS Node Tracking

GPS tracking for GMRS nodes. Your node reads its position from a USB GPS receiver and sends it to the GMRS-Link live map.

## Before you start

You will need:

* A GMRS node running **HamVoIP** or **ASL3** that you can SSH into
* A **VFAN USB GPS receiver** ([Amazon link](https://www.amazon.com/dp/B073P3Y48Q/))
* The **username and password** from your GMRS Node Tracking registration e-mail

---

## Step 1: Install

1. SSH into your node and open a bash shell.
2. Copy and paste this line, then press **ENTER**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_installer.sh)"
```

3. The installer detects whether your node runs **HamVoIP** or **ASL3**. Press **ENTER** to confirm, or type `n` to pick the other one.
4. When asked, enter your **node number**. If the installer found it already, just press **ENTER**.
5. The install finishes on its own. Move on to Step 2.

> [!NOTE]
> **Where the files go:**
> * HamVoIP: `/root/GPS`
> * ASL3: `/opt/GPS`
>
> On ASL3, use `/opt/GPS` everywhere this guide says `/root/GPS`.

---

## Step 2: Plug in the GPS receiver

Plug the VFAN GPS receiver into a USB port on your node, then run:

```bash
dmesg | grep tty
```

You should see something like this:

```text
[0.000859] printk: console [tty1] enabled
[5.950629] 3f201000.serial: ttyAMA0 at MMIO 0x3f201000 (irq = 81, base_baud = 0) is a PL011 rev2
[8.403356] cdc_acm 1-1.2:1.0: ttyACM0: USB ACM device
```

Look for the line with **USB ACM device**. It will almost always say `ttyACM0` or `ttyACM1`.

* `ttyACM0` is the default, so there's nothing to change.
* If it says `ttyACM1`, remember it for Step 3.

---

## Step 3: Edit the config file

Open the sender file:

```bash
nano /root/GPS/gps_sender.py      # HamVoIP
```

```bash
nano /opt/GPS/gps_sender.py       # ASL3
```

Near the top is the **USER CONFIG** section. It looks like this. The values below are an example, so change them to match your node:

```python
#-----------------------------------------#
#               USER CONFIG               #
#-----------------------------------------#

CALLSIGN = 'WRXX123'          # Your callsign only -- no dash or number
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
NODE_TYPE = 'mobile'          # 'mobile', 'base', 'repeater', 'portable' or '' for none
NETWORK = ''                  # Network name, e.g. 'T.G.L.N', 'G.F.N', 'N.E.G', '' for none (20 max limit)
NODE_LINK = ''                # Status page URL, e.g. 'https://...' -- '' for none

# ---- Credentials From Registration ---- #

AUTH_USER = "YOUR_USERNAME"   # Username
AUTH_PASS = "YOUR_PASSWORD"   # Password

# --------------------------------------- #
```

> [!IMPORTANT]
> * Keep the quote marks around text values like `'WRXX123'`.
> * `True` and `False` start with a capital letter and have **no** quotes.

### Basic settings

| Setting | What to put there |
|---|---|
| `CALLSIGN` | Your call sign **only**, e.g. `'WRXX123'`. No dash and no number. |
| `SSID` | Which unit this is. `1` shows your call sign alone (`WRXX123`). `2` to `10` are for extra units and show as `WRXX123-2` up to `WRXX123-10`. |
| `ICON` | The pin shown on the map. Pick one from the [Map Icons](https://gmrs-link.com/map/icons/map_icons.pdf) list, e.g. `'pin_blue'` or `'pickup'`. |
| `DEBUG` | `True` prints extra output for testing the connection. Use `False` for normal use. |
| `SEND_INTERVAL` | How often your position is sent, in seconds. Use **60 to 600**. The server won't accept faster than every 30 seconds; if you set less, your node slows down to 30 on its own. |
| `INCLUDE_SPEED` | `True` for mobile nodes, `False` for base stations. |
| `INCLUDE_TRAIL` | `True` leaves a trail on the map showing where you've been. `False` for no trail. |
| `OVERRIDE_ALWAYS_RUN` | `False` lets you turn tracking on and off from your radio (see [How to use](#how-to-use)). `True` ignores the on/off flag file and always runs. |

### Map extras (optional)

These add more detail to your pin on the map. Leave them as they are if you're not sure.

| Setting | What it does |
|---|---|
| `INCLUDE_HEADING` | `True` shows a direction arrow on your pin while you're moving. |
| `INCLUDE_GPS_INFO` | `True` adds altitude and satellite count to the popup when someone clicks your pin. |
| `NODE_TYPE` | `'mobile'`, `'base'`, `'repeater'` or `'portable'`. Use `''` for none. |
| `NETWORK` | The network your node is on, e.g. `'T.G.L.N'`, `'G.F.N'` or `'N.E.G'`. Up to 20 characters. Use `''` for none. |
| `NODE_LINK` | A link to your node's status page, starting with `https://`. Use `''` for none. |

### Login

| Setting | What to put there |
|---|---|
| `AUTH_USER` | The **username** from your registration e-mail. This is your call sign. |
| `AUTH_PASS` | The **password** from your registration e-mail, typed exactly as shown. |

> [!TIP]
> **More than one unit?** Use the same `CALLSIGN`, `AUTH_USER` and `AUTH_PASS` on each one, and give each unit its own `SSID`.
> * Base station: `SSID = 1` shows as `WRXX123`
> * Truck: `SSID = 2` shows as `WRXX123-2`
> * Portable: `SSID = 3` shows as `WRXX123-3`

### GPS device

If Step 2 showed `ttyACM1`, find this line in the same file and change `ttyACM0` to `ttyACM1`:

```python
DEVICE = '/dev/ttyACM0'
```

When you're done, save and close the file. In nano, press **Ctrl+O**, then **ENTER**, then **Ctrl+X**.

---

## Step 4: Restart the service

```bash
systemctl restart gps_sender.service
```

Run this again any time you change `gps_sender.py`.

---

## How to use

Use your radio's DTMF keypad or Supermon:

| Command | Action |
|---|---|
| `*A50` | Enable GPS tracking |
| `*A51` | Disable GPS tracking |

Then open the tracking map listed in your registration e-mail and check that your pin shows up.

> [!NOTE]
> * Every time you reboot the node, you need to re-enable GPS tracking with `*A50`, unless `OVERRIDE_ALWAYS_RUN = True`.
> * Any time you change `gps_sender.py`, run `systemctl restart gps_sender.service`.

---

## Viewing the logs

If your pin isn't showing up, the log will usually tell you why.

| What | Command |
|---|---|
| Watch the sender live | `journalctl -u gps_sender -f` |
| Last 50 lines | `journalctl -u gps_sender -n 50` |
| DTMF enable / disable | `journalctl -t GPS -f` |

Press **Ctrl+C** to stop watching. For more detail, set `DEBUG = True` in `gps_sender.py`, restart the service, and watch the log again. Set it back to `False` when you're done.

> [!NOTE]
> HamVoIP clears the log every time the node reboots. To keep it, run:
> ```bash
> mkdir -p /var/log/journal && systemctl restart systemd-journald
> ```

### Common log messages

| Message | What it means |
|---|---|
| `GPS Sender Ver 12.2 starting for WRXX123` | Started normally. The name at the end is how you'll show on the map. |
| `GPS disabled (waiting for flag file)` | Tracking is off. Send `*A50` to turn it on. |
| `GPS enabled` followed by nothing | No GPS fix yet. Normal for the first few minutes, or if the GPS can't see the sky. |
| `Error opening serial port` | The GPS isn't on `/dev/ttyACM0`. Re-check Step 2 and the `DEVICE` line. |
| `CONFIG ERROR in gps_sender.py` | A setting is wrong or still has its placeholder (`YOUR_CALLSIGN`, `YOUR_USERNAME`, `YOUR_PASSWORD`). The rest of the line says which one. |
| `Server rejected authentication` | `AUTH_USER` or `AUTH_PASS` doesn't match your registration e-mail. |
| `username must match the callsign` | Your login can only send for its own call sign. Check `CALLSIGN` and `AUTH_USER`. |
| `not allowed -- use CALLSIGN alone or CALLSIGN-2 to CALLSIGN-10` | `SSID` is out of range. Use `1` to `10`. |
| `Icon '...' not found on the server` | That icon name isn't on the map. Check the spelling against the Map Icons list. |
| `Network name is ... characters` | `NETWORK` is too long. Keep it to 20 characters. |
| `SEND_INTERVAL ... is below the server minimum` | Your interval is under 30 seconds. The node uses 30 on its own; nothing to fix. |

---

## Troubleshooting

| Problem | Try this |
|---|---|
| Not showing on the map | Watch the log (see [Viewing the logs](#viewing-the-logs)) and check the message against the table above. Make sure `AUTH_USER` and `AUTH_PASS` match your e-mail exactly. |
| Script won't start after editing | Usually a missing quote mark or a lowercase `true` / `false`. Compare with the example above. The log shows `CONFIG ERROR` if a setting is wrong. |
| No `ttyACM` device in Step 2 | Unplug the GPS, wait a few seconds, and plug it back in. Try another USB port. |
| No position or no fix | The GPS needs a view of the sky. Move it near a window or outside. The first fix can take several minutes. |
| Default pin instead of your icon | Check the `ICON` spelling against the Map Icons list. |
| Two units keep replacing each other on the map | Each unit needs a different `SSID`. |
| Wrong name on the map | `CALLSIGN` is your call sign only. Set the `-2`, `-3` ending with `SSID`, not in `CALLSIGN`. |

---

## Uninstall

```bash
/root/GPS/gps_uninstall.sh      # HamVoIP
```

```bash
/opt/GPS/gps_uninstall.sh       # ASL3
```

Type **y** and press **ENTER** when asked to confirm.

---

## Author

* [WRQC343](https://www.gmrs-link.com)
