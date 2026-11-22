#!/usr/bin/env bats
# 05-cache.bats — US-006: Geteilter TTL-Cache.
#
# Getestet wird die cache-Sektion: Pfadbildung (IPv6-':' -> '_'), atomares
# Schreiben mit umask 002 (Dateirechte 664), TTL via mtime, Alters-Rueckgabe
# fuer die CACHED-Spalte, --no-cache/--clear-cache/--cache-stats sowie der
# Fallback bei nicht beschreibbarem Cache-Verzeichnis (Warnung + Weiterlauf).

load helpers

setup() {
  aic_setup_env
  aic_source_tool
  # Cache-Verzeichnis fuer die Tests explizit setzen und anlegen.
  export AIC_CACHE_DIR="${AIC_TMP}/cache"
  mkdir -p "${AIC_CACHE_DIR}"
}
teardown() { aic_teardown_env; }

# --------------------------------------------------------------- Pfadbildung
@test "aic_cache_path bildet IPv4-Dateinamen im Cache-Dir" {
  run aic_cache_path "9.9.9.9"
  [ "${status}" -eq 0 ]
  [[ "${output}" == "${AIC_CACHE_DIR}/9.9.9.9.json" ]]
}

@test "aic_cache_path ersetzt ':' durch '_' bei IPv6" {
  run aic_cache_path "2001:db8::1"
  [ "${status}" -eq 0 ]
  # keine Doppelpunkte im Dateinamen
  [[ "${output}" != *":"* ]]
  [[ "${output}" == "${AIC_CACHE_DIR}/2001_db8__1.json" ]]
}

# --------------------------------------------------------------- Schreiben (atomar, umask 002)
@test "aic_cache_write legt Datei mit JSON-Inhalt an" {
  local json='{"data":{"ipAddress":"9.9.9.9","abuseConfidenceScore":0}}'
  aic_cache_write "9.9.9.9" "${json}"
  local f="${AIC_CACHE_DIR}/9.9.9.9.json"
  [ -f "${f}" ]
  # Inhalt ist valides JSON und enthaelt die IP.
  jq -e '.data.ipAddress == "9.9.9.9"' "${f}"
}

@test "aic_cache_write erzeugt Dateirechte 664 (umask 002)" {
  local json='{"data":{"abuseConfidenceScore":0}}'
  aic_cache_write "9.9.9.9" "${json}"
  local f="${AIC_CACHE_DIR}/9.9.9.9.json"
  [ "$(stat -c '%a' "${f}")" == "664" ]
}

@test "aic_cache_write schreibt atomar (kein zurueckbleibendes mktemp)" {
  local json='{"data":{"abuseConfidenceScore":0}}'
  aic_cache_write "9.9.9.9" "${json}"
  # Im Cache-Dir darf nur die Ziel-JSON liegen, keine Temp-Reste.
  local count
  count="$(find "${AIC_CACHE_DIR}" -type f | wc -l)"
  [ "${count}" -eq 1 ]
  [ -f "${AIC_CACHE_DIR}/9.9.9.9.json" ]
}

@test "aic_cache_write legt fehlendes Cache-Verzeichnis selbst an" {
  export AIC_CACHE_DIR="${AIC_TMP}/neuer-cache"
  [ ! -d "${AIC_CACHE_DIR}" ]
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_write '9.9.9.9' '{\"x\":1}'"
  [ "${status}" -eq 0 ]
  [ -f "${AIC_CACHE_DIR}/9.9.9.9.json" ]
}

# --------------------------------------------------------------- Lesen + TTL
@test "aic_cache_read liefert frischen Eintrag (innerhalb TTL)" {
  local json='{"data":{"ipAddress":"9.9.9.9","abuseConfidenceScore":0}}'
  aic_cache_write "9.9.9.9" "${json}"
  run aic_cache_read "9.9.9.9"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *'"ipAddress":"9.9.9.9"'* ]] || echo "${output}" | jq -e '.data.ipAddress == "9.9.9.9"'
}

@test "aic_cache_read: Miss bei fehlendem Eintrag" {
  run aic_cache_read "1.2.3.4"
  [ "${status}" -ne 0 ]
}

@test "aic_cache_read: abgelaufener Eintrag (mtime alt) = Miss" {
  local json='{"data":{"abuseConfidenceScore":0}}'
  aic_cache_write "9.9.9.9" "${json}"
  local f="${AIC_CACHE_DIR}/9.9.9.9.json"
  # mtime auf 48h in der Vergangenheit setzen; TTL Default 24h.
  touch -d '48 hours ago' "${f}"
  AIC_TTL_HOURS=24
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; AIC_TTL_HOURS=24; aic_cache_read '9.9.9.9'"
  [ "${status}" -ne 0 ]
}

@test "aic_cache_read: Eintrag innerhalb konfigurierter TTL = Hit" {
  local json='{"data":{"abuseConfidenceScore":0}}'
  aic_cache_write "9.9.9.9" "${json}"
  local f="${AIC_CACHE_DIR}/9.9.9.9.json"
  touch -d '2 hours ago' "${f}"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; AIC_TTL_HOURS=24; aic_cache_read '9.9.9.9'"
  [ "${status}" -eq 0 ]
}

@test "TTL uebersteuerbar via kurze TTL macht 2h-Eintrag ungueltig" {
  local json='{"data":{"abuseConfidenceScore":0}}'
  aic_cache_write "9.9.9.9" "${json}"
  local f="${AIC_CACHE_DIR}/9.9.9.9.json"
  touch -d '2 hours ago' "${f}"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; AIC_TTL_HOURS=1; aic_cache_read '9.9.9.9'"
  [ "${status}" -ne 0 ]
}

