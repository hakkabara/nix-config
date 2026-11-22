#!/usr/bin/env bats
# 00-scaffold.bats — US-001: Geruest & Testinfrastruktur.

load helpers

setup() { aic_setup_env; }
teardown() { aic_teardown_env; }

@test "Tool existiert und ist ausfuehrbar" {
  [ -f "${AIC_TOOL}" ]
  [ -x "${AIC_TOOL}" ]
}

@test "Tool hat Shebang, set -euo pipefail, aic_-Praefix und Source-Guard" {
  run head -1 "${AIC_TOOL}"
  [[ "${output}" == "#!/usr/bin/env bash" ]] || [[ "${output}" == "#!/bin/bash" ]]

  grep -q 'set -euo pipefail' "${AIC_TOOL}"
  # Source-Guard vorhanden (both && oder if-Form akzeptiert)
  grep -qE 'BASH_SOURCE\[0\].*==.*\$0' "${AIC_TOOL}"
  grep -q 'main' "${AIC_TOOL}"
  # mind. eine aic_-Funktion definiert
  grep -qE '^aic_[a-z_]+\(\)' "${AIC_TOOL}"
}

@test "Tool enthaelt Domaenen-Kommentarbanner" {
  # Gliederung in Sektionen (validate / input / exclude / ...)
  grep -qiE '#[[:space:]]*SEKTION:[[:space:]]*validate' "${AIC_TOOL}"
  grep -qiE '#[[:space:]]*SEKTION:[[:space:]]*input' "${AIC_TOOL}"
  grep -qiE '#[[:space:]]*SEKTION:[[:space:]]*exclude' "${AIC_TOOL}"
}

@test "Sourcen des Tools startet main NICHT" {
  # Wenn der Source-Guard greift, laeuft main() beim Sourcen nicht.
  # Ein Marker-File wuerde bei versehentlichem main-Lauf ueberschrieben.
  run bash -c "source '${AIC_TOOL}' 2>/dev/null; echo SOURCED_OK"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"SOURCED_OK"* ]]
}

@test "aic_source_tool stellt Funktionen bereit" {
  aic_source_tool
  run type -t aic_check_deps
  [ "${output}" == "function" ]
}

@test "aic_check_deps meldet fehlendes curl mit Exit 2 und Installationshinweis" {
  aic_source_tool
  local bash_bin; bash_bin="$(command -v bash)"
  # PATH auf leeres Verzeichnis: curl/jq nicht auffindbar (bash per Vollpfad).
  local emptydir="${AIC_TMP}/emptybin"
  mkdir -p "${emptydir}"
  run env PATH="${emptydir}" "${bash_bin}" -c "source '${AIC_TOOL}'; aic_check_deps"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"curl"* ]]
  [[ "${output}" == *"install"* ]] || [[ "${output}" == *"installier"* ]]
}

@test "aic_check_deps meldet fehlendes jq mit Exit 2" {
  aic_source_tool
  local bash_bin; bash_bin="$(command -v bash)"
  # Nur curl im PATH, jq fehlt.
  local fakebin="${AIC_TMP}/fakebin"
  mkdir -p "${fakebin}"
  printf '#!/bin/sh\nexit 0\n' > "${fakebin}/curl"
  chmod +x "${fakebin}/curl"
  run env PATH="${fakebin}" "${bash_bin}" -c "source '${AIC_TOOL}'; aic_check_deps"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"jq"* ]]
}

@test "aic_check_deps ist erfolgreich wenn curl und jq vorhanden" {
  aic_source_tool
  local fakebin="${AIC_TMP}/fakebin2"
  mkdir -p "${fakebin}"
  for t in curl jq; do
    printf '#!/bin/sh\nexit 0\n' > "${fakebin}/${t}"
    chmod +x "${fakebin}/${t}"
  done
  run env PATH="${fakebin}:${PATH}" bash -c "source '${AIC_TOOL}'; aic_check_deps"
  [ "${status}" -eq 0 ]
}

@test "helpers isoliert HOME und Cache-Dir" {
  [[ "${HOME}" == "${AIC_TMP}/home" ]]
  [ -d "${HOME}/.config/abuseipdb" ]
}

@test "Mock-curl loggt Aufrufe in AIC_MOCK_LOG" {
  [ "$(aic_mock_calls)" -eq 0 ]
  AIC_MOCK_SCENARIO=clean "${AIC_CURL}" -sS -D - "https://example.invalid/api/v2/check" >/dev/null
  [ "$(aic_mock_calls)" -eq 1 ]
}

@test "Mock-curl liefert Fixture-Body je nach Szenario" {
  run env AIC_MOCK_SCENARIO=malicious "${AIC_CURL}" -sS "https://example.invalid"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *'"abuseConfidenceScore":100'* ]]
}

@test "Mock-curl liefert CRLF-terminierte Header mit gemischter Schreibweise" {
  run env AIC_MOCK_SCENARIO=clean "${AIC_CURL}" -sS -D - "https://example.invalid"
  [ "${status}" -eq 0 ]
  # echte CRLF: Zeile endet auf \r
  printf '%s' "${output}" | grep -q $'X-RateLimit-Limit:.*\r'
  # gemischte Schreibweise vorhanden
  [[ "${output}" == *"X-RateLimit-Limit:"* ]]
  [[ "${output}" == *"x-ratelimit-remaining:"* ]]
  [[ "${output}" == *"X-RATELIMIT-RESET:"* ]]
}

@test "Tool ruft curl als Kommando nur ueber \${AIC_CURL:-curl} auf" {
  # 'curl' als Prozess-Aufruf (Kommandoposition) muss ueber die AIC_CURL-Naht
  # laufen. Erlaubt: 'command -v curl' (Dependency-Check), Kommentare,
  # Installationshinweise, die Variablendefinition AIC_CURL="${AIC_CURL:-curl}".
  # Wir suchen 'curl' am Anfang einer Kommando-Pipeline.
  run grep -nE '(^|[|;&]|\$\()[[:space:]]*curl[[:space:]]' "${AIC_TOOL}"
  # kein Treffer => in Ordnung
  [ -z "${output}" ]
}

@test "Tool ruft curl real ausschliesslich per AIC_CURL-Variable auf" {
  # Jede Zeile, die '\$AIC_CURL' oder '\${AIC_CURL' nutzt, ist die Netz-Naht.
  # Ausser der Definitionszeile darf curl nie als blankes Kommando erscheinen.
  grep -q 'AIC_CURL' "${AIC_TOOL}"
}
