{ ... }:

{
  xdg.configFile."copyq/copyq-commands.ini".text = ''
[Commands]

7\Command="copyq:${builtins.readFile ./scripts/dfir-classifier.js}"
7\Automatic=true
7\Icon=
7\InMenu=false
7\Input=text/plain
7\InternalId=dfir_auto_classifier
7\Name=DFIR Auto Classifier


8\Command="copyq:
if (plugins.itemtags.hasTag('hash')) {
    var value = str(input()).trim();
    open('https://www.virustotal.com/gui/search/' + value);
}
"
8\Icon=
8\InMenu=false
8\Input=text/plain
8\InternalId=dfir_vt_hash_lookup
8\Name=DFIR: VirusTotal Hash Lookup


9\Command="copyq:
if (plugins.itemtags.hasTag('ipv4') || plugins.itemtags.hasTag('ipv6')) {
    var value = str(input()).trim();
    open('https://www.virustotal.com/gui/search/' + value);
}
"
9\Icon=
9\InMenu=false
9\Input=text/plain
9\InternalId=dfir_vt_ip_lookup
9\Name=DFIR: VirusTotal IP Lookup


10\Command="copyq:
if (plugins.itemtags.hasTag('ipv4') || plugins.itemtags.hasTag('ipv6')) {
    var value = str(input()).trim();
    open('https://www.abuseipdb.com/check/' + value);
}
"
10\Icon=
10\InMenu=false
10\Input=text/plain
10\InternalId=dfir_abuseipdb_lookup
10\Name=DFIR: AbuseIPDB IP Lookup


size=10
'';
}
