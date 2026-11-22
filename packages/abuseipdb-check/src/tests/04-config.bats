#!/usr/bin/env bats
# 04-config.bats — US-005: Konfiguration & Key-Aufloesung.
#
# Getestet wird die config-Sektion: zeilenweises Parsen mit Key-Whitelist
# (niemals source/eval), Prioritaet --api-key > ABUSEIPDB_API_KEY > Config,
# interaktive Ersteinrichtung (TTY) vs. Exit 2 (nicht-TTY) bei fehlendem Key,
# Warnung bei world-readable Key-Quellen, whitelist-Wert fliesst in die
# Exclude-Logik.

load helpers

setup() { aic_setup_env; aic_source_tool; }
teardown() { aic_teardown_env; }

# Hilfsfunktion: schreibt eine Config-Datei an den Standardpfad.
_write_config() {
  local content="${1}"
  local cfg="${HOME}/.config/abuseipdb/config"
  mkdir -p "$(dirname "${cfg}")"
  printf '%s\n' "${content}" > "${cfg}"
  printf '%s\n' "${cfg}"
}

# --------------------------------------------------------------- aic_load_config Parsing
@test "aic_load_config parst key=value in Config-Variablen" {
  local cfg
  cfg="$(_write_config 'api_key=ABC123
ttl_hours=12
max_age_in_days=30
threshold_critical=80
threshold_suspect=20
cache_dir=/data/cache
whitelist=9.9.9.9,10.0.0.0/8')"
  aic_load_config "${cfg}"
  [ "${AIC_CFG_api_key}" == "ABC123" ]
  [ "${AIC_CFG_ttl_hours}" == "12" ]
  [ "${AIC_CFG_max_age_in_days}" == "30" ]
  [ "${AIC_CFG_threshold_critical}" == "80" ]
  [ "${AIC_CFG_threshold_suspect}" == "20" ]
  [ "${AIC_CFG_cache_dir}" == "/data/cache" ]
  [ "${AIC_CFG_whitelist}" == "9.9.9.9,10.0.0.0/8" ]
}

@test "aic_load_config ignoriert Kommentare und Leerzeilen" {
  local cfg
  cfg="$(_write_config '# das ist ein Kommentar
api_key=KEY42

# noch einer
ttl_hours=6')"
  aic_load_config "${cfg}"
  [ "${AIC_CFG_api_key}" == "KEY42" ]
  [ "${AIC_CFG_ttl_hours}" == "6" ]
}

@test "aic_load_config ignoriert unbekannte Keys (Whitelist)" {
  local cfg
  cfg="$(_write_config 'api_key=KEY
evil_key=boom
PATH=/pwned')"
  aic_load_config "${cfg}"
  [ "${AIC_CFG_api_key}" == "KEY" ]
  # unbekannte Keys duerfen keine Variable/Umgebung setzen
  [ -z "${AIC_CFG_evil_key:-}" ]
  [[ "${PATH}" != "/pwned" ]]
}

@test "aic_load_config toleriert = im Wert (nur am ersten = splitten)" {
  local cfg
  cfg="$(_write_config 'api_key=abc=def=ghi')"
  aic_load_config "${cfg}"
  [ "${AIC_CFG_api_key}" == "abc=def=ghi" ]
}

@test "aic_load_config bei fehlender Datei: kein Fehler, keine Werte" {
  aic_load_config "${AIC_TMP}/nichtda.config"
  [ -z "${AIC_CFG_api_key:-}" ]
}

# --------------------------------------------------------------- Code-Injection-Schutz
@test "aic_load_config fuehrt Command-Substitution NICHT aus (kein source/eval)" {
  rm -f /tmp/pwned_aic_test
  local cfg
  cfg="$(_write_config 'api_key=$(touch /tmp/pwned_aic_test)')"
  aic_load_config "${cfg}"
  # Die Datei darf NICHT existieren — nichts wurde ausgefuehrt.
  [ ! -e /tmp/pwned_aic_test ]
  # Der Wert wird literal uebernommen.
  [ "${AIC_CFG_api_key}" == '$(touch /tmp/pwned_aic_test)' ]
}

@test "aic_load_config fuehrt Backtick-Substitution NICHT aus" {
  rm -f /tmp/pwned_aic_backtick
  local cfg
  cfg="$(_write_config 'api_key=`touch /tmp/pwned_aic_backtick`')"
  aic_load_config "${cfg}"
  [ ! -e /tmp/pwned_aic_backtick ]
}

