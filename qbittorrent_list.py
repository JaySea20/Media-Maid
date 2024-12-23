#!/usr/bin/env bash
#
# qbittorrent_list.sh
# Logs into qBittorrent Web UI, fetches a list of torrents,
# and writes their names to a text file (torrent_names.txt).

########################################
# Configuration
########################################
QB_HOST="http://127.0.0.1"     # qBittorrent Web UI host
QB_PORT="8080"                 # qBittorrent Web UI port
QB_USER="admin"                # Your QB username
QB_PASS="adminadmin"           # Your QB password

COOKIE_FILE="./qbit_cookie.txt"
TORRENT_NAMES_FILE="./torrent_names.txt"  # Where to store list of torrent names

########################################
# 1. Log in to qBittorrent
########################################
echo "=> Logging in to qBittorrent at ${QB_HOST}:${QB_PORT} ..."
LOGIN_RESPONSE=$(curl -i -s -X POST \
  -c "${COOKIE_FILE}" \
  -d "username=${QB_USER}&password=${QB_PASS}" \
  "${QB_HOST}:${QB_PORT}/api/v2/auth/login")

# Check if login was successful
# qBittorrent returns "Ok." (status 200) on success.
if echo "${LOGIN_RESPONSE}" | grep -q "Ok."; then
  echo "   Login successful."
else
  echo "ERROR: Failed to log in. Check username/password or qBittorrent settings."
  exit 1
fi

########################################
# 2. Fetch list of torrents
########################################
echo "=> Fetching list of torrents..."
TORRENTS_RESPONSE=$(curl -s \
  -b "${COOKIE_FILE}" \
  "${QB_HOST}:${QB_PORT}/api/v2/torrents/info")

# (Optional) If you want to see raw JSON:
# echo "${TORRENTS_RESPONSE}"

########################################
# 3. Extract torrent names and write to file
########################################
echo "=> Parsing torrent names and writing to: ${TORRENT_NAMES_FILE}"
python3 <<EOF
import json

try:
    data = json.loads('''${TORRENTS_RESPONSE}''')
    with open("${TORRENT_NAMES_FILE}", "w", encoding="utf-8") as f:
        for t in data:
            name = t.get("name", "UNKNOWN_TORRENT")
            f.write(name + "\\n")
    print(f"Wrote {len(data)} names to ${TORRENT_NAMES_FILE}")
except Exception as e:
    print("Error parsing qBittorrent JSON:", e)
    raise
EOF

########################################
# 4. Cleanup
########################################
rm -f "${COOKIE_FILE}"
echo "=> Done. Cookie removed."
echo "Torrent names are in: ${TORRENT_NAMES_FILE}"
