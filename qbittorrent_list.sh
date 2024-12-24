#!/usr/bin/env bash
#
# qbittorrent_list.sh
# Fetches a list of all torrents from qBittorrent using the Web API and saves their names to a file.

##################################################################
#                          CONFIGURATION                        #
##################################################################

###############################
# --- User Configuration ---
###############################

# Base URL of your qBittorrent Web API (ensure correct port and protocol)
QBITTORRENT_HOST="http://url_here:port"

# Username and Password for qBittorrent authentication
QBITTORRENT_USERNAME="qbitUser"
QBITTORRENT_PASSWORD="qbitpass"

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output directories (relative to the script's directory)
TORRENT_OUTPUT_DIR="${SCRIPT_DIR}/torrent_lists"
LOG_DIR="${SCRIPT_DIR}/logs"
TMP_DIR="${SCRIPT_DIR}/tmp"

# Output file for torrent names (within the torrent output directory)
TORRENT_NAMES_FILE="${TORRENT_OUTPUT_DIR}/torrent_names.txt"

# Log file to record the script's activities (within the logs directory)
LOG_FILE="${LOG_DIR}/qbittorrent_list.log"

###############################
# --- Development Config ---
###############################

# Do not change unless you are sure about the implications.

# qBittorrent Web API endpoint
QBITTORRENT_API_URL="${QBITTORRENT_HOST}/api/v2"

# Temporary file to store cookies for session management (within tmp directory)
COOKIE_FILE="${TMP_DIR}/qbittorrent_cookies.txt"

##################################################################
#                             SETUP                              #
##################################################################

###############################
# --- Setup Commands ---
###############################

# Ensure the output directories exist. Create them if they don't.
mkdir -p "${TORRENT_OUTPUT_DIR}"
mkdir -p "${LOG_DIR}"
mkdir -p "${TMP_DIR}"

# Initialize or clear the log file
echo "== qBittorrent List Script Log ==" > "${LOG_FILE}"
echo "Script started at $(date)" >> "${LOG_FILE}"

##################################################################
#               LOGIN TO QBITTORRENT WEB API                     #
##################################################################

echo
echo "STEP 1: Logging in to qBittorrent Web UI at: $QBITTORRENT_HOST"
echo "STEP 1: Logging in to qBittorrent Web UI at: $QBITTORRENT_HOST" >> "$LOG_FILE"

# Perform login and store cookies, capture HTTP status code
LOGIN_RESPONSE=$(curl -s \
  -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --cookie-jar "${COOKIE_FILE}" \
  --data "username=${QBITTORRENT_USERNAME}&password=${QBITTORRENT_PASSWORD}" \
  "${QBITTORRENT_API_URL}/auth/login" \
  --max-time 15 \
  --insecure \
  -w "HTTPSTATUS:%{http_code}")

# Extract body and status
LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
LOGIN_STATUS=$(echo "$LOGIN_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

# Log the raw response
echo "Login response (raw JSON):" >> "$LOG_FILE"
echo "$LOGIN_BODY" | sed 's/^/  /' >> "$LOG_FILE"
echo "Login HTTP Status: $LOGIN_STATUS" >> "$LOG_FILE"

# Check if login was successful
if [ "$LOGIN_STATUS" -eq 200 ]; then
  echo "=> Logged in successfully."
  echo "=> Logged in successfully." >> "$LOG_FILE"
else
  echo "ERROR: Login failed. Check username or password."
  echo "ERROR: Login failed with HTTP status $LOGIN_STATUS." >> "$LOG_FILE"
  rm -f "${COOKIE_FILE}"
  exit 1
fi

#######################################
# 2. Fetch Torrent Data
#######################################
echo
echo "STEP 2: Fetching torrent data..."
echo "STEP 2: Fetching torrent data..." >> "$LOG_FILE"

TORRENTS_RESPONSE=$(curl -s \
  -X GET \
  -H "Content-Type: application/json" \
  --cookie "${COOKIE_FILE}" \
  "${QBITTORRENT_API_URL}/torrents/info" \
  --max-time 15 \
  --insecure \
  -w "HTTPSTATUS:%{http_code}")

# Extract body and status
TORRENTS_BODY=$(echo "$TORRENTS_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
TORRENTS_STATUS=$(echo "$TORRENTS_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

echo "Torrent data (raw JSON) saved to log." >> "$LOG_FILE"
echo "$TORRENTS_BODY" | sed 's/^/  /' >> "$LOG_FILE"
echo "Torrent Data HTTP Status: $TORRENTS_STATUS" >> "$LOG_FILE"

# Check if fetch was successful
if [ "$TORRENTS_STATUS" -ne 200 ]; then
  echo "ERROR: Failed to fetch torrent data. HTTP status $TORRENTS_STATUS."
  echo "ERROR: Failed to fetch torrent data. HTTP status $TORRENTS_STATUS." >> "$LOG_FILE"
  rm -f "${COOKIE_FILE}"
  exit 1
fi

#######################################
# 3. Parse & Output to File
#######################################
echo
echo "STEP 3: Parsing torrent data, writing names to '$TORRENT_NAMES_FILE'."
echo "STEP 3: Parsing torrent data, writing names to '$TORRENT_NAMES_FILE'." >> "$LOG_FILE"

python3 <<EOF
import json, sys

try:
    data = json.loads("""${TORRENTS_BODY}""")
    if not isinstance(data, list):
        print("Unexpected data format.")
        sys.exit(1)

    if not data:
        print("No torrents found.")
    else:
        # Save torrent names to file
        with open("${TORRENT_NAMES_FILE}", "w", encoding="utf-8") as f:
            for torrent in data:
                name = torrent.get("name", "UNKNOWN")
                f.write(name + "\\n")

        # Optionally print summary
        print("===> Torrent Names <===")
        for torrent in data:
            name = torrent.get("name", "UNKNOWN")
            print(f"- {name}")
except json.JSONDecodeError as e:
    print("Error decoding JSON from qBittorrent:", e)
    sys.exit(1)
except Exception as e:
    print("Error parsing torrent data:", e)
    sys.exit(1)
EOF

#######################################
# 4. Clean Up
#######################################
echo
echo "STEP 4: Cleaning up..."
echo "STEP 4: Cleaning up..." >> "$LOG_FILE"

rm -f "${COOKIE_FILE}"

echo "Removed cookie file: ${COOKIE_FILE}" >> "$LOG_FILE"
echo "Torrent names are saved to: $TORRENT_NAMES_FILE"
echo "Log written to: $LOG_FILE"
echo "Done."
echo "== Finished at $(date) ==" >> "$LOG_FILE"
