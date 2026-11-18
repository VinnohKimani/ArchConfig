#!/usr/bin/env python3
"""
MacBook Pro 13" (Early 2015 - MacBookPro12,1) Cirrus Logic CS4208 Quad-Speaker / Woofer Enabler.

By default on Linux, snd_hda_codec_cirrus only powers up Node 0x03 -> Pin 0x12 (the upper tweeters)
while leaving Node 0x04 -> Pin 0x13 (the internal Bass Woofers, 0x90100112) powered down in D3 and muted.
This script powers up Node 0x04 and Pin 0x13 to D0, enables the CS4208 GPIO speaker amplifier lines,
unmutes DAC 0x04 to 0dB (0x7f), and syncs DAC 0x04's converter stream with DAC 0x03.
"""
import fcntl
import os
import struct
import time

HDA_IOCTL_VERB_WRITE = 0xC0084811
DEV_PATH = "/dev/snd/hwC1D0"


def verb(fd: int, nid: int, v: int, param: int) -> int:
    val = (nid << 24) | (v << 8) | param
    buf = struct.pack("II", val, 0)
    res = fcntl.ioctl(fd, HDA_IOCTL_VERB_WRITE, buf)
    return struct.unpack("II", res)[1]


def sync_woofers(fd: int) -> None:
    # Power up AFG (0x01), DAC1 (0x03), Woofer DAC2 (0x04), and Speaker Pins (0x12, 0x13) to D0
    for nid in (0x01, 0x03, 0x04, 0x12, 0x13):
        verb(fd, nid, 0x705, 0x00)

    # Enable GPIOs 0, 1, 2, 3 (Speaker + Woofer amplifier enable lines on CS4208)
    verb(fd, 0x01, 0x716, 0x0F)
    verb(fd, 0x01, 0x717, 0x0F)
    verb(fd, 0x01, 0x715, 0x0F)

    # Read active stream/channel ID from DAC 0x03 and mirror to Woofer DAC 0x04
    conv = verb(fd, 0x03, 0xF06, 0x00)
    verb(fd, 0x04, 0x706, conv if conv else 0x50)

    # Unmute and match DAC 0x03 gain on Woofer DAC 0x04 (0x3b0 = Set Output Amp L+R)
    gain_l = verb(fd, 0x03, 0xB00, 0x8000) & 0x7F
    target_gain = gain_l if gain_l > 0 else 0x7F
    verb(fd, 0x04, 0x3B0, target_gain)

    # Set Pin Widget Control to OUT (0x40) on both 0x12 and 0x13
    verb(fd, 0x12, 0x707, 0x40)
    verb(fd, 0x13, 0x707, 0x40)


def main() -> None:
    # Ensure kernel HDA parser knows 0x13 is the second internal speaker pair (0x90100012)
    sysfs_base = "/sys/class/sound/card1/hwC1D0"
    try:
        with open(f"{sysfs_base}/user_pin_configs", "r") as f:
            cur_pins = f.read()
        if "0x13 0x90100012" not in cur_pins:
            with open(f"{sysfs_base}/user_pin_configs", "w") as f:
                f.write("0x12 0x90100010\n0x13 0x90100012\n")
    except Exception:
        pass

    fd = os.open(DEV_PATH, os.O_RDWR)
    try:
        sync_woofers(fd)
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()
