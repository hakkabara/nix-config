#!/usr/bin/env bats
# 01-validation.bats — US-002: IP-Validierung & Klassifizierung IPv4/IPv6.

load helpers

setup() { aic_setup_env; aic_source_tool; }
teardown() { aic_teardown_env; }

# ---------------------------------------------------------------- aic_valid_ipv4
@test "aic_valid_ipv4 akzeptiert gueltige Adressen" {
  aic_valid_ipv4 "1.2.3.4"
  aic_valid_ipv4 "0.0.0.0"
  aic_valid_ipv4 "255.255.255.255"
  aic_valid_ipv4 "192.168.0.1"
  aic_valid_ipv4 "9.9.9.9"
}

@test "aic_valid_ipv4 lehnt out-of-range Oktett ab" {
  run aic_valid_ipv4 "256.1.1.1"
  [ "${status}" -ne 0 ]
  run aic_valid_ipv4 "1.2.3.300"
  [ "${status}" -ne 0 ]
}

@test "aic_valid_ipv4 lehnt fuehrende Nullen ab (01.2.3.4 ungueltig)" {
  run aic_valid_ipv4 "01.2.3.4"
  [ "${status}" -ne 0 ]
  run aic_valid_ipv4 "1.02.3.4"
  [ "${status}" -ne 0 ]
  # aber "0" allein im Oktett ist gueltig
  aic_valid_ipv4 "10.0.0.0"
}

@test "aic_valid_ipv4 lehnt falsche Oktettzahl / leeres / Whitespace ab" {
  run aic_valid_ipv4 "1.2.3"; [ "${status}" -ne 0 ]
  run aic_valid_ipv4 "1.2.3.4.5"; [ "${status}" -ne 0 ]
  run aic_valid_ipv4 ""; [ "${status}" -ne 0 ]
  run aic_valid_ipv4 "  "; [ "${status}" -ne 0 ]
  run aic_valid_ipv4 "1.2.3.a"; [ "${status}" -ne 0 ]
  run aic_valid_ipv4 "1.2.3.4 "; [ "${status}" -ne 0 ]
}

# ---------------------------------------------------------------- aic_valid_ipv6
@test "aic_valid_ipv6 akzeptiert gueltige Adressen" {
  aic_valid_ipv6 "::1"
  aic_valid_ipv6 "fe80::1"
  aic_valid_ipv6 "2001:db8::1"
  aic_valid_ipv6 "2606:4700:4700::1111"
  aic_valid_ipv6 "fc00::1"
  aic_valid_ipv6 "::"
}

@test "aic_valid_ipv6 akzeptiert IPv4-mapped ::ffff:1.2.3.4" {
  aic_valid_ipv6 "::ffff:1.2.3.4"
}

@test "aic_valid_ipv6 ist case-insensitiv (Gross/Klein)" {
  aic_valid_ipv6 "2001:DB8::1"
  aic_valid_ipv6 "FE80::ABCD"
}

@test "aic_valid_ipv6 lehnt Unsinn / leeres / Whitespace ab" {
  run aic_valid_ipv6 "1.2.3.4"; [ "${status}" -ne 0 ]
  run aic_valid_ipv6 "gggg::1"; [ "${status}" -ne 0 ]
  run aic_valid_ipv6 "2001:db8:::1"; [ "${status}" -ne 0 ]
  run aic_valid_ipv6 ""; [ "${status}" -ne 0 ]
  run aic_valid_ipv6 "  "; [ "${status}" -ne 0 ]
  run aic_valid_ipv6 "12345::1"; [ "${status}" -ne 0 ]
}

# --------------------------------------------------------------- aic_classify_ip
@test "aic_classify_ip: oeffentliche IPv4" {
  run aic_classify_ip "9.9.9.9"; [ "${output}" == "public" ]
  run aic_classify_ip "8.8.8.8"; [ "${output}" == "public" ]
  run aic_classify_ip "1.1.1.1"; [ "${output}" == "public" ]
}

