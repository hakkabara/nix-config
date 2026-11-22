#!/usr/bin/env bats
# 08-export.bats — US-010: Exporte in 5 Formaten (csv|json|jsonl|txt|md).
#
# Export erfolgt NUR bei --output-file. Alle Formate nutzen dieselbe sortierte
# Zeilenliste (aic_results_tsv). Datei wird atomar geschrieben (Tempfile+mv),
# bestehende Datei ueberschrieben, nicht beschreibbarer Pfad -> Exit 2.

load helpers

setup() {
  aic_setup_env
  aic_source_tool
  export AIC_CACHE_DIR="${AIC_TMP}/cache"
  mkdir -p "${AIC_CACHE_DIR}"
  export AIC_RUN_DIR="${AIC_TMP}/run"
  mkdir -p "${AIC_RUN_DIR}"
  export AIC_SKIP_FILE="${AIC_TMP}/skip.txt"
  : > "${AIC_SKIP_FILE}"
  export TZ="Europe/Berlin"
}
teardown() { aic_teardown_env; }

_put_result() {
  local name="${1}"; shift
  printf '%s' "${1}" > "${AIC_RUN_DIR}/${name}.json"
}

# Ergebnis mit Komma im ISP-Namen (CSV-Quoting-Testfall) + FEHLER + null.
_seed_mixed() {
  _put_result "9.9.9.9" '{"ipAddress":"9.9.9.9","abuseConfidenceScore":0,"countryCode":"US","isp":"Quad9, Inc.","usageType":"Data Center","domain":"quad9.net","isTor":false,"isWhitelisted":true,"totalReports":0,"numDistinctUsers":0,"lastReportedAt":null,"status":"OK","source":"live","http_code":200,"cache_age":null,"error_detail":null,"ratelimit":{"limit":"1000","remaining":"995","reset":"1752278400"}}'
  _put_result "185.220.101.1" '{"ipAddress":"185.220.101.1","abuseConfidenceScore":100,"countryCode":"DE","isp":"Tor \"Exit\" Relay","usageType":"Data Center","domain":"torproject.org","isTor":true,"isWhitelisted":false,"totalReports":842,"numDistinctUsers":301,"lastReportedAt":"2026-07-11T06:05:00+00:00","status":"OK","source":"live","http_code":200,"cache_age":null,"error_detail":null,"ratelimit":{"limit":"1000","remaining":"993","reset":"1752278400"}}'
  _put_result "203.0.113.9" '{"ipAddress":"203.0.113.9","abuseConfidenceScore":null,"status":"FEHLER","source":"live","http_code":429,"error_detail":"Daily rate limit exceeded","cache_age":null,"retry_after":"3600","ratelimit":{"limit":"1000","remaining":"0","reset":"1752278400"}}'
}

# ============================================================================
# CSV
# ============================================================================

@test "aic_export csv schreibt Header + Zeilen in Datei" {
  _seed_mixed
  local out="${AIC_TMP}/out.csv"
  run aic_export "csv" "${out}"
  [ "${status}" -eq 0 ]
  [ -f "${out}" ]
  head -n1 "${out}" | grep -qi 'ip'
  head -n1 "${out}" | grep -qi 'score'
  grep -q '185.220.101.1' "${out}"
  grep -q '9.9.9.9' "${out}"
}

@test "aic_export csv: Komma im ISP-Namen wird korrekt gequotet" {
  _seed_mixed
  local out="${AIC_TMP}/out.csv"
  run aic_export "csv" "${out}"
  [ "${status}" -eq 0 ]
  # "Quad9, Inc." muss in Anfuehrungszeichen stehen (Komma nicht als Trenner).
  grep -q '"Quad9, Inc."' "${out}"
}

@test "aic_export csv: doppelte Anfuehrungszeichen im Wert werden verdoppelt" {
  _seed_mixed
  local out="${AIC_TMP}/out.csv"
  run aic_export "csv" "${out}"
  [ "${status}" -eq 0 ]
  # Tor "Exit" Relay -> im CSV als "Tor ""Exit"" Relay".
  grep -q '""Exit""' "${out}"
}

@test "aic_export csv respektiert die Score-Sortierung (kritisch zuerst)" {
  _seed_mixed
  local out="${AIC_TMP}/out.csv"
  run aic_export "csv" "${out}"
  [ "${status}" -eq 0 ]
  # Erste Datenzeile (nach Header) = hoechster Score.
  local firstdata
  firstdata="$(sed -n '2p' "${out}")"
  [[ "${firstdata}" == *"185.220.101.1"* ]]
}

# ============================================================================
# JSON
# ============================================================================

@test "aic_export json: valides JSON mit meta, results und skipped" {
  _seed_mixed
  printf '10.0.0.1\tPRIVATE\n' > "${AIC_SKIP_FILE}"
  local out="${AIC_TMP}/out.json"
  run aic_export "json" "${out}"
  [ "${status}" -eq 0 ]
  jq -e . "${out}"
  jq -e '.meta' "${out}"
  jq -e '.results | type == "array"' "${out}"
  jq -e '.results | length == 3' "${out}"
  jq -e '.skipped | type == "array"' "${out}"
  jq -e '.skipped[0].ip == "10.0.0.1"' "${out}"
  jq -e '.skipped[0].reason == "PRIVATE"' "${out}"
}

