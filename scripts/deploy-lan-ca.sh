#!/usr/bin/env bash
# Internal CA for HTTPS on the deployment LAN.
#
#   deploy-lan-ca.sh init  <ca-dir>
#   deploy-lan-ca.sh issue <ca-dir> <out-dir> <name> [<name-or-ipv4>...]
#
# init creates a passphrase-protected CA key and a CA certificate that is
# name-constrained to DEPLOY_LAN_DOMAIN and DEPLOY_LAN_NET: even a leaked CA
# key cannot sign certificates for any other name. Keep ca.key offline
# (password manager); only ca.crt is public.
#
# issue signs a server certificate. The private key is written unencrypted
# and must go straight into a SOPS document.
#
# The CA passphrase is asked for once (init: twice to confirm) or taken from
# DEPLOY_LAN_CA_PASS, and handed to openssl through the environment.
set -euo pipefail
umask 077

domain="${DEPLOY_LAN_DOMAIN:-deploy.internal}"
net="${DEPLOY_LAN_NET:-192.168.245.0/255.255.255.0}"
ca_days="${DEPLOY_LAN_CA_DAYS:-3650}"
cert_days="${DEPLOY_LAN_CERT_DAYS:-730}"

ask_pass() {
  local confirm="$1" again

  if [ -n "${DEPLOY_LAN_CA_PASS:-}" ]; then
    export DEPLOY_LAN_CA_PASS
    return
  fi

  read -rsp "CA-Passphrase: " DEPLOY_LAN_CA_PASS
  echo >&2
  [ -n "$DEPLOY_LAN_CA_PASS" ] || {
    echo "ERROR: empty passphrase" >&2
    exit 1
  }

  if [ "$confirm" = confirm ]; then
    read -rsp "CA-Passphrase wiederholen: " again
    echo >&2
    [ "$again" = "$DEPLOY_LAN_CA_PASS" ] || {
      echo "ERROR: passphrases differ" >&2
      exit 1
    }
  fi

  export DEPLOY_LAN_CA_PASS
}

usage() {
  sed -n '4,5p' "$0" >&2
  exit 2
}

init() {
  local dir="$1"

  [ ! -e "$dir/ca.key" ] || {
    echo "ERROR: $dir/ca.key exists already" >&2
    exit 1
  }
  mkdir -p "$dir"
  ask_pass confirm

  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
    -aes-256-cbc -pass env:DEPLOY_LAN_CA_PASS -out "$dir/ca.key"

  openssl req -x509 -new -sha256 -days "$ca_days" \
    -key "$dir/ca.key" -passin env:DEPLOY_LAN_CA_PASS \
    -subj "/CN=Deployment LAN CA ($domain)" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "subjectKeyIdentifier=hash" \
    -addext "nameConstraints=critical,permitted;DNS:$domain,permitted;IP:$net" \
    -out "$dir/ca.crt"

  chmod 644 "$dir/ca.crt"
  openssl x509 -in "$dir/ca.crt" -noout -subject -enddate -fingerprint -sha256
}

issue() {
  local ca_dir="$1" out="$2" name="$3"
  shift 3

  local san="DNS:$name" entry
  for entry in "$@"; do
    if [[ "$entry" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
      san+=",IP:$entry"
    else
      san+=",DNS:$entry"
    fi
  done

  mkdir -p "$out"

  openssl req -new -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
    -subj "/CN=$name" \
    -keyout "$out/$name.key" \
    -out "$out/$name.csr"

  ask_pass once

  openssl x509 -req -sha256 -days "$cert_days" \
    -in "$out/$name.csr" \
    -CA "$ca_dir/ca.crt" -CAkey "$ca_dir/ca.key" -CAcreateserial \
    -passin env:DEPLOY_LAN_CA_PASS \
    -extfile <(
      printf '%s\n' \
        "basicConstraints=critical,CA:FALSE" \
        "keyUsage=critical,digitalSignature" \
        "extendedKeyUsage=serverAuth" \
        "subjectKeyIdentifier=hash" \
        "authorityKeyIdentifier=keyid" \
        "subjectAltName=$san"
    ) \
    -out "$out/$name.crt"

  rm -f "$out/$name.csr"
  openssl verify -CAfile "$ca_dir/ca.crt" "$out/$name.crt"
  openssl x509 -in "$out/$name.crt" -noout -subject -enddate -ext subjectAltName
}

case "${1:-}" in
  init)
    [ $# -eq 2 ] || usage
    init "$2"
    ;;
  issue)
    [ $# -ge 4 ] || usage
    issue "${@:2}"
    ;;
  *)
    usage
    ;;
esac
