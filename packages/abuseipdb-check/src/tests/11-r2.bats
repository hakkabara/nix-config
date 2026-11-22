#!/usr/bin/env bats
# 11-r2.bats — Feature-Runde 2 (F1 TTL, F2 Multi-Key-Rotation, F3 data/-Ordner).
#
# F1 — TTL mit Suffix (d/h/nackt), Default 10 Tage (240h), Config ttl vs
#      ttl_hours-Vorrang, Ersteinrichtung fragt Tage und schreibt ttl=<N>d.
# F2 — Mehrere API-Keys mit Rotation bei HTTP 429 (Tageskontingent leer):
#      Wechsel zum naechsten Key + Retry DIESER IP; alle Keys leer -> FEHLER +
#      Exit 3; .ratelimit pro Key-Fingerprint (nie der Key selbst im Namen);
#      kein Key-Wert in Ausgabe/Exports/Metadaten.
# F3 — Aufgeraeumter Tool-Ordner: Cache-Default <tooldir>/data/cache,
#      Metadaten unter data/, Migration von altem cache/.
#
# Muster wie 06/09/10: isoliertes HOME, AIC_CURL-Mock, nicht-TTY (</dev/null),
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

# Wie in 09/10: eigenstaendiger Prozess, stdin=/dev/null (nicht-TTY, sofort EOF).
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

# Baut einen key-abhaengigen Fake-curl: der Mock inspiziert den "Key: <wert>"-
# Header (via -H) und entscheidet daran HTTP-Code + Body. So ist ein
# Rotationsszenario je KEY unterscheidbar (K1 -> 429, K2 -> 200). Regeln in
# AIC_KEY429_LIST (kommasepariert): jeder dort genannte Key liefert 429.
_make_key_aware_curl() {
  local path="${AIC_TMP}/curl-keyaware"
  cat > "${path}" <<'SH'
#!/usr/bin/env bash
set -u
log="${AIC_MOCK_LOG:-/dev/null}"
line="CALL"; for a in "$@"; do line+=" $(printf '%q' "$a")"; done
printf '%s\n' "$line" >> "$log" 2>/dev/null || true

header_file=""; write_out=""; prev=""; ip=""; key=""; uses_config=0
for a in "$@"; do
  case "$prev" in
    -D|--dump-header) [ "$a" != "-" ] && header_file="$a" ;;
    -w|--write-out) write_out="$a" ;;
    --data-urlencode) [[ "$a" == ipAddress=* ]] && ip="${a#ipAddress=}" ;;
  esac
  case "$a" in --config|-K) uses_config=1 ;; esac
  prev="$a"
done
# SEC2: Key kommt via curl --config (stdin), nicht mehr als -H-Argument.
if [ "$uses_config" -eq 1 ] && [ ! -t 0 ]; then
  while IFS= read -r cfgline || [ -n "$cfgline" ]; do
    case "$cfgline" in
      *[Hh]eader*Key:*) key="${cfgline#*Key:}"; key="${key%\"}"; key="${key# }" ;;
    esac
  done
fi

# Ist dieser Key in der 429-Liste? -> Tageskontingent leer.
is429=0
IFS=',' read -r -a bad <<< "${AIC_KEY429_LIST:-}"
for b in "${bad[@]}"; do
  [ "$b" = "$key" ] && { is429=1; break; }
done

if [ "$is429" -eq 1 ]; then
  http=429; rem=0
  body='{"errors":[{"detail":"Daily rate limit of 1000 requests exceeded for this endpoint. See headers for additional details.","status":429}]}'
else
  http=200; rem=900
  body="{\"data\":{\"ipAddress\":\"${ip}\",\"abuseConfidenceScore\":0,\"countryCode\":\"US\",\"isp\":\"Test\",\"usageType\":\"DC\",\"domain\":\"t.example\",\"isTor\":false,\"isWhitelisted\":false,\"totalReports\":0,\"numDistinctUsers\":0,\"lastReportedAt\":null}}"
fi

