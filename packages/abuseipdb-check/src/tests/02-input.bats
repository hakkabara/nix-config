#!/usr/bin/env bats
# 02-input.bats — US-003: Eingabewege & Dedupe.

load helpers

setup() { aic_setup_env; aic_source_tool; }
teardown() { aic_teardown_env; }

# aic_read_inputs schreibt die (deduplizierten) IPs auf stdout, eine pro Zeile.
# Steuerung ueber globale Arrays/Variablen, die das Argument-Parsing setzt:
#   AIC_INPUT_FILE, AIC_POSITIONAL (Array), AIC_EXTRACT (0/1), stdin.
# Fuer Unit-Tests rufen wir aic_read_inputs mit vorbereiteten Variablen auf.

@test "aic_read_inputs liest Positionsargumente" {
  AIC_POSITIONAL=("1.2.3.4" "9.9.9.9")
  AIC_INPUT_FILE=""
  AIC_EXTRACT=0
  run aic_read_inputs < /dev/null
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1.2.3.4"* ]]
  [[ "${output}" == *"9.9.9.9"* ]]
}

@test "aic_read_inputs liest -f Datei, ignoriert Kommentare und Leerzeilen" {
  local f="${AIC_TMP}/ips.txt"
  cat > "${f}" <<'EOF'
# Kommentar
1.2.3.4

  9.9.9.9
# noch ein Kommentar
2001:db8::1
EOF
  AIC_POSITIONAL=()
  AIC_INPUT_FILE="${f}"
  AIC_EXTRACT=0
  run aic_read_inputs < /dev/null
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1.2.3.4"* ]]
  [[ "${output}" == *"9.9.9.9"* ]]
  [[ "${output}" == *"2001:db8::1"* ]]
  [[ "${output}" != *"Kommentar"* ]]
}

@test "aic_read_inputs liest stdin-Pipe (kein TTY)" {
  AIC_POSITIONAL=()
  AIC_INPUT_FILE=""
  AIC_EXTRACT=0
  run bash -c "source '${AIC_TOOL}'; AIC_POSITIONAL=(); AIC_INPUT_FILE=''; AIC_EXTRACT=0; printf '1.2.3.4\n9.9.9.9\n' | aic_read_inputs"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1.2.3.4"* ]]
  [[ "${output}" == *"9.9.9.9"* ]]
}

@test "aic_read_inputs --extract fischt IPs aus Fliesstext" {
  AIC_POSITIONAL=()
  AIC_INPUT_FILE=""
  AIC_EXTRACT=1
  run bash -c "source '${AIC_TOOL}'; AIC_POSITIONAL=(); AIC_INPUT_FILE=''; AIC_EXTRACT=1; printf 'Angriff von 45.155.205.233 auf Port 22, auch 2001:db8::1 gesehen.\n' | aic_read_inputs"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"45.155.205.233"* ]]
  [[ "${output}" == *"2001:db8::1"* ]]
}

@test "aic_read_inputs entschaerft uniq-c-Zeilen auch ohne --extract" {
  local f="${AIC_TMP}/uniqc.txt"
  printf '      5 61.80.67.162\n      2 127.0.0.1\n      1 kein-treffer hier\n' > "${f}"
  AIC_POSITIONAL=()
  AIC_INPUT_FILE="${f}"
  AIC_EXTRACT=0
  run aic_read_inputs < /dev/null
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"61.80.67.162"* ]]
  [[ "${output}" == *"127.0.0.1"* ]]
  # Der uniq-c-Zaehler darf nicht als eigener Kandidat auftauchen.
  ! printf '%s\n' "${output}" | grep -qx '5'
  # Zeile ohne IP-Token bleibt als ganzer (spaeter INVALID) Kandidat erhalten.
  [[ "${output}" == *"kein-treffer hier"* ]]
}

@test "aic_read_inputs zerlegt Zeilen mit mehreren IPs ohne --extract" {
  run bash -c "source '${AIC_TOOL}'; AIC_POSITIONAL=(); AIC_INPUT_FILE=''; AIC_EXTRACT=0; printf '1.2.3.4 9.9.9.9\r\n' | aic_read_inputs"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1.2.3.4"* ]]
  [[ "${output}" == *"9.9.9.9"* ]]
}

@test "aic_read_inputs kombiniert mehrere Quellen (Datei + Argumente)" {
  local f="${AIC_TMP}/ips2.txt"
  printf '1.2.3.4\n' > "${f}"
  run bash -c "source '${AIC_TOOL}'; AIC_POSITIONAL=('9.9.9.9'); AIC_INPUT_FILE='${f}'; AIC_EXTRACT=0; aic_read_inputs < /dev/null"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1.2.3.4"* ]]
  [[ "${output}" == *"9.9.9.9"* ]]
}

# --------------------------------------------------------------------- Dedupe
@test "aic_dedupe entfernt exakte Duplikate und zaehlt sie" {
  # aic_dedupe liest IPs von stdin, gibt eindeutige auf stdout,
  # Anzahl der Duplikate auf AIC_DUP_COUNT (globale Variable) oder fd.
  run bash -c "source '${AIC_TOOL}'; printf '1.2.3.4\n1.2.3.4\n9.9.9.9\n' | aic_dedupe"
  [ "${status}" -eq 0 ]
  # 1.2.3.4 nur einmal
  [ "$(printf '%s\n' "${output}" | grep -c '^1\.2\.3\.4$')" -eq 1 ]
  [ "$(printf '%s\n' "${output}" | grep -c '^9\.9\.9\.9$')" -eq 1 ]
}

@test "aic_dedupe normalisiert IPv6 case-insensitiv" {
  run bash -c "source '${AIC_TOOL}'; printf '2001:DB8::1\n2001:db8::1\n' | aic_dedupe"
  [ "${status}" -eq 0 ]
  # nur ein Eintrag (case-insensitiv gleich)
  local count
  count="$(printf '%s\n' "${output}" | grep -ci '2001:db8::1')"
  [ "${count}" -eq 1 ]
}

@test "aic_dedupe meldet Duplikate fuer die Skip-Sektion (Grund DUPLIKAT)" {
  # Duplikate landen als 'ip\tDUPLIKAT' im Skip-Kanal (fd 3 oder Datei).
  local dupfile="${AIC_TMP}/dups.txt"
  run bash -c "source '${AIC_TOOL}'; printf '1.2.3.4\n1.2.3.4\n' | AIC_SKIP_FILE='${dupfile}' aic_dedupe > /dev/null"
  [ "${status}" -eq 0 ]
  [ -f "${dupfile}" ]
  grep -q 'DUPLIKAT' "${dupfile}"
  grep -q '1.2.3.4' "${dupfile}"
}
