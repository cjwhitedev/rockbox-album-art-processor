# rockbox-album-art-processor

A bash script that gets album art ready for Rockbox. For every album folder it makes sure there is a `cover.jpg` that is:

- named `cover.jpg`
- a real JPEG, and baseline (non-progressive)
- 500×500 or smaller

It runs in two modes:

- **`check`** reports problems and changes nothing.
- **`fix`** renames, converts, shrinks, and re-saves images so they follow the rules above.

An album folder is any folder that contains audio files. Folders without audio, such as artist folders that only hold album folders, are skipped.

## Why `cover.jpg`

For each track, Rockbox looks for album art in this order and uses the first match:

1. `<track filename>.jpg` (for example `01 - Song.jpg` next to `01 - Song.mp3`)
2. `<album name>.jpg`, using the album name from the track's tags
3. `cover.jpg`
4. `folder.jpg`
5. `/.rockbox/albumart/<artist>-<album>.jpg`
6. `<album name>.jpg` or `cover.jpg` in the parent folder

It doesn't look for `albumart.jpg`, so art with that name never shows. `cover.jpg` is the simplest name that works for every album. Rockbox also can't display progressive JPEGs. Source: [Rockbox album art code](https://github.com/Rockbox/rockbox/blob/master/apps/recorder/albumart.c).

## 1. Install ImageMagick

The script runs on Linux and macOS, and on Windows through WSL. Skip this if `magick` or `convert` already works.

```bash
sudo apt update && sudo apt install imagemagick   # Ubuntu, Debian, and WSL
brew install imagemagick                          # macOS
```

The script uses `magick` if ImageMagick 7 is installed. Otherwise it uses `convert` from ImageMagick 6, which is what Ubuntu's `imagemagick` package provides.

On Windows, install [WSL](https://learn.microsoft.com/windows/wsl/install) with Ubuntu, then follow the Ubuntu steps inside it. Windows drives are under `/mnt`, so a library in `C:\Music` is `/mnt/c/Music`. Git Bash isn't tested.

## 2. Put the script in your library

Copy `albumart.sh` into the top of your music library and make it executable:

```bash
chmod +x albumart.sh
```

The commands below are run from inside the library, so `./` is the library. You can also run the script from anywhere and pass the library path instead of `./`.

## 3. Report first

```bash
./albumart.sh check ./
```

Example output:

```
Missing:     ./Artist A/Album 1
Needs fix:   ./Artist B/Album 3/albumart.png (rename, PNG, 1200x1200)
Needs fix:   ./Artist C/Album 2/cover.jpg (1200x1200, progressive)
Extra:       ./Artist D/Album 4/albumart.jpg
```

Folders that are already fine aren't listed, so no output means every album is ready.

| Label         | Meaning                                                                         |
| ------------- | ------------------------------------------------------------------------------- |
| `Missing:`    | The folder has audio but no `cover.*` or `albumart.*` image.                    |
| `Needs fix:`  | The image breaks a rule. The reasons are in brackets (see below).               |
| `Extra:`      | A second image in a folder that already has one. It's left alone in both modes. |
| `Unreadable:` | ImageMagick couldn't read the image. It may be damaged or empty.                |
| `Fixed:`      | (`fix` only) The image was fixed.                                               |
| `FAILED:`     | (`fix` only) The fix didn't work. The original is left in place.                |

`Needs fix` reasons:

- `rename`: the image isn't named `cover.jpg`.
- `PNG` (or another format): the image isn't a JPEG. This includes PNGs saved with a `.jpg` name.
- `1200x1200` (the image's size): larger than 500×500.
- `progressive`: a progressive JPEG.

To save the report to a file:

```bash
./albumart.sh check ./ > albumart-report.txt
```

To show only one type of result:

```bash
./albumart.sh check ./ | grep '^Missing'
./albumart.sh check ./ | grep '^Needs fix'
./albumart.sh check ./ | grep '^Extra'
```

## 4. Apply the fixes

> **Back up your music folder first, or test on a copy of a few album folders.** `fix` changes files in place and deletes each `albumart.*` or PNG file once its `cover.jpg` has been written.

```bash
./albumart.sh fix ./
```

To keep the original `albumart.*` and PNG files, for example because another player uses them:

```bash
KEEP_ORIGINALS=1 ./albumart.sh fix ./
```

Kept originals show up as `Extra` in later reports.

Run `check` again afterwards. Anything left in the report needs a manual look. `Missing` folders stay in the report, since `fix` can't create album art that doesn't exist.

## What `fix` does

- **Picks one image per folder**, in this order: `cover.jpg`, `cover.png`, `albumart.jpg`, `albumart.png`. Capitalisation doesn't matter, so `AlbumArt.JPG` counts as `albumart.jpg`. Any other matching images in the folder are reported as `Extra` and left alone; decide which one to keep yourself.
- **Renames it to `cover.jpg`.** An image that only needs renaming is renamed, not re-saved, so it loses no quality.
- **Converts PNGs to JPEG.** Transparent areas are flattened onto white, since JPEG can't store transparency.
- **Shrinks images larger than 500×500.** It never enlarges them: a 300×300 image stays 300×300, and 1200×1200 becomes 500×500. Non-square images keep their proportions, so the longest side becomes 500.
- **Re-saves progressive JPEGs as baseline** (standard, non-progressive).
- **Converts re-saved images to standard sRGB colour and removes metadata**, which keeps files small and compatible with older players.
- **Leaves a `cover.jpg` alone** if it already follows every rule, so re-running is safe.
- **Never overwrites a different image.** If a folder has both `cover.jpg` and `albumart.jpg`, `cover.jpg` is used and `albumart.jpg` is reported as `Extra`.

## Settings you can change

At the top of the script:

- `max=500`: the largest allowed width or height, in pixels.
- `names=(...)`: the image names to look for, in order of preference.

To look for other audio formats, add them to the `find` line in the same style, for example `-o -iname '*.dsf'`.

## After fixing

Copy the library to your player, or sync it, then play an album you've fixed. Skip to another track and back, or restart the player, if the old screen is still showing.

## If artwork still doesn't show

- **Your theme may not display album art.** Rockbox only shows artwork if the theme's playback screen includes it. Switch to the default theme (Cabbie) and play a fixed album. If the art appears there, the problem is your original theme.
- **Your theme may hide album art behind a setting.** Some themes switch to a layout without artwork depending on a Rockbox setting. For example, [Flesh and Bones](https://github.com/nicnic-cc/fleshandbones) only shows album art when **Settings → General Settings → Display → Status-/Scrollbar → Volume Display** is set to **Graphic**; with **Numeric** it uses a layout without art. Check your theme's README, or search its `.wps` file for `%St(` to see which settings it reads.
- **Rockbox may prefer embedded artwork, or have album art turned off.** Set **Settings → Playback Settings → Album Art** to **Prefer Image File**. With **Prefer Embedded**, a picture stored inside the audio file is used instead of `cover.jpg`, and this script doesn't check those pictures. With **Off**, no artwork is shown.
- **Another image may be taking priority.** A `<track filename>.jpg` or `<album name>.jpg` in the folder is used before `cover.jpg` (see [Why `cover.jpg`](#why-coverjpg)).
- **Embedded artwork is also supported** for MP3 and FLAC files, but it means rewriting every audio file. Only try it if `cover.jpg` doesn't work.

Menu names can differ slightly between Rockbox versions.

## AI disclaimer

This script and README were written with the help of an AI assistant (GitHub Copilot) and reviewed by a person. The script was tested on Ubuntu, Alpine Linux, and macOS with sample libraries, but not on every system, player, or library. Read the script before you run it, start with `check`, and back up your music before using `fix`. It's provided as is, without warranty.
