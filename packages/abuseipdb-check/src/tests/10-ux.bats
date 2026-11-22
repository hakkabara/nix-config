#!/usr/bin/env bats
# 10-ux.bats — UX-Features F1/F2/F3.
#
# F1 — Kein Input -> Help statt Stille: Aufruf ohne jegliche IP-Quelle und ohne
#      eigenstaendige Aktion gibt "Keine IPs" (stderr) + Help-Menue + Exit 2.
# F2 — Fortschrittsanzeige: Startzeile + Live-Zaehler auf stderr, aber NUR bei
#      TTY oder AIC_FORCE_PROGRESS=1; ohne Force + nicht-TTY: kein Progress-Text.
# F3 — Eingabe-Bilanz: Bilanzzeile auf stdout mit exakten Zahlen; Invariante
#      eingelesen == geprueft + uebersprungen; input_total im JSON-Export.
#
# Muster wie 09: isoliertes HOME, AIC_CURL-Mock, nicht-TTY-Pfad (</dev/null),
# reine Bash-Assertions (run + $status/$output). Kein echter Netzzugriff.

load helpers

setup() {
  aic_setup_env
  aic_source_tool
  export AIC_CACHE_DIR="${AIC_TMP}/cache"
  mkdir -p "${AIC_CACHE_DIR}"
  export TZ="Europe/Berlin"
}
teardown() { aic_teardown_env; }

# Wie in 09: eigenstaendiger Prozess, stdin=/dev/null (nicht-TTY, sofort EOF).
_run_tool() {
  run bash -c "
    cd '${AIC_ROOT_DIR}' &&
    AIC_CURL='${AIC_CURL}' \
    AIC_CACHE_DIR='${AIC_CACHE_DIR}' \
    AIC_MOCK_LOG='${AIC_MOCK_LOG}' \
    AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' \
    AIC_MOCK_SCENARIO='${AIC_MOCK_SCENARIO:-clean}' \
    HOME='${HOME}' \
    ${_TOOL_ENV:-} \
    ./abuseipdb-check $* </dev/null
  "
}

# ============================================================================
# F1 — Kein Input -> Help statt Stille (Exit 2)
# ============================================================================

@test "F1: ohne Argumente -> Exit 2 + Keine-IPs-Meldung + Help" {
  # Key gesetzt, damit ein evtl. spaeterer Key-Zwang nicht das Ergebnis faelscht.
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool
  [ "${status}" -eq 2 ]
  # Help-Menue vollstaendig ausgegeben.
  [[ "${output}" == *"VERWENDUNG"* ]]
  # Kurze Meldung.
  [[ "${output}" == *"Keine IPs"* ]]
}

@test "F1: Aufruf mit </dev/null (kein stdin-Input) -> identisch Exit 2 + Help" {
  # _run_tool haengt bereits </dev/null an; explizit derselbe Fall.
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"VERWENDUNG"* ]]
  [[ "${output}" == *"Keine IPs"* ]]
}

@test "F1: --help bleibt Exit 0 (keine Keine-IPs-Meldung)" {
  _run_tool --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"VERWENDUNG"* ]]
  [[ "${output}" != *"Keine IPs"* ]]
}

@test "F1: --clear-cache ist eigenstaendige Aktion (Exit 0, keine Keine-IPs-Meldung)" {
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --clear-cache
  [ "${status}" -eq 0 ]
  [[ "${output}" != *"Keine IPs"* ]]
}

@test "F1: --cache-stats ist eigenstaendige Aktion (Exit 0, keine Keine-IPs-Meldung)" {
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --cache-stats
  [ "${status}" -eq 0 ]
  [[ "${output}" != *"Keine IPs"* ]]
}

@test "F1: reiner Skip-Lauf (nur private/ungueltige IPs) loest KEINE Keine-IPs-Meldung aus" {
  # Es gibt Eingaben (nur eben nichts Pruefbares) -> Exit 0, keine F1-Meldung.
  _run_tool 10.0.0.1 127.0.0.1 999.1.1.1
  [ "${status}" -eq 0 ]
  [[ "${output}" != *"Keine IPs"* ]]
  [[ "${output}" == *"PRIVATE"* ]]
}

