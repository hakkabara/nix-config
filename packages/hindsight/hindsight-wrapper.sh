#!/usr/bin/env bash
# Wrapper um das PyInstaller-Binary von hindsight.
#
# hindsight bestimmt seinen Logpfad als dirname(sys.executable)/<log>, und bei
# einem RELATIVEN -l wird dieser ebenfalls an das (read-only) Store-Verzeichnis
# geheftet. Ohne -l oder mit relativem -l -> PermissionError, der jede
# Standard-Nutzung sofort abbricht. Nur ein ABSOLUTER -l-Pfad umgeht das.
# Deshalb setzt dieser Wrapper einen absoluten Default-Logpfad im aktuellen
# Arbeitsverzeichnis -- aber nur, wenn der Nutzer nicht selbst -l/--log uebergibt.
#
# @real@ wird in der installPhase durch den echten Binary-Pfad ersetzt.
set -euo pipefail

log_given=0
for a in "$@"; do
  case "$a" in
  -l | --log) log_given=1 ;;
  esac
done

if [ "$log_given" -eq 0 ]; then
  set -- -l "$PWD/hindsight.log" "$@"
fi

exec "@real@" "$@"
