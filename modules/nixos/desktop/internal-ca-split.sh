# internal-ca-split SOURCE RUNDIR USER MAX [DOMAINS]
#
# Split a PEM bundle of CA certificates into RUNDIR/ca-N.crt and write the
# Chromium policy RUNDIR/chromium-policy.json. Prints counts only, never
# names or fingerprints. Everything in RUNDIR belongs to USER, mode 0400.

source_file="$1"
run_dir="$2"
user="$3"
max="$4"
domains_file="${5:-}"

umask 077
tmp="$(mktemp -d -p "$(dirname "$run_dir")" internal-ca.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

if [ ! -r "$source_file" ]; then
  # Keep an empty policy so the links in /etc do not dangle.
  echo '{}' >"$tmp/chromium-policy.json"
  count=0
  echo "internal-ca: $source_file missing, no CA installed" >&2
else
  awk -v dir="$tmp" '/-----BEGIN CERTIFICATE-----/ {n++} n {print > (dir "/in-" n ".pem")}' "$source_file"
  count=0
  : >"$tmp/der.list"
  for pem in "$tmp"/in-*.pem; do
    [ -e "$pem" ] || continue
    # Only well-formed CA certificates are passed on.
    openssl x509 -in "$pem" -noout -ext basicConstraints 2>/dev/null | grep -q 'CA:TRUE' || continue
    # The same CA may come with several chains; keep it once.
    digest="$(openssl x509 -in "$pem" -outform DER | sha256sum | cut -d' ' -f1)"
    if grep -qx "$digest" "$tmp/seen.list" 2>/dev/null; then continue; fi
    echo "$digest" >>"$tmp/seen.list"
    count=$((count + 1))
    openssl x509 -in "$pem" -out "$tmp/ca-$count.crt"
    openssl x509 -in "$pem" -outform DER | base64 -w0 >>"$tmp/der.list"
    echo >>"$tmp/der.list"
  done
  rm -f "$tmp"/in-*.pem "$tmp/seen.list"

  domains='[]'
  if [ -n "$domains_file" ] && [ -r "$domains_file" ]; then
    domains="$({ grep -E '^[A-Za-z0-9.-]+$' "$domains_file" || true; } | jq -R . | jq -cs .)"
  fi
  if [ "$domains" != '[]' ]; then
    jq -R . "$tmp/der.list" | jq -cs --argjson names "$domains" \
      '{CACertificatesWithConstraints: map({certificate: ., constraints: {permitted_dns_names: $names}})}' \
      >"$tmp/chromium-policy.json"
  else
    jq -R . "$tmp/der.list" | jq -cs '{CACertificates: .}' >"$tmp/chromium-policy.json"
  fi
  rm -f "$tmp/der.list"

  if [ "$count" -gt "$max" ]; then
    echo "internal-ca: $count certificates, Firefox/Floorp only get the first $max (maxCertificates)" >&2
  fi
  echo "internal-ca: $count CA certificate(s) installed"
fi

chmod 0400 "$tmp"/*
chown -R "$user" "$tmp"
chmod 0500 "$tmp"
rm -rf "$run_dir"
mv "$tmp" "$run_dir"
trap - EXIT
