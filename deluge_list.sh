#!/usr/bin/env bash
#
# deluge_list.sh
# Logs into Deluge, displays torrent info, and writes torrent names to a txt file (torrent_names.txt).

#######################################
# Configuration
#######################################
HOME_DIR="/home/user"
COOKIE_FILE="${HOME_DIR}/deluge_cookie.txt"
LOG_FILE="${HOME_DIR}/deluge_script.log"
TORRENT_NAMES_FILE="${HOME_DIR}/torrent_names.txt"  # Change if desired

#######################################
# 0. Prompt the user for configuration
#######################################
echo "===================================="
echo " DELUGE LIST SCRIPT (TORRENT NAMES) "
echo "===================================="

# 1) Deluge Web UI host/port
read -rp "Enter Deluge Web UI address [default: http://127.0.0.1:8112]: " DELUGE_HOST
if [ -z "$DELUGE_HOST" ]; then
  DELUGE_HOST="http://127.0.0.1:8112"
fi

# 2) Deluge Web UI password
read -rp "Enter Deluge Web UI password [default: deluge]: " DELUGE_PASSWORD
if [ -z "$DELUGE_PASSWORD" ]; then
  DELUGE_PASSWORD="deluge"
fi

# 3) All fields or partial fields?
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
  FIELDS_ARRAY="[]"
else
  FIELDS_ARRAY='["name","state","progress","download_payload_rate","upload_payload_rate"]'
fi

#######################################
# (Optional) Start a log file
#######################################
echo "Deluge Script starting at $(date)" > "$LOG_FILE"
echo "Using HOME_DIR: $HOME_DIR" >> "$LOG_FILE"
echo "COOKIE_FILE: $COOKIE_FILE" >> "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" >> "$LOG_FILE"
echo "TORRENT_NAMES_FILE: $TORRENT_NAMES_FILE" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"

#######################################
# 1. Log in to the Deluge Web UI
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

# Log the raw response
echo "Login response (raw JSON):" >> "$LOG_FILE"
echo "$LOGIN_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

# Check if login was successful
LOGIN_RESULT=$(python3 <<EOF
import sys, json
obj = json.loads("""${LOGIN_RESPONSE}""")
print(obj.get("result"))
EOF
)

if [ "${LOGIN_RESULT}" != "True" ]; then
  echo "ERROR: Login failed (result=${LOGIN_RESULT}). Check password or Deluge Web settings."
  echo "ERROR: Login failed (result=${LOGIN_RESULT})." >> "$LOG_FILE"
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
    "${DELUGE_HOST}/json"
)

echo "Hosts response (raw JSON):" >> "$LOG_FILE"
echo "$GET_HOSTS_RESPONSE" | sed 's/^/  /' >> "$LOG_FILE"

HOST_ID=$(python3 <<EOF
import sys, json
data = json.loads("""${GET_HOSTS_RESPONSE}""")
hosts = data.get("result", [])
print(hosts[0][0] if hosts and len(hosts[0])>0 else "")
EOF
)

if [ -z "$HOST_ID" ]; then
  echo "ERROR: No Deluge daemon hosts found."
  echo "ERROR: No Deluge daemon hosts found." >> "$LOG_FILE"
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
    "${DELUGE_HOST}/json"
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
    "${DELUGE_HOST}/json"
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
import sys, json

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
            print("===> Partial Fields (name, state, progress, speeds) <===")
            for h, info in torrents.items():
                print(f"- {info.get('name','UNKNOWN')}: "
                      f"State={info.get('state','?')} "
                      f"Progress={info.get('progress',0)}% "
                      f"DL={info.get('download_payload_rate',0)}B/s "
                      f"UL={info.get('upload_payload_rate',0)}B/s")

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
