{ ... }:

{
  home.file.".config/copyq/dfir-commands.ini".text = ''
[Commands]

7\Command="copyq:
var text = str(input())

var tags = []

if (text.length <= 1000000) {

    if (/^[a-fA-F0-9]{32}$/.test(text)) {
        tags.push('hash')
        tags.push('md5')
    }

    if (/^[a-fA-F0-9]{40}$/.test(text)) {
        tags.push('hash')
        tags.push('sha1')
    }

    if (/^[a-fA-F0-9]{64}$/.test(text)) {
        tags.push('hash')
        tags.push('sha256')
    }

    if (/^[a-fA-F0-9]{128}$/.test(text)) {
        tags.push('hash')
        tags.push('sha512')
    }
}

if (tags.length > 0) {
    setData('application/x-copyq-tags', tags.join(','))
}
"

7\Automatic=true
7\Icon=
7\InMenu=true
7\Input=text/plain
7\InternalId=dfir_auto_hash_tag
7\Name=DFIR Auto Hash Tag
'';
}
