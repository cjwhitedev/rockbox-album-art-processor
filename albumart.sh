#!/usr/bin/env bash
# Makes sure every album folder has a cover.jpg that Rockbox can show: a baseline
# (non-progressive) JPEG no larger than 500x500.
#
# Usage:
#   ./albumart.sh check [music_dir]   report only, changes nothing
#   ./albumart.sh fix   [music_dir]   rename, convert, shrink, and make JPEGs baseline
#
# Looks for cover.jpg, cover.png, albumart.jpg, and albumart.png, in any capitalisation.
# Set KEEP_ORIGINALS=1 to keep the albumart.* or PNG file a cover.jpg was made from.

mode="${1:-check}"
root="${2:-.}"
max=500
names=(cover.jpg cover.png albumart.jpg albumart.png)

case "$mode" in
  check|fix) ;;
  *) echo "Usage: $0 check|fix [music_dir]" >&2; exit 1 ;;
esac

if command -v magick >/dev/null; then im=magick
elif command -v convert >/dev/null; then im=convert
else echo "ImageMagick is required: https://imagemagick.org/script/download.php" >&2; exit 1
fi

# Sets art to the images in folder $1 that match names (any case), best first.
find_art() {
  local name file
  art=()
  shopt -s nocasematch
  for name in "${names[@]}"; do
    for file in "$1"/*; do
      [[ -f "$file" && "${file##*/}" == "$name" ]] || continue
      # An existing cover.jpg always leads, so a differently-cased copy never overwrites it.
      if [[ "$file" -ef "$1/cover.jpg" ]]; then art=("$file" "${art[@]}"); else art+=("$file"); fi
    done
  done
  shopt -u nocasematch
}

# Writes cover.jpg in folder $2 from image $1. A file that only needs renaming isn't re-encoded.
fix_art() {
  local src="$1" target="$2/cover.jpg" tmp="$2/.cover-tmp-$$.jpg"
  if [[ "$3" == rename ]]; then
    cp -- "$src" "$tmp"
  else
    "$im" "$src[0]" -background white -alpha remove -alpha off -colorspace sRGB \
      -resize "${max}x${max}>" -strip -interlace none -sampling-factor 4:2:0 -quality 90 "$tmp"
  fi || { rm -f -- "$tmp"; return 1; }
  # Removing the source first lets a case-insensitive drive take the lowercase name.
  if [[ "$src" -ef "$target" || "${KEEP_ORIGINALS:-0}" != 1 ]]; then rm -f -- "$src"; fi
  mv -f -- "$tmp" "$target"
}

find "$root" -type f \( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' \
  -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.aac' \
  -o -iname '*.wma' -o -iname '*.ape' -o -iname '*.wv' -o -iname '*.mpc' \) |
  sed 's|/[^/]*$||' | sort -u |
while IFS= read -r dir; do
  find_art "$dir"
  if (( ${#art[@]} == 0 )); then
    echo "Missing:     $dir"
    continue
  fi

  src="${art[0]}"
  # %[interlace] is "None" for baseline JPEGs.
  read -r format width height interlace <<< \
    "$("$im" "$src[0]" -format '%m %w %h %[interlace]' info: 2>/dev/null)"
  issues=""
  [[ "${src##*/}" != cover.jpg ]] && issues+=", rename"
  [[ "$format" != JPEG ]] && issues+=", $format"
  (( width > max || height > max )) && issues+=", ${width}x${height}"
  [[ "$format" == JPEG && "$interlace" != None ]] && issues+=", progressive"
  issues="${issues#, }"

  if [[ -z "$width" ]]; then
    echo "Unreadable:  $src"
  elif [[ -n "$issues" ]]; then
    if [[ "$mode" == check ]]; then
      echo "Needs fix:   $src ($issues)"
    elif fix_art "$src" "$dir" "$issues"; then
      echo "Fixed:       $src ($issues)"
    else
      echo "FAILED:      $src ($issues)"
    fi
  fi

  for extra in "${art[@]:1}"; do
    echo "Extra:       $extra"
  done
done
