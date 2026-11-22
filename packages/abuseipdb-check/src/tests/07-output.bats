#!/usr/bin/env bats
# 07-output.bats — US-009: sortierte Terminal-Tabelle, Farben, Skip-Sektion,
# Rate-Limit-Zeile. Zusaetzlich die von Batch 3 uebergebenen offenen Punkte:
#   A) Skip-Filter (nicht-public/invalid IPs vor dem Runner aussortieren),
#   B) stdin blockiert nicht mehr bei nicht-TTY ohne anliegende Daten.
#
# Kern-Naht: aic_results_tsv baut aus den Ergebnis-JSONs in AIC_RUN_DIR EINE
# sortierte, Tab-getrennte Zeilenliste (Quelle fuer Tabelle UND Exporte).
# Spalten (Tab): ip score country isp usage domain tor wl reports reporter
#                last source error_detail

load helpers

setup() {
  aic_setup_env
  aic_source_tool
  export AIC_CACHE_DIR="${AIC_TMP}/cache"
  mkdir -p "${AIC_CACHE_DIR}"
  # Lauf-Tempdir mit fertigen Ergebnis-JSONs (Renderer liest daraus).
  export AIC_RUN_DIR="${AIC_TMP}/run"
  mkdir -p "${AIC_RUN_DIR}"
  export TZ="Europe/Berlin"
}
teardown() { aic_teardown_env; }

# Hilfsfunktion: legt ein Ergebnis-JSON (ein Objekt) in AIC_RUN_DIR ab.
_put_result() {
  local name="${1}"; shift
  printf '%s' "${1}" > "${AIC_RUN_DIR}/${name}.json"
}

# Drei typische Ergebnisse: sauber (0), verdaechtig (42), kritisch (100).
_seed_three() {
  _put_result "9.9.9.9" '{"ipAddress":"9.9.9.9","abuseConfidenceScore":0,"countryCode":"US","isp":"Quad9","usageType":"Data Center","domain":"quad9.net","isTor":false,"isWhitelisted":true,"totalReports":0,"numDistinctUsers":0,"lastReportedAt":null,"status":"OK","source":"live","http_code":200,"cache_age":null,"error_detail":null,"ratelimit":{"limit":"1000","remaining":"995","reset":"1752278400"}}'
  _put_result "45.155.205.233" '{"ipAddress":"45.155.205.233","abuseConfidenceScore":42,"countryCode":"RU","isp":"Example Hosting","usageType":"Data Center","domain":"example-host.ru","isTor":false,"isWhitelisted":false,"totalReports":17,"numDistinctUsers":9,"lastReportedAt":"2026-07-10T18:22:11+00:00","status":"OK","source":"live","http_code":200,"cache_age":null,"error_detail":null,"ratelimit":{"limit":"1000","remaining":"994","reset":"1752278400"}}'
  _put_result "185.220.101.1" '{"ipAddress":"185.220.101.1","abuseConfidenceScore":100,"countryCode":"DE","isp":"Tor Exit Relay","usageType":"Data Center","domain":"torproject.org","isTor":true,"isWhitelisted":false,"totalReports":842,"numDistinctUsers":301,"lastReportedAt":"2026-07-11T06:05:00+00:00","status":"OK","source":"live","http_code":200,"cache_age":null,"error_detail":null,"ratelimit":{"limit":"1000","remaining":"993","reset":"1752278400"}}'
}

# ============================================================================
# aic_results_tsv — zentrale sortierte Zeilenliste
# ============================================================================

@test "aic_results_tsv gibt eine Tab-getrennte Zeile pro Ergebnis" {
  _seed_three
  run aic_results_tsv
  [ "${status}" -eq 0 ]
  [ "$(printf '%s\n' "${output}" | grep -c .)" -eq 3 ]
  # Jede Zeile hat 13 Tab-getrennte Felder (12 Tabs).
  local line
  while IFS= read -r line; do
    [ "$(awk -F'\t' '{print NF}' <<< "${line}")" -eq 13 ]
  done <<< "${output}"
}

@test "aic_results_tsv sortiert Default nach Score absteigend" {
  _seed_three
  run aic_results_tsv
  [ "${status}" -eq 0 ]
  # Erste Datenzeile = hoechster Score (185.220.101.1, 100).
  local first
  first="$(printf '%s\n' "${output}" | head -n1)"
  [[ "${first}" == "185.220.101.1"* ]]
  local last
  last="$(printf '%s\n' "${output}" | tail -n1)"
  [[ "${last}" == "9.9.9.9"* ]]
}

@test "aic_results_tsv --reverse kehrt die Sortierung um (Score aufsteigend)" {
  _seed_three
  export AIC_SORT_KEY="score"
  export AIC_SORT_REVERSE=1
  run aic_results_tsv
  [ "${status}" -eq 0 ]
  local first
  first="$(printf '%s\n' "${output}" | head -n1)"
  [[ "${first}" == "9.9.9.9"* ]]
}

@test "aic_results_tsv sortiert nach country" {
  _seed_three
  export AIC_SORT_KEY="country"
  run aic_results_tsv
  [ "${status}" -eq 0 ]
  # Laender: US, RU, DE -> absteigend (Default) US, RU, DE.
  local first
  first="$(printf '%s\n' "${output}" | awk -F'\t' 'NR==1{print $3}')"
  [ "${first}" = "US" ]
}

@test "aic_results_tsv sortiert nach reports numerisch" {
  _seed_three
  export AIC_SORT_KEY="reports"
  run aic_results_tsv
  [ "${status}" -eq 0 ]
  # Hoechste Reports zuerst: 842 (185.220.101.1).
  local first
  first="$(printf '%s\n' "${output}" | head -n1)"
  [[ "${first}" == "185.220.101.1"* ]]
}

@test "aic_results_tsv: FEHLER-Zeilen (Score null) sortieren stabil ans Ende" {
  _seed_three
  _put_result "203.0.113.9" '{"ipAddress":"203.0.113.9","abuseConfidenceScore":null,"status":"FEHLER","source":"live","http_code":429,"error_detail":"Daily rate limit exceeded","cache_age":null,"retry_after":"3600","ratelimit":{"limit":"1000","remaining":"0","reset":"1752278400"}}'
  run aic_results_tsv
  [ "${status}" -eq 0 ]
  # Default score desc: die FEHLER-Zeile (null) steht ganz unten.
  local last
  last="$(printf '%s\n' "${output}" | tail -n1)"
  [[ "${last}" == "203.0.113.9"* ]]
}

@test "aic_results_tsv: ungueltiger Sort-Key ist nicht Sache dieser Funktion (main validiert)" {
  # Sort-Key-Validierung liegt in aic_main/aic_parse_args (Exit 2).
  # Hier nur: gesetzter, gueltiger Key funktioniert.
  _seed_three
  export AIC_SORT_KEY="isp"
  run aic_results_tsv
  [ "${status}" -eq 0 ]
}

# ============================================================================
# aic_render_table — ASCII-Tabelle
# ============================================================================

@test "aic_render_table zeigt Kopfzeile mit allen Spalten" {
  _seed_three
  run aic_render_table
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"IP"* ]]
  [[ "${output}" == *"SCORE"* ]]
  [[ "${output}" == *"LAND"* ]]
  [[ "${output}" == *"ISP"* ]]
  [[ "${output}" == *"REPORTS"* ]]
  [[ "${output}" == *"QUELLE"* ]]
}

@test "aic_render_table zeigt alle drei IPs" {
  _seed_three
  run aic_render_table
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"9.9.9.9"* ]]
  [[ "${output}" == *"45.155.205.233"* ]]
  [[ "${output}" == *"185.220.101.1"* ]]
}

@test "aic_render_table: null-Felder werden als '-' dargestellt" {
  _put_result "203.0.113.7" '{"ipAddress":"203.0.113.7","abuseConfidenceScore":5,"countryCode":"AU","isp":"Example ISP","usageType":"Fixed Line ISP","domain":null,"isTor":false,"isWhitelisted":null,"totalReports":1,"numDistinctUsers":1,"lastReportedAt":null,"status":"OK","source":"live","http_code":200,"cache_age":null,"error_detail":null,"ratelimit":{"limit":"1000","remaining":"992","reset":"1752278400"}}'
  run aic_render_table
  [ "${status}" -eq 0 ]
  # Domain ist null -> irgendwo ein '-'.
  [[ "${output}" == *"-"* ]]
}

@test "aic_render_table: QUELLE zeigt CACHED mit Alter" {
  _put_result "9.9.9.9" '{"ipAddress":"9.9.9.9","abuseConfidenceScore":0,"countryCode":"US","isp":"Quad9","usageType":"DC","domain":"quad9.net","isTor":false,"isWhitelisted":true,"totalReports":0,"numDistinctUsers":0,"lastReportedAt":null,"status":"OK","source":"cache","http_code":200,"cache_age":"3h","error_detail":null,"ratelimit":{"limit":"","remaining":"","reset":""}}'
  run aic_render_table
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"CACHED"* ]]
  [[ "${output}" == *"3h"* ]]
}

@test "aic_render_table: FEHLER-Zeile zeigt QUELLE=FEHLER und error_detail" {
  _put_result "203.0.113.9" '{"ipAddress":"203.0.113.9","abuseConfidenceScore":null,"status":"FEHLER","source":"live","http_code":429,"error_detail":"Daily rate limit exceeded","cache_age":null,"retry_after":"3600","ratelimit":{"limit":"1000","remaining":"0","reset":"1752278400"}}'
  run aic_render_table
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"FEHLER"* ]]
  # error_detail erscheint kompakt (in der ISP-Spalte, dokumentierte Wahl).
  [[ "${output}" == *"rate limit"* ]] || [[ "${output}" == *"Daily"* ]]
}

# ============================================================================
# Farben
# ============================================================================

@test "aic_render_table: nicht-TTY (Default in bats) enthaelt KEINE ANSI-Sequenzen" {
  _seed_three
  run aic_render_table
  [ "${status}" -eq 0 ]
  # Kein ESC[ (0x1b) im Output.
  ! printf '%s' "${output}" | grep -q $'\x1b'
}

@test "aic_render_table: mit erzwungener Farbe (AIC_COLOR=1) enthaelt ANSI fuer kritischen Score" {
  _seed_three
  export AIC_COLOR=1
  run aic_render_table
  [ "${status}" -eq 0 ]
  printf '%s' "${output}" | grep -q $'\x1b'
}

@test "aic_render_table: --no-color (AIC_COLOR=0) unterdrueckt ANSI trotz TTY-Annahme" {
  _seed_three
  export AIC_COLOR=0
  run aic_render_table
  [ "${status}" -eq 0 ]
  ! printf '%s' "${output}" | grep -q $'\x1b'
}

# ============================================================================
# Skip-Sektion
# ============================================================================

@test "aic_render_skips gruppiert nach Grund mit Zaehlern" {
  local skip="${AIC_TMP}/skip.txt"
  {
    printf '10.0.0.1\tPRIVATE\n'
    printf '10.0.0.2\tPRIVATE\n'
    printf '127.0.0.1\tLOOPBACK\n'
    printf '999.999.999.999\tINVALID\n'
    printf '9.9.9.9\tWHITELIST\n'
    printf '1.2.3.4\tDUPLIKAT\n'
  } > "${skip}"
  export AIC_SKIP_FILE="${skip}"
  run aic_render_skips
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"PRIVATE"* ]]
  [[ "${output}" == *"LOOPBACK"* ]]
  [[ "${output}" == *"INVALID"* ]]
  [[ "${output}" == *"WHITELIST"* ]]
  [[ "${output}" == *"DUPLIKAT"* ]]
  # PRIVATE hat Zaehler 2.
  [[ "${output}" == *"2"* ]]
}