emit() {
  printf 'HTTP/1.1 %s\r\n' "$http"
  printf 'Content-Type: application/json\r\n'
  printf 'X-RateLimit-Limit: 1000\r\n'
  printf 'x-ratelimit-remaining: %s\r\n' "$rem"
  printf 'X-RATELIMIT-RESET: 1752278400\r\n'
  if [ "$http" = "429" ]; then printf 'Retry-After: 3600\r\n'; fi
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
# F1 — TTL mit Suffix (d/h/nackt) + Default 10 Tage
# ============================================================================

@test "F1: aic_ttl_to_hours parst Tages-Suffix (10d -> 240)" {
  run aic_ttl_to_hours "10d"
  [ "${status}" -eq 0 ]
  [ "${output}" == "240" ]
}

@test "F1: aic_ttl_to_hours parst Stunden-Suffix (12h -> 12)" {
  run aic_ttl_to_hours "12h"
  [ "${status}" -eq 0 ]
  [ "${output}" == "12" ]
}

@test "F1: aic_ttl_to_hours behandelt nackte Zahl als Stunden (abwaertskompatibel)" {
  run aic_ttl_to_hours "48"
  [ "${status}" -eq 0 ]
  [ "${output}" == "48" ]
}

@test "F1: aic_ttl_to_hours parst 1d korrekt (-> 24)" {
  run aic_ttl_to_hours "1d"
  [ "${status}" -eq 0 ]
  [ "${output}" == "24" ]
}

@test "F1: aic_ttl_to_hours weist 0 zurueck (Exit != 0)" {
  run aic_ttl_to_hours "0"
  [ "${status}" -ne 0 ]
  run aic_ttl_to_hours "0d"
  [ "${status}" -ne 0 ]
  run aic_ttl_to_hours "0h"
  [ "${status}" -ne 0 ]
}

@test "F1: aic_ttl_to_hours weist negative/Muell-Werte zurueck" {
  run aic_ttl_to_hours "-5"
  [ "${status}" -ne 0 ]
  run aic_ttl_to_hours "abc"
  [ "${status}" -ne 0 ]
  run aic_ttl_to_hours "5x"
  [ "${status}" -ne 0 ]
  run aic_ttl_to_hours "1.5d"
  [ "${status}" -ne 0 ]
  run aic_ttl_to_hours ""
  [ "${status}" -ne 0 ]
}

@test "F1: ungueltiges --ttl -> Exit 2 (Nutzungsfehler)" {
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --ttl 0 9.9.9.9
  [ "${status}" -eq 2 ]
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --ttl muell 9.9.9.9
  [ "${status}" -eq 2 ]
}

@test "F1: Default-TTL ist 240h (10 Tage) — 8-Tage-alter Cache ist noch frisch" {
  # Bewusste Default-Aenderung: frueher 24h, jetzt 240h. Ein 8 Tage alter
  # Cache-Eintrag ist damit ein Treffer (kein Live-Call noetig).
  local cached='{"data":{"ipAddress":"9.9.9.9","abuseConfidenceScore":0,"isWhitelisted":false,"lastReportedAt":null}}'
  aic_cache_write "9.9.9.9" "${cached}"
  touch -d '8 days ago' "${AIC_CACHE_DIR}/9.9.9.9.json"
  # Default-TTL (kein --ttl, kein Config-ttl): 8d < 10d -> Hit.
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; unset AIC_TTL_HOURS AIC_OPT_TTL AIC_CFG_ttl AIC_CFG_ttl_hours; AIC_TTL_HOURS=\"\$(aic_resolve_ttl_hours)\"; aic_cache_read '9.9.9.9'"
  [ "${status}" -eq 0 ]
}

@test "F1: Default-TTL 240h — 11-Tage-alter Cache ist abgelaufen (Miss)" {
  local cached='{"data":{"ipAddress":"9.9.9.9","abuseConfidenceScore":0}}'
  aic_cache_write "9.9.9.9" "${cached}"
  touch -d '11 days ago' "${AIC_CACHE_DIR}/9.9.9.9.json"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; unset AIC_TTL_HOURS AIC_OPT_TTL AIC_CFG_ttl AIC_CFG_ttl_hours; AIC_TTL_HOURS=\"\$(aic_resolve_ttl_hours)\"; aic_cache_read '9.9.9.9'"
  [ "${status}" -ne 0 ]
}

@test "F1: aic_resolve_ttl_hours — Default ohne Konfiguration ist 240" {
  run bash -c "source '${AIC_TOOL}'; unset AIC_OPT_TTL AIC_CFG_ttl AIC_CFG_ttl_hours; aic_resolve_ttl_hours"
  [ "${status}" -eq 0 ]
  [ "${output}" == "240" ]
}

@test "F1: Config ttl (mit Suffix) hat Vorrang vor legacy ttl_hours" {
  # Beide gesetzt: ttl (5d=120h) gewinnt gegen ttl_hours (24).
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_TTL=''; AIC_CFG_ttl='5d'; AIC_CFG_ttl_hours='24'; aic_resolve_ttl_hours"
  [ "${status}" -eq 0 ]
  [ "${output}" == "120" ]
}

@test "F1: legacy ttl_hours bleibt gueltig, wenn ttl nicht gesetzt" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_TTL=''; AIC_CFG_ttl=''; AIC_CFG_ttl_hours='6'; aic_resolve_ttl_hours"
  [ "${status}" -eq 0 ]
  [ "${output}" == "6" ]
}

@test "F1: --ttl (Flag) hat Vorrang vor Config ttl und ttl_hours" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_TTL='2d'; AIC_CFG_ttl='5d'; AIC_CFG_ttl_hours='24'; aic_resolve_ttl_hours"
  [ "${status}" -eq 0 ]
  [ "${output}" == "48" ]
}

@test "F1: Config-Whitelist erlaubt den neuen Key 'ttl'" {
  local cfg="${HOME}/.config/abuseipdb/config"
  mkdir -p "$(dirname "${cfg}")"
  printf 'api_key=KEY\nttl=7d\n' > "${cfg}"
  run bash -c "source '${AIC_TOOL}'; aic_load_config '${cfg}'; printf '%s' \"\${AIC_CFG_ttl}\""
  [ "${status}" -eq 0 ]
  [ "${output}" == "7d" ]
}

@test "F1: Config-Whitelist erlaubt den neuen Key 'api_keys'" {
  local cfg="${HOME}/.config/abuseipdb/config"
  mkdir -p "$(dirname "${cfg}")"
  printf 'api_keys=K1,K2,K3\n' > "${cfg}"
  run bash -c "source '${AIC_TOOL}'; aic_load_config '${cfg}'; printf '%s' \"\${AIC_CFG_api_keys}\""
  [ "${status}" -eq 0 ]
  [ "${output}" == "K1,K2,K3" ]
}

@test "F1: Ersteinrichtung fragt TTL in TAGEN und schreibt ttl=<N>d" {
  local cfg="${HOME}/.config/abuseipdb/config"
  rm -f "${cfg}"
  # Key 'INTERKEY', keine weiteren Keys (Leerzeile), TTL '7' (Tage) -> ttl=7d.
  run bash -c "source '${AIC_TOOL}'; printf 'INTERKEY\n\n7\n' | AIC_ASSUME_TTY=1 aic_config_init '${cfg}'"
  [ "${status}" -eq 0 ]
  [ -f "${cfg}" ]
  grep -q '^api_key=INTERKEY$' "${cfg}"
  grep -q '^ttl=7d$' "${cfg}"
}

@test "F1: Ersteinrichtung mit leerer TTL-Antwort schreibt Default 10d" {
  local cfg="${HOME}/.config/abuseipdb/config"
  rm -f "${cfg}"
  run bash -c "source '${AIC_TOOL}'; printf 'INTERKEY\n\n' | AIC_ASSUME_TTY=1 aic_config_init '${cfg}'"
  [ "${status}" -eq 0 ]
  grep -q '^api_key=INTERKEY$' "${cfg}"
  grep -q '^ttl=10d$' "${cfg}"
}

@test "F1: Ersteinrichtungs-Prompt nennt Tage (nicht Stunden)" {
  local cfg="${HOME}/.config/abuseipdb/config"
  rm -f "${cfg}"
  run bash -c "source '${AIC_TOOL}'; printf 'INTERKEY\n\n' | AIC_ASSUME_TTY=1 aic_config_init '${cfg}' 2>&1"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Tage"* ]]
}

# ============================================================================
# F2 — Mehrere API-Keys + Rotation bei 429
# ============================================================================

@test "F2: aic_resolve_api_keys liefert wiederholte --api-key in Reihenfolge" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_API_KEYS=(K1 K2 K3); unset ABUSEIPDB_API_KEY; AIC_CFG_api_key=''; AIC_CFG_api_keys=''; aic_resolve_api_keys"
  [ "${status}" -eq 0 ]
  [ "${output}" == "K1
K2
K3" ]
}

@test "F2: Env ABUSEIPDB_API_KEY darf kommasepariert mehrere enthalten" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_API_KEYS=(); ABUSEIPDB_API_KEY='E1,E2'; AIC_CFG_api_key=''; AIC_CFG_api_keys=''; aic_resolve_api_keys"
  [ "${status}" -eq 0 ]
  [ "${output}" == "E1
E2" ]
}

@test "F2: Config api_keys (kommasepariert) + api_key werden zusammengefuehrt" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_API_KEYS=(); unset ABUSEIPDB_API_KEY; AIC_CFG_api_key='Ck'; AIC_CFG_api_keys='Ca,Cb'; aic_resolve_api_keys"
  [ "${status}" -eq 0 ]
  # Reihenfolge innerhalb der Config-Quelle: api_key zuerst, dann api_keys.
  [[ "${output}" == *"Ck"* ]]
  [[ "${output}" == *"Ca"* ]]
  [[ "${output}" == *"Cb"* ]]
}

@test "F2: Quellen-Prioritaet Flag > Env > Config" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_API_KEYS=(F1); ABUSEIPDB_API_KEY='E1'; AIC_CFG_api_key='C1'; AIC_CFG_api_keys=''; aic_resolve_api_keys"
  [ "${status}" -eq 0 ]
  # Nur die Flag-Quelle zaehlt (hoechste Prioritaet gewinnt die QUELLE).
  [ "${output}" == "F1" ]
}

@test "F2: kein Key vorhanden -> aic_resolve_api_keys Exit != 0" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_API_KEYS=(); unset ABUSEIPDB_API_KEY; AIC_CFG_api_key=''; AIC_CFG_api_keys=''; aic_resolve_api_keys"
  [ "${status}" -ne 0 ]
}