# --------------------------------------------------------------- Alter (CACHED-Spalte)
@test "aic_cache_age liefert menschenlesbares Alter (Stunden)" {
  local json='{"data":{"abuseConfidenceScore":0}}'
  aic_cache_write "9.9.9.9" "${json}"
  local f="${AIC_CACHE_DIR}/9.9.9.9.json"
  touch -d '3 hours ago' "${f}"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_age '9.9.9.9'"
  [ "${status}" -eq 0 ]
  # Format wie '3h' (ungefaehr; Toleranz +-1h wegen Sekundenrundung)
  [[ "${output}" == "3h" ]] || [[ "${output}" == "2h" ]] || [[ "${output}" == "4h" ]]
}

# --------------------------------------------------------------- --clear-cache
@test "aic_clear_cache entfernt alle Cache-Eintraege" {
  aic_cache_write "9.9.9.9" '{"x":1}'
  aic_cache_write "8.8.8.8" '{"x":2}'
  [ "$(find "${AIC_CACHE_DIR}" -name '*.json' | wc -l)" -eq 2 ]
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_clear_cache"
  [ "${status}" -eq 0 ]
  [ "$(find "${AIC_CACHE_DIR}" -name '*.json' 2>/dev/null | wc -l)" -eq 0 ]
}

@test "aic_clear_cache loescht auch die Rate-Limit-Metadatei falls vorhanden" {
  aic_cache_write "9.9.9.9" '{"x":1}'
  # Metadatei simulieren (Name wird von der Implementierung vorgegeben).
  local meta="${AIC_CACHE_DIR}/.ratelimit"
  printf 'remaining=100\n' > "${meta}"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_clear_cache"
  [ "${status}" -eq 0 ]
  [ ! -f "${meta}" ]
}

@test "aic_clear_cache toleriert leeres/fehlendes Verzeichnis (Exit 0)" {
  export AIC_CACHE_DIR="${AIC_TMP}/gibtsnicht"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_clear_cache"
  [ "${status}" -eq 0 ]
}

# --------------------------------------------------------------- --cache-stats
@test "aic_cache_stats zeigt Anzahl der Eintraege" {
  aic_cache_write "9.9.9.9" '{"x":1}'
  aic_cache_write "8.8.8.8" '{"x":2}'
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_stats"
  [ "${status}" -eq 0 ]
  # Anzahl 2 muss irgendwo auftauchen.
  [[ "${output}" == *"2"* ]]
}

@test "aic_cache_stats toleriert leeres Verzeichnis (Exit 0)" {
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_stats"
  [ "${status}" -eq 0 ]
}

@test "aic_cache_stats toleriert fehlendes Verzeichnis (Exit 0)" {
  export AIC_CACHE_DIR="${AIC_TMP}/existiert-nicht"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_stats"
  [ "${status}" -eq 0 ]
}

# --------------------------------------------------------------- Fallback nicht beschreibbar
@test "aic_cache_write bei nicht beschreibbarem Verzeichnis: Warnung + Weiterlauf (Exit 0)" {
  # Als root sind Rechte-Beschraenkungen wirkungslos -> Test dann skippen.
  [ "$(id -u)" -eq 0 ] && skip "als root nicht aussagekraeftig"
  local rocache="${AIC_TMP}/ro-cache"
  mkdir -p "${rocache}"
  chmod 555 "${rocache}"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${rocache}'; aic_cache_write '9.9.9.9' '{\"x\":1}'"
  # Kein Abbruch: return 0, aber Warnung auf stderr.
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Warnung"* ]] || [[ "${output}" == *"Cache"* ]]
  chmod 755 "${rocache}"
}

@test "aic_cache_read bei fehlendem Verzeichnis: sauberer Miss (kein Abbruch)" {
  export AIC_CACHE_DIR="${AIC_TMP}/nada"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_read '9.9.9.9'"
  [ "${status}" -ne 0 ]
  # kein bash-Fehler (Exit != 2/andere Katastrophe): Miss ist 1.
  [ "${status}" -eq 1 ]
}

# --------------------------------------------------------------- Cache-Dir-Aufloesung
@test "aic_cache_resolve_dir: --cache-dir/Flag hat Vorrang vor Config" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_CACHE_DIR='/flag/dir'; AIC_CFG_cache_dir='/config/dir'; aic_cache_resolve_dir"
  [ "${status}" -eq 0 ]
  [ "${output}" == "/flag/dir" ]
}

@test "aic_cache_resolve_dir: Config vor Default" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_CACHE_DIR=''; AIC_CFG_cache_dir='/config/dir'; aic_cache_resolve_dir"
  [ "${status}" -eq 0 ]
  [ "${output}" == "/config/dir" ]
}

@test "aic_cache_resolve_dir: Default neben dem Tool (BASH_SOURCE-basiert)" {
  # F3 (Feature-Runde 2): Default-Cache liegt jetzt unter <tooldir>/data/cache
  # statt <tooldir>/cache (aufgeraeumter Tool-Ordner). Bewusste Default-Aenderung.
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_CACHE_DIR=''; AIC_CFG_cache_dir=''; aic_cache_resolve_dir"
  [ "${status}" -eq 0 ]
  # Default endet auf /data/cache und liegt neben dem Tool.
  [[ "${output}" == *"/data/cache" ]]
  [[ "${output}" == "${AIC_ROOT_DIR}/data/cache" ]]
}