@test "aic_render_skips: leere/fehlende Skip-Datei -> kein Fehler, keine Sektion" {
  export AIC_SKIP_FILE="${AIC_TMP}/leer.txt"
  : > "${AIC_SKIP_FILE}"
  run aic_render_skips
  [ "${status}" -eq 0 ]
}

# ============================================================================
# Rate-Limit-Zeile (Epoch -> Lokalzeit, fixer Testvektor)
# ============================================================================

@test "aic_render_ratelimit: Reset-Epoch 1752278400 wird als lokale Zeit dargestellt" {
  export TZ="Europe/Berlin"
  # Erwartete lokale Zeit fuer 1752278400 in Europe/Berlin.
  local expect
  expect="$(date -d @1752278400 '+%H:%M')"
  run aic_render_ratelimit "1000" "993" "1752278400"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1000"* ]]
  [[ "${output}" == *"993"* ]]
  [[ "${output}" == *"${expect}"* ]]
  [[ "${output}" == *"Limit"* ]] || [[ "${output}" == *"API-Limit"* ]]
}

@test "aic_render_ratelimit: leere Werte werden tolerant behandelt" {
  run aic_render_ratelimit "" "" ""
  [ "${status}" -eq 0 ]
}

# ============================================================================
# aic_output — Gesamtausgabe (Tabelle + Skips + Ratelimit)
# ============================================================================

@test "aic_output kombiniert Tabelle, Skip-Sektion und Rate-Limit-Zeile" {
  _seed_three
  local skip="${AIC_TMP}/skip.txt"
  printf '10.0.0.1\tPRIVATE\n' > "${skip}"
  export AIC_SKIP_FILE="${skip}"
  run aic_output
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"185.220.101.1"* ]]
  [[ "${output}" == *"PRIVATE"* ]]
}

# ============================================================================
# Offener Punkt A — Skip-Filter: nicht-public/invalid IPs vor dem Runner
# ============================================================================
#
# aic_filter_classify liest IPs von stdin, gibt nur public IPs auf stdout aus
# und schreibt nicht-public/ungueltige mit Grosschrift-Grund in AIC_SKIP_FILE.

@test "aic_filter_classify laesst public IPs durch" {
  local skip="${AIC_TMP}/skip.txt"; : > "${skip}"
  export AIC_SKIP_FILE="${skip}"
  run bash -c "source '${AIC_TOOL}'; export AIC_SKIP_FILE='${skip}'; printf '9.9.9.9\n8.8.8.8\n' | aic_filter_classify"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"9.9.9.9"* ]]
  [[ "${output}" == *"8.8.8.8"* ]]
}

@test "aic_filter_classify sortiert private/loopback/link-local/multicast/reserved/invalid aus" {
  local skip="${AIC_TMP}/skip.txt"; : > "${skip}"
  run bash -c "source '${AIC_TOOL}'; export AIC_SKIP_FILE='${skip}'; printf '10.0.0.1\n127.0.0.1\n169.254.1.1\n224.0.0.1\n240.0.0.1\n999.1.1.1\n9.9.9.9\n' | aic_filter_classify"
  [ "${status}" -eq 0 ]
  # Nur die public IP kommt durch.
  [[ "${output}" == *"9.9.9.9"* ]]
  [[ "${output}" != *"10.0.0.1"* ]]
  [[ "${output}" != *"127.0.0.1"* ]]
  # Skip-Datei traegt die Gruende in Grossbuchstaben.
  grep -q '10.0.0.1	PRIVATE' "${skip}"
  grep -q '127.0.0.1	LOOPBACK' "${skip}"
  grep -q '169.254.1.1	LINK-LOCAL' "${skip}"
  grep -q '224.0.0.1	MULTICAST' "${skip}"
  grep -q '240.0.0.1	RESERVED' "${skip}"
  grep -q '999.1.1.1	INVALID' "${skip}"
}