@test "F2: Key-Fingerprint ist stabil und enthaelt NICHT den Key-Wert" {
  run bash -c "source '${AIC_TOOL}'; aic_key_fingerprint 'GEHEIMER_KEY_123'"
  [ "${status}" -eq 0 ]
  # Der Fingerprint darf den Key nicht im Klartext enthalten.
  [[ "${output}" != *"GEHEIMER_KEY_123"* ]]
  # Kurzer Hex-Hash.
  [[ "${output}" =~ ^[0-9a-f]+$ ]]
  # Stabil: gleicher Key -> gleicher Fingerprint.
  local fp2
  fp2="$(bash -c "source '${AIC_TOOL}'; aic_key_fingerprint 'GEHEIMER_KEY_123'")"
  [ "${output}" == "${fp2}" ]
  # Unterschiedlicher Key -> anderer Fingerprint.
  local fp3
  fp3="$(bash -c "source '${AIC_TOOL}'; aic_key_fingerprint 'ANDERER_KEY'")"
  [ "${output}" != "${fp3}" ]
}

@test "F2: .ratelimit-Metadatei-Pfad ist key-abhaengig, ohne Key im Namen" {
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; AIC_ACTIVE_KEY='SECRETKEY'; aic_cache_meta_path"
  [ "${status}" -eq 0 ]
  [[ "${output}" != *"SECRETKEY"* ]]
  # Liegt im/neben dem Cache-Verzeichnis.
  [[ "${output}" == "${AIC_CACHE_DIR}"* ]]
}

@test "F2: Rotation — K1 (429) -> K2 (200): alle IPs OK, Rotation-Hinweis" {
  local fake; fake="$(_make_key_aware_curl)"
  export AIC_CURL="${fake}"
  export AIC_KEY429_LIST="K1"
  _TOOL_ENV="AIC_KEY429_LIST=K1" _run_tool --parallel 2 --api-key K1 --api-key K2 9.9.9.9 8.8.8.8 1.1.1.1
  [ "${status}" -eq 0 ]
  # Alle drei IPs am Ende OK (kein FEHLER in der Tabelle).
  [[ "${output}" != *"FEHLER"* ]]
  # Rotation wurde vermerkt (Hinweis auf Key-Wechsel).
  [[ "${output}" == *"Rotation"* ]] || [[ "${output}" == *"Key gewechselt"* ]] || [[ "${output}" == *"naechsten Key"* ]]
  # Kein Key-Wert taucht in der Ausgabe auf.
  [[ "${output}" != *"K1"* ]]
  [[ "${output}" != *"K2"* ]]
}

@test "F2: Rotation retryt jede 429-IP genau einmal mit dem naechsten Key" {
  local fake; fake="$(_make_key_aware_curl)"
  export AIC_CURL="${fake}"
  _TOOL_ENV="AIC_KEY429_LIST=K1" _run_tool --parallel 2 --api-key K1 --api-key K2 9.9.9.9 8.8.8.8
  [ "${status}" -eq 0 ]
  # 2 IPs: je ein 429-Call (K1) + ein OK-Call (K2) = hoechstens 4 Calls.
  # Wichtig: kein Endlos-Retry.
  local calls; calls="$(grep -c '^CALL' "${AIC_MOCK_LOG}")"
  [ "${calls}" -le 4 ]
  [ "${calls}" -ge 3 ]
  # Jede IP wurde mit K2 (dem funktionierenden Key) erfolgreich abgefragt:
  # in der Tabelle erscheinen beide IPs ohne FEHLER.
  [[ "${output}" == *"9.9.9.9"* ]]
  [[ "${output}" == *"8.8.8.8"* ]]
}

@test "F2: alle Keys erschoepft (429) -> IPs FEHLER + Exit 3" {
  local fake; fake="$(_make_key_aware_curl)"
  export AIC_CURL="${fake}"
  # Beide Keys in der 429-Liste -> nichts geht durch.
  _TOOL_ENV="AIC_KEY429_LIST=K1,K2" _run_tool --parallel 2 --api-key K1 --api-key K2 9.9.9.9 8.8.8.8
  [ "${status}" -eq 3 ]
  [[ "${output}" == *"FEHLER"* ]]
}

@test "F2: Rate-Limit-Zeile zeigt 'Key <i>/<n>' bei mehreren Keys" {
  local fake; fake="$(_make_key_aware_curl)"
  export AIC_CURL="${fake}"
  _TOOL_ENV="AIC_KEY429_LIST=K1" _run_tool --parallel 2 --api-key K1 --api-key K2 9.9.9.9 8.8.8.8
  [ "${status}" -eq 0 ]
  # Nach Rotation ist Key 2 aktiv -> "Key 2/2".
  [[ "${output}" == *"Key 2/2"* ]]
}

