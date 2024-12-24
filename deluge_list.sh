#!/usr/bin/env bash
#
# deluge_list.sh
# Fetches a list of all torrents from Deluge using the JSON-RPC API and saves their names to a file.

##################################################################
#                          CONFIGURATION                        #
##################################################################

###############################
# --- User Configuration ---
###############################

# Base URL of your Deluge JSON-RPC API (ensure correct port and protocol)
# This uses WEB Port. Not your Daemon port
DELUGE_HOST="http://url_here:port"

# Password for Deluge authentication
DELUGE_PASSWORD="deluge_pass"

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output directories (relative to the script's directory)
TORRENT_OUTPUT_DIR="${SCRIPT_DIR}/torrent_lists"
LOG_DIR="${SCRIPT_DIR}/logs"
TMP_DIR="${SCRIPT_DIR}/tmp"

# Output file for torrent names (within the torrent output directory)
TORRENT_NAMES_FILE="${TORRENT_OUTPUT_DIR}/torrent_names.txt"

# Log file to record the script's activities (within the logs directory)
LOG_FILE="${LOG_DIR}/deluge_list.log"

# Deluge JSON-RPC fields to retrieve for each torrent (customize as needed)
# Example: To retrieve only the 'name' field
FIELDS_ARRAY='["name"]'

# Field choice for summary output (1 for full JSON, any other number for partial fields)
FIELD_CHOICE=2

###############################
# --- Development Config ---
###############################

# Do not change unless you are sure about the implications.

# Deluge JSON-RPC endpoint
DELUGE_RPC_URL="${DELUGE_HOST}/json"

# Temporary file to store cookies for session management (within tmp directory)
COOKIE_FILE="${TMP_DIR}/deluge_cookies.txt"

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
echo "== Deluge List Script Log ==" > "${LOG_FILE}"
echo "Script started at $(date)" >> "${LOG_FILE}"

##################################################################
#               LOGIN TO DELUGE JSON-RPC API                     #
##################################################################

echo
echo "STEP 1: Logging in to Deluge Web UI at: $DELUGE_HOST"
echo "STEP 1: Logging in to Deluge Web UI at: $DELUGE_HOST" >> "$LOG_FILE"

LOGIN_RESPONSE=$(
  curl -s \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --cookie-jar "${COOKIE_FILE}" \
    --data '{
      "method": "auth.login",
      "params": ["'"${DELUGE_PASSWORD}"'"],
      "id": 1
    }' \
    "${DELUGE_RPC_URL}" \
    --max-time 15 \
    --insecure
)

# Log the raw response
echo "Login response (raw JSON):" >> "$LOG_FILE"
echo "$LOGIN_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

# Check if login was successful
LOGIN_RESULT=$(python3 <<EOF
import sys, json
try:
    obj = json.loads("""${LOGIN_RESPONSE}""")
    result = obj.get("result")
    if isinstance(result, bool):
        print("True" if result else "False")
    else:
        print("False")
except:
    print("False")
EOF
)

if [ "${LOGIN_RESULT}" != "True" ]; then
  echo "ERROR: Login failed (result=${LOGIN_RESULT}). Check password or Deluge Web settings."
  echo "ERROR: Login failed (result=${LOGIN_RESULT})." >> "$LOG_FILE"
  rm -f "${COOKIE_FILE}"
  exit 1
fi
echo "=> Logged in successfully."
echo "=> Logged in successfully." >> "$LOG_FILE"

#######################################
# 2. Retrieve list of daemon hosts
#######################################
echo
echo "STEP 2: Retrieving list of daemon hosts..."
echo "STEP 2: Retrieving list of daemon hosts..." >> "$LOG_FILE"

GET_HOSTS_RESPONSE=$(
  curl -s \
    -X POST \
    --cookie "${COOKIE_FILE}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data '{
      "method": "web.get_hosts",
      "params": [],
      "id": 2
    }' \
    "${DELUGE_RPC_URL}" \
    --max-time 15 \
    --insecure
)

echo "Hosts response (raw JSON):" >> "$LOG_FILE"
echo "$GET_HOSTS_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

HOST_ID=$(python3 <<EOF
import sys, json
try:
    data = json.loads("""${GET_HOSTS_RESPONSE}""")
    hosts = data.get("result", [])
    if hosts and isinstance(hosts, list):
        first_host = hosts[0][0] if len(hosts[0]) > 0 else ""
        print(first_host)
    else:
        print("")
except:
    print("")
EOF
)

if [ -z "$HOST_ID" ]; then
  echo "ERROR: No Deluge daemon hosts found."
  echo "ERROR: No Deluge daemon hosts found." >> "$LOG_FILE"
  rm -f "${COOKIE_FILE}"
  exit 1
fi
echo "=> Found host ID: $HOST_ID"
echo "=> Found host ID: $HOST_ID" >> "$LOG_FILE"

#######################################
# 3. Connect to daemon host
#######################################
echo
echo "STEP 3: Connecting to daemon host: $HOST_ID"
echo "STEP 3: Connecting to daemon host: $HOST_ID" >> "$LOG_FILE"

CONNECT_RESPONSE=$(
  curl -s \
    -X POST \
    --cookie "${COOKIE_FILE}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data '{
      "method": "web.connect",
      "params": ["'"$HOST_ID"'"],
      "id": 3
    }' \
    "${DELUGE_RPC_URL}" \
    --max-time 15 \
    --insecure
)

echo "Connect response (raw JSON):" >> "$LOG_FILE"
echo "$CONNECT_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

#######################################
# 4. Fetch Torrent Data
#######################################
echo
echo "STEP 4: Fetching torrent data..."
echo "STEP 4: Fetching torrent data..." >> "$LOG_FILE"

TORRENTS_RESPONSE=$(
  curl -s \
    -X POST \
    --cookie "${COOKIE_FILE}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data '{
      "method": "core.get_torrents_status",
      "params": [
        {},
        '"$FIELDS_ARRAY"'
      ],
      "id": 4
    }' \
    "${DELUGE_RPC_URL}" \
    --max-time 15 \
    --insecure
)

echo "Torrent data (raw JSON) saved to log." >> "$LOG_FILE"
echo "$TORRENTS_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

#######################################
# 5. Parse & Output to File
#######################################
echo
echo "STEP 5: Parsing torrent data, writing names to '$TORRENT_NAMES_FILE'."
echo "STEP 5: Parsing torrent data, writing names to '$TORRENT_NAMES_FILE'." >> "$LOG_FILE"

python3 <<EOF
import json, sys

try:
    data = json.loads("""${TORRENTS_RESPONSE}""")
    torrents = data.get("result", {})
    if not torrents:
        print("No torrents found or empty result.")
    else:
        # Save torrent names to file
        with open("${TORRENT_NAMES_FILE}", "w", encoding="utf-8") as f:
            for hash_id, info in torrents.items():
                name = info.get("name", "UNKNOWN")
                f.write(name + "\\n")

        # Optionally print summary
        if ${FIELD_CHOICE} == 1:
            print("===> Full JSON (All Fields) <===")
            print(json.dumps(torrents, indent=2))
        else:
            print("===> Partial Fields (name) <===")
            for h, info in torrents.items():
                print(f"- {info.get('name','UNKNOWN')}")
except json.JSONDecodeError as e:
    print("Error decoding JSON from Deluge:", e)
except Exception as e:
    print("Error parsing torrent data:", e)
EOF

#######################################
# 6. Clean Up
#######################################
echo
echo "STEP 6: Cleaning up..."
echo "STEP 6: Cleaning up..." >> "$LOG_FILE"

rm -f "${COOKIE_FILE}"

echo "Removed cookie file: ${COOKIE_FILE}" >> "$LOG_FILE"
echo "Torrent names are saved to: $TORRENT_NAMES_FILE"
echo "Log written to: $LOG_FILE"
echo "Done."
echo "== Finished at $(date) ==" >> "$LOG_FILE"