@test "main-Pipeline: private/ungueltige IPs erreichen den Runner NICHT (kein Key noetig)" {
  # Nur nicht-public/ungueltige IPs -> keine Live-Calls, kein Key-Zwang, Exit 0.
  export AIC_MOCK_SCENARIO="clean"
  run bash -c "cd '${AIC_ROOT_DIR}' && AIC_CURL='${AIC_TEST_DIR}/mocks/curl' AIC_CACHE_DIR='${AIC_CACHE_DIR}' AIC_MOCK_LOG='${AIC_MOCK_LOG}' AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' AIC_MOCK_SCENARIO=clean HOME='${HOME}' ./abuseipdb-check 10.0.0.1 127.0.0.1 999.1.1.1 </dev/null"
  [ "${status}" -eq 0 ]
  # Kein Live-Call (Mock-Log leer von CALL).
  [ "$(aic_mock_calls)" -eq 0 ]
  # Skip-Sektion nennt die Gruende.
  [[ "${output}" == *"PRIVATE"* ]]
  [[ "${output}" == *"INVALID"* ]]
}

@test "main-Pipeline: gemischte Liste — nur public IP erreicht den Runner" {
  export AIC_MOCK_SCENARIO="clean"
  run bash -c "cd '${AIC_ROOT_DIR}' && AIC_CURL='${AIC_TEST_DIR}/mocks/curl' AIC_CACHE_DIR='${AIC_CACHE_DIR}' AIC_MOCK_LOG='${AIC_MOCK_LOG}' AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' AIC_MOCK_SCENARIO=clean HOME='${HOME}' ABUSEIPDB_API_KEY=TESTKEY ./abuseipdb-check 9.9.9.9 10.0.0.1 </dev/null"
  [ "${status}" -eq 0 ]
  # Genau ein Live-Call (nur 9.9.9.9).
  [ "$(aic_mock_calls)" -eq 1 ]
  grep -q 'ipAddress=9.9.9.9' "${AIC_MOCK_LOG}"
  ! grep -q 'ipAddress=10.0.0.1' "${AIC_MOCK_LOG}"
}

# ============================================================================
# Offener Punkt B — stdin blockiert nicht mehr bei nicht-TTY ohne Daten
# ============================================================================

@test "main terminiert mit Positionsargs und nicht-TTY-stdin OHNE anliegende Daten" {
  # Regression: frueher blockierte aic_read_inputs auf stdin, wenn stdin kein
  # TTY war (z. B. unter bats/xargs) aber keine Pipe-Daten anlagen. Der Aufruf
  # MUSS terminieren. stdin wird hier auf eine leere, nicht-blockierende Quelle
  # gelenkt, die NICHT auf EOF wartet (FIFO waere blockierend) — /dev/null ist
  # nicht-TTY und liefert sofort EOF, deckt den Regressionsfall ab.
  export AIC_MOCK_SCENARIO="clean"
  run timeout 15 bash -c "cd '${AIC_ROOT_DIR}' && AIC_CURL='${AIC_TEST_DIR}/mocks/curl' AIC_CACHE_DIR='${AIC_CACHE_DIR}' AIC_MOCK_LOG='${AIC_MOCK_LOG}' AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' AIC_MOCK_SCENARIO=clean HOME='${HOME}' ABUSEIPDB_API_KEY=TESTKEY ./abuseipdb-check 9.9.9.9 </dev/null"
  # timeout gibt 124 zurueck, wenn es haengt — hier MUSS es 0 sein.
  [ "${status}" -eq 0 ]
  grep -q 'ipAddress=9.9.9.9' "${AIC_MOCK_LOG}"
}

@test "aic_read_inputs liest stdin NICHT, wenn Positionsargumente vorliegen" {
  # Mit Positionsargumenten UND einer stdin-Pipe: Positionsargs haben Vorrang,
  # stdin wird ignoriert (verhindert Blockieren bei versehentlicher Pipe).
  run bash -c "source '${AIC_TOOL}'; AIC_POSITIONAL=('9.9.9.9'); AIC_INPUT_FILE=''; AIC_EXTRACT=0; printf '8.8.8.8\n' | aic_read_inputs"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"9.9.9.9"* ]]
  [[ "${output}" != *"8.8.8.8"* ]]
}
