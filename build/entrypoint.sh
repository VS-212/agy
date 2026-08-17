#!/bin/sh
set -e
cd /home/aguser
exec python3 /home/aguser/driver.py "$@"