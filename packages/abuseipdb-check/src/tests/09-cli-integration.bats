#!/usr/bin/env bats
# 09-cli-integration.bats — US-011: Exit-Codes, --help, Ende-zu-Ende-Integration.
#
# Deckt die vier Abnahmekriterien der Story ab:
#   1. --help: alle Flags, Beispiele fuer alle 4 Eingabewege, Exit-Code-Legende.
#   2. Exit-Codes befundbasiert (0/1/2/3) inkl. Prioritaet 2 vor 3 vor 1.
#   3. E2E gemischte Liste (public/privat/ungueltig/doppelt/IPv6/whitelisted)
#      ueber alle 4 Eingabewege: korrekte Tabelle, Skip-Sektion, Exit-Code.
#   4. Nicht-TTY-Ausgabe ohne ANSI; 0-Live-Call-Assertion ueber den Mock-Log.
#
# ROT-Erwartung (TDD): Die befundbasierte Exit-Code-Logik (aic_run_checks_from_file
# gibt heute immer 0 zurueck) existiert im Tool noch NICHT — die Exit-1/-3-Tests
# und der Prioritaetsfall bleiben absichtlich rot, bis US-011 implementiert ist.
#
# Muster wie in 06/07: isoliertes HOME, AIC_CURL-Mock, AIC_ASSUME_TTY nie gesetzt
# (nicht-TTY-Pfad). Der Gesamtlauf beruehrt niemals das echte Netz.

load helpers

setup() {
  aic_setup_env
  aic_source_tool
  export AIC_CACHE_DIR="${AIC_TMP}/cache"
  mkdir -p "${AIC_CACHE_DIR}"
  export TZ="Europe/Berlin"
}
teardown() { aic_teardown_env; }

# ---------------------------------------------------------------------------
# Hilfsfunktion: fuehrt das Tool als eigenstaendigen Prozess aus (echter main-
# Pfad inkl. Exit-Code) mit isolierter, gemockter Umgebung. stdin ist /dev/null
# (nicht-TTY, sofortiges EOF) — verhindert Blockieren von aic_read_inputs.
# Zusatz-Env/Argumente werden durchgereicht.
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

# Baut einen IP-abhaengigen Fake-curl: Score/HTTP-Code richten sich nach der
# abgefragten ipAddress. So laesst sich ein gemischter Lauf (sauber + kritisch +
# API-Fehler) in EINEM Prozess abbilden, was der globale AIC_MOCK_SCENARIO nicht
# kann. Regeln (nach letztem Oktett / Muster der IP):
#   * IP endet auf .66  -> HTTP 200, abuseConfidenceScore 100 (kritisch)
#   * IP endet auf .55  -> HTTP 429, Fehler (Daily rate limit)
#   * sonst              -> HTTP 200, abuseConfidenceScore 0 (sauber)
_make_ip_aware_curl() {
  local path="${AIC_TMP}/curl-ipaware"
  cat > "${path}" <<'SH'
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

last="${ip##*.}"
http=200; score=0; body=""
case "$last" in
  66) http=200; score=100 ;;
  55) http=429 ;;
  *)  http=200; score=0 ;;
esac

if [ "$http" = "429" ]; then
  body='{"errors":[{"detail":"Daily rate limit exceeded","status":429}]}'
  rem=0
else
  body="{\"data\":{\"ipAddress\":\"${ip}\",\"abuseConfidenceScore\":${score},\"countryCode\":\"US\",\"isp\":\"Test\",\"usageType\":\"DC\",\"domain\":\"t.example\",\"isTor\":false,\"isWhitelisted\":false,\"totalReports\":0,\"numDistinctUsers\":0,\"lastReportedAt\":null}}"
  rem=900
fi

emit() {
  printf 'HTTP/1.1 %s\r\n' "$http"
  printf 'Content-Type: application/json\r\n'
  printf 'X-RateLimit-Limit: 1000\r\n'
  printf 'x-ratelimit-remaining: %s\r\n' "$rem"
  printf 'X-RATELIMIT-RESET: 1752278400\r\n'
  printf '\r\n'
}
[ -n "$header_file" ] && emit > "$header_file"
printf '%s' "$body"
[ -n "$write_out" ] && printf '%b' "${write_out//\%\{http_code\}/$http}"
exit 0
SH
  chmod +x "${path}"
  printf '%s\n' "${path}"
}

