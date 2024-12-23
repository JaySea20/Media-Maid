#!/usr/bin/env bash
#
# deluge_list.sh
# A fully interactive script to list torrents from a Deluge daemon, printing each step to the shell
# and also outputting torrent names to a txt file.
#
# It uses Python to parse JSON instead of jq.
# It stores any temporary files and logs in /home/user/

#######################################
# Configuration: All writes in HOME_DIR
#######################################
HOME_DIR="/home/user"
COOKIE_FILE="${HOME_DIR}/deluge_cookie.txt"          # File to store session cookie
LOG_FILE="${HOME_DIR}/deluge_script.log"             # Example log file (if needed)
TORRENT_NAMES_FILE="${HOME_DIR}/deluge_torrent_names.txt"  # Where to save torrent names

# If you want to store a temp file with a random suffix, you can do:
# COOKIE_FILE="$(mktemp -p "$HOME_DIR" deluge_cookie.XXXXXX)"

#######################################
# 0. Prompt the user for configuration
#######################################

echo "===================================="
echo "     DELUGE INTERACTIVE SCRIPT      "
echo "===================================="

# 1) Deluge Web UI host/port
read -rp "Enter Deluge Web UI address [default: http://127.0.0.1:port]: " DELUGE_HOST
if [ -z "$DELUGE_HOST" ]; then
  DELUGE_HOST="http://127.0.0.1:port"
fi

# 2) Deluge Web UI password
read -rp "Enter Deluge Web UI password [default: password]: " DELUGE_PASSWORD
if [ -z "$DELUGE_PASSWORD" ]; then
  DELUGE_PASSWORD="password"
fi

# 3) Which fields do we want to see?
#    - If "all", pass an empty array [] to get everything
#    - If "some", pass a predefined subset of fields
echo
echo "Choose how much torrent info you want to see:"
echo "1) All fields (full JSON for each torrent)"
echo "2) Only a few fields (name, state, progress, speeds)"
read -rp "Your choice [1/2, default=2]: " FIELD_CHOICE
if [ -z "$FIELD_CHOICE" ]; then
  FIELD_CHOICE=2
fi

FIELDS_ARRAY=''
if [ "$FIELD_CHOICE" = "1" ]; then
  # All fields
  FIELDS_ARRAY="[]"
else
  # Some fields
  FIELDS_ARRAY='["name","state","progress","download_payload_rate","upload_payload_rate"]'
fi

#######################################
# (Optional) Start a log file
#######################################
echo "Deluge Interactive Script starting at $(date)" > "$LOG_FILE"
echo "Using HOME_DIR: $HOME_DIR" >> "$LOG_FILE"
echo "COOKIE_FILE: $COOKIE_FILE" >> "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" >> "$LOG_FILE"
echo "TORRENT_NAMES_FILE: $TORRENT_NAMES_FILE" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"

#######################################
# 1. Log in to the Web UI
#######################################
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
    "${DELUGE_HOST}/json"
)

# Print the raw login response to the shell and log file
echo "Login response (raw JSON):"
echo "$LOGIN_RESPONSE" | sed 's/^/  /'
echo "Login response (raw JSON):" >> "$LOG_FILE"
echo "$LOGIN_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

# Check if login was successful (using inline Python)
LOGIN_RESULT=$(python3 <<EOF
import sys, json
data = json.loads("""${LOGIN_RESPONSE}""")
print(data.get("result"))
EOF
)

if [ "${LOGIN_RESULT}" != "True" ]; then
  echo "ERROR: Login failed (result=${LOGIN_RESULT}). Check your password or Deluge Web settings."
  echo "ERROR: Login failed (result=${LOGIN_RESULT})." >> "$LOG_FILE"
  exit 1
fi
echo "=> Logged in successfully."
echo "=> Logged in successfully." >> "$LOG_FILE"

#######################################
# 2. Get the list of available hosts
#######################################
echo
echo "STEP 2: Retrieving list of daemon hosts..."
echo "STEP 2: Retrieving list of daemon hosts..." >> "$LOG_FILE"

GET_HOSTS_RESPONSE=$(
  curl -s \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --cookie "${COOKIE_FILE}" \
    --data '{
      "method": "web.get_hosts",
      "params": [],
      "id": 2
    }' \
    "${DELUGE_HOST}/json"
)

echo "Hosts response (raw JSON):"
echo "$GET_HOSTS_RESPONSE" | sed 's/^/  /'
echo "Hosts response (raw JSON):" >> "$LOG_FILE"
echo "$GET_HOSTS_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

# Extract first host ID using Python
HOST_ID=$(python3 <<EOF
import sys, json
data = json.loads("""${GET_HOSTS_RESPONSE}""")
hosts = data.get("result", [])
if hosts and len(hosts[0]) > 0:
    print(hosts[0][0])
EOF
)

if [ -z "${HOST_ID}" ]; then
  echo "ERROR: No Deluge daemon hosts found. Make sure you have a running daemon."
  echo "ERROR: No Deluge daemon hosts found." >> "$LOG_FILE"
  exit 1
