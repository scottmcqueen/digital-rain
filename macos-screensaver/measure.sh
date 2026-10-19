#!/bin/bash
# Starts the selected screen saver, lets it settle, then samples power.
# Keep your hands off the mouse and keyboard until the readings print (about 25 seconds).
set -euo pipefail
sudo -v
open /System/Library/CoreServices/ScreenSaverEngine.app
sleep 12
sudo powermetrics --samplers gpu_power,cpu_power -i 2000 -n 5 \
  | grep -E "GPU HW active residency|GPU Power|CPU Power"
