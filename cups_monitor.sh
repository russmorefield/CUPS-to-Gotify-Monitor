#!/bin/bash
#
# cups_monitor.sh
#
# Monitors CUPS for:
# 1. Completed print jobs (via page_log)
# 2. Printer hardware/filter errors (via error_log)
# 3. CUPS service status (via systemctl)
#
# Runs persistently. Designed to be managed by a systemd service.
#

# --- CONFIGURATION ---
# !! SET THESE VALUES !!
GOTIFY_URL="http://your-gotify-server.example.com"
GOTIFY_TOKEN="YourGotifyAppTokenHere"
# ---------------------

# --- SCRIPT SETTINGS ---
LOG_FILE="/var/log/cups/page_log"
ERROR_LOG="/var/log/cups/error_log"
SERVICE_NAME="cups.service"
# How often (in seconds) to check if the CUPS service is running
SERVICE_CHECK_INTERVAL=60
# Hostname to include in the message for clarity
PI_HOSTNAME=$(hostname)
# ---------------------

#
# Generic function to send a notification to Gotify
#
send_gotify() {
    local title="$1"
    local message="$2"
    local priority="$3"

    curl -s -X POST "$GOTIFY_URL/message" \
         -H "X-Gotify-Key: $GOTIFY_TOKEN" \
         -H "Content-Type: application/json" \
         -d "{\"title\": \"$title\", \"message\": \"$message\", \"priority\": $priority}"
}

#
# TASK 1: Monitor for successful print jobs
#
monitor_success() {
    echo "[Monitor] Starting success log monitor for $LOG_FILE..."
    tail -n 0 -f "$LOG_FILE" | while read line
    do
        # Check if the line is not empty
        if [ -n "$line" ]; then
            # Parse the page_log line
            # Format (from PageLogFormat %p %u %j %T %P %C):
            # $1=Printer, $2=User, $3=Job-ID, $4/$5=Time, $6=Pages, $7=Copies
            # NOTE: Your log showed pages as field 7 ("total 1"), so we use $7.
            # If your PageLogFormat is different, this 'awk' command may need to be changed.
            
            local PRINTER=$(echo "$line" | awk '{print $1}')
            local USER=$(echo "$line" | awk '{print $2}')
            local JOB_ID=$(echo "$line" | awk '{print $3}')
            local PAGES=$(echo "$line" | awk '{print $7}') # Using $7 based on user log
            
            # Prepare notification content
            local TITLE="Print Job Completed: $JOB_ID"
            local MESSAGE="$USER printed $PAGES page(s) on $PRINTER (Job $JOB_ID) via $PI_HOSTNAME."
            
            # Send notification in the background
            send_gotify "$TITLE" "$MESSAGE" 5 &
        fi
    done
}

#
# TASK 2: Monitor for hardware and software errors
#
monitor_errors() {
    echo "[Monitor] Starting error log monitor for $ERROR_LOG..."
    # We tail the error_log and pipe it to grep to filter for critical errors
    # --line-buffered is ESSENTIAL so grep outputs lines immediately
    tail -n 0 -f "$ERROR_LOG" | grep --line-buffered -E -i \
        "filter failed|unable to open|not responding|disconnected|offline|stopped" | \
    while read error_line
    do
        # Check if the line is not empty
        if [ -n "$error_line" ]; then
            # Send high-priority notification in the background
            local TITLE="CUPS Printer Error on $PI_HOSTNAME"
            # Send the raw error line for debugging
            local MESSAGE="$error_line"
            send_gotify "$TITLE" "$MESSAGE" 8 &
        fi
    done
}

#
# TASK 3: Monitor that the CUPS service itself is running
#
monitor_service() {
    echo "[Monitor] Starting service monitor for $SERVICE_NAME..."
    # We need to track the last known status to avoid spamming notifications
    local last_status="active"

    while true
    do
        # Check the service status
        local current_status=$(systemctl is-active "$SERVICE_NAME")

        if [ "$current_status" != "active" ] && [ "$last_status" == "active" ]; then
            # The service just went down
            local TITLE="CUPS Service DOWN on $PI_HOSTNAME"
            local MESSAGE="The CUPS service ($SERVICE_NAME) is no longer active. Status: $current_status"
            send_gotify "$TITLE" "$MESSAGE" 10 &
            last_status="inactive"

        elif [ "$current_status" == "active" ] && [ "$last_status" == "inactive" ]; then
            # The service just came back up
            local TITLE="CUPS Service RESTORED on $PI_HOSTNAME"
            local MESSAGE="The CUPS service ($SERVICE_NAME) is active again."
            send_gotify "$TITLE" "$MESSAGE" 5 &
            last_status="active"
        fi
        
        # Wait for the next check
        sleep "$SERVICE_CHECK_INTERVAL"
    done
}

# --- Main Execution ---

# Check if log files are readable
if [ ! -r "$LOG_FILE" ]; then
    echo "Error: Cannot read $LOG_FILE. Please run as root or fix permissions." >&2
    echo "This file may also not exist. See README.md for setup instructions." >&2
    exit 1
fi
if [ ! -r "$ERROR_LOG" ]; then
    echo "Error: Cannot read $ERROR_LOG. Please run as root or fix permissions." >&2
    exit 1
fi

echo "Starting all CUPS Gotify monitors..."

# Launch all three monitoring functions in the background
monitor_success &
monitor_errors &
monitor_service &

# Wait for all backgrounded processes to exit
# If any of them crash, 'wait' will exit, and systemd will restart the script.
wait