# ============================================================================
# Kriterium 1 — --help
# ============================================================================

@test "--help: Exit 0 und Grundstruktur" {
  _run_tool --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"abuseipdb-check"* ]]
  [[ "${output}" == *"VERWENDUNG"* ]]
}

@test "--help nennt alle Eingabe- und Filter-Flags" {
  _run_tool --help
  [ "${status}" -eq 0 ]
  for flag in "-f" "--extract" "--exclude" "--exclude-file" "--api-key" "--config"; do
    [[ "${output}" == *"${flag}"* ]] || { echo "FEHLT: ${flag}"; false; }
  done
}

@test "--help nennt alle Cache-Flags" {
  _run_tool --help
  [ "${status}" -eq 0 ]
  for flag in "--cache-dir" "--ttl" "--no-cache" "--clear-cache" "--cache-stats"; do
    [[ "${output}" == *"${flag}"* ]] || { echo "FEHLT: ${flag}"; false; }
  done
}

@test "--help nennt alle Abfrage- und Ausgabe-Flags" {
  _run_tool --help
  [ "${status}" -eq 0 ]
  for flag in "--parallel" "--max-age" "--sort" "--reverse" "--no-color"; do
    [[ "${output}" == *"${flag}"* ]] || { echo "FEHLT: ${flag}"; false; }
  done
}

@test "--help nennt die Export-Flags" {
  _run_tool --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"--output-file"* ]]
  [[ "${output}" == *"--output-format"* ]]
}

@test "--help zeigt Beispiele fuer alle 4 Eingabewege" {
  _run_tool --help
  [ "${status}" -eq 0 ]
  # Weg 1: Positionsargumente (IP ...)
  [[ "${output}" == *"IP ..."* ]]
  # Weg 2: Datei via -f/--file
  [[ "${output}" == *"-f"* ]]
  # Weg 3: stdin-Pipe
  [[ "${output}" == *"stdin"* ]] || [[ "${output}" == *"Pipe"* ]] || [[ "${output}" == *"cat "* ]]
  # Weg 4: Text-Extraktion
  [[ "${output}" == *"--extract"* ]]
}

@test "--help zeigt eine Exit-Code-Legende mit 0/1/2/3" {
  _run_tool --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"EXIT"* ]] || [[ "${output}" == *"Exit"* ]]
  # Alle vier Codes muessen erklaert sein.
  [[ "${output}" == *"0"* ]]
  [[ "${output}" == *"1"* ]]
  [[ "${output}" == *"2"* ]]
  [[ "${output}" == *"3"* ]]
  # Die Bedeutungen (Stichworte) sind genannt.
  [[ "${output}" == *"sauber"* ]] || [[ "${output}" == *"unauffaellig"* ]]
  [[ "${output}" == *"kritisch"* ]] || [[ "${output}" == *"Schwellenwert"* ]]
  [[ "${output}" == *"API"* ]] || [[ "${output}" == *"Netz"* ]]
}

# ============================================================================
# Kriterium 2 — Exit-Codes befundbasiert (0/1/2/3) + Prioritaet 2>3>1
# ============================================================================

@test "Exit 0: nur saubere IPs (Score < kritisch)" {
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9 8.8.8.8
  [ "${status}" -eq 0 ]
}

@test "Exit 1: mindestens eine IP >= kritischem Schwellenwert" {
  export AIC_MOCK_SCENARIO="malicious"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 185.220.101.1
  # ROT bis US-011: Runner gibt heute immer 0 zurueck.
  [ "${status}" -eq 1 ]
}

@test "Exit 2: unbekanntes Flag (+ Hilfe-Hinweis)" {
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --nonsense-flag 9.9.9.9
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"--help"* ]] || [[ "${output}" == *"Hilfe"* ]]
}

@test "Exit 2: ungueltiges --max-age" {
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --max-age 9999 9.9.9.9
  [ "${status}" -eq 2 ]
}

@test "Exit 2: ungueltiges --output-format" {
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --output-file "${AIC_TMP}/out" --output-format xml 9.9.9.9
  [ "${status}" -eq 2 ]
}