# --------------------------------------------------------------- Key-Aufloesung (Prioritaet)
@test "aic_resolve_api_key: --api-key gewinnt vor Env und Config" {
  local cfg
  cfg="$(_write_config 'api_key=FROM_CONFIG')"
  aic_load_config "${cfg}"
  AIC_OPT_API_KEY="FROM_FLAG"
  run bash -c "source '${AIC_TOOL}'; AIC_CFG_api_key='FROM_CONFIG'; AIC_OPT_API_KEY='FROM_FLAG'; ABUSEIPDB_API_KEY='FROM_ENV'; aic_resolve_api_key"
  [ "${status}" -eq 0 ]
  [ "${output}" == "FROM_FLAG" ]
}

@test "aic_resolve_api_key: Env gewinnt vor Config (kein Flag)" {
  run bash -c "source '${AIC_TOOL}'; AIC_CFG_api_key='FROM_CONFIG'; AIC_OPT_API_KEY=''; ABUSEIPDB_API_KEY='FROM_ENV'; aic_resolve_api_key"
  [ "${status}" -eq 0 ]
  [ "${output}" == "FROM_ENV" ]
}

@test "aic_resolve_api_key: Config als letzte Quelle" {
  run bash -c "source '${AIC_TOOL}'; AIC_CFG_api_key='FROM_CONFIG'; AIC_OPT_API_KEY=''; unset ABUSEIPDB_API_KEY; aic_resolve_api_key"
  [ "${status}" -eq 0 ]
  [ "${output}" == "FROM_CONFIG" ]
}

@test "aic_resolve_api_key: kein Key vorhanden -> Rueckgabe != 0, leere Ausgabe" {
  run bash -c "source '${AIC_TOOL}'; AIC_CFG_api_key=''; AIC_OPT_API_KEY=''; unset ABUSEIPDB_API_KEY; aic_resolve_api_key"
  [ "${status}" -ne 0 ]
  [ -z "${output}" ]
}

# --------------------------------------------------------------- Ohne Key + nicht-TTY -> Exit 2
@test "Ohne Key und ohne TTY: Exit 2 mit Hinweis auf die drei Quellen" {
  # aic_ensure_api_key entscheidet: nicht-TTY -> Fehlermeldung + Return 2.
  run bash -c "source '${AIC_TOOL}'; AIC_CFG_api_key=''; AIC_OPT_API_KEY=''; unset ABUSEIPDB_API_KEY; aic_ensure_api_key < /dev/null"
  [ "${status}" -eq 2 ]
  # Hinweis nennt alle drei Quellen.
  [[ "${output}" == *"--api-key"* ]]
  [[ "${output}" == *"ABUSEIPDB_API_KEY"* ]]
  [[ "${output}" == *"config"* ]]
}

# --------------------------------------------------------------- Interaktive Ersteinrichtung (TTY)
@test "Ersteinrichtung schreibt Config mit chmod 600 (nicht-interaktiv geprueft)" {
  # aic_config_init nimmt Key (und optional TTL) und schreibt die Config.
  # Wir rufen es direkt mit Argumenten auf (statt echtem TTY-Prompt), so
  # dass die Datei-Anlage und die Rechte deterministisch pruefbar sind.
  local cfg="${HOME}/.config/abuseipdb/config"
  rm -f "${cfg}"
  run bash -c "source '${AIC_TOOL}'; aic_config_write '${cfg}' 'MYKEY' '48'"
  [ "${status}" -eq 0 ]
  [ -f "${cfg}" ]
  grep -q '^api_key=MYKEY$' "${cfg}"
  grep -q '^ttl_hours=48$' "${cfg}"
  # chmod 600
  [ "$(stat -c '%a' "${cfg}")" == "600" ]
}

@test "Ersteinrichtung legt Konfig-Verzeichnis an falls fehlend" {
  rm -rf "${HOME}/.config/abuseipdb"
  local cfg="${HOME}/.config/abuseipdb/config"
  run bash -c "source '${AIC_TOOL}'; aic_config_write '${cfg}' 'MYKEY' ''"
  [ "${status}" -eq 0 ]
  [ -d "${HOME}/.config/abuseipdb" ]
  [ -f "${cfg}" ]
  grep -q '^api_key=MYKEY$' "${cfg}"
}