@test "F2: einzelner Key zeigt KEINE 'Key i/n'-Angabe (n==1)" {
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9
  [ "${status}" -eq 0 ]
  [[ "${output}" != *"Key 1/1"* ]]
}

@test "F2: kein Key-Wert im JSON-Export (auch nicht in Metadaten)" {
  local fake; fake="$(_make_key_aware_curl)"
  export AIC_CURL="${fake}"
  local out="${AIC_TMP}/rep.json"
  _TOOL_ENV="AIC_KEY429_LIST=K1" _run_tool --parallel 2 --api-key K1 --api-key K2 \
    9.9.9.9 8.8.8.8 --output-file "${out}" --output-format json
  [ "${status}" -eq 0 ]
  [ -f "${out}" ]
  ! grep -q 'K1' "${out}"
  ! grep -q 'K2' "${out}"
  # Auch kein Klartext-Key in den .ratelimit-Metadateien.
  ! grep -rq 'K1' "${AIC_CACHE_DIR}"/.ratelimit* 2>/dev/null
  ! grep -rq 'K2' "${AIC_CACHE_DIR}"/.ratelimit* 2>/dev/null
}

@test "F2: Cache-Resume nach Voll-429 — zweiter Lauf prueft nur Fehlende" {
  local fake; fake="$(_make_key_aware_curl)"
  export AIC_CURL="${fake}"
  # Lauf 1: beide Keys 429 -> alle FEHLER, nichts gecached.
  _TOOL_ENV="AIC_KEY429_LIST=K1,K2" _run_tool --parallel 2 --api-key K1 --api-key K2 9.9.9.9 8.8.8.8
  [ "${status}" -eq 3 ]
  : > "${AIC_MOCK_LOG}"
  # Lauf 2: jetzt geht K1 durch (nicht mehr in der 429-Liste).
  _TOOL_ENV="AIC_KEY429_LIST=" _run_tool --parallel 2 --api-key K1 --api-key K2 9.9.9.9 8.8.8.8
  [ "${status}" -eq 0 ]
  # Beide IPs waren nicht gecached -> beide live abgefragt.
  [ "$(grep -c '^CALL' "${AIC_MOCK_LOG}")" -eq 2 ]
}

# ============================================================================
# F2b — Aggregierte Rate-Limit-Anzeige ueber alle Keys
# ============================================================================

@test "F2b: aic_ratelimit_aggregate summiert limit/remaining ueber bekannte Keys" {
  # Zwei Keys mit bekannten Metadaten: Summe limit=3000, remaining=2455.
  local m1 m2
  m1="$(AIC_ACTIVE_KEY=KA AIC_CACHE_DIR="${AIC_CACHE_DIR}" bash -c "source '${AIC_TOOL}'; AIC_ACTIVE_KEY='KA'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_meta_path")"
  m2="$(AIC_ACTIVE_KEY=KB AIC_CACHE_DIR="${AIC_CACHE_DIR}" bash -c "source '${AIC_TOOL}'; AIC_ACTIVE_KEY='KB'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_meta_path")"
  printf 'remaining=1200\nlimit=1000\nreset=1752278400\n' > "${m1}"
  printf 'remaining=1255\nlimit=2000\nreset=1752281999\n' > "${m2}"
  # aggregate gibt: sum_limit \t sum_remaining \t reset \t nkeys \t unused \t partial
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; AIC_RUN_KEYS=(KA KB); aic_ratelimit_aggregate"
  [ "${status}" -eq 0 ]
  local sl sr rst nk un pt
  IFS=$'\t' read -r sl sr rst nk un pt <<< "${output}"
  [ "${sl}" == "3000" ]
  [ "${sr}" == "2455" ]
  [ "${nk}" == "2" ]
  [ "${un}" == "0" ]
  [ "${pt}" == "0" ]
  # Reset ist die FRUEHESTE (kleinste) unter den bekannten Keys.
  [ "${rst}" == "1752278400" ]
}

@test "F2b: aic_ratelimit_aggregate weist ungenutzte Keys transparent aus (Teilsumme)" {
  # KA bekannt, KB ohne Metadaten (nie benutzt) -> Teilsumme, unused=1, partial=1.
  local m1
  m1="$(AIC_ACTIVE_KEY=KA AIC_CACHE_DIR="${AIC_CACHE_DIR}" bash -c "source '${AIC_TOOL}'; AIC_ACTIVE_KEY='KA'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_meta_path")"
  printf 'remaining=800\nlimit=1000\nreset=1752278400\n' > "${m1}"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; AIC_RUN_KEYS=(KA KB); aic_ratelimit_aggregate"
  [ "${status}" -eq 0 ]
  local sl sr rst nk un pt
  IFS=$'\t' read -r sl sr rst nk un pt <<< "${output}"
  [ "${sl}" == "1000" ]
  [ "${sr}" == "800" ]
  [ "${nk}" == "2" ]
  [ "${un}" == "1" ]
  [ "${pt}" == "1" ]
}

