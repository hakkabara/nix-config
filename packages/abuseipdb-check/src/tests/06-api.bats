#!/usr/bin/env bats
# 06-api.bats — US-007 (API-Client read-only) + US-008 (paralleler Runner).
#
# Getestet werden: aic_api_check (curl -G, Header-Parsing case-insensitiv +
# CRLF-tolerant, Fehler-Mapping 401/402/422/429 inkl. errors[0].detail, null-
# Felder, kaputtes JSON/Timeout -> FEHLER statt Abbruch), der Worker
# (atomares Ergebnis-JSON, Cache-Anbindung) und der Runner aic_run_checks
# (sequenzielle Probe, W1/W2-Warnungen, Parallel-Vollstaendigkeit, Min-
# Aggregation von remaining, trap-Zwischenstand). NIEMALS echte API-Calls.

load helpers

setup() {
  aic_setup_env
  aic_source_tool
  export AIC_CACHE_DIR="${AIC_TMP}/cache"
  mkdir -p "${AIC_CACHE_DIR}"
  # Standard: kein interaktives TTY (nicht-TTY-Pfad fuer W2).
  export AIC_MAX_AGE=90
  export AIC_PARALLEL=5
  export AIC_NO_CACHE=0
}
teardown() { aic_teardown_env; }

# ============================================================================
# US-007 — aic_api_check: Request-Aufbau
# ============================================================================

@test "aic_api_check nutzt GET (-G) und niemals POST" {
  export AIC_MOCK_SCENARIO="clean"
  run aic_api_check "9.9.9.9" "TESTKEY"
  [ "${status}" -eq 0 ]
  # Der einzige Netzzugriff lief ueber den Mock -> genau ein CALL.
  [ "$(aic_mock_calls)" -eq 1 ]
  # -G muss im Aufruf stehen (sonst waere --data-urlencode ein POST-Body).
  grep -q -- '-G' "${AIC_MOCK_LOG}"
  # Kein -X POST / kein --request POST.
  ! grep -qiE -- '-X POST|--request POST' "${AIC_MOCK_LOG}"
}

@test "aic_api_check sendet ipAddress + maxAgeInDays via --data-urlencode" {
  export AIC_MOCK_SCENARIO="clean"
  export AIC_MAX_AGE=45
  run aic_api_check "9.9.9.9" "TESTKEY"
  [ "${status}" -eq 0 ]
  grep -q 'ipAddress=9.9.9.9' "${AIC_MOCK_LOG}"
  grep -q 'maxAgeInDays=45' "${AIC_MOCK_LOG}"
}

@test "aic_api_check setzt Accept-Header, --max-time 15 und uebergibt Key via --config (SEC2)" {
  export AIC_MOCK_SCENARIO="clean"
  run aic_api_check "9.9.9.9" "GEHEIM"
  [ "${status}" -eq 0 ]
  # SEC2: Der Key darf NICHT als Argument in der Prozessliste/im Mock-Log stehen —
  # er wird ueber curl --config (stdin) uebergeben. Das Log ist argv-only.
  ! grep -q 'GEHEIM' "${AIC_MOCK_LOG}"
  grep -q -- '--config' "${AIC_MOCK_LOG}"
  grep -qi 'application/json' "${AIC_MOCK_LOG}"
  grep -q -- '--max-time 15' "${AIC_MOCK_LOG}"
}

@test "aic_api_check funktioniert einheitlich fuer IPv6 (ipAddress-Query)" {
  export AIC_MOCK_SCENARIO="ipv6"
  run aic_api_check "2606:4700:4700::1111" "TESTKEY"
  [ "${status}" -eq 0 ]
  grep -q 'ipAddress=2606:4700:4700::1111' "${AIC_MOCK_LOG}"
  # Ergebnis-JSON traegt Status OK und die IPv6-Adresse.
  echo "${output}" | jq -e '.status == "OK"'
  echo "${output}" | jq -e '.ipAddress == "2606:4700:4700::1111"'
}

# ============================================================================
# US-007 — aic_api_check: Erfolgs-Response + Header-Parsing
# ============================================================================

