# meeting – create or reopen local meeting notes (Markdown, one file each).
# Notes stay on the WorkVM (customer content), not in the personal vault.

notes_dir="${MEETING_NOTES_DIR:?}"

usage() {
  cat <<'USAGE'
Usage:
  meeting <title...>   new note from the template and open it
  meeting              pick an existing note (newest first) and open it
  meeting -l           list notes, newest first
  meeting -d           print the notes directory
USAGE
}

open_note() {
  exec "${EDITOR:-vi}" "$1"
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
---

# $title

**Teilnehmer:**

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
