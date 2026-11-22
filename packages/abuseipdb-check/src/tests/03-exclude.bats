#!/usr/bin/env bats
# 03-exclude.bats — US-004: Whitelist/Exclude IP+CIDR.

load helpers

setup() { aic_setup_env; aic_source_tool; }
teardown() { aic_teardown_env; }

# --------------------------------------------------------------- aic_in_cidr (IPv4)
@test "aic_in_cidr IPv4: /8 enthaelt passende Adresse" {
  aic_in_cidr "10.5.6.7" "10.0.0.0/8"
  run aic_in_cidr "11.0.0.1" "10.0.0.0/8"; [ "${status}" -ne 0 ]
}

@test "aic_in_cidr IPv4: /24" {
  aic_in_cidr "192.168.1.55" "192.168.1.0/24"
  run aic_in_cidr "192.168.2.1" "192.168.1.0/24"; [ "${status}" -ne 0 ]
}

@test "aic_in_cidr IPv4: /32 exakter Treffer" {
  aic_in_cidr "9.9.9.9" "9.9.9.9/32"
  run aic_in_cidr "9.9.9.8" "9.9.9.9/32"; [ "${status}" -ne 0 ]
}

@test "aic_in_cidr IPv4: /0 matcht alles" {
  aic_in_cidr "1.2.3.4" "0.0.0.0/0"
  aic_in_cidr "255.255.255.255" "0.0.0.0/0"
}

@test "aic_in_cidr IPv4: blanke IP ohne / als /32 behandeln" {
  aic_in_cidr "9.9.9.9" "9.9.9.9"
  run aic_in_cidr "9.9.9.8" "9.9.9.9"; [ "${status}" -ne 0 ]
}

# --------------------------------------------------------------- aic_in_cidr (IPv6)
@test "aic_in_cidr IPv6: komprimiertes 2001:db8::1 matcht 2001:db8::/32" {
  aic_in_cidr "2001:db8::1" "2001:db8::/32"
  aic_in_cidr "2001:db8:aaaa:bbbb::1" "2001:db8::/32"
}

@test "aic_in_cidr IPv6: ausserhalb /32 matcht nicht" {
  run aic_in_cidr "2001:db9::1" "2001:db8::/32"; [ "${status}" -ne 0 ]
}

@test "aic_in_cidr IPv6: /128 exakter Treffer, case-insensitiv" {
  aic_in_cidr "2001:DB8::1" "2001:db8::1/128"
  run aic_in_cidr "2001:db8::2" "2001:db8::1/128"; [ "${status}" -ne 0 ]
}

@test "aic_in_cidr IPv6: /7 fc00 ULA-Bereich" {
  aic_in_cidr "fd12:3456::1" "fc00::/7"
  aic_in_cidr "fc00::1" "fc00::/7"
  run aic_in_cidr "fe80::1" "fc00::/7"; [ "${status}" -ne 0 ]
}

# --------------------------------------------------------------- aic_is_excluded
@test "aic_is_excluded matcht per --exclude Einzel-IP" {
  AIC_EXCLUDES=("9.9.9.9")
  aic_is_excluded "9.9.9.9"
  run aic_is_excluded "8.8.8.8"; [ "${status}" -ne 0 ]
}

@test "aic_is_excluded matcht per --exclude CIDR" {
  AIC_EXCLUDES=("192.168.0.0/16" "2001:db8::/32")
  aic_is_excluded "192.168.5.5"
  aic_is_excluded "2001:db8::dead"
  run aic_is_excluded "9.9.9.9"; [ "${status}" -ne 0 ]
}

@test "aic_load_exclude_file liest Datei mit Kommentaren" {
  local f="${AIC_TMP}/excl.txt"
  cat > "${f}" <<'EOF'
# interne Netze
10.0.0.0/8
# einzelne IP
9.9.9.9

2001:db8::/32
EOF
  AIC_EXCLUDES=()
  aic_load_exclude_file "${f}"
  # nach dem Laden muessen die Eintraege matchen
  aic_is_excluded "10.1.2.3"
  aic_is_excluded "9.9.9.9"
  aic_is_excluded "2001:db8::5"
  run aic_is_excluded "8.8.8.8"; [ "${status}" -ne 0 ]
}

# ------------------------------------------------------------- CLI-Integration
@test "--exclude ist wiederholbar und fuehrt zu WHITELIST-Skip" {
  local skipfile="${AIC_TMP}/skips.txt"
  # aic_filter_excluded liest IPs von stdin, gibt nicht-ausgeschlossene aus,
  # schreibt ausgeschlossene mit Grund WHITELIST in AIC_SKIP_FILE.
  run bash -c "source '${AIC_TOOL}'; AIC_EXCLUDES=('9.9.9.9' '10.0.0.0/8'); printf '9.9.9.9\n10.1.1.1\n8.8.8.8\n' | AIC_SKIP_FILE='${skipfile}' aic_filter_excluded"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"8.8.8.8"* ]]
  [[ "${output}" != *"9.9.9.9"* ]]
  [[ "${output}" != *"10.1.1.1"* ]]
  grep -q 'WHITELIST' "${skipfile}"
  grep -q '9.9.9.9' "${skipfile}"
  grep -q '10.1.1.1' "${skipfile}"
}

@test "--exclude-file wirkt ueber aic_filter_excluded" {
  local f="${AIC_TMP}/excl2.txt"
  printf '192.168.0.0/16\n' > "${f}"
  local skipfile="${AIC_TMP}/skips2.txt"
  run bash -c "source '${AIC_TOOL}'; AIC_EXCLUDES=(); aic_load_exclude_file '${f}'; printf '192.168.1.1\n9.9.9.9\n' | AIC_SKIP_FILE='${skipfile}' aic_filter_excluded"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"9.9.9.9"* ]]
  [[ "${output}" != *"192.168.1.1"* ]]
  grep -q 'WHITELIST' "${skipfile}"
}