@test "Interaktive Ersteinrichtung via aic_config_init liest Key von stdin" {
  # Simuliert TTY-Ersteinrichtung: aic_config_init liest den Key (und leere
  # TTL-Antwort = Default) und schreibt die Config. Bei nicht-TTY-Aufruf mit
  # AIC_ASSUME_TTY=1 wird der interaktive Zweig erzwungen.
  local cfg="${HOME}/.config/abuseipdb/config"
  rm -f "${cfg}"
  run bash -c "source '${AIC_TOOL}'; printf 'INTERKEY\n\n' | AIC_ASSUME_TTY=1 aic_config_init '${cfg}'"
  [ "${status}" -eq 0 ]
  [ -f "${cfg}" ]
  grep -q '^api_key=INTERKEY$' "${cfg}"
  [ "$(stat -c '%a' "${cfg}")" == "600" ]
}

@test "aic_config_init nimmt mehrere Keys fuer die Rotation entgegen (api_keys=)" {
  local cfg="${HOME}/.config/abuseipdb/config"
  rm -f "${cfg}"
  # Antworten: Pflicht-Key, zwei weitere Keys, Ende der Key-Schleife, TTL 14.
  run bash -c "source '${AIC_TOOL}'; printf 'K1\nK2\nK3\n\n14\n' | AIC_ASSUME_TTY=1 aic_config_init '${cfg}'"
  [ "${status}" -eq 0 ]
  grep -q '^api_key=K1$' "${cfg}"
  grep -q '^api_keys=K2,K3$' "${cfg}"
  grep -q '^ttl=14d$' "${cfg}"
  [ "$(stat -c '%a' "${cfg}")" == "600" ]
  # Die Aufloesung liefert alle drei Keys in Reihenfolge.
  run bash -c "source '${AIC_TOOL}'; AIC_CONFIG_PATH='${cfg}'; aic_load_config '${cfg}'; aic_resolve_api_keys"
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" == "K1" ]
  [ "${lines[1]}" == "K2" ]
  [ "${lines[2]}" == "K3" ]
}

# --------------------------------------------------------------- Warnung world-readable
@test "Warnung bei world-readable Config-Datei" {
  local cfg
  cfg="$(_write_config 'api_key=SECRET')"
  chmod 644 "${cfg}"
  run bash -c "source '${AIC_TOOL}'; aic_warn_insecure_config '${cfg}'"
  [ "${status}" -eq 0 ]
  # Warnung geht nach stderr (run mischt stdout+stderr).
  [[ "${output}" == *"world-readable"* ]] || [[ "${output}" == *"lesbar"* ]] || [[ "${output}" == *"Rechte"* ]]
}

@test "Keine Warnung bei chmod 600 Config" {
  local cfg
  cfg="$(_write_config 'api_key=SECRET')"
  chmod 600 "${cfg}"
  run bash -c "source '${AIC_TOOL}'; aic_warn_insecure_config '${cfg}'"
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}

# --------------------------------------------------------------- whitelist -> Exclude-Logik
@test "Config-whitelist fliesst in AIC_EXCLUDES ein" {
  # aic_apply_config_whitelist haengt die kommaseparierten Eintraege an
  # AIC_EXCLUDES an, so dass aic_is_excluded sie beruecksichtigt.
  run bash -c "source '${AIC_TOOL}'; AIC_EXCLUDES=(); AIC_CFG_whitelist='9.9.9.9,10.0.0.0/8,2001:db8::/32'; aic_apply_config_whitelist; for e in \"\${AIC_EXCLUDES[@]}\"; do echo \"\$e\"; done"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"9.9.9.9"* ]]
  [[ "${output}" == *"10.0.0.0/8"* ]]
  [[ "${output}" == *"2001:db8::/32"* ]]
}

@test "Config-whitelist-Eintraege wirken in aic_is_excluded" {
  run bash -c "source '${AIC_TOOL}'; AIC_EXCLUDES=(); AIC_CFG_whitelist='10.0.0.0/8'; aic_apply_config_whitelist; aic_is_excluded '10.1.2.3' && echo EXCLUDED; aic_is_excluded '8.8.8.8' || echo NOTEXCLUDED"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"EXCLUDED"* ]]
  [[ "${output}" == *"NOTEXCLUDED"* ]]
}

@test "Leere Config-whitelist fuegt nichts hinzu" {
  run bash -c "source '${AIC_TOOL}'; AIC_EXCLUDES=(); AIC_CFG_whitelist=''; aic_apply_config_whitelist; echo \"count=\${#AIC_EXCLUDES[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"count=0"* ]]
}