@test "Exit 2: fehlender Key (nicht-TTY)" {
  # Kein ABUSEIPDB_API_KEY, kein --api-key, isoliertes HOME ohne Config.
  _run_tool 9.9.9.9
  [ "${status}" -eq 2 ]
  # Hinweis auf die drei Key-Quellen.
  [[ "${output}" == *"API-Key"* ]] || [[ "${output}" == *"api_key"* ]] || [[ "${output}" == *"--api-key"* ]]
}

@test "Exit 3: API-Fehler, alle IPs FEHLER (err429)" {
  export AIC_MOCK_SCENARIO="err429"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9
  # ROT bis US-011: befundbasierter Exit 3 fehlt noch.
  [ "${status}" -eq 3 ]
}

@test "Exit 3: API-Fehler bei kaputtem JSON (badjson)" {
  export AIC_MOCK_SCENARIO="badjson"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9
  [ "${status}" -eq 3 ]
}

@test "Prioritaet 3 vor 1: kritischer Fund UND API-Fehler im selben Lauf -> Exit 3" {
  # IP-abhaengiger Mock: .66 -> Score 100 (kritisch), .55 -> HTTP 429 (Fehler).
  local fake
  fake="$(_make_ip_aware_curl)"
  export AIC_CURL="${fake}"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 203.0.113.66 203.0.113.55
  # Prioritaet: 3 (API-Fehler) schlaegt 1 (kritisch). ROT bis US-011.
  [ "${status}" -eq 3 ]
}

@test "Prioritaet 2 vor 3: Usage-Fehler schlaegt einen potenziellen API-Fehler" {
  # Unbekanntes Flag -> Abbruch in aic_parse_args (Exit 2), bevor irgendein
  # API-Call laeuft. Selbst mit err429-Szenario bleibt es Exit 2.
  export AIC_MOCK_SCENARIO="err429"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --bogus 9.9.9.9
  [ "${status}" -eq 2 ]
  # Kein einziger Live-Call, weil vor dem Runner abgebrochen.
  [ "$(aic_mock_calls)" -eq 0 ]
}

# ============================================================================
# Kriterium 3 — E2E gemischte Liste ueber alle 4 Eingabewege
# ============================================================================
#
# Gemischte Liste: public (9.9.9.9), privat (10.0.0.1), ungueltig (999.1.1.1),
# Duplikat (9.9.9.9 doppelt), IPv6-privat (fc00::1), whitelisted (8.8.8.8 via
# --exclude). Erwartung nach US-011:
#   * Tabelle enthaelt nur die zu pruefende public IP (9.9.9.9),
#   * Skip-Sektion nennt PRIVATE, INVALID, DUPLIKAT, WHITELIST,
#   * nur 9.9.9.9 erzeugt einen Live-Call, Exit 0 (alles sauber).

@test "E2E Weg 1 (Positionsargumente): gemischte Liste" {
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool \
    --exclude 8.8.8.8 9.9.9.9 9.9.9.9 8.8.8.8 10.0.0.1 999.1.1.1 fc00::1
  [ "${status}" -eq 0 ]
  # Nur die public, nicht-excludete IP wird abgefragt.
  [ "$(aic_mock_calls)" -eq 1 ]
  grep -q 'ipAddress=9.9.9.9' "${AIC_MOCK_LOG}"
  ! grep -q 'ipAddress=10.0.0.1' "${AIC_MOCK_LOG}"
  ! grep -q 'ipAddress=8.8.8.8' "${AIC_MOCK_LOG}"
  # Tabelle zeigt die geprüfte IP.
  [[ "${output}" == *"9.9.9.9"* ]]
  # Skip-Sektion nennt alle Gruende.
  [[ "${output}" == *"PRIVATE"* ]]
  [[ "${output}" == *"INVALID"* ]]
  [[ "${output}" == *"DUPLIKAT"* ]]
  [[ "${output}" == *"WHITELIST"* ]]
}

