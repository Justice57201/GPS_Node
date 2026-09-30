![Logo](https://gmrs-link.com/map/Node-tracking.png)

![Release Version](https://img.shields.io/badge/Version-v9.0.0-blue?color=blue)
![Release Version](https://img.shields.io/badge/BETA_Testing-black?color=orange)
![OS Version](https://img.shields.io/badge/OS-Linux_*_Hamvoip-red?color=red)

# GMRS-Link Node Tracking

GPS tracking for GMRS nodes. Your node reads its position from a USB GPS receiver and sends it to the GMRS-Link node tracking map.

## Before you start

You will need:

* A GMRS node running Linux or HamVoIP that you can SSH into
* A **VFAN USB GPS receiver** ([Amazon link](https://www.amazon.com/dp/B073P3Y48Q/))
* The **username and password** from your GMRS Node Tracking registration e-mail

---

## Step 1: Install

1. SSH into your node and open a bash shell.
2. Copy and paste this line, then press **ENTER**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_installer.sh)"
```

3. When asked, enter your **node number**.
4. The install finishes on its own. Move on to Step 2.

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
nano /root/GPS/gps_sender.py
```

Near the top is the **USER CONFIG** section. It looks like this. The values below are an example, so change them to match your node:

```python
#------------------------------------------#
#               USER CONFIG                #
#------------------------------------------#

CALLSIGN = 'WRXX123-1234'     # Callsign-Node#
ICON = 'marker_blue'          # See pin list
DEBUG = False                 # Debug output
SEND_INTERVAL = 60            # Seconds
INCLUDE_SPEED = False         # True / False
INCLUDE_TRAIL = False         # True / False

OVERRIDE_ALWAYS_RUN = False   # True = ignore flag file and always run

# ---- Map extras (all optional) ---- #

INCLUDE_HEADING = True        # Direction arrow on the map while moving
HEADING_MIN_SPEED = 3         # mph -- no arrow below this (GPS heading is junk when parked)
INCLUDE_GPS_INFO = True       # Altitude + satellite count in the popup
NODE_TYPE = 'mobile'          # 'mobile', 'base', 'repeater', 'portable' or '' for none
CHANNEL = 'GMRS 20'           # e.g. 'GMRS 20' or '462.675' -- '' for none
NODE_LINK = ''                # Status page URL, e.g. 'https://...' -- '' for none

# ---- Credentials From Registration ---- #

AUTH_USER = "USER_NAME"       # Username
AUTH_PASS = "PASSWORD"        # Password

# ---------------------------------------- #
```

> [!IMPORTANT]
> * Keep the quote marks around text values like `'WRXX123-1234'`.
> * `True` and `False` start with a capital letter and have **no** quotes.

### Basic settings

| Setting | What to put there |
|---|---|
| `CALLSIGN` | Your call sign **and** node number, joined with a dash, e.g. `'WRXX123-1234'`. This is the name shown on the map. |
| `ICON` | The pin shown on the map. Pick one from the [Map Icons](https://gmrs-link.com/map/icons/map_icons.pdf) list, e.g. `'marker_blue'` or `'pickup'`. |
| `DEBUG` | `True` prints extra output for testing the connection. Use `False` for normal use. |
| `SEND_INTERVAL` | How often your position is sent, in seconds. Use **60 to 600**. |
| `INCLUDE_SPEED` | `True` for mobile nodes, `False` for base stations. |
| `INCLUDE_TRAIL` | `True` leaves a trail on the map showing where you've been. `False` for no trail. |
| `OVERRIDE_ALWAYS_RUN` | `False` lets you turn tracking on and off from your radio (see [How to use](#how-to-use)). `True` ignores the on/off flag file and always runs. |

### Map extras (optional)

These add more detail to your pin on the map. Leave them as they are if you're not sure.

| Setting | What it does |
|---|---|
| `INCLUDE_HEADING` | `True` shows a direction arrow on your pin while you're moving. |
| `HEADING_MIN_SPEED` | The arrow only shows above this speed, in mph. GPS direction is unreliable when parked, so `3` is a good start. |
| `INCLUDE_GPS_INFO` | `True` adds altitude and satellite count to the popup when someone clicks your pin. |
| `NODE_TYPE` | `'mobile'`, `'base'`, `'repeater'` or `'portable'`. Use `''` for none. |
| `CHANNEL` | The channel or frequency you monitor, e.g. `'GMRS 20'` or `'462.675'`. Use `''` for none. |
| `NODE_LINK` | A link to your node's status page, starting with `https://`. Use `''` for none. |

### Login

| Setting | What to put there |
|---|---|
| `AUTH_USER` | The **username** from your registration e-mail. This is your call sign only, **without** the node number. |
| `AUTH_PASS` | The **password** from your registration e-mail, typed exactly as shown. |

> [!TIP]
> `CALLSIGN` and `AUTH_USER` are different:
> * `CALLSIGN = 'WRXX123-1234'` has the node number.
> * `AUTH_USER = "WRXX123"` does not.

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
> * This is a beta and subject to change.

---

## Troubleshooting

| Problem | Try this |
|---|---|
| Not showing on the map | Set `DEBUG = True`, restart the service, and watch the output. Check that `AUTH_USER` and `AUTH_PASS` match your e-mail exactly. |
| Script won't start after editing | Usually a missing quote mark or a lowercase `true` / `false`. Compare with the example above. |
| No `ttyACM` device in Step 2 | Unplug the GPS, wait a few seconds, and plug it back in. Try another USB port. |
| No position or no fix | The GPS needs a view of the sky. Move it near a window or outside. The first fix can take several minutes. |
| Default pin instead of your icon | Check the `ICON` spelling against the Map Icons list. |

---

## Uninstall

```bash
/root/GPS/gps_uninstall.sh
```

Enter your node number when asked.

---

## Author

* [WRQC343](https://www.gmrs-link.com)