@test "F2b: Ausgabe zeigt aggregierte Summe bei zwei bekannten Keys" {
  # Zwei Keys, beide vorab mit Metadaten -> Zeile summiert.
  local fake; fake="$(_make_key_aware_curl)"
  export AIC_CURL="${fake}"
  local m1 m2
  m1="$(AIC_ACTIVE_KEY=K1 AIC_CACHE_DIR="${AIC_CACHE_DIR}" bash -c "source '${AIC_TOOL}'; AIC_ACTIVE_KEY='K1'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_meta_path")"
  m2="$(AIC_ACTIVE_KEY=K2 AIC_CACHE_DIR="${AIC_CACHE_DIR}" bash -c "source '${AIC_TOOL}'; AIC_ACTIVE_KEY='K2'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_meta_path")"
  printf 'remaining=1000\nlimit=1000\nreset=1752278400\n' > "${m1}"
  printf 'remaining=2000\nlimit=2000\nreset=1752278400\n' > "${m2}"
  # Lauf mit beiden Keys (K1 geht durch -> aktualisiert K1-Meta auf 900).
  _TOOL_ENV="AIC_KEY429_LIST=" _run_tool --parallel 2 --api-key K1 --api-key K2 9.9.9.9
  [ "${status}" -eq 0 ]
  # Summierte Anzeige: Gesamt-Limit 3000, "2 Keys".
  [[ "${output}" == *"3000"* ]]
  [[ "${output}" == *"2 Keys"* ]]
}

@test "F2b: Ausgabe kennzeichnet Teilsumme mit >= und 'ungenutzt'" {
  local fake; fake="$(_make_key_aware_curl)"
  export AIC_CURL="${fake}"
  # Nur K1 bekommt beim Lauf Metadaten (geht durch); K2 bleibt ungenutzt,
  # weil keine 429-Rotation ausgeloest wird.
  _TOOL_ENV="AIC_KEY429_LIST=" _run_tool --parallel 2 --api-key K1 --api-key K2 9.9.9.9
  [ "${status}" -eq 0 ]
  # Teilsumme: >= vorangestellt, ungenutzt ausgewiesen.
  [[ "${output}" == *">="* ]]
  [[ "${output}" == *"ungenutzt"* ]]
  [[ "${output}" == *"2 Keys"* ]]
}

@test "F2b: einzelner Key -> keine Aggregat-Kennzeichnung (Anzeige wie bisher)" {
  export AIC_MOCK_SCENARIO="clean"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool 9.9.9.9
  [ "${status}" -eq 0 ]
  [[ "${output}" != *"Keys"* ]]
  [[ "${output}" != *"ungenutzt"* ]]
  [[ "${output}" != *"Key 1/1"* ]]
}

@test "F2b: W1-Vorwarnung rechnet gegen aggregierte Verbleibend-Zahl" {
  # Zwei Keys mit je 2 remaining -> aggregiert 4. Bei 3 IPs reicht 4 -> KEINE W1.
  # (Ohne Aggregation wuerde der aktive Key mit remaining=2 < 3 faelschlich W1 werfen.)
  local fake; fake="$(_make_key_aware_curl)"
  export AIC_CURL="${fake}"
  local m1 m2
  m1="$(AIC_ACTIVE_KEY=K1 AIC_CACHE_DIR="${AIC_CACHE_DIR}" bash -c "source '${AIC_TOOL}'; AIC_ACTIVE_KEY='K1'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_meta_path")"
  m2="$(AIC_ACTIVE_KEY=K2 AIC_CACHE_DIR="${AIC_CACHE_DIR}" bash -c "source '${AIC_TOOL}'; AIC_ACTIVE_KEY='K2'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_meta_path")"
  printf 'remaining=2\nlimit=1000\nreset=1752278400\n' > "${m1}"
  printf 'remaining=2\nlimit=1000\nreset=1752278400\n' > "${m2}"
  _TOOL_ENV="AIC_KEY429_LIST=" _run_tool --parallel 2 --api-key K1 --api-key K2 9.9.9.9 8.8.8.8 1.1.1.1
  [ "${status}" -eq 0 ]
  # Aggregiert 4 >= 3 IPs -> keine Vorwarnung.
  [[ "${output}" != *"Vorwarnung"* ]]
}

# ============================================================================
# SEC — Security-Fixes (ANSI-Injection, Key-Übergabe, Config-Trim, Symlink)
# ============================================================================

