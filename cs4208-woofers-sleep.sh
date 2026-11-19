#!/bin/sh
# Systemd sleep hook to re-enable Cirrus Logic CS4208 Woofers on resume
case "$1/$2" in
    post/*)
        /usr/local/bin/enable-cs4208-woofers.py >/dev/null 2>&1 || true
        ;;
esac
