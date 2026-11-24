# meeting – create or reopen local meeting notes (Markdown, one file each).
# Notes stay on the WorkVM (customer content), not in the personal vault.
#
# When the editor closes and the note has changed, an empty "end:" field in
# the front matter is set to the current time and the whole note is copied
# to the clipboard. An end time typed by hand is kept.

notes_dir="${MEETING_NOTES_DIR:?}"

usage() {
  cat <<'USAGE'
Usage:
  meeting <title...>   new note from the template and open it
  meeting              pick an existing note (newest first) and open it
  meeting -l           list notes, newest first
  meeting -d           print the notes directory

After the editor closes, a changed note gets its end time (unless "end:" is
already filled in) and is copied to the clipboard.
USAGE
}

# Fill an empty "end:" in the front matter. The time alone, or date and time
# when the note is closed on another day than its "date:".
set_end() {
  local file="$1" day end
  day="$(sed -n '2,/^---$/ s/^date:[[:space:]]*//p' "$file" | head -n1)"
  end="$(date +%H:%M)"
  if [ -n "$day" ] && [ "$day" != "$(date +%Y-%m-%d)" ]; then
    end="$(date '+%Y-%m-%d %H:%M')"
  fi
  sed -i "2,/^---\$/ s/^end:[[:space:]]*\$/end: $end/" "$file"
}

copy_note() {
  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "meeting: no Wayland session, note not copied to the clipboard" >&2
    return 0
  fi
  wl-copy --type text/plain <"$1"
  echo "meeting: note copied to the clipboard"
}

# Closing the editor without a change neither stamps nor copies the note.
open_note() {
  local file="$1" before
  before="$(sha256sum <"$file")"
  "${EDITOR:-vi}" "$file"
  [ -e "$file" ] || return 0
  [ "$(sha256sum <"$file")" != "$before" ] || return 0
  set_end "$file"
  copy_note "$file"
}

list_notes() {
  find "$notes_dir" -maxdepth 1 -type f -name '*.md' -printf '%T@ %f\n' |
    sort -rn | cut -d' ' -f2-
}

mkdir -p "$notes_dir"

case "${1:-}" in
-h | --help) usage ;;
-d) echo "$notes_dir" ;;
-l) list_notes ;;
"")
  choice="$(list_notes | fzf --prompt='meeting> ' --no-sort \
    --preview "bat --style=plain --color=always '$notes_dir'/{}")" || exit 0
  open_note "$notes_dir/$choice"
  ;;
*)
  title="$*"
  slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' |
    sed -e 's/ä/ae/g; s/ö/oe/g; s/ü/ue/g; s/ß/ss/g' \
      -e 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//' | cut -c1-60)"
  file="$notes_dir/$(date +%Y-%m-%d_%H%M)_${slug:-meeting}.md"
  if [ ! -e "$file" ]; then
    cat >"$file" <<NOTE
---
title: "$title"
date: $(date +%Y-%m-%d)
start: $(date +%H:%M)
end:
---

# $title

**Teilnehmer:** ${MEETING_ATTENDEE:-}

**Agenda:**

## Notizen

## Entscheidungen

## ToDos

- [ ]
NOTE
  fi
  open_note "$file"
  ;;
esac