@test "E2E Weg 2 (Datei via -f): gemischte Liste" {
  export AIC_MOCK_SCENARIO="clean"
  local list="${AIC_TMP}/ips.txt"
  {
    printf '# Kommentar wird ignoriert\n'
    printf '9.9.9.9\n'
    printf '9.9.9.9\n'      # Duplikat
    printf '8.8.8.8\n'      # whitelisted via --exclude
    printf '10.0.0.1\n'     # privat
    printf '999.1.1.1\n'    # ungueltig
    printf 'fc00::1\n'      # IPv6 privat (ULA)
  } > "${list}"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --exclude 8.8.8.8 -f "${list}"
  [ "${status}" -eq 0 ]
  [ "$(aic_mock_calls)" -eq 1 ]
  grep -q 'ipAddress=9.9.9.9' "${AIC_MOCK_LOG}"
  [[ "${output}" == *"PRIVATE"* ]]
  [[ "${output}" == *"INVALID"* ]]
  [[ "${output}" == *"DUPLIKAT"* ]]
  [[ "${output}" == *"WHITELIST"* ]]
}

@test "E2E Weg 3 (stdin-Pipe): gemischte Liste" {
  export AIC_MOCK_SCENARIO="clean"
  run bash -c "
    cd '${AIC_ROOT_DIR}' &&
    printf '9.9.9.9\n9.9.9.9\n8.8.8.8\n10.0.0.1\n999.1.1.1\nfc00::1\n' | \
    AIC_CURL='${AIC_CURL}' AIC_CACHE_DIR='${AIC_CACHE_DIR}' \
    AIC_MOCK_LOG='${AIC_MOCK_LOG}' AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' \
    AIC_MOCK_SCENARIO=clean HOME='${HOME}' ABUSEIPDB_API_KEY=TESTKEY \
    ./abuseipdb-check --exclude 8.8.8.8
  "
  [ "${status}" -eq 0 ]
  [ "$(aic_mock_calls)" -eq 1 ]
  grep -q 'ipAddress=9.9.9.9' "${AIC_MOCK_LOG}"
  [[ "${output}" == *"PRIVATE"* ]]
  [[ "${output}" == *"INVALID"* ]]
  [[ "${output}" == *"DUPLIKAT"* ]]
  [[ "${output}" == *"WHITELIST"* ]]
}

@test "E2E Weg 4 (--extract aus Fliesstext): gemischte Liste" {
  export AIC_MOCK_SCENARIO="clean"
  local text="${AIC_TMP}/log.txt"
  {
    printf 'Angriff von 9.9.9.9 erkannt, siehe auch 9.9.9.9 (doppelt).\n'
    printf 'Whitelisted-Gateway 8.8.8.8 und internes 10.0.0.1 im Netz.\n'
    printf 'Kaputt: 999.1.1.1 sowie IPv6 fc00::1 aus dem ULA-Bereich.\n'
  } > "${text}"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --extract --exclude 8.8.8.8 -f "${text}"
  [ "${status}" -eq 0 ]
  # Nur 9.9.9.9 (public, nicht-excludet) wird abgefragt.
  grep -q 'ipAddress=9.9.9.9' "${AIC_MOCK_LOG}"
  ! grep -q 'ipAddress=10.0.0.1' "${AIC_MOCK_LOG}"
  ! grep -q 'ipAddress=8.8.8.8' "${AIC_MOCK_LOG}"
  [[ "${output}" == *"WHITELIST"* ]]
  [[ "${output}" == *"PRIVATE"* ]]
}

@test "E2E: Exit-Code passt zum Befund (gemischt mit kritischer IP -> Exit 1)" {
  # .66 -> Score 100 (kritisch), Rest sauber/uebersprungen.
  local fake
  fake="$(_make_ip_aware_curl)"
  export AIC_CURL="${fake}"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 203.0.113.66 10.0.0.1 999.1.1.1
  # Nur .66 wird gecheckt (Score 100) -> Exit 1. ROT bis US-011.
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"PRIVATE"* ]]
  [[ "${output}" == *"INVALID"* ]]
}

# ============================================================================
# Kriterium 4 — Nicht-TTY-Ausgabe ohne ANSI + 0-Live-Call-Assertion
# ============================================================================