fi
echo "=> Found host ID: ${HOST_ID}"
echo "=> Found host ID: ${HOST_ID}" >> "$LOG_FILE"

#######################################
# 3. Connect to the host (daemon)
#######################################
echo
echo "STEP 3: Connecting to daemon host: ${HOST_ID}"
echo "STEP 3: Connecting to daemon host: ${HOST_ID}" >> "$LOG_FILE"

CONNECT_RESPONSE=$(
  curl -s \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --cookie "${COOKIE_FILE}" \
    --data '{
      "method": "web.connect",
      "params": ["'"${HOST_ID}"'"],
      "id": 3
    }' \
    "${DELUGE_HOST}/json"
)

echo "Connect response (raw JSON):"
echo "$CONNECT_RESPONSE" | sed 's/^/  /'
echo "Connect response (raw JSON):" >> "$LOG_FILE"
echo "$CONNECT_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

# Check if connect was successful or not (optional)
CONNECT_ERROR=$(python3 <<EOF
import sys, json
data = json.loads("""${CONNECT_RESPONSE}""")
print(data.get("error"))
EOF
)
if [ "${CONNECT_ERROR}" != "None" ]; then
  echo "WARNING: Something might have gone wrong connecting to the daemon. (error=$CONNECT_ERROR)"
  echo "WARNING: Something might have gone wrong. (error=$CONNECT_ERROR)" >> "$LOG_FILE"
fi
echo "=> Connection command sent."
echo "=> Connection command sent." >> "$LOG_FILE"

#######################################
# 4. Fetch and print torrent data
#######################################
echo
echo "STEP 4: Fetching torrent data..."
echo "STEP 4: Fetching torrent data..." >> "$LOG_FILE"
echo "   Fields array = $FIELDS_ARRAY"
echo "   Fields array = $FIELDS_ARRAY" >> "$LOG_FILE"

TORRENTS_RESPONSE=$(
  curl -s \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --cookie "${COOKIE_FILE}" \
    --data '{
      "method": "core.get_torrents_status",
      "params": [
        {},
        '"${FIELDS_ARRAY}"'
      ],
      "id": 4
    }' \
    "${DELUGE_HOST}/json"
)

echo "Torrents response (raw JSON):"
echo "$TORRENTS_RESPONSE" | sed 's/^/  /'
echo "Torrents response (raw JSON):" >> "$LOG_FILE"
echo "$TORRENTS_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

#######################################
# 5. Parse torrent data & Write to file
#######################################
echo
echo "STEP 5: Parsing torrent data and displaying it. Also writing torrent names to file."
echo "STEP 5: Parsing torrent data and writing to '$TORRENT_NAMES_FILE'." >> "$LOG_FILE"

python3 <<EOF
import json

try:
    data = json.loads("""${TORRENTS_RESPONSE}""")
    result = data.get("result", {})
    if not result:
        print("No torrents found or empty result.")
    else:
        # We'll open the output file and write each torrent name to it
        with open("${TORRENT_NAMES_FILE}", "w", encoding="utf-8") as name_file:
            if ${FIELD_CHOICE} == 1:
                # If user chose 1 (all fields), just pretty-print the entire data to the console
                print("Displaying ALL fields for each torrent (pretty-printed):")
                print(json.dumps(result, indent=2))
                print()
                print(f"Also writing each torrent name to: ${TORRENT_NAMES_FILE}")
                for torrent_hash, info in result.items():
                    name = info.get("name", "UNKNOWN")
                    name_file.write(name + "\\n")
            else:
                # If user chose partial fields, let's show them in a friendlier format
                print("Displaying partial fields (name, state, progress, speeds):")
                print("---------------------------------------------------")
                for torrent_hash, info in result.items():
                    name = info.get("name", "UNKNOWN")
                    state = info.get("state", "UNKNOWN")
                    progress = info.get("progress", 0.0)
                    dl_speed = info.get("download_payload_rate", 0)
                    ul_speed = info.get("upload_payload_rate", 0)
                    print(f"Torrent: {name}")
                    print(f"  Hash: {torrent_hash}")
                    print(f"  State: {state}")
                    print(f"  Progress: {progress}%")
                    print(f"  Download Speed: {dl_speed} B/s")
                    print(f"  Upload Speed:   {ul_speed} B/s")
                    print("---------------------------------------------------")

                    name_file.write(name + "\\n")

except Exception as e:
    print("Failed to parse or retrieve torrents:", e)
EOF

#######################################
# 6. Clean up
#######################################
echo
echo "STEP 6: Cleaning up temporary file(s)."
echo "STEP 6: Cleaning up temporary file(s)." >> "$LOG_FILE"

if [ -f "$COOKIE_FILE" ]; then
  rm -f "$COOKIE_FILE"
  echo "Removed cookie file: $COOKIE_FILE"
  echo "Removed cookie file: $COOKIE_FILE" >> "$LOG_FILE"
fi

echo
echo "All done! Log written to: $LOG_FILE"
echo "Torrent names are saved to: $TORRENT_NAMES_FILE"
echo "Exiting..."
echo "Script finished at $(date)" >> "$LOG_FILE"
