
![Logo](https://gmrs-link.com/map/Node-tracking.png)  
![Release Version](https://img.shields.io/badge/Version-v7.0.0-blue?color=blue)
![Release Version](https://img.shields.io/badge/BETA_Testing-black?color=orange)
![OS Version](https://img.shields.io/badge/OS-Linux_*_Hamvoip-red?color=red)

# GMRS-Link Node Tracking

GPS Tracking for GMRS nodes

Required Equipment:
        
   * VFAN USB GPS Receiver <a href="https://www.amazon.com/dp/B073P3Y48Q/?coliid=I2EOEUSAIB3X45&colid=3FZ081E0DMKUH&psc=1&ref_=list_c_wl_lv_ov_lig_dp_it)" target="_blank" rel="noopener noreferrer">Amazon Link</a>

## Installation & Setup

{ Automated Installation }

1. SSH into your Node.

2. Open a bash shell terminal.

3. Copy & Paste the line below.
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Justice57201/GPS_Node/main/gps_installer.sh)"
```
   Press ENTER, and the install will begin.

4. You will now be asked to enter your node number.

5. The install will now be finished, time to set up the script.
&nbsp;

&nbsp;

## Setup

1. Navigate to /root/GPS/gps_sender.py , open the file in the editor.

2. Find the ( User Config ) section and configure your sender file.

    * Add your callsign and node number.

        CALLSIGN = 'WLMR400-1240'

    * Select your icon from the list of <a href="https://gmrs-link.com/map/icons/map_icons.pdf" target="_blank" rel="noopener noreferrer">Map Icons</a>

    * Set the Send Interval between 60 - 600 Seconds

    * Set the Speed. If you are a base, then select False. If mobile, then select True
    
    * Set Trail. If you don't want to leave a map trail, set to False

    * Debug is for testing the connection. 
    
    * Enter your Username and Password from the registration e-mail.

&nbsp;

3. Plug in the V-Fan GPS receiver, then in the terminal enter
```bash
dmesg | grep tty              
```

4. It should return a message like this.

  ```bash
[0.000859] printk: console [tty1] enabled
[5.950629] 3f201000.serial: ttyAMA0 at MMIO 0x3f201000 (irq = 81, base_baud = 0) is a PL011 rev2
[8.403356] cdc_acm 1-1.2:1.0: ttyACM0: USB ACM device    
```  

   Look for the parts that read tty****.  Most likely it will be ttyACM0 or ttyACM1    
   If it's 1, then change it where it says DEVICE = '/dev/ttyACM0'.     
   The default is ttyACM0

5. Save & Close the file 

6. In the terminal, enter
```bash
systemctl restart gps_sender.service 
```
&nbsp;

&nbsp;

## How to use

Using your radio's DTMF keypad or Supermon

  * Enable  = *A50   
  * Disable = *A51

Open the tracking website listed in your registration e-mail and test.
&nbsp;

&nbsp;

> [!NOTE]
>
>                                            
> * Every time you reboot the node, you will need to re-enable the GPS tracking.
> * Anytime changes are made to the gps_sender.py file, you will need to do the     
>   ( systemctl restart gps_sender.service ) to update the file.
> * Remember this is a Beta and subject to change.
&nbsp;

&nbsp;
## Uninstall

1. Open Terminal & enter

```bash
/root/GPS/gps_uninstall.sh
```
2. Enter your node number.
&nbsp;

&nbsp;
## Author

- [WRQC343](https://www.gmrs-link.com)

