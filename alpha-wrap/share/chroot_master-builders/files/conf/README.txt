
This is a droppin folder for headless setup.

SSH login:
To log in over SSH drop an SSH public key here, use any name but ended with the extension '.pub'.
If key is found, the SSH server will be automatically launched.
SSH key will be installed for 'master' user.


Network headless-setup:

If Ethernet interface (or interfaces) is available, AlpBase will try to acquire IP using DHCP.

Wireless network:
if the 'wpa_supplicant.conf' file is available, AlpBase will attempt to configure WI-FI using this file and DHCP. If it fails, it will try to set up cable connection.

After the network is up, AlpBase adverises IP and hostname with Avahi.
