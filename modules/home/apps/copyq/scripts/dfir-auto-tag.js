function onClipboardChanged() {
    var text = str(read());

    if (!text)
        return;

    var length = text.length;

    if (/^[a-fA-F0-9]+$/.test(text)) {

        if (length === 32) {
            plugins.itemtags.tag("hash");
            plugins.itemtags.tag("md5");
        }

        if (length === 40) {
            plugins.itemtags.tag("hash");
            plugins.itemtags.tag("sha1");
        }

        if (length === 64) {
            plugins.itemtags.tag("hash");
            plugins.itemtags.tag("sha256");
        }

        if (length === 128) {
            plugins.itemtags.tag("hash");
            plugins.itemtags.tag("sha512");
        }
    }
}
