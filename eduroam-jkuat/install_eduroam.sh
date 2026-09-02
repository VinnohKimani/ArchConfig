#!/usr/bin/env python3
import os
import subprocess
import configparser
import time
import pwd
import grp

if os.geteuid() != 0:
    print("Please run this script with sudo.")
    exit(1)

print("Telling NetworkManager to temporarily stop interfering with wlan0...")
subprocess.run(['nmcli', 'device', 'set', 'wlan0', 'managed', 'no'])
time.sleep(1)

print("Cleaning up...")
subprocess.run(['nmcli', 'connection', 'delete', 'eduroam'], stderr=subprocess.DEVNULL)
try:
    os.remove('/var/lib/iwd/eduroam.8021x')
except:
    pass

config = configparser.ConfigParser()
config.optionxform = str
config['Security'] = {
    'EAP-Method': 'TTLS',
    'EAP-Identity': 'anonymous@jkuat.ac.ke',
    'EAP-TTLS-Phase2-Method': 'Tunneled-PAP',
    'EAP-TTLS-Phase2-Identity': 'vincent.kimani2024@students.jkuat.ac.ke',
    'EAP-TTLS-Phase2-Password': 'sct222-0131/2024',
    'EAP-TTLS-CACert': '/etc/ssl/certs/jkuat_ca.pem'
}
config['Settings'] = {
    'AutoConnect': 'true'
}

print("Creating TTLS+PAP iwd profile...")
with open('/var/lib/iwd/eduroam.8021x', 'w') as configfile:
    config.write(configfile, space_around_delimiters=False)

# Claude's genius fix: enforcing strict root ownership for everything iwd touches!
uid = pwd.getpwnam('root').pw_uid
gid = grp.getgrnam('root').gr_gid

os.chown('/var/lib/iwd/eduroam.8021x', uid, gid)
os.chmod('/var/lib/iwd/eduroam.8021x', 0o600)

if os.path.exists('/etc/ssl/certs/jkuat_ca.pem'):
    os.chown('/etc/ssl/certs/jkuat_ca.pem', uid, gid)
    os.chmod('/etc/ssl/certs/jkuat_ca.pem', 0o644)

time.sleep(2)

print("Restarting iwd just to be absolutely sure it picks up the clean permissions...")
subprocess.run(['systemctl', 'restart', 'iwd'])
time.sleep(2)

print("Telling iwd to connect...")
res = subprocess.run(['iwctl', 'station', 'wlan0', 'connect', 'eduroam'])

if res.returncode == 0:
    print("\n=====================")
    print("Connected successfully via native iwd!")
    print("=====================")
else:
    print("\n=====================")
    print("Connection failed natively too. Here is exactly why iwd rejected it:")
    subprocess.run('journalctl -u iwd -n 30 --no-pager', shell=True)
    print("=====================")

print("\nRestoring NetworkManager control over wlan0...")
subprocess.run(['nmcli', 'device', 'set', 'wlan0', 'managed', 'yes'])
