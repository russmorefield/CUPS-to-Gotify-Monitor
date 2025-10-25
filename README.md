CUPS to Gotify Monitor
# CUPS Gotify Monitor

This project contains a simple Bash script and systemd service to actively monitor a CUPS print server on a Linux machine (like a Raspberry Pi). It sends notifications to a Gotify server for print successes, hardware/software failures, and CUPS service status.

This monitor is designed to be lightweight, persistent, and "set-it-and-forget-it."

---

## Features

- **Success Notifications:** Sends a low-priority message for every successfully completed print job, including user, printer, and page count.
- **Failure Monitoring:** Watches the `error_log` for critical errors (e.g., "filter failed", "disconnected", "offline") and sends a high-priority alert.
- **Service Monitoring:** Actively polls systemd to check if the `cups.service` is running. It sends a high-priority alert if the service goes down and a follow-up notification when it's restored.
- **Persistent:** Runs as a systemd service, so it starts automatically on boot and restarts if it ever crashes.

---

## Requirements

- A Linux server running **CUPS**
- A running **Gotify server** and an application token
- **curl** installed on the CUPS server  
  ```bash
  sudo apt install curl