# ============================================================================
# F2 — Fortschrittsanzeige (TTY/Force-gated, nur stderr)
# ============================================================================

@test "F2: mit AIC_FORCE_PROGRESS=1 erscheint Startzeile + Fortschritt auf stderr" {
  export AIC_MOCK_SCENARIO="clean"
  run bash -c "
    cd '${AIC_ROOT_DIR}' &&
    AIC_CURL='${AIC_CURL}' AIC_CACHE_DIR='${AIC_CACHE_DIR}' \
    AIC_MOCK_LOG='${AIC_MOCK_LOG}' AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' \
    AIC_MOCK_SCENARIO=clean HOME='${HOME}' ABUSEIPDB_API_KEY=TESTKEY \
    AIC_FORCE_PROGRESS=1 \
    ./abuseipdb-check --parallel 2 9.9.9.9 8.8.8.8 1.1.1.1 </dev/null 2>'${AIC_TMP}/err.log'
  "
  [ "${status}" -eq 0 ]
  local err; err="$(cat "${AIC_TMP}/err.log")"
  # Startzeile.
  [[ "${err}" == *"Pruefe"* ]]
  # Live-Zaehler.
  [[ "${err}" == *"Fortschritt:"* ]]
  # x/y-Muster (Gesamtzahl 3 taucht auf).
  [[ "${err}" == *"/3"* ]]
}

@test "F2: ohne Force + nicht-TTY -> KEIN Fortschritt-Text (weder stdout noch stderr)" {
  export AIC_MOCK_SCENARIO="clean"
  run bash -c "
    cd '${AIC_ROOT_DIR}' &&
    AIC_CURL='${AIC_CURL}' AIC_CACHE_DIR='${AIC_CACHE_DIR}' \
    AIC_MOCK_LOG='${AIC_MOCK_LOG}' AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' \
    AIC_MOCK_SCENARIO=clean HOME='${HOME}' ABUSEIPDB_API_KEY=TESTKEY \
    ./abuseipdb-check --parallel 2 9.9.9.9 8.8.8.8 1.1.1.1 </dev/null 2>'${AIC_TMP}/err2.log'
  "
  [ "${status}" -eq 0 ]
  local err; err="$(cat "${AIC_TMP}/err2.log")"
  [[ "${err}" != *"Fortschritt:"* ]]
  [[ "${err}" != *"Pruefe "* ]]
  # stdout ebenfalls frei von Progress-Artefakten.
  [[ "${output}" != *"Fortschritt:"* ]]
}

@test "F2: Force-Progress zaehlt bis zur Gesamtzahl (fertig == gesamt am Ende)" {
  export AIC_MOCK_SCENARIO="clean"
  run bash -c "
    cd '${AIC_ROOT_DIR}' &&
    AIC_CURL='${AIC_CURL}' AIC_CACHE_DIR='${AIC_CACHE_DIR}' \
    AIC_MOCK_LOG='${AIC_MOCK_LOG}' AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' \
    AIC_MOCK_SCENARIO=clean HOME='${HOME}' ABUSEIPDB_API_KEY=TESTKEY \
    AIC_FORCE_PROGRESS=1 \
    ./abuseipdb-check --parallel 3 9.9.9.9 8.8.8.8 1.1.1.1 208.67.222.222 </dev/null 2>'${AIC_TMP}/err3.log'
  "
  [ "${status}" -eq 0 ]
  local err; err="$(cat "${AIC_TMP}/err3.log")"
  # Endzaehler erreicht 4/4.
  [[ "${err}" == *"4/4"* ]]
}

# ============================================================================
# F3 — Eingabe-Bilanz
# ============================================================================

