#!/usr/bin/env bash

set -euo pipefail

copyq eval '
var text = str(data("text/plain"));

if (/^[a-fA-F0-9]{32}$/.test(text)) {
    setData("application/x-copyq-tags", "hash,md5");
}

if (/^[a-fA-F0-9]{40}$/.test(text)) {
    setData("application/x-copyq-tags", "hash,sha1");
}

if (/^[a-fA-F0-9]{64}$/.test(text)) {
    setData("application/x-copyq-tags", "hash,sha256");
}

if (/^[a-fA-F0-9]{128}$/.test(text)) {
    setData("application/x-copyq-tags", "hash,sha512");
}
'