# Feindlicher IP-abhaengiger Fake-curl: liefert Feldwerte mit ANSI-Escape (ESC),
# BEL und OSC-Sequenz in isp/domain — zum Testen der Sanitisierung. Die rohen
# Steuerbytes (\x1b, \x07) werden per printf '%b' in den JSON-String gebaut.
_make_hostile_curl() {
  local path="${AIC_TMP}/curl-hostile"
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
emit() {
  printf 'HTTP/1.1 200\r\n'
  printf 'X-RateLimit-Limit: 1000\r\n'
  printf 'x-ratelimit-remaining: 900\r\n'
  printf 'X-RATELIMIT-RESET: 1752278400\r\n'
  printf '\r\n'
}
[ -n "$header_file" ] && emit > "$header_file"
# isp traegt ANSI-Farbe (ESC[31m) + OSC-Titel (ESC]0;pwned BEL) — realistisch
# als GUELTIGES JSON kodiert (/ statt roher Bytes, so wie eine echte
# API angreiferkontrollierte Felder liefern wuerde). Der Body ist damit valides
# JSON; erst NACH dem Parsen entstehen die echten Steuerzeichen -> die
# Sanitisierung des Tools muss sie entfernen.
isp='\u001b[31mEVIL\u001b]0;pwned\u0007'
printf '%s' "{\"data\":{\"ipAddress\":\"${ip}\",\"abuseConfidenceScore\":0,\"countryCode\":\"US\",\"isp\":\"${isp}\",\"usageType\":\"DC\",\"domain\":\"evil.example\",\"isTor\":false,\"isWhitelisted\":false,\"totalReports\":0,\"numDistinctUsers\":0,\"lastReportedAt\":null}}"
[ -n "$write_out" ] && printf '%b' "${write_out//\%\{http_code\}/200}"
exit 0
SH
  chmod +x "${path}"
  printf '%s\n' "${path}"
}

@test "SEC1: Terminal-Ausgabe enthaelt keine ESC/BEL-Bytes (ANSI-Injection gefiltert)" {
  local fake; fake="$(_make_hostile_curl)"
  export AIC_CURL="${fake}"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --no-color 9.9.9.9
  [ "${status}" -eq 0 ]
  ! printf '%s' "${output}" | grep -q $'\x1b'
  ! printf '%s' "${output}" | grep -q $'\x07'
  # Der Nutztext bleibt erhalten (nur Steuerzeichen entfernt).
  [[ "${output}" == *"EVIL"* ]]
}

@test "SEC1: kein ESC/BEL in CSV/TXT/MD/JSON/JSONL-Export" {
  local fake; fake="$(_make_hostile_curl)"
  export AIC_CURL="${fake}"
  local fmt out
  for fmt in csv txt md json jsonl; do
    out="${AIC_TMP}/hostile.${fmt}"
    _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --no-color 9.9.9.9 \
      --output-file "${out}" --output-format "${fmt}"
    [ "${status}" -eq 0 ]
    [ -f "${out}" ]
    ! grep -q $'\x1b' "${out}"
    ! grep -q $'\x07' "${out}"
  done
}

@test "SEC1: auch Cache-Treffer werden sanitisiert (kein ESC/BEL nach Roundtrip)" {
  local fake; fake="$(_make_hostile_curl)"
  export AIC_CURL="${fake}"
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --no-color 9.9.9.9
  [ "${status}" -eq 0 ]
  _TOOL_ENV="ABUSEIPDB_API_KEY=TESTKEY" _run_tool --no-color 9.9.9.9
  [ "${status}" -eq 0 ]
  ! printf '%s' "${output}" | grep -q $'\x1b'
  ! printf '%s' "${output}" | grep -q $'\x07'
  [[ "${output}" == *"CACHED"* ]]
}

@test "SEC2: Key erscheint NICHT als Argument in der Mock-Logzeile" {
  export AIC_MOCK_SCENARIO="clean"
  run aic_api_check "9.9.9.9" "SUPERGEHEIM"
  [ "${status}" -eq 0 ]
  ! grep -q 'SUPERGEHEIM' "${AIC_MOCK_LOG}"
  [ "$(aic_mock_calls)" -eq 1 ]
}

@test "SEC2: Key wird via curl --config (stdin) uebergeben, Request funktioniert" {
  export AIC_MOCK_SCENARIO="clean"
  run aic_api_check "9.9.9.9" "TESTKEY"
  [ "${status}" -eq 0 ]
  echo "${output}" | jq -e '.status == "OK"'
  grep -q -- '--config' "${AIC_MOCK_LOG}"
}

@test "SEC3: aic_load_config trimmt CR am Wertende (api_key=ABC CR -> ABC)" {
  local cfg="${AIC_TMP}/crlf.config"
  printf 'api_key=ABC\r\n' > "${cfg}"
  run bash -c "source '${AIC_TOOL}'; aic_load_config '${cfg}'; printf '[%s]' \"\${AIC_CFG_api_key}\""
  [ "${status}" -eq 0 ]
  [ "${output}" == "[ABC]" ]
}

@test "SEC3: aic_load_config trimmt rechtsseitigen Whitespace" {
  local cfg="${AIC_TMP}/ws.config"
  printf 'api_key=ABC   \n' > "${cfg}"
  run bash -c "source '${AIC_TOOL}'; aic_load_config '${cfg}'; printf '[%s]' \"\${AIC_CFG_api_key}\""
  [ "${status}" -eq 0 ]
  [ "${output}" == "[ABC]" ]
}

