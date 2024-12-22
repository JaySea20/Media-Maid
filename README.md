# Media-Maid

**Media-Maid** is a utility script designed to clean up your download folder by identifying completed media files and organizing or removing them based on their presence in your Plex library. It focuses on automating the tedious task of manually managing downloaded content.

---

## Features

- **Deluge Folder Skipping**: Automatically skips folders still being downloaded via Deluge to avoid conflicts.
- **Plex Library Integration**: Checks whether movies or TV episodes are already present in your Plex library.
- **Media Analysis**: Uses `guessit` to analyze folder and file names, determining whether the content is a movie or TV show.
- **Selective Deletion**: Provides an option to safely delete media files that are confirmed to be in Plex.
- **Episode-by-Episode Verification**: Ensures all episodes of a TV show folder are present in Plex before considering the folder for deletion.
- **User Confirmation**: Allows manual confirmation before deleting any content, with an optional automatic deletion mode.


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
   pip install -r requirements.txt
   ```

3. Configure the script (see Configuration section below).

4. Run the script:
   ```bash
   ./media_maid.py
   ```

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

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create a new branch:
   ```bash
   git checkout -b feature/my-feature
   ```
3. Commit your changes:
   ```bash
   git commit -m "Add new feature"
   ```
4. Push to your fork and submit a pull request.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Python PlexAPI](https://github.com/pkkid/python-plexapi) for seamless Plex integration.
- [GuessIt](https://github.com/guessit-io/guessit) for robust media file parsing.