@test "aic_export json: meta enthaelt ratelimit und counts" {
  _seed_mixed
  local out="${AIC_TMP}/out.json"
  run aic_export "json" "${out}"
  [ "${status}" -eq 0 ]
  jq -e '.meta.ratelimit' "${out}"
  jq -e '.meta.counts' "${out}"
  jq -e '.meta.tool' "${out}"
}

@test "aic_export json: results sind score-sortiert (kritisch zuerst)" {
  _seed_mixed
  local out="${AIC_TMP}/out.json"
  run aic_export "json" "${out}"
  [ "${status}" -eq 0 ]
  jq -e '.results[0].ipAddress == "185.220.101.1"' "${out}"
}

# ============================================================================
# JSONL
# ============================================================================

@test "aic_export jsonl: ein valides JSON-Objekt pro Zeile (nur results)" {
  _seed_mixed
  local out="${AIC_TMP}/out.jsonl"
  run aic_export "jsonl" "${out}"
  [ "${status}" -eq 0 ]
  # Drei Zeilen, jede fuer sich valides JSON.
  [ "$(grep -c . "${out}")" -eq 3 ]
  local line
  while IFS= read -r line; do
    printf '%s' "${line}" | jq -e . >/dev/null
  done < "${out}"
  # Erste Zeile = hoechster Score.
  head -n1 "${out}" | jq -e '.ipAddress == "185.220.101.1"'
}

# ============================================================================
# TXT
# ============================================================================

@test "aic_export txt: gerenderte Tabelle OHNE ANSI-Farben" {
  _seed_mixed
  local out="${AIC_TMP}/out.txt"
  run aic_export "txt" "${out}"
  [ "${status}" -eq 0 ]
  [ -f "${out}" ]
  grep -q '185.220.101.1' "${out}"
  # keine ANSI-Escape-Sequenzen.
  ! grep -q $'\x1b' "${out}"
}

@test "aic_export txt: enthaelt Skip-Sektion und Rate-Limit-Zeile" {
  _seed_mixed
  printf '10.0.0.1\tPRIVATE\n' > "${AIC_SKIP_FILE}"
  local out="${AIC_TMP}/out.txt"
  run aic_export "txt" "${out}"
  [ "${status}" -eq 0 ]
  grep -q 'PRIVATE' "${out}"
}

# ============================================================================
# Markdown
# ============================================================================

@test "aic_export md: Report mit Ueberschrift, Summary und Tabelle" {
  _seed_mixed
  local out="${AIC_TMP}/out.md"
  run aic_export "md" "${out}"
  [ "${status}" -eq 0 ]
  # Ueberschrift (#) vorhanden.
  grep -q '^#' "${out}"
  # Markdown-Tabelle (Pipe-getrennt) vorhanden.
  grep -q '|' "${out}"
  # Summary nennt kritisch/verdaechtig/sauber/Fehler.
  grep -qi 'kritisch' "${out}"
  grep -qi 'fehler' "${out}"
  grep -q '185.220.101.1' "${out}"
}

@test "aic_export md: Summary zaehlt FEHLER-Zeilen korrekt (Fehler: 1)" {
  # _seed_mixed enthaelt genau eine FEHLER-Zeile (203.0.113.9), eine kritische
  # (100) und eine saubere (0). Der Summary-Block muss das exakt abbilden —
  # und darf KEINE Bash-Fehler ("integer expected") auf stderr erzeugen.
  _seed_mixed
  local out="${AIC_TMP}/out.md"
  run aic_export "md" "${out}"
  [ "${status}" -eq 0 ]
  # Kein Bash-Fehler im kombinierten Output.
  [[ "${output}" != *"integer expected"* ]]
  grep -qE '^- Fehler: 1$' "${out}"
  grep -qE '^- Kritisch: 1$' "${out}"
  grep -qE '^- Sauber: 1$' "${out}"
}

# ============================================================================
# Format-Default, Validierung, atomar, Fehlerpfade
# ============================================================================

@test "aic_export: Default-Format ist csv" {
  _seed_mixed
  local out="${AIC_TMP}/out.default"
  run aic_export "" "${out}"
  [ "${status}" -eq 0 ]
  head -n1 "${out}" | grep -qi 'ip'
}

@test "aic_export: ungueltiges Format -> Exit 2" {
  _seed_mixed
  local out="${AIC_TMP}/out.xxx"
  run aic_export "xml" "${out}"
  [ "${status}" -eq 2 ]
}

@test "aic_export: bestehende Datei wird ueberschrieben" {
  _seed_mixed
  local out="${AIC_TMP}/out.csv"
  printf 'ALTER INHALT\n' > "${out}"
  run aic_export "csv" "${out}"
  [ "${status}" -eq 0 ]
  ! grep -q 'ALTER INHALT' "${out}"
}

@test "aic_export: nicht beschreibbarer Pfad -> Fehlermeldung + Exit 2" {
  _seed_mixed
  local out="/nonexistent-dir-xyz/out.csv"
  run aic_export "csv" "${out}"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"Fehler"* ]] || [[ "${output}" == *"nicht"* ]]
}

@test "aic_export: Schreiben ist atomar (kein .tmp-Rest im Zielverzeichnis)" {
  _seed_mixed
  local out="${AIC_TMP}/out.csv"
  run aic_export "csv" "${out}"
  [ "${status}" -eq 0 ]
  # Kein liegengebliebenes Tempfile neben der Zieldatei.
  run bash -c "ls '${AIC_TMP}'/*.tmp* 2>/dev/null | wc -l"
  [ "${output}" -eq 0 ]
}
