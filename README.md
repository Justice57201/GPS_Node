
![Logo](https://gmrs-link.com/map/Node-tracking.png)


# GMRS-Link Node Tracking

GPS Tracking for GMRS nodes running ( Hamvoip )

Required Equipment:
        
   * VFAN USB GPS Receiver <a href="https://www.amazon.com/dp/B073P3Y48Q/?coliid=I2EOEUSAIB3X45&colid=3FZ081E0DMKUH&psc=1&ref_=list_c_wl_lv_ov_lig_dp_it)" target="_blank" rel="noopener noreferrer">Amazon Link</a>

Installation & Setup

{ Automated Installation }

1. SSH into your Node.

2. Open a bash shell terminal.

3. Copy & Paste or Type in the line below.

        bash -c "$(curl -fsSL https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_installer.sh)"

  Press ENTER, and the install will begin.

4. You will now be asked to enter your node number.

5. The install will now be finished, time to set up the script.
&nbsp;

&nbsp;

## { Setup }

1. Navigate to /root/GPS/gps_sender.py , open the file in the editor.

2. Find the ( User Config ) section and configure your sender file.

    * Add your callsign and node number.

        CALLSIGN = 'WLMR400-1240'

    * Select your icon from the list of <a href="https://gmrs-link.com/map/icons/map_icons.pdf" target="_blank" rel="noopener noreferrer">Map Icons</a>

    * Enter your Username and Password from the registration e-mail.

3. Plug in the V-Fan GPS receiver, then in the terminal enter

       dmesg | grep tty

4. It should return a message like this:

<pre>
[    0.000859] printk: console [tty1] enabled
[    5.950629] 3f201000.serial: ttyAMA0 at MMIO 0x3f201000 (irq = 81, base_baud = 0) is a PL011 rev2
[    8.403356] cdc_acm 1-1.2:1.0: ttyACM0: USB ACM device    
</pre>

Look for the parts that read tty****.  Most likely it will be ttyACM0 or ttyACM1    
If it's 1, then change it where it says DEVICE = '/dev/ttyACM0'.     
The default is ttyACM0

5. Save & Close the file 

6. In the terminal, enter

       systemctl restart gps_sender.service 
&nbsp;

&nbsp;

## { How to use }

Using your radio's DTMF keypad or Supermon

  * Enable  = *A50   
  * Disable = *A51

Open the tracking website listed in your registration e-mail and test.


NOTES:   
    
  * Every time you reboot the node, you will need to re-enable the GPS tracking.
  * Anytime changes are made to the gps_sender.py file, you will need to do the ( systemctl restart gps_sender.service )
    to update the file.
  * Remember this is a Beta and subject to change.


## Author

- [WRQC343](https://www.gmrs-link.com)