@test "SEC4: aic_cache_read liest KEINEN Symlink (Miss, Zieldatei unangetastet)" {
  local secret="${AIC_TMP}/secret.txt"
  printf 'GEHEIM' > "${secret}"
  ln -s "${secret}" "${AIC_CACHE_DIR}/9.9.9.9.json"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_read '9.9.9.9'"
  [ "${status}" -ne 0 ]
  [[ "${output}" != *"GEHEIM"* ]]
  [ "$(cat "${secret}")" == "GEHEIM" ]
}

@test "SEC4: aic_cache_write ersetzt vorplatzierten Symlink (folgt ihm nicht)" {
  local secret="${AIC_TMP}/secret2.txt"
  printf 'GEHEIM2' > "${secret}"
  ln -s "${secret}" "${AIC_CACHE_DIR}/8.8.8.8.json"
  run bash -c "source '${AIC_TOOL}'; AIC_CACHE_DIR='${AIC_CACHE_DIR}'; aic_cache_write '8.8.8.8' '{\"data\":{\"x\":1}}'"
  [ "${status}" -eq 0 ]
  [ ! -L "${AIC_CACHE_DIR}/8.8.8.8.json" ]
  [ -f "${AIC_CACHE_DIR}/8.8.8.8.json" ]
  [ "$(cat "${secret}")" == "GEHEIM2" ]
}

# ============================================================================
# F3 — data/-Unterordner + Migration
# ============================================================================

@test "F3: Default-Cache liegt unter <tooldir>/data/cache (BASH_SOURCE)" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_CACHE_DIR=''; AIC_CFG_cache_dir=''; aic_cache_resolve_dir"
  [ "${status}" -eq 0 ]
  [[ "${output}" == "${AIC_ROOT_DIR}/data/cache" ]]
}

@test "F3: --cache-dir uebersteuert weiterhin direkt" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_CACHE_DIR='/flag/dir'; AIC_CFG_cache_dir='/config/dir'; aic_cache_resolve_dir"
  [ "${status}" -eq 0 ]
  [ "${output}" == "/flag/dir" ]
}

@test "F3: Config cache_dir uebersteuert den Default" {
  run bash -c "source '${AIC_TOOL}'; AIC_OPT_CACHE_DIR=''; AIC_CFG_cache_dir='/config/dir'; aic_cache_resolve_dir"
  [ "${status}" -eq 0 ]
  [ "${output}" == "/config/dir" ]
}

@test "F3: Migration verschiebt altes <tooldir>/cache nach data/cache" {
  # Simulierte Tool-Installation in einem Temp-Verzeichnis: altes cache/ da,
  # data/cache noch nicht. aic_migrate_cache_layout verschiebt best effort.
  local tooldir="${AIC_TMP}/tool"
  mkdir -p "${tooldir}/cache"
  printf '{"x":1}' > "${tooldir}/cache/9.9.9.9.json"
  run bash -c "source '${AIC_TOOL}'; AIC_MIGRATE_TOOLDIR='${tooldir}'; aic_migrate_cache_layout"
  [ "${status}" -eq 0 ]
  # Datei ist jetzt unter data/cache, altes cache/ weg.
  [ -f "${tooldir}/data/cache/9.9.9.9.json" ]
  [ ! -d "${tooldir}/cache" ] || [ -z "$(find "${tooldir}/cache" -maxdepth 1 -name '*.json' 2>/dev/null)" ]
}

@test "F3: Migration ist idempotent, wenn data/cache bereits existiert" {
  local tooldir="${AIC_TMP}/tool2"
  mkdir -p "${tooldir}/cache"
  mkdir -p "${tooldir}/data/cache"
  printf '{"x":1}' > "${tooldir}/cache/1.1.1.1.json"
  printf '{"x":2}' > "${tooldir}/data/cache/2.2.2.2.json"
  # data/cache existiert schon -> KEINE Migration (kein Ueberschreiben).
  run bash -c "source '${AIC_TOOL}'; AIC_MIGRATE_TOOLDIR='${tooldir}'; aic_migrate_cache_layout"
  [ "${status}" -eq 0 ]
  # Der bestehende data/cache-Eintrag bleibt unangetastet.
  [ -f "${tooldir}/data/cache/2.2.2.2.json" ]
}

@test "F3: Migration gibt einmaligen stderr-Hinweis aus" {
  local tooldir="${AIC_TMP}/tool3"
  mkdir -p "${tooldir}/cache"
  printf '{"x":1}' > "${tooldir}/cache/9.9.9.9.json"
  run bash -c "source '${AIC_TOOL}'; AIC_MIGRATE_TOOLDIR='${tooldir}'; aic_migrate_cache_layout 2>&1"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"data/cache"* ]] || [[ "${output}" == *"verschoben"* ]] || [[ "${output}" == *"Migration"* ]]
}
