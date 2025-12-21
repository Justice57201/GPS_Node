
![Logo](https://gmrs-link.com/map/Node-tracking.png)


# GMRS-Link Node Tracking

GPS Tracking for GMRS nodes running (Hamvoip)

Installation & Setup

{ Automated Installation }

1. SSH into your Node.

2. Open a bash shell terminal.

3. Copy & Paste or Type in the line below.

  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_installer.sh)"

  Press ENTER, and the install will begin.

4. You will now be asked to enter your node number.

5. The install will now be finished, time to set up the script.


{ Setup }

1. Navigate to /root/GPS/gps_sender.py , open the file in the editor.

2. Find the (User Config) section.

  * Add your callsign and node number.

    CALLSIGN = 'WLMR400-1240'

  * Select your icon from the list of <a href="https://gmrs-link.com/map/icons/map_icons.pdf" target="_blank">Map icons</a>

  * Enter your Username and Password from the registration e-mail.

3. Plug in the V-Fan GPS receiver, then in the terminal enter

   dmesg | grep tty

4. It should return a message like this:

[    0.000000] Kernel command line: coherent_pool=1M 8250.nr_uarts=1 snd_bcm2835.enable_compat_alsa=0 snd_bcm2835.enable_hdmi=1 bcm2708_fb.fbwidth=640 				bcm2708_fb.fbheight=480 bcm2708_fb.fbswap=1 vc_mem.mem_base=0x3ec00000 vc_mem.mem_size=0x40000000  root=/dev/mmcblk0p2 rw rootwait console=tty1 selinux=0 			plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 elevator=noop audit=0
[    0.000860] printk: console [tty1] enabled
[    5.949104] 3f201000.serial: ttyAMA0 at MMIO 0x3f201000 (irq = 81, base_baud = 0) is a PL011 rev2
[  285.652564] cdc_acm 1-1.1.3:1.0: ttyACM0: USB ACM device
[ 2706.877036] cdc_acm 1-1.1.3:1.0: ttyACM1: USB ACM device

You are looking for the USB ACM device. the ttyxxxx: USB ACM device is the path you want. Copy that and place it in the DEVICE = section of the gps_sender.py file.

5. When done, save the file.

{ How to use }

Using your radio's DTMF keypad or Supermon

Enable  = A50   
Disable = A51


## Author

- [WRQC343](https://www.gmrs-link.com)

