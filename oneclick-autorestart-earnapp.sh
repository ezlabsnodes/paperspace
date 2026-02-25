#!/bin/bash

# Ensure the script is run as root (needed for systemctl)
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (Use sudo)"
  exit
fi

echo "========================================="
echo " Installing Dependencies (Python3 & Screen)"
echo "========================================="
# Installing dependencies directly for a faster setup
apt-get install -y python3 screen

echo -e "\n========================================="
echo " Creating Python File (autorestart.py)"
echo "========================================="

# Using cat EOF to write directly to the autorestart.py file
cat << 'EOF' > autorestart.py
import time
import os
import subprocess

# --- CONFIGURATION ---
SERVICE_NAME = "earnapp-proxy"
CHECK_INTERVAL = 180  # 3 Minutes (seconds)
DENIED_THRESHOLD = 5  # If there are 5 "denied" or more, restart immediately

def check_log_status():
    print(f"\n[LOG] Checking service status: {SERVICE_NAME}...")
    
    # Command to get the latest status & log (without paging)
    # -n 20 means grab the last 20 lines
    cmd = f"systemctl status {SERVICE_NAME} -n 20 --no-pager"
    
    try:
        # Run the command and capture its output
        output = subprocess.check_output(cmd, shell=True, text=True)
        
        # Count the word "denied"
        denied_count = output.count("denied")
        
        print(f"[INFO] Found {denied_count} 'denied' errors in the latest log.")
        return denied_count
        
    except subprocess.CalledProcessError:
        print("[ERROR] Failed to check status (service might be completely dead).")
        return 0

def restart_service():
    print(f"[ACTION] Too many errors! Restarting service {SERVICE_NAME}...")
    os.system(f"systemctl restart {SERVICE_NAME}")
    print("[DONE] Service restarted. Waiting 1 minute to stabilize...")
    time.sleep(60) # Wait a bit to let the log clear up

# --- MAIN PROGRAM ---
print(f"=== LOG WATCHER BOT: {SERVICE_NAME} STARTED ===")
print(f"Check Interval: {CHECK_INTERVAL} seconds | Denied Threshold: {DENIED_THRESHOLD}")

while True:
    try:
        error_count = check_log_status()

        if error_count >= DENIED_THRESHOLD:
            # If errors pile up, RESTART
            restart_service()
        else:
            # If safe
            print("[OK] Log looks safe. Waiting for the next check...")
    
    except Exception as e:
        print(f"[ERROR] An error occurred in the bot: {e}")

    # Wait 3 minutes
    print(f">> Sleep {CHECK_INTERVAL} seconds...\n")
    time.sleep(CHECK_INTERVAL)
EOF

echo "File autorestart.py successfully created!"

echo -e "\n========================================="
echo " Running Script in Background (Screen)"
echo "========================================="

# Remove old screen if it exists with the same name to avoid duplicates
screen -S autorestart-earnapp -X quit 2>/dev/null

# Run python script inside a detached screen (-dmS)
screen -dmS autorestart-earnapp python3 $(pwd)/autorestart.py

echo "Done! The script is now running in the background."
echo "========================================="
echo ">> To view the bot log, use the command: screen -r autorestart-earnapp"
echo ">> To exit the screen view (without killing the bot), press: CTRL+A, then press D"
echo "========================================="
