CUPS to Gotify MonitorThis project contains a simple Bash script and systemd service to actively monitor a CUPS print server on a Linux machine (like a Raspberry Pi). It sends notifications to a Gotify server for print successes, hardware/software failures, and CUPS service status.This monitor is designed to be lightweight, persistent, and "set-it-and-forget-it."FeaturesSuccess Notifications: Sends a low-priority message for every successfully completed print job, including user, printer, and page count.Failure Monitoring: Watches the error_log for critical errors (e.g., "filter failed", "disconnected", "offline") and sends a high-priority alert.Service Monitoring: Actively polls systemd to check if the cups.service is running. It sends a high-priority alert if the service goes down and a follow-up notification when it's restored.Persistent: Runs as a systemd service, so it starts automatically on boot and restarts if it ever crashes.RequirementsA Linux server running CUPS.A running Gotify server and an application token.curl installed on the CUPS server (sudo apt install curl).systemd (standard on most modern Linux distros, including Raspbian).InstallationClone or Download:Clone this repository or download the three files (cups_monitor.sh, cups-gotify-monitor.service, README.md) to your CUPS server.Configure the Monitor Script:Open cups_monitor.sh and edit the configuration variables at the top:# --- CONFIGURATION ---
# !! SET THESE VALUES !!
GOTIFY_URL="[http://your-gotify-server.example.com](http://your-gotify-server.example.com)"
GOTIFY_TOKEN="YourGotifyAppTokenHere"
# ---------------------
Install the Script:Move the script to a standard binary location and make it executable:sudo mv cups_monitor.sh /usr/local/bin/cups_monitor.sh
sudo chmod +x /usr/local/bin/cups_monitor.sh
Install the Systemd Service:Move the .service file to the systemd directory:sudo mv cups-gotify-monitor.service /etc/systemd/system/cups-gotify-monitor.service
Note: If you changed the script location in the previous step, you must edit cups-gotify-monitor.service and update the ExecStart= path to match.Enable and Start the Service:Reload the systemd daemon, enable the service to start on boot, and start it right now:sudo systemctl daemon-reload
sudo systemctl enable cups-gotify-monitor.service
sudo systemctl start cups-gotify-monitor.service
Post-Installation: MUST-DO ConfigurationYour monitor will not work until you do this!By default, CUPS does not write to the page_log file that this script relies on for success notifications. You must enable it.Edit your CUPS configuration file:sudo nano /etc/cups/cupsd.conf
Find and edit the following lines. They may be commented out (with a #) or have different values. Make them look like this:# Set LogLevel to 'info' to capture job completion
LogLevel info

# Define the format for the page_log
PageLogFormat %p %u %j %T %P %C

# Ensure the PageLog is enabled (no '#' in front)
PageLog /var/log/cups/page_log
The PageLogFormat line is critical. If it's blank or missing, the page_log will remain empty.Restart the CUPS service to apply the new configuration:sudo systemctl restart cups.service
Manually Create the Log File (Optional but Recommended):The page_log file might not be created until the first successful print. To ensure the monitor service starts correctly, it's best to create the file manually:sudo touch /var/log/cups/page_log
sudo chown root:adm /var/log/cups/page_log
sudo chmod 640 /var/log/cups/page_log
Now, restart your monitor service to make sure it's running:sudo systemctl restart cups-gotify-monitor.service
Print a Test Page!You're all set. Send a test print. You should receive a Gotify notification in a few seconds!Checking the Monitor StatusTo see if the service is running correctly:sudo systemctl status cups-gotify-monitor.service
You should see Active: active (running).To watch the live log output from the script itself:sudo journalctl -u cups-gotify-monitor.service -f
LicenseThis project is licensed under the MIT License. See the LICENSE file for details.
