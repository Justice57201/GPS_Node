Installation & Setup

{ Automated Installation }

1. SSH into your Node.

2. Open a bash shell terminal

3. Enter

  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_installer.sh)"

  Press ENTER, and the install will begin.

4. You will now be asked to enter your node number.

5. The install will now be finished, time to set up the script.


{ Setup }

1. Navigate to /root/GPS/gps_sender.py , open the file in the editor

2. Find the User Config section

  * Add your callsign and node number

    CALLSIGN = 'WLMR400-1240'

  * Choose your icon from the list of Icons

  * Enter your Username and Password from registration

3. Plug in the V-Fan GPS receiver, then in the terminal enter

   dmesg | grep tty

4. You will see something like what is below. You are looking for the underlined parts, which are the device ID. Please take note of it and compare it to the device listed in the script.
   If it is anything other than the ttyAMA0, change the script to match.

======================================================================================================================================================================================================
|                                                                                                                                                                                                    |
| [    0.000000] Kernel command line: coherent_pool=1M 8250.nr_uarts=1 snd_bcm2835.enable_compat_alsa=0 snd_bcm2835.enable_hdmi=1 bcm2708_fb.fbwidth=640 bcm2708_fb.fbheight=480 bcm2708_fb.fbswap=1 | 
| vc_mem.mem_base=0x3ec00000 vc_mem.mem_size=0x40000000 root=/dev/mmcblk0p2 rw rootwait console=tty1 selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 elevator=noop audit=0    |
| [    0.000859] printk: console [tty1] enabled                                                                                                                                                      |
| [    5.955167] 3f201000.serial: ttyAMA0 at MMIO 0x3f201000 (irq = 81, ase_baud = 0) is a PL011 rev2                                                                                                |
| [    8.340419] cdc_acm 1-1.2:1.0: ttyACM0: USB ACM device                                                                                                                                          |
|                                                                                                                                                                                                    |
======================================================================================================================================================================================================

5.