@test "F3: gemischte Datei -> Bilanzzeile mit exakten Zahlen" {
  export AIC_MOCK_SCENARIO="clean"
  local list="${AIC_TMP}/mixed.txt"
  {
    printf '# Kommentar wird ignoriert\n'   # zaehlt NICHT
    printf '\n'                             # Leerzeile, zaehlt NICHT
    printf '9.9.9.9\n'                      # public
    printf '9.9.9.9\n'                      # Duplikat
    printf '10.0.0.1\n'                     # privat
    printf '8.8.8.8\n'                      # public
  } > "${list}"
  # eingelesen = 4 (zwei 9.9.9.9, 10.0.0.1, 8.8.8.8)
  # geprueft   = 2 (9.9.9.9, 8.8.8.8)  uebersprungen = 2 (Duplikat, PRIVATE)
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool -f "${list}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Bilanz:"* ]]
  [[ "${output}" == *"4 Eingaben"* ]]
  [[ "${output}" == *"2 geprueft"* ]]
  [[ "${output}" == *"2 uebersprungen"* ]]
  # Keine Invarianten-Warnung, da 4 == 2 + 2.
  [[ "${output}" != *"Parsing-Luecke"* ]]
}

@test "F3: Bilanz unterscheidet live und Cache" {
  export AIC_MOCK_SCENARIO="clean"
  # Erster Lauf: 9.9.9.9 live -> in Cache.
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9
  [ "${status}" -eq 0 ]
  # Zweiter Lauf: 9.9.9.9 (Cache) + 8.8.8.8 (live).
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9 8.8.8.8
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Bilanz:"* ]]
  [[ "${output}" == *"2 geprueft"* ]]
  [[ "${output}" == *"1 live"* ]]
  [[ "${output}" == *"1 Cache"* ]]
}

@test "F3: keine Invarianten-Warnung bei korrekter Bilanz (nur uebersprungene)" {
  _run_tool 10.0.0.1 127.0.0.1
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Bilanz:"* ]]
  [[ "${output}" == *"2 Eingaben"* ]]
  [[ "${output}" == *"0 geprueft"* ]]
  [[ "${output}" == *"2 uebersprungen"* ]]
  [[ "${output}" != *"Parsing-Luecke"* ]]
}

@test "F3: JSON-Export enthaelt counts.input_total" {
  export AIC_MOCK_SCENARIO="clean"
  local out="${AIC_TMP}/report.json"
  local list="${AIC_TMP}/in.txt"
  {
    printf '9.9.9.9\n'
    printf '9.9.9.9\n'   # Duplikat
    printf '10.0.0.1\n'  # privat
  } > "${list}"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool -f "${list}" \
    --output-file "${out}" --output-format json
  [ "${status}" -eq 0 ]
  [ -f "${out}" ]
  # input_total = 3 (zwei 9.9.9.9 + 10.0.0.1).
  local it; it="$(jq -r '.meta.counts.input_total' "${out}")"
  [ "${it}" -eq 3 ]
}

@test "F3: MD-Export enthaelt die Bilanzzeile" {
  export AIC_MOCK_SCENARIO="clean"
  local out="${AIC_TMP}/report.md"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9 10.0.0.1 \
    --output-file "${out}" --output-format md
  [ "${status}" -eq 0 ]
  [ -f "${out}" ]
  grep -q 'Bilanz:' "${out}"
}

@test "F3: Bilanzzeile geht auf stdout (nicht stderr)" {
  export AIC_MOCK_SCENARIO="clean"
  run bash -c "
    cd '${AIC_ROOT_DIR}' &&
    AIC_CURL='${AIC_CURL}' AIC_CACHE_DIR='${AIC_CACHE_DIR}' \
    AIC_MOCK_LOG='${AIC_MOCK_LOG}' AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' \
    AIC_MOCK_SCENARIO=clean HOME='${HOME}' ABUSEIPDB_API_KEY=TESTKEY \
    ./abuseipdb-check 9.9.9.9 </dev/null 2>/dev/null
  "
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Bilanz:"* ]]
}
