# tests/helpers.bash — gemeinsames Test-Setup fuer alle bats-Suiten.
#
# Sourct das Tool `abuseipdb-check` OHNE main auszufuehren (Source-Guard),
# stellt eine isolierte TMP-Umgebung bereit (eigenes HOME, Cache-Dir, Mock-Log)
# und verdrahtet den Mock-curl ueber AIC_CURL.

# Projektwurzel = ein Verzeichnis ueber tests/
AIC_TEST_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
AIC_ROOT_DIR="$( cd "${AIC_TEST_DIR}/.." && pwd )"
export AIC_TEST_DIR AIC_ROOT_DIR

# Pfad zum zu testenden Tool.
AIC_TOOL="${AIC_ROOT_DIR}/abuseipdb-check"
export AIC_TOOL

# aic_setup_env: isolierte Umgebung pro Test.
# Legt ein temporaeres HOME, Cache-Verzeichnis und Mock-Log an und exportiert
# AIC_CURL auf den Mock. Wird typischerweise in setup() jeder Suite aufgerufen.
aic_setup_env() {
  AIC_TMP="$(mktemp -d "${BATS_TMPDIR:-/tmp}/aic.XXXXXX")"
  export AIC_TMP
  export HOME="${AIC_TMP}/home"
  mkdir -p "${HOME}/.config/abuseipdb"

  export AIC_CACHE_DIR="${AIC_TMP}/cache"
  export AIC_CURL="${AIC_TEST_DIR}/mocks/curl"
  export AIC_MOCK_LOG="${AIC_TMP}/mock-curl.log"
  export AIC_MOCK_FIXTURES="${AIC_TEST_DIR}/mocks/fixtures"
  : > "${AIC_MOCK_LOG}"

  # Standard-Szenario fuer Tests, die keinen echten Score brauchen.
  export AIC_MOCK_SCENARIO="clean"
}

# aic_teardown_env: raeumt die TMP-Umgebung wieder auf.
aic_teardown_env() {
  [ -n "${AIC_TMP:-}" ] && [ -d "${AIC_TMP}" ] && rm -rf "${AIC_TMP}"
  return 0
}

# aic_source_tool: sourct das Tool, ohne main() zu starten.
# Der Source-Guard im Tool ([[ "${BASH_SOURCE[0]}" == "$0" ]]) verhindert,
# dass main beim Sourcen laeuft. Funktionen stehen danach direkt zur Verfuegung.
aic_source_tool() {
  # shellcheck disable=SC1090
  source "${AIC_TOOL}"
}

# aic_mock_calls: Anzahl der protokollierten Mock-curl-Aufrufe (CALL-Zeilen).
aic_mock_calls() {
  if [ -f "${AIC_MOCK_LOG}" ]; then
    local n
    n="$(grep -c '^CALL' "${AIC_MOCK_LOG}" 2>/dev/null)" || n=0
    printf '%s\n' "${n}"
  else
    printf '0\n'
  fi
}
