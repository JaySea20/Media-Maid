#!/usr/bin/env python3
"""
media_maid.py
---------------------
1) Skip folders that are listed in a skip-file (by default: torrent_names.txt).
2) For each folder in downloads:
   - If folder type is 'movie', check if that movie is in Plex, then optionally delete.
   - If folder type is 'episode', we examine each video file in that folder to see if
     all episodes are in Plex. If so, optionally delete the folder. Otherwise, keep it.
   - Otherwise, skip.
"""

import os
import shutil
from guessit import guessit
from plexapi.server import PlexServer

############################################
# ----------------- CONFIG -----------------
############################################

# Downoload Directory.
# This is the directory you want to clean
DATA_DIR = "/home/torrents/data"

PLEX_BASEURL = "http://url.to.plex:port"  # Plex server URL
PLEX_TOKEN = "plex_token"                  # Replace with your Plex token

DELETE_CONFIRMED = False  # If True, auto-delete found content. If False, prompt user.

############################################
# ---           DEV Config             ---
############################################

plex = PlexServer(PLEX_BASEURL, PLEX_TOKEN)

# Determine the directory where the script is located
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Output directories (relative to the script's directory)
TORRENTS_OUTPUT_DIR = os.path.join(SCRIPT_DIR, "torrent_lists")

# Output file for torrent names (within the torrent output directory)
TORRENTS_FILE = os.path.join(TORRENTS_OUTPUT_DIR, "torrent_names.txt")

# ------------------------------------------
# 1) Movie logic
# ------------------------------------------
def is_in_plex_movie(title, year=None):
    """
    Search Plex for a movie with matching title (and optional year).
    Returns True if at least one result matches, else False.
    """
    results = plex.search(title, mediatype='movie')
    for video in results:
        if video.type == 'movie':
            # Simple normalization
            plex_title = video.title.lower().replace(":", "").replace("'", "").strip()
            guess_title = title.lower().replace(":", "").replace("'", "").strip()

            if plex_title == guess_title:
                if year is not None:
                    if video.year == year:
                        return True
                else:
                    return True
    return False

# ------------------------------------------
# 2) TV logic
# ------------------------------------------
def is_in_plex_show(series_name, season_num, episode_num):
    """
    Check if Plex has a specific show episode:
      - 'series_name', 'season_num', 'episode_num'.
    Returns True if found, else False.
    """
    results = plex.search(series_name, mediatype='show')
    for show in results:
        if show.type == 'show':
            # Compare titles with some normalization
            plex_title = show.title.lower().replace(":", "").replace("'", "").strip()
            guess_title = series_name.lower().replace(":", "").replace("'", "").strip()

            if plex_title == guess_title:
                try:
                    found_ep = show.episode(season=season_num, episode=episode_num)
                    if found_ep:
                        return True
                except:
                    pass
    return False

def check_tv_folder(folder_path):
    """
    For a TV folder, look at each video file within it:
      - Parse each file with guessit
      - If we can parse 'series', 'season', 'episode', check Plex
      - If ANY episode is missing, keep the folder
      - If ALL episodes are found, consider folder safe to remove
    Returns True if folder can be removed, False otherwise.
    """
    all_found = True
    video_extensions = {'.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.ts', '.m4v'}

    for root, dirs, files in os.walk(folder_path):
        for filename in files:
            # Only parse known video file extensions
            _, ext = os.path.splitext(filename)
            if ext.lower() not in video_extensions:
                continue

            filepath = os.path.join(root, filename)
            info = guessit(filename)

            if info.get('type') != 'episode':
                print(f"  [!] File '{filename}' not recognized as an episode. Keeping folder.")
                return False

            series = info.get('title')
            season = info.get('season')
            episode = info.get('episode')

            if not series or season is None or episode is None:
                print(f"  [!] Could not parse series/season/episode from '{filename}'. Keeping folder.")
                return False

            print(f"  Checking episode: series='{series}', season={season}, ep={episode}")
            if not is_in_plex_show(series, season, episode):
                print(f"  => Episode S{season}E{episode} NOT in Plex. Keeping folder.")
                all_found = False
                # Could break here, but we continue in case you want to see more missing episodes.

    return all_found

def main():
    # 1) Read the skip-list
    if not os.path.isfile(TORRENTS_FILE):
        print(f"ERROR: Skip-list file not found: {TORRENTS_FILE}")
        return

    with open(TORRENTS_FILE, 'r') as f:
        skip_set = { line.strip() for line in f if line.strip() }

    print("Folders listed in skip-list (skip_set):")
    for name in skip_set:
        print(f"  - {name}")
    print("------------------------------------------------")

    # 2) Iterate over folders in DATA_DIR
    if not os.path.isdir(DATA_DIR):
        print(f"ERROR: DATA_DIR not found: {DATA_DIR}")
        return

    for entry in os.scandir(DATA_DIR):
        if not entry.is_dir():
            continue

        folder_name = entry.name
        folder_path = entry.path

        # Skip if folder is in skip-list
        if folder_name in skip_set:
            print(f"[SKIP] '{folder_name}' is in skip-list. Doing nothing.")
            continue

        # Initial guessit parse
        info = guessit(folder_name)
        media_type = info.get('type')

        if not media_type:
            print(f"[SKIP] Could not determine media type for '{folder_name}'.")
            continue

        # -------------------------
        # Movie Logic
        # -------------------------
        if media_type == 'movie':
            title = info.get('title')
            year = info.get('year')
            if not title:
                print(f"[SKIP] No title found for '{folder_name}'.")
                continue

            print(f"\nFolder: {folder_name} => MOVIE detected. title='{title}', year={year}")
            in_plex = is_in_plex_movie(title, year)
            if in_plex:
                print("  => Found in Plex library. Safe to remove.")
                if DELETE_CONFIRMED:
                    shutil.rmtree(folder_path)
                    print("  Folder removed automatically.")
                else:
                    user_inp = input("  Delete this folder? (y/N) ")
                    if user_inp.lower().startswith('y'):
                        shutil.rmtree(folder_path)
                        print("  Folder removed.")
                    else:
                        print("  Skipping removal.")
            else:
                print("  => NOT found in Plex. Keeping folder.")

        # -------------------------
        # TV Logic
        # -------------------------
        elif media_type == 'episode':
            print(f"\nFolder: {folder_name} => TV SHOW detected.")
            safe_to_remove = check_tv_folder(folder_path)
            if safe_to_remove:
                print("  => ALL episodes found in Plex. Safe to remove.")
                if DELETE_CONFIRMED:
                    shutil.rmtree(folder_path)
                    print("  Folder removed automatically.")
                else:
                    user_inp = input("  Delete this TV folder? (y/N) ")
                    if user_inp.lower().startswith('y'):
                        shutil.rmtree(folder_path)
                        print("  Folder removed.")
                    else:
                        print("  Skipping removal.")
            else:
                print("  => Some or all episodes missing. Keeping folder.")

        else:
            print(f"[SKIP] '{folder_name}': guessit type='{media_type}' (not movie or TV).")
            continue

if __name__ == "__main__":
    main()
