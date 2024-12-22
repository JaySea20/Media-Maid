# Media-Maid

**Media-Maid** is a utility script designed to clean up your download folder by identifying completed media files and organizing or removing them based on their presence in your Plex library. It focuses on automating the tedious task of manually managing downloaded content.

---

## Features

- **Deluge Folder Skipping**: Automatically skips folders still in Deluge to avoid conflicts.
- **Plex Library Integration**: Checks whether movies or TV episodes are already present in your Plex library.
- **Media Analysis**: Uses `guessit` to analyze folder and file names, determining whether the content is a movie or TV show.
- **Selective Deletion**: Provides an option to safely delete media files that are confirmed to be in Plex.
- **Episode-by-Episode Verification**: Ensures all episodes of a TV show folder are present in Plex before considering the folder for deletion.
- **User Confirmation**: Allows manual confirmation before deleting any content, with an optional automatic deletion mode.


---

## Example User Interface

```Terminal
Folder: House.of.the.Dragon.S02E04.iNTERNAL.1080p.WEB.H264-NHTFS => TV SHOW detected.
  Checking episode: series='house of the dragon', season=2, ep=4
  => ALL episodes found in Plex. Safe to remove.
  Delete this TV folder? (y/N) y
  Folder removed.

Folder: Silo S02E05 Descent ATVP WEB-DL AAC2 0 H 264-BTW => TV SHOW detected.
  Checking episode: series='Silo', season=2, ep=5
  => Episode S2E5 NOT in Plex. Keeping folder.
  => Some or all episodes missing. Keeping folder.

Folder: Upload.S03E08.1080p.WEB.h264-ETHEL => TV SHOW detected.
  Checking episode: series='Upload', season=3, ep=8
  => ALL episodes found in Plex. Safe to remove.
  Delete this TV folder? (y/N) y
  Folder removed.

Folder: Remnant 2024 1080p AMZN WEB-DL DDP5 1 H 264-FLUX => MOVIE detected. title='Remnant', year=2024
  => NOT found in Plex. Keeping folder.

Folder: Family.Guy.S15E11.Gronkowsbees.720p.HEVC.x265-MeGusta => TV SHOW detected.
  Checking episode: series='Family Guy', season=15, ep=11
  => ALL episodes found in Plex. Safe to remove.
  Delete this TV folder? (y/N) y
  Folder removed.

Folder: When Calls The Heart S02 WEBRip EAC3 5 1 1080p x265-iVy => TV SHOW detected.
  Checking episode: series='When Calls The Heart', season=2, ep=4
  Checking episode: series='When Calls The Heart', season=2, ep=6
  Checking episode: series='When Calls The Heart', season=2, ep=7
  Checking episode: series='When Calls The Heart', season=2, ep=1
  Checking episode: series='When Calls The Heart', season=2, ep=3
  Checking episode: series='When Calls The Heart', season=2, ep=2
  Checking episode: series='When Calls The Heart', season=2, ep=5
  => ALL episodes found in Plex. Safe to remove.
  Delete this TV folder? (y/N) y
```

---

## Installation

### Requirements

- Python 3.8 or higher
- [PlexAPI](https://github.com/pkkid/python-plexapi)
- [GuessIt](https://github.com/guessit-io/guessit)

### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/JaySea20/Media-Maid.git
   cd Media-Maid
   ```

2. Install dependencies:
   ```bash
   pip install guessit plexapi
   ```

3. Configure the script (see Configuration section below).


---

## Configuration

Media-Maid uses hardcoded configuration values, which can be edited directly in the script (`media_maid.py`):

- **Deluge Torrent File**:
  Path to the text file listing active torrents:
  ```python
  DELUGE_TORRENTS_FILE = "/home/user/deluge_torrent_names.txt"
  ```

- **Data Directory**:
  Path to your media downloads:
  ```python
  DATA_DIR = "/home/user/torrents/data"
  ```

- **Plex Server Details**:
  Update your Plex URL and token:
  ```python
  PLEX_BASEURL = "http://plex.ip.address:32400"
  PLEX_TOKEN = "YourPlexTokenHere"
  ```

- **Delete Confirmation**:
  Toggle automatic deletion:
  ```python
  DELETE_CONFIRMED = False
  ```

---

## Usage

1. Ensure your `DELUGE_TORRENTS_FILE` and `DATA_DIR` are correctly set.

2. Run the script to process media folders:
   ```bash
   ./media_maid.py
   ```

3. Follow on-screen prompts for any manual deletions (if `DELETE_CONFIRMED` is set to `False`).

4. Logs will display skipped folders, media types detected, and any actions taken.

---

## Example Output

- Skipping folders in active Deluge torrents:
  ```bash
  [SKIP] 'example_folder' is still in Deluge. Doing nothing.
  ```

- Checking a movie folder:
  ```bash
  Folder: Example.Movie.2023 => MOVIE detected. title='Example Movie', year=2023
  => Found in Plex library. Safe to remove.
  Delete this folder? (y/N)
  ```

- Checking a TV show folder:
  ```bash
  Folder: Example.Show.S01E01 => TV SHOW detected.
  Checking episode: series='Example Show', season=1, ep=1
  => Episode S1E1 found in Plex.
  ```

---

## Contributing

Its definatey not perfect. 
Contributions are welcome!

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Python PlexAPI](https://github.com/pkkid/python-plexapi) for seamless Plex integration.
- [GuessIt](https://github.com/guessit-io/guessit) for robust media file parsing.