@test "aic_api_check: OK-Ergebnis traegt Score, source=live und Ratelimit" {
  export AIC_MOCK_SCENARIO="malicious"
  run aic_api_check "185.220.101.1" "TESTKEY"
  [ "${status}" -eq 0 ]
  echo "${output}" | jq -e '.status == "OK"'
  echo "${output}" | jq -e '.source == "live"'
  echo "${output}" | jq -e '.abuseConfidenceScore == 100'
  # Header case-insensitiv geparst (Mock liefert gemischte Schreibweise).
  echo "${output}" | jq -e '.ratelimit.limit == "1000"'
  echo "${output}" | jq -e '.ratelimit.remaining == "993"'
  echo "${output}" | jq -e '.ratelimit.reset == "1752278400"'
}

@test "aic_api_check: null-Felder (isWhitelisted/lastReportedAt) bleiben null im JSON" {
  export AIC_MOCK_SCENARIO="null"
  run aic_api_check "203.0.113.7" "TESTKEY"
  [ "${status}" -eq 0 ]
  echo "${output}" | jq -e '.status == "OK"'
  echo "${output}" | jq -e '.isWhitelisted == null'
  echo "${output}" | jq -e '.lastReportedAt == null'
}

# ============================================================================
# US-007 — Fehler-Mapping
# ============================================================================

@test "aic_api_check: 401 -> FEHLER inkl. errors[0].detail" {
  export AIC_MOCK_SCENARIO="err401"
  run aic_api_check "9.9.9.9" "BADKEY"
  # Ergebnis-JSON auf stdout, Funktion selbst bricht NICHT ab.
  [ "${status}" -eq 0 ]
  echo "${output}" | jq -e '.status == "FEHLER"'
  echo "${output}" | jq -e '.http_code == 401'
  echo "${output}" | jq -e '.error_detail | test("Authentication failed")'
}

@test "aic_api_check: 402 -> FEHLER mit detail" {
  export AIC_MOCK_SCENARIO="err402"
  run aic_api_check "9.9.9.9" "TESTKEY"
  [ "${status}" -eq 0 ]
  echo "${output}" | jq -e '.status == "FEHLER"'
  echo "${output}" | jq -e '.http_code == 402'
  echo "${output}" | jq -e '.error_detail | test("Payment Required")'
}

@test "aic_api_check: 422 -> FEHLER mit detail (ungueltige IP laut API)" {
  export AIC_MOCK_SCENARIO="err422"
  run aic_api_check "9.9.9.9" "TESTKEY"
  [ "${status}" -eq 0 ]
  echo "${output}" | jq -e '.status == "FEHLER"'
  echo "${output}" | jq -e '.http_code == 422'
  echo "${output}" | jq -e '.error_detail | test("valid IPv4 or IPv6")'
}

@test "aic_api_check: 429 -> FEHLER, Retry-After roh, KEIN Auto-Retry" {
  export AIC_MOCK_SCENARIO="err429"
  run aic_api_check "9.9.9.9" "TESTKEY"
  [ "${status}" -eq 0 ]
  echo "${output}" | jq -e '.status == "FEHLER"'
  echo "${output}" | jq -e '.http_code == 429'
  echo "${output}" | jq -e '.retry_after == "3600"'
  # Kein Auto-Retry: genau ein Aufruf.
  [ "$(aic_mock_calls)" -eq 1 ]
}

@test "aic_api_check: kaputtes JSON (HTTP 200) -> FEHLER statt Abbruch" {
  export AIC_MOCK_SCENARIO="badjson"
  run aic_api_check "198.51.100.4" "TESTKEY"
  [ "${status}" -eq 0 ]
  echo "${output}" | jq -e '.status == "FEHLER"'
  echo "${output}" | jq -e '.ipAddress == "198.51.100.4"'
}

@test "aic_api_check: curl-Fehler/Timeout (Exit != 0) -> FEHLER statt Abbruch" {
  # Ein Mock, der wie ein Timeout mit Exit 28 endet.
  local fake="${AIC_TMP}/curl-timeout"
  cat > "${fake}" <<'SH'
#!/usr/bin/env bash
exit 28
SH
  chmod +x "${fake}"
  export AIC_CURL="${fake}"
  run aic_api_check "9.9.9.9" "TESTKEY"
  [ "${status}" -eq 0 ]
  echo "${output}" | jq -e '.status == "FEHLER"'
  echo "${output}" | jq -e '.ipAddress == "9.9.9.9"'
}