@test "aic_classify_ip: private RFC1918" {
  run aic_classify_ip "10.0.0.1"; [ "${output}" == "private" ]
  run aic_classify_ip "172.16.5.4"; [ "${output}" == "private" ]
  run aic_classify_ip "172.31.255.255"; [ "${output}" == "private" ]
  run aic_classify_ip "192.168.1.1"; [ "${output}" == "private" ]
  # 172.32.x ist NICHT privat
  run aic_classify_ip "172.32.0.1"; [ "${output}" == "public" ]
}

@test "aic_classify_ip: loopback 127/8" {
  run aic_classify_ip "127.0.0.1"; [ "${output}" == "loopback" ]
  run aic_classify_ip "127.255.255.254"; [ "${output}" == "loopback" ]
}

@test "aic_classify_ip: link-local 169.254/16" {
  run aic_classify_ip "169.254.1.1"; [ "${output}" == "link-local" ]
}

@test "aic_classify_ip: multicast 224/4" {
  run aic_classify_ip "224.0.0.1"; [ "${output}" == "multicast" ]
  run aic_classify_ip "239.255.255.255"; [ "${output}" == "multicast" ]
}

@test "aic_classify_ip: reserved 240/4, 0/8, 100.64/10 (CGN)" {
  run aic_classify_ip "240.0.0.1"; [ "${output}" == "reserved" ]
  run aic_classify_ip "0.1.2.3"; [ "${output}" == "reserved" ]
  run aic_classify_ip "100.64.0.1"; [ "${output}" == "reserved" ]
  run aic_classify_ip "100.127.255.255"; [ "${output}" == "reserved" ]
  # 100.63 und 100.128 sind public
  run aic_classify_ip "100.63.255.255"; [ "${output}" == "public" ]
  run aic_classify_ip "100.128.0.1"; [ "${output}" == "public" ]
}

@test "aic_classify_ip: invalid" {
  run aic_classify_ip "256.1.1.1"; [ "${output}" == "invalid" ]
  run aic_classify_ip "01.2.3.4"; [ "${output}" == "invalid" ]
  run aic_classify_ip "nonsense"; [ "${output}" == "invalid" ]
  run aic_classify_ip ""; [ "${output}" == "invalid" ]
}

@test "aic_classify_ip: IPv6 loopback ::1" {
  run aic_classify_ip "::1"; [ "${output}" == "loopback" ]
}

@test "aic_classify_ip: IPv6 link-local fe80::/10" {
  run aic_classify_ip "fe80::1"; [ "${output}" == "link-local" ]
  run aic_classify_ip "febf::1"; [ "${output}" == "link-local" ]
  run aic_classify_ip "FE80::ABCD"; [ "${output}" == "link-local" ]
}

@test "aic_classify_ip: IPv6 ULA fc00::/7 -> private" {
  run aic_classify_ip "fc00::1"; [ "${output}" == "private" ]
  run aic_classify_ip "fd12:3456::1"; [ "${output}" == "private" ]
}

@test "aic_classify_ip: IPv6 multicast ff00::/8" {
  run aic_classify_ip "ff02::1"; [ "${output}" == "multicast" ]
}

@test "aic_classify_ip: IPv6 doc/reserved 2001:db8::/32 -> reserved" {
  run aic_classify_ip "2001:db8::1"; [ "${output}" == "reserved" ]
  run aic_classify_ip "2001:DB8:aaaa::1"; [ "${output}" == "reserved" ]
}

@test "aic_classify_ip: IPv6 public" {
  run aic_classify_ip "2606:4700:4700::1111"; [ "${output}" == "public" ]
  run aic_classify_ip "2001:4860:4860::8888"; [ "${output}" == "public" ]
}

@test "aic_classify_ip: IPv4-mapped ::ffff:a.b.c.d nach IPv4-Regeln" {
  run aic_classify_ip "::ffff:10.0.0.1"; [ "${output}" == "private" ]
  run aic_classify_ip "::ffff:9.9.9.9"; [ "${output}" == "public" ]
  run aic_classify_ip "::ffff:127.0.0.1"; [ "${output}" == "loopback" ]
}
