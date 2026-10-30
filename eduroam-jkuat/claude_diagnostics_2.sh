#!/usr/bin/env python3
# Second-pass iwd diagnostic (PEAP/MSCHAPv2 with debug daemon).
# Credentials come from the environment; nothing is stored in this file:
#   sudo EDUROAM_IDENTITY='you@students.jkuat.ac.ke' ./claude_diagnostics_2.sh
import os
import subprocess
import getpass
import sys
import time
import configparser

if os.geteuid() != 0:
    print("Please run this script with sudo.")
    exit(1)

identity = os.environ.get('EDUROAM_IDENTITY', '').strip() or input(
    'JKUAT student identity (e.g. you@students.jkuat.ac.ke): ').strip()
if not identity:
    sys.exit('No identity supplied, aborting.')
password = os.environ.get('EDUROAM_PASSWORD', '') or getpass.getpass('Eduroam password: ')
if not password:
    sys.exit('No password supplied, aborting.')

print("--- Checking for conflicting profiles in /var/lib/iwd ---")
subprocess.run(['ls', '-la', '/var/lib/iwd/'])

print("\n--- Generating full .8021x file for testing ---")
subprocess.run(['nmcli', 'device', 'set', 'wlan0', 'managed', 'no'])
time.sleep(1)
subprocess.run(['nmcli', 'connection', 'delete', 'eduroam'], stderr=subprocess.DEVNULL)
try:
    os.remove('/var/lib/iwd/eduroam.8021x')
except:
    pass

config = configparser.ConfigParser()
config.optionxform = str
config['Security'] = {
    'EAP-Method': 'PEAP',
    'EAP-Identity': 'anonymous@jkuat.ac.ke',
    'EAP-PEAP-Phase2-Method': 'MSCHAPV2',
    'EAP-PEAP-Phase2-Identity': identity,
    'EAP-PEAP-Phase2-Password': password
}
config['Settings'] = {
    'AutoConnect': 'true'
}

with open('/var/lib/iwd/eduroam.8021x', 'w') as configfile:
    config.write(configfile, space_around_delimiters=False)

os.chmod('/var/lib/iwd/eduroam.8021x', 0o600)
import pwd, grp
uid = pwd.getpwnam('root').pw_uid
gid = grp.getgrnam('root').gr_gid
os.chown('/var/lib/iwd/eduroam.8021x', uid, gid)

print("\n--- Full Hexdump of File ---")
subprocess.run(['hexdump', '-C', '/var/lib/iwd/eduroam.8021x'])

print("\n--- Stopping system iwd and starting debug daemon ---")
subprocess.run(['systemctl', 'stop', 'iwd'])

# Use /usr/lib/iwd/iwd which is standard for arch
iwd_cmd = "/usr/lib/iwd/iwd"
if not os.path.exists(iwd_cmd):
    iwd_cmd = "/usr/libexec/iwd"

iwd_proc = subprocess.Popen([iwd_cmd, "-d"], stdout=open("/tmp/iwd_debug.log", "w"), stderr=subprocess.STDOUT)
time.sleep(3)

print("\n--- Known Networks List before connect ---")
subprocess.run(['iwctl', 'known-networks', 'list'])

print("\n--- Connecting... ---")
subprocess.run(['iwctl', 'station', 'wlan0', 'connect', 'eduroam'])
time.sleep(4)

print("\n--- Stopping debug daemon ---")
iwd_proc.terminate()
time.sleep(1)
subprocess.run(['systemctl', 'start', 'iwd'])
subprocess.run(['nmcli', 'device', 'set', 'wlan0', 'managed', 'yes'])

print("\n--- IWD DEBUG LOGS (Filtered for eduroam and EAP) ---")
# Claude wants the full debug output, but we will print it so the user can paste it.
with open('/tmp/iwd_debug.log', 'r') as f:
    for line in f:
        print(line, end='')