@test "Nicht-TTY: E2E-Ausgabe enthaelt keine ANSI-Sequenzen" {
  export AIC_MOCK_SCENARIO="malicious"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 185.220.101.1
  # Egal ob Exit 0 oder 1 (US-011): der stdout darf kein ESC[ enthalten.
  ! printf '%s' "${output}" | grep -q $'\x1b'
}

@test "Nicht-TTY: gemischter E2E-Lauf bleibt ANSI-frei" {
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool \
    --exclude 8.8.8.8 9.9.9.9 10.0.0.1 999.1.1.1
  ! printf '%s' "${output}" | grep -q $'\x1b'
}

@test "0-Live-Call-Assertion: der gesamte E2E-Lauf lief nur ueber die Mock-Naht" {
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool \
    --exclude 8.8.8.8 9.9.9.9 9.9.9.9 8.8.8.8 10.0.0.1 999.1.1.1 fc00::1
  [ "${status}" -eq 0 ]
  # Genau ein Netzzugriff (nur 9.9.9.9), alle ueber AIC_CURL (den Mock).
  [ "$(aic_mock_calls)" -eq 1 ]
  # Der Mock-Log existiert und enthaelt ausschliesslich CALL-Zeilen mit
  # ipAddress-Query (keine anderweitige Netzaktivitaet moeglich, da der Mock
  # die EINZIGE curl-Naht ist).
  grep -q '^CALL' "${AIC_MOCK_LOG}"
}

@test "0-Live-Call-Assertion: reiner Skip-Lauf macht KEINEN Netzzugriff" {
  export AIC_MOCK_SCENARIO="clean"
  # Nur nicht-public/ungueltige IPs -> kein Key noetig, kein Call, Exit 0.
  _run_tool 10.0.0.1 127.0.0.1 999.1.1.1 fc00::1
  [ "${status}" -eq 0 ]
  [ "$(aic_mock_calls)" -eq 0 ]
  [[ "${output}" == *"PRIVATE"* ]]
  [[ "${output}" == *"LOOPBACK"* ]]
  [[ "${output}" == *"INVALID"* ]]
}

# ============================================================================
# Regression (Orchestrator-Sichtpruefung): --cache-dir erreicht Fan-Out-Worker
# ============================================================================

@test "Regression: parallele Worker cachen in --cache-dir, nicht im Default neben dem Tool" {
  # Bewusst OHNE AIC_CACHE_DIR-Env — nur der Flag-Pfad zaehlt. Vor dem Fix
  # schrieben xargs-Kindprozesse in <tooldir>/cache statt in --cache-dir.
  local flagcache="${AIC_TMP}/flagcache"
  # AIC_CACHE_DIR='' noetig: die in setup() exportierte Test-Naht hat Vorrang
  # vor dem Flag und wuerde genau den Flag-Pfad maskieren, den der Bug betraf.
  run bash -c "
    cd '${AIC_ROOT_DIR}' &&
    AIC_CACHE_DIR='' \
    AIC_CURL='${AIC_CURL}' \
    AIC_MOCK_LOG='${AIC_MOCK_LOG}' \
    AIC_MOCK_FIXTURES='${AIC_MOCK_FIXTURES}' \
    AIC_MOCK_SCENARIO=clean \
    ABUSEIPDB_API_KEY=TESTKEY \
    ./abuseipdb-check --no-color --parallel 2 --cache-dir '${flagcache}' \
      9.9.9.9 8.8.8.8 1.1.1.1 </dev/null
  "
  [ "${status}" -eq 0 ]
  # Alle drei IPs liegen im Flag-Cache (Probe + beide Fan-Out-Worker) ...
  [ -f "${flagcache}/9.9.9.9.json" ]
  [ -f "${flagcache}/8.8.8.8.json" ]
  [ -f "${flagcache}/1.1.1.1.json" ]
  # ... und NICHT im Default-Cache neben dem Tool (F3: jetzt data/cache).
  [ ! -f "${AIC_ROOT_DIR}/data/cache/8.8.8.8.json" ]
  [ ! -f "${AIC_ROOT_DIR}/data/cache/1.1.1.1.json" ]
  [ ! -f "${AIC_ROOT_DIR}/cache/8.8.8.8.json" ]
  [ ! -f "${AIC_ROOT_DIR}/cache/1.1.1.1.json" ]
}