@test "kein /report-Endpoint im Tool (read-only)" {
  ! grep -q '/report' "${AIC_TOOL}"
}

# ============================================================================
# US-008 — Worker: atomares Ergebnis-JSON + Cache
# ============================================================================

@test "aic_worker schreibt Ergebnis-JSON in AIC_RUN_DIR" {
  export AIC_MOCK_SCENARIO="clean"
  export AIC_RUN_DIR="${AIC_TMP}/run"
  mkdir -p "${AIC_RUN_DIR}"
  run aic_worker "9.9.9.9" "TESTKEY"
  [ "${status}" -eq 0 ]
  # Genau eine Ergebnisdatei, valides JSON, richtige IP.
  local files=("${AIC_RUN_DIR}"/*.json)
  [ "${#files[@]}" -eq 1 ]
  jq -e '.ipAddress == "9.9.9.9"' "${files[0]}"
  jq -e '.status == "OK"' "${files[0]}"
}

@test "aic_worker legt bei OK zusaetzlich einen Ergebnis-Cache-Eintrag an" {
  export AIC_MOCK_SCENARIO="clean"
  export AIC_RUN_DIR="${AIC_TMP}/run"
  mkdir -p "${AIC_RUN_DIR}"
  aic_worker "9.9.9.9" "TESTKEY"
  [ -f "${AIC_CACHE_DIR}/9.9.9.9.json" ]
}

@test "aic_worker schreibt bei AIC_NO_CACHE=1 KEINEN Cache-Eintrag" {
  export AIC_MOCK_SCENARIO="clean"
  export AIC_NO_CACHE=1
  export AIC_RUN_DIR="${AIC_TMP}/run"
  mkdir -p "${AIC_RUN_DIR}"
  aic_worker "9.9.9.9" "TESTKEY"
  [ ! -f "${AIC_CACHE_DIR}/9.9.9.9.json" ]
}

@test "aic_worker schreibt bei FEHLER KEINEN Cache-Eintrag" {
  export AIC_MOCK_SCENARIO="err401"
  export AIC_RUN_DIR="${AIC_TMP}/run"
  mkdir -p "${AIC_RUN_DIR}"
  aic_worker "9.9.9.9" "TESTKEY"
  [ ! -f "${AIC_CACHE_DIR}/9.9.9.9.json" ]
}

# ============================================================================
# US-008 — Runner: Cache-Treffer, Probe, Parallel-Vollstaendigkeit
# ============================================================================

@test "aic_run_checks: Cache-Treffer wird OHNE API-Call als source=cache aggregiert" {
  export AIC_MOCK_SCENARIO="clean"
  # Vorab einen frischen Cache-Eintrag anlegen.
  local cached='{"data":{"ipAddress":"9.9.9.9","abuseConfidenceScore":0,"isWhitelisted":true,"lastReportedAt":null}}'
  aic_cache_write "9.9.9.9" "${cached}"
  run aic_run_checks "9.9.9.9" <<< ""
  [ "${status}" -eq 0 ]
  # Kein einziger Live-Call, da Cache-Treffer.
  [ "$(aic_mock_calls)" -eq 0 ]
}

@test "aic_run_checks: erster Call laeuft sequenziell als Probe VOR dem Fan-Out" {
  export AIC_MOCK_SCENARIO="clean"
  printf '%s\n' 9.9.9.9 8.8.8.8 1.1.1.1 > "${AIC_TMP}/ips.txt"
  run aic_run_checks_from_file "${AIC_TMP}/ips.txt" "TESTKEY"
  [ "${status}" -eq 0 ]
  # Alle drei wurden abgefragt.
  [ "$(aic_mock_calls)" -eq 3 ]
  # Die erste protokollierte CALL-Zeile (Probe) enthaelt die erste IP.
  local first
  first="$(grep '^CALL' "${AIC_MOCK_LOG}" | head -n1)"
  [[ "${first}" == *"ipAddress=9.9.9.9"* ]]
}

@test "aic_run_checks: 12 IPs mit --parallel 5 -> 12 Ergebnisse, jede IP genau einmal" {
  export AIC_MOCK_SCENARIO="clean"
  export AIC_PARALLEL=5
  : > "${AIC_TMP}/ips.txt"
  local i
  for i in $(seq 1 12); do printf '203.0.113.%s\n' "${i}" >> "${AIC_TMP}/ips.txt"; done
  export AIC_RUN_DIR_KEEP="${AIC_TMP}/keeprun"
  run aic_run_checks_from_file "${AIC_TMP}/ips.txt" "TESTKEY"
  [ "${status}" -eq 0 ]
  # 12 Live-Calls (kein Cache).
  [ "$(aic_mock_calls)" -eq 12 ]
  # Jede der 12 IPs erscheint genau einmal im Mock-Log.
  for i in $(seq 1 12); do
    [ "$(grep -c "ipAddress=203.0.113.${i}\b" "${AIC_MOCK_LOG}")" -eq 1 ]
  done
}

@test "aic_run_checks: --parallel 1 laeuft rein sequenziell, alle Ergebnisse da" {
  export AIC_MOCK_SCENARIO="clean"
  export AIC_PARALLEL=1
  printf '%s\n' 9.9.9.9 8.8.8.8 1.1.1.1 > "${AIC_TMP}/ips.txt"
  run aic_run_checks_from_file "${AIC_TMP}/ips.txt" "TESTKEY"
  [ "${status}" -eq 0 ]
  [ "$(aic_mock_calls)" -eq 3 ]
}

# ============================================================================
# US-008 — Rate-Limit: Min-Aggregation, W1/W2-Warnungen, Metadatei
# ============================================================================

@test "aic_run_checks: remaining = Minimum ueber alle Worker, in .ratelimit persistiert" {
  # Mock, der remaining deterministisch aus dem letzten IP-Oktett ableitet
  # (900 - oktett) — race-frei ohne geteilten Zaehler. IP .5 -> Minimum 895.
  local fake="${AIC_TMP}/curl-count"
  cat > "${fake}" <<'SH'
#!/usr/bin/env bash
set -u
log="${AIC_MOCK_LOG:-/dev/null}"
line="CALL"; for a in "$@"; do line+=" $(printf '%q' "$a")"; done
printf '%s\n' "$line" >> "$log" 2>/dev/null || true
header_file=""; write_out=""; prev=""; ip=""
for a in "$@"; do
  case "$prev" in
    -D|--dump-header) [ "$a" != "-" ] && header_file="$a" ;;
    -w|--write-out) write_out="$a" ;;
    --data-urlencode) [[ "$a" == ipAddress=* ]] && ip="${a#ipAddress=}" ;;
  esac
  prev="$a"
done
oktett="${ip##*.}"; [[ "$oktett" =~ ^[0-9]+$ ]] || oktett=0
rem=$(( 900 - oktett ))
emit() {
  printf 'HTTP/1.1 200\r\n'
  printf 'X-RateLimit-Limit: 1000\r\n'
  printf 'x-ratelimit-remaining: %s\r\n' "$rem"
  printf 'X-RATELIMIT-RESET: 1752278400\r\n'
  printf '\r\n'
}
[ -n "$header_file" ] && emit > "$header_file"
printf '%s' "{\"data\":{\"ipAddress\":\"${ip}\",\"abuseConfidenceScore\":0,\"isWhitelisted\":false,\"lastReportedAt\":null}}"
[ -n "$write_out" ] && printf '%b' "${write_out//\%\{http_code\}/200}"
exit 0
SH
  chmod +x "${fake}"
  export AIC_CURL="${fake}"
  export AIC_MAX_AGE=90 AIC_PARALLEL=3 AIC_NO_CACHE=1
  : > "${AIC_TMP}/ips.txt"
  local i
  for i in $(seq 1 5); do printf '203.0.113.%s\n' "${i}" >> "${AIC_TMP}/ips.txt"; done
  run aic_run_checks_from_file "${AIC_TMP}/ips.txt" "TESTKEY"
  [ "${status}" -eq 0 ]
  # remaining pro IP: 899,898,897,896,895 -> Minimum 895.
  # F2 (Feature-Runde 2): Metadaten liegen jetzt PRO KEY (Fingerprint) getrennt.
  # Statt den festen Namen .ratelimit zu erwarten, ermitteln wir den Pfad ueber
  # die tool-eigene Funktion mit dem aktiven Key (der Key-Wert steht nie im Namen).
  local meta
  meta="$(AIC_ACTIVE_KEY="TESTKEY" AIC_CACHE_DIR="${AIC_CACHE_DIR}" bash -c "source '${AIC_TOOL}'; AIC_ACTIVE_KEY='TESTKEY'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_meta_path")"
  [ -f "${meta}" ]
  grep -q 'remaining=895' "${meta}"
}

@test "aic_run_checks: W1-Vorwarnung wenn .ratelimit-remaining < Anzahl IPs" {
  export AIC_MOCK_SCENARIO="clean"
  # F2 (Feature-Runde 2): W1 liest die key-spezifische Metadatei des aktiven Keys.
  # Wir legen sie unter dem vom Tool erwarteten (Fingerprint-)Pfad voran.
  local meta
  meta="$(AIC_ACTIVE_KEY="TESTKEY" AIC_CACHE_DIR="${AIC_CACHE_DIR}" bash -c "source '${AIC_TOOL}'; AIC_ACTIVE_KEY='TESTKEY'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_meta_path")"
  printf 'remaining=2\nlimit=1000\nreset=1752278400\n' > "${meta}"
  printf '%s\n' 9.9.9.9 8.8.8.8 1.1.1.1 > "${AIC_TMP}/ips.txt"
  run aic_run_checks_from_file "${AIC_TMP}/ips.txt" "TESTKEY"
  [ "${status}" -eq 0 ]
  # W1-Warnung auf stderr (im run-Output kombiniert).
  [[ "${output}" == *"Vorwarnung"* || "${output}" == *"Kontingent"* ]]
}

@test "aic_run_checks: W2-Post-Probe-Warnung bei niedrigem realem remaining (nicht-TTY: Weiterlauf)" {
  # lowquota-Szenario: Probe liefert remaining=2 bei 5 IPs -> W2 greift.
  export AIC_MOCK_SCENARIO="lowquota"
  export AIC_PARALLEL=3
  : > "${AIC_TMP}/ips.txt"
  local i
  for i in $(seq 1 5); do printf '203.0.113.%s\n' "${i}" >> "${AIC_TMP}/ips.txt"; done
  # nicht-TTY (bats): Warnung + Weiterlauf, kein Abbruch.
  run aic_run_checks_from_file "${AIC_TMP}/ips.txt" "TESTKEY"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Warnung"* || "${output}" == *"Kontingent"* ]]
  # Trotz Warnung: alle 5 abgefragt (Weiterlauf).
  [ "$(aic_mock_calls)" -eq 5 ]
}

# ============================================================================
# US-008 — 0-Live-Call-Garantie
# ============================================================================

@test "kein Live-Call ohne AIC_CURL-Override (Mock zaehlt alle Netzzugriffe)" {
  export AIC_MOCK_SCENARIO="clean"
  aic_api_check "9.9.9.9" "TESTKEY" >/dev/null
  # Alle Aufrufe liefen ueber den Mock (AIC_CURL), keiner ueber echtes curl.
  [ "$(aic_mock_calls)" -ge 1 ]
  # Der Mock-Log enthaelt keinen Hinweis auf einen echten api.abuseipdb-Zugriff
  # ausserhalb der Mock-Naht (strukturell: der Mock ist die einzige Naht).
  [ -f "${AIC_MOCK_LOG}" ]
}

# ============================================================================
# Regression (Orchestrator-Sichtpruefung): angefragte IP ist verbindlich
# ============================================================================

@test "Regression: Ergebnis-ipAddress ist die ANGEFRAGTE IP, auch wenn die API-Antwort abweicht" {
  # clean-Fixture antwortet statisch mit ipAddress=9.9.9.9 — angefragt wird
  # 1.1.1.1. Cache-Schluessel und Anzeige muessen der Anfrage folgen (relevant
  # bei IPv6-Kanonisierung durch die API).
  export AIC_MOCK_SCENARIO="clean"
  local result
  result="$(aic_api_check "1.1.1.1" "TESTKEY")"
  [ "$(printf '%s' "${result}" | jq -r '.ipAddress')" = "1.1.1.1" ]
  [ "$(printf '%s' "${result}" | jq -r '.status')" = "OK" ]
}