@test "Flag ohne Pflicht-Argument fuehrt zu Exit 2 mit Fehlermeldung" {
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --sort
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"benoetigt ein Argument"* ]]
}

@test "Regression: paralleler Fan-Out liefert LIVE-Ergebnisse ohne FEHLER (Env-Exporte vollstaendig)" {
  # Der Mock verlangt jetzt wie echtes curl eine URL (sonst Exit 2). Fehlt ein
  # Export (AIC_API_URL/AIC_MAX_AGE) fuer die xargs-Kinder, kippen alle IPs
  # nach der Probe auf FEHLER — genau der im Nutzertest gefundene Live-Bug.
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --parallel 3 9.9.9.9 8.8.8.8 1.1.1.1 208.67.222.222
  [ "${status}" -eq 0 ]
  [[ "${output}" != *"FEHLER"* ]]
  [ "$(grep -c '^CALL' "${AIC_MOCK_LOG}")" -eq 4 ]
}

@test "Regression: voll gecachter Lauf zeigt die Rate-Limit-Zeile aus der Key-Metadatei" {
  # Vor dem Fix blieb AIC_ACTIVE_KEY ohne Live-Runde ungesetzt: die Anzeige
  # las den Legacy-Pfad (.ratelimit) statt .ratelimit.<fingerprint> und zeigte
  # veraltete oder gar keine Werte.
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Verbleibend: 995"* ]]
  # Zweiter Lauf: komplett aus dem Cache (0 live), Werte muessen erhalten bleiben.
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"(0 live, 1 Cache)"* ]]
  [[ "${output}" == *"API-Limit: 1000 | Verbleibend: 995"* ]]
}

@test "Cache-Abgleich zeigt Fortschritt bei aktiver Progress-Anzeige" {
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9
  [ "${status}" -eq 0 ]
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY AIC_FORCE_PROGRESS=1" _run_tool 9.9.9.9
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Cache-Abgleich: 1/1"* ]]
}

@test "--output-file ohne Endung bekommt die Endung des Export-Formats" {
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --output-file "${AIC_TMP}/report" --output-format csv 9.9.9.9
  [ "${status}" -eq 0 ]
  [ -f "${AIC_TMP}/report.csv" ]
  [ ! -f "${AIC_TMP}/report" ]
}

@test "--output-file mit eigener Endung bleibt unangetastet (Nutzereingabe hat Vorrang)" {
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --output-file "${AIC_TMP}/eigene.txt" --output-format csv 9.9.9.9
  [ "${status}" -eq 0 ]
  [ -f "${AIC_TMP}/eigene.txt" ]
  [ ! -f "${AIC_TMP}/eigene.txt.csv" ]
}

@test "--init richtet die Config interaktiv ein und beendet sich (Exit 0)" {
  local cfg="${AIC_TMP}/initcfg"
  run bash -c "
    cd '${AIC_ROOT_DIR}' &&
    HOME='${HOME}' printf 'HAUPTKEY\nZWEITKEY\n\n7\n' | ./abuseipdb-check --init --config '${cfg}'
  "
  [ "${status}" -eq 0 ]
  [ -f "${cfg}" ]
  grep -q '^api_key=HAUPTKEY$' "${cfg}"
  grep -q '^api_keys=ZWEITKEY$' "${cfg}"
  grep -q '^ttl=7d$' "${cfg}"
  [[ "${output}" == *"Konfiguration gespeichert"* ]]
  # --init prueft keine IPs und beruehrt nie das Netz.
  [ "$(grep -c '^CALL' "${AIC_MOCK_LOG}")" -eq 0 ]
}

@test "--init ueberschreibt eine bestehende Config nur mit Hinweis" {
  local cfg="${AIC_TMP}/initcfg2"
  printf 'api_key=ALT\n' > "${cfg}"
  run bash -c "
    cd '${AIC_ROOT_DIR}' &&
    HOME='${HOME}' printf 'NEU\n\n\n' | ./abuseipdb-check --init --config '${cfg}'
  "
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"ueberschrieben"* ]]
  grep -q '^api_key=NEU$' "${cfg}"
  ! grep -q 'ALT' "${cfg}"
}
