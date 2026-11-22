# abuseipdb-check

Read-only IP-Reputationsprüfung gegen AbuseIPDB APIv2 (`GET /api/v2/check`).

Das Tool prüft beliebig lange IP-Listen (IPv4 und IPv6) ausschließlich lesend — kein Reporting, kein `/bulk-report`, keine Schreiboperationen. Ungültige, private und doppelte IPs werden vor jedem API-Aufruf aussortiert. Ergebnisse erscheinen als farbcodierte ASCII-Tabelle im Terminal; optional werden sie in CSV, JSON, JSONL, TXT oder Markdown exportiert. Ein geteilter TTL-Cache unter `<tool-dir>/data/cache` spart Tageskontingent für alle Nutzer eines Servers. Mehrere API-Keys können hinterlegt werden; ist das Tageskontingent eines Keys erschöpft, rotiert das Tool automatisch auf den nächsten.

---

## Voraussetzungen

| Abhängigkeit | Mindestversion | Kali (vorinstalliert) |
|---|---|---|
| bash | 4.0 | ja |
| curl | beliebig | ja |
| jq | 1.6 | ja |

Für die Test-Suite wird zusätzlich bats-core benötigt:

```bash
# Kali / Debian / Ubuntu
apt install bats

# alternativ: lokale Kopie im Repo (keine Installation nötig)
# tests/lib/bats-core/bin/bats ist nach dem Einrichten der Test-Infrastruktur vorhanden
```

shellcheck ist optional, wird für Qualitätsprüfungen empfohlen:

```bash
apt install shellcheck
```

---

## Installation

Das Tool ist eine einzelne Bash-Datei ohne Build-Schritt. Für den Einzelnutzer genügt es, die Datei ausführbar zu machen:

```bash
chmod +x abuseipdb-check
```

Für einen Server, auf dem mehrere Nutzer das Tool und seinen Cache teilen sollen, richtet ein Administrator das Verzeichnis einmalig ein:

```bash
install -d -m 2775 -g <gruppe> /data/tools/abuse
install -m 755 abuseipdb-check /data/tools/abuse/
install -d -m 2775 -g <gruppe> /data/tools/abuse/data/cache
```

Alle Laufzeitdaten liegen unter `<tool-dir>/data/`, der Ergebnis-Cache unter `<tool-dir>/data/cache`. Das setgid-Bit (`2775`) stellt sicher, dass neue Cache-Dateien der Gruppe gehören. Das Tool setzt beim Schreiben `umask 002`, damit alle Gruppenmitglieder die Dateien lesen können. Kann das Tool das Cache-Verzeichnis nicht beschreiben (fehlende Berechtigung), gibt es eine Warnung aus und läuft ohne Cache weiter — der Lauf wird nicht abgebrochen.

Ein bestehender `cache/`-Ordner aus einer älteren Version wird beim ersten Lauf automatisch nach `data/cache/` migriert.

---

## API-Key

### Schlüssel besorgen

1. Konto auf [abuseipdb.com](https://www.abuseipdb.com) anlegen
2. Unter **Account → API** einen neuen APIv2-Key erzeugen (nicht den alten v1-Key verwenden)

### Konfigurationswege (Priorität: Flag > Env > Config)

**1. Flag (einmalig, für Ausnahmen)**

```bash
abuseipdb-check --api-key DEIN_KEY 1.2.3.4
```

Den Key als Flag anzugeben landet in der Shell-History. Nur für Ausnahmen verwenden — für Skripte stattdessen Env oder Config nutzen.

**2. Umgebungsvariable**

```bash
export ABUSEIPDB_API_KEY=DEIN_KEY
abuseipdb-check 1.2.3.4
```

**3. Config-Datei**

```bash
mkdir -p ~/.config/abuseipdb
cat > ~/.config/abuseipdb/config <<'EOF'
api_key=DEIN_KEY
ttl=10d
EOF
chmod 600 ~/.config/abuseipdb/config
```

Das Tool warnt beim Start, wenn die Config-Datei world-readable ist.

**4. Interaktive Einrichtung (`--init`)**

```bash
abuseipdb-check --init
```

Fragt den Pflicht-Key, danach beliebig viele weitere Keys für die Rotation (Enter beendet die Abfrage) und die Cache-TTL in Tagen ab, schreibt die Config mit `chmod 600` und beendet sich. Mit `--config DATEI` lässt sich ein abweichender Zielpfad wählen; eine bestehende Config wird nach einem Hinweis überschrieben.

Derselbe Dialog startet automatisch beim ersten Prüflauf ohne gesetzten Key, sofern ein Terminal angeschlossen ist.

### Mehrere API-Keys

Reicht das Tageskontingent eines einzelnen Keys nicht, lassen sich mehrere Keys hinterlegen. Läuft ein Key beim Prüflauf in sein Tageslimit (HTTP 429), rotiert das Tool automatisch auf den nächsten Key und wiederholt die betroffene IP. Alle Konfigurationswege lassen sich kombinieren:

```bash
# Flag wiederholbar
abuseipdb-check --api-key KEY_A --api-key KEY_B 1.2.3.4

# Env kommasepariert
export ABUSEIPDB_API_KEY=KEY_A,KEY_B,KEY_C
abuseipdb-check 1.2.3.4

# Config: api_keys (kommasepariert), zusätzlich zu api_key
cat >> ~/.config/abuseipdb/config <<'EOF'
api_keys=KEY_A,KEY_B
EOF
```

Sind alle Keys erschöpft, werden die verbleibenden IPs als `FEHLER` markiert (Exit 3). Ein erneuter Aufruf mit derselben Liste bezieht die bereits geprüften IPs aus dem Cache und fragt nur den Rest live ab (Resume, siehe unten). Jede betroffene IP wird höchstens einmal je Key wiederholt — es gibt keinen Endlos-Retry.

Bei mehr als einem Key summiert der Rate-Limit-Block das Kontingent über alle Accounts auf und weist mit `Key i/n` den zuletzt aktiven Key aus. Format:

```
API-Limit: [>=]<summe> (<n> Keys[, <u> ungenutzt]) | Verbleibend: [>=]<summe> | Reset: <zeit> | Key <i>/<n>
```

Beispiel mit zwei bekannten Keys:

```
API-Limit: 3000 (2 Keys) | Verbleibend: 1800 | Reset: 2025-07-12 02:00:00 CEST | Key 1/2
```

Die Summen laufen über alle Keys mit bekannten Metadaten. Keys, die bislang nie benutzt wurden (noch keine Metadaten), werden als `ungenutzt` ausgewiesen; die Summen sind dann Teilsummen und werden bei Limit **und** Verbleibend mit vorangestelltem `>=` gekennzeichnet, da die ungenutzten Keys zusätzliches Kontingent beisteuern:

```
API-Limit: >=1000 (2 Keys, 1 ungenutzt) | Verbleibend: >=900 | Reset: 2025-07-12 02:00:00 CEST | Key 1/2
```

`Reset` zeigt die früheste bekannte Reset-Zeit. Bei genau einem Key bleibt die Zeile unverändert ohne diese Zusätze.

Die Keys selbst werden nie auf die Platte geschrieben oder in Ausgaben (inkl. Exports) ausgegeben. Rate-Limit-Metadaten werden pro Key getrennt geführt, wobei der Dateiname einen kurzen Hash-Fingerprint des Keys trägt — nie den Key-Wert.

---

## Schnellstart

```bash
# Einzelne IP
abuseipdb-check 1.2.3.4

# Mehrere IPs als Argumente
abuseipdb-check 1.2.3.4 5.6.7.8 2001:db8::1

# IP-Liste aus Datei (-f)
abuseipdb-check -f ips.txt

# Via stdin-Pipe
cat ips.txt | abuseipdb-check
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' access.log | abuseipdb-check

# IPs aus Logdatei extrahieren (unstrukturierter Text, --extract)
abuseipdb-check --extract < /var/log/auth.log
cat nginx_error.log | abuseipdb-check --extract
```

---

## Alle Eingabewege

Das Tool kombiniert beliebige Eingabewege in einem Lauf:

| Weg | Beispiel | Hinweis |
|---|---|---|
| `-f DATEI` | `abuseipdb-check -f ips.txt` | `#`-Kommentare und Leerzeilen werden ignoriert |
| Argumente | `abuseipdb-check 1.1.1.1 8.8.8.8` | IPv4 und IPv6 gemischt möglich |
| stdin-Pipe | `cat ips.txt \| abuseipdb-check` | Nur aktiv, wenn kein Terminal angeschlossen ist |
| `--extract` | `cat auth.log \| abuseipdb-check --extract` | Regex-Extraktion aus Fließtext |

Duplikate werden automatisch entfernt und in der „Übersprungen"-Sektion gezählt. IPv6-Adressen werden dabei case-insensitiv verglichen.

**Unsaubere Listen** werden auch ohne `--extract` entschärft: Enthält eine Zeile neben der IP weiteres (z. B. die Zähler einer `sort | uniq -c`-Ausgabe wie `      5 61.80.67.162`, Windows-Zeilenenden oder mehrere IPs pro Zeile), löst das Tool die IP-Tokens automatisch heraus. Zeilen ganz ohne IP bleiben als Kandidat erhalten und erscheinen als `INVALID` in der „Übersprungen"-Sektion — zusammen mit den Zählern für `LOOPBACK`, `PRIVATE`, `LINK-LOCAL`, `MULTICAST`, `RESERVED`, `WHITELIST` und `DUPLIKAT` geht so keine Eingabe stillschweigend verloren.

Wird das Tool ganz ohne IPs aufgerufen (keine Argumente, keine Datei, keine stdin-Daten), gibt es die Meldung `Keine IPs uebergeben.` samt Hilfe-Menü aus und beendet sich mit Exit-Code 2.

---

## Fortschritt und Bilanz

Bei angeschlossenem Terminal zeigt das Tool den Fortschritt auf stderr an: einen Zähler `Cache-Abgleich: x/y` während des Cache-Abgleichs, eine Startzeile `Pruefe N IPs ...` und einen fortlaufenden Zähler `Fortschritt: x/y` für die Live-Abfragen. Auch ein komplett aus dem Cache bedienter Lauf ist damit sichtbar. Läuft die Ausgabe in eine Pipe oder Umleitung, bleibt die Fortschrittsanzeige automatisch stumm, sodass sie maschinenlesbare Ausgaben nicht verunreinigt.

Nach jedem Lauf folgt eine Bilanzzeile, die Eingaben und Ergebnisse gegenüberstellt:

```
Bilanz: N Eingaben -> X geprueft (live/Cache), F Fehler, S uebersprungen
```

Weicht die Summe aus geprüften, fehlerhaften und übersprungenen IPs von der Zahl der Eingaben ab, gibt das Tool zusätzlich eine Warnung aus. Im JSON-Export enthält der `meta`-Block das Feld `counts.input_total` mit der Zahl der ursprünglichen Eingaben.

---

## Flags

### Eingabe

| Flag | Beschreibung |
|---|---|
| `-f`, `--file DATEI` | IP-Liste aus Datei (eine IP pro Zeile) |
| `--extract` | IPs per Regex aus unstrukturiertem Text extrahieren |

### Whitelist / Ausschluss

| Flag | Beschreibung |
|---|---|
| `--exclude IP\|CIDR` | IP oder CIDR-Bereich ausschließen (wiederholbar, IPv4 und IPv6) |
| `--exclude-file DATEI` | Ausschlussliste aus Datei (Kommentare mit `#` erlaubt) |

Ausgeschlossene IPs erscheinen in der Ausgabe mit Grund `WHITELIST`. Dauerhafter Ausschluss ist über den `whitelist`-Eintrag in der Config-Datei möglich.

### Konfiguration

| Flag | Beschreibung |
|---|---|
| `--init` | Interaktive Einrichtung: API-Key(s) und TTL abfragen, Config schreiben, beenden |
| `--api-key KEY` | API-Key (Vorrang vor Env und Config); wiederholbar für mehrere Keys |
| `--config DATEI` | Abweichende Config-Datei (Standard: `~/.config/abuseipdb/config`) |

### Cache

| Flag | Beschreibung |
|---|---|
| `--cache-dir VERZ` | Cache-Verzeichnis (Standard: `<tool-dir>/data/cache`) |
| `--ttl DAUER` | Cache-TTL: `10d` (Tage), `36h` (Stunden) oder nackte Zahl = Stunden (Standard: `10d`) |
| `--no-cache` | Ergebnis-Cache umgehen, immer live abfragen |
| `--clear-cache` | Cache inklusive Rate-Limit-Metadatei leeren und beenden |
| `--cache-stats` | Cache-Statistik anzeigen (Einträge, Alter, Größe) und beenden |

### Abfrage

| Flag | Beschreibung |
|---|---|
| `--parallel N` | Parallele Abfragen (Standard: 5, Maximum: 10, 1 = sequenziell) |
| `--max-age TAGE` | `maxAgeInDays` für die API (Standard: 90, Bereich: 1–365) |

### Ausgabe

| Flag | Beschreibung |
|---|---|
| `--sort KEY` | Sortierung: `score`, `country`, `isp`, `reports`, `last-reported` (Standard: `score`) |
| `--reverse` | Sortierreihenfolge umkehren |
| `--no-color` | Farbige Ausgabe abschalten (wird automatisch deaktiviert, wenn kein Terminal angeschlossen ist) |
| `--threshold-critical N` | Ab diesem Score rot einfärben (Standard: 75) |
| `--threshold-suspect N` | Ab diesem Score gelb einfärben (Standard: 25) |

### Export

| Flag | Beschreibung |
|---|---|
| `--output-file DATEI` | Ergebnis zusätzlich in Datei schreiben |
| `--output-format FORMAT` | `csv` (Standard), `json`, `jsonl`, `txt`, `md` |

Export findet nur statt, wenn `--output-file` angegeben ist. Alle Formate berücksichtigen `--sort` und `--reverse`. Hat die angegebene Datei keine Endung, wird automatisch die des Formats angehängt (`--output-file report --output-format csv` → `report.csv`); eine selbst gewählte Endung bleibt unangetastet.

---

## Ausgabeformate

| Format | Inhalt |
|---|---|
| `csv` | Header-Zeile + eine Ergebniszeile pro IP, Felder korrekt gequotet |
| `json` | JSON-Array aller Ergebnisse inklusive übersprungener IPs und Metadaten (Laufzeit, Rate-Limit, `counts` inkl. `input_total`) |
| `jsonl` | Ein JSON-Objekt pro Zeile |
| `txt` | Tabelle ohne Farbcodes (identisch mit Terminal-Ausgabe, maschinenlesbar) |
| `md` | Markdown-Report mit Summary-Block (kritisch/verdächtig/sauber/Fehler/übersprungen) und Tabelle |

---

## Exit-Codes

| Code | Bedeutung |
|---|---|
| 0 | Alle geprüften IPs unauffällig |
| 1 | Mindestens eine IP erreicht oder überschreitet den kritischen Schwellenwert (Standard: Score ≥ 75) |
| 2 | Nutzungs-, Eingabe- oder Abhängigkeitsfehler (falsches Flag, fehlende Datei, curl/jq nicht installiert) |
| 3 | API- oder Netzwerkfehler (Timeout, HTTP 5xx, ungültiges JSON in der Antwort) |

**Priorität bei mehreren Bedingungen: 2 vor 3 vor 1.**

Beispiel für Skript-Einbindung:

```bash
if ! abuseipdb-check -f verdaechtige-ips.txt --output-file bericht.csv; then
  case $? in
    1) echo "Kritische IPs gefunden — Bericht in bericht.csv" ;;
    2) echo "Fehler in den Eingaben oder fehlende Abhängigkeit" ;;
    3) echo "API oder Netzwerk nicht erreichbar" ;;
  esac
fi
```

---

## Score-Interpretation

AbuseIPDB veröffentlicht folgende Richtwerte für den Abuse Confidence Score:

| Bereich | Bedeutung | Farbe |
|---|---|---|
| 0 | Keine bekannten Meldungen | grün |
| 1–24 | Vereinzelte oder historische Meldungen | grün |
| 25–74 | Erhöhtes Risiko | gelb |
| 75–100 | Hohe Missbrauchswahrscheinlichkeit (Blocklisten-Empfehlung) | rot |

Die Schwellen 75 und 25 sind über `--threshold-critical` und `--threshold-suspect` sowie über die Config-Felder `threshold_critical` und `threshold_suspect` anpassbar. Der Exit-Code 1 wird ausgelöst, wenn mindestens eine IP den kritischen Schwellenwert erreicht oder überschreitet.

---

## Rate-Limits und Tageskontingent

AbuseIPDB begrenzt `/check`-Anfragen pro Tag je nach Plan:

| Plan | Anfragen/Tag (`/check`) |
|---|---|
| Free | 1.000 |
| Basic | 10.000 |
| Premium | 50.000 |

Das Kontingent wird täglich um Mitternacht UTC zurückgesetzt.

Das Tool zeigt nach jedem Lauf Limit, verbleibendes Kontingent und Reset-Zeit an. Sind mehrere Keys konfiguriert, summiert die Zeile das Kontingent über alle Accounts und weist mit `Key i/n` den zuletzt aktiven Key aus (Format und `>=`-Teilsummen siehe „Mehrere API-Keys"). Vor dem eigentlichen parallelen Lauf wird eine einzelne Rate-Limit-Probe durchgeführt:

- **W1:** Wenn eine Metadatei aus einem vorangegangenen Lauf vorliegt, schätzt das Tool anhand des dort gespeicherten Restwertes, ob das Kontingent reichen könnte. Bei mehreren Keys rechnet die Vorwarnung gegen die aggregierte Verbleibend-Summe über alle Keys. Liegen für einzelne Keys noch keine Metadaten vor (`ungenutzt`), ist diese Summe nur eine Teilsumme; W1 warnt dann konservativ **nicht**, da das tatsächliche Budget durch die ungenutzten Keys höher liegt.
- **W2 (verbindlich):** Nach der Probe-Abfrage wird mit dem tatsächlichen `X-RateLimit-Remaining`-Wert verglichen. Reicht das Kontingent nicht für alle verbleibenden IPs, warnt das Tool. Bei angeschlossenem Terminal wird eine Bestätigung verlangt; bei stdin-Pipe läuft es mit Warnung weiter.

**Automatische Key-Rotation:** Läuft ein Key beim Prüfen in sein Tageslimit (HTTP 429), wechselt das Tool auf den nächsten konfigurierten Key und wiederholt die betroffene IP. Rate-Limit-Metadaten werden je Key getrennt (pro Key-Fingerprint) geführt; der Key selbst landet dabei nie auf der Platte.

**Cache-basiertes Resume:** Sind alle Keys erschöpft, werden die verbleibenden IPs als `FEHLER` markiert. Beim erneuten Aufruf mit derselben Liste bezieht das Tool bereits gecachte Ergebnisse aus dem Cache und fragt nur die verbleibenden IPs live ab — ohne zusätzliche Konfiguration.

---

## Geteilter Cache und Server-Deployment

Alle Laufzeitdaten liegen unter `<tool-dir>/data/`; der Cache im Unterverzeichnis `<tool-dir>/data/cache`. Jede IP wird als separate JSON-Datei gespeichert (IPv6-Doppelpunkte werden im Dateinamen durch `_` ersetzt). Schreibvorgänge sind atomar (`mktemp` + `mv`), sodass parallele Läufe mehrerer Nutzer keine Dateien korrumpieren.

**Migration aus älteren Versionen:** Ein bestehender `cache/`-Ordner neben dem Tool wird beim ersten Lauf automatisch nach `data/cache/` migriert. Vorhandene Cache-Einträge bleiben dabei erhalten.

**Admin-Voranlage für Multi-User-Betrieb:**

```bash
# Einmalig als root oder mit sudo
install -d -m 2775 -g analysten /data/tools/abuse
install -m 755 abuseipdb-check /data/tools/abuse/
install -d -m 2775 -g analysten /data/tools/abuse/data/cache

# Nutzer der Gruppe hinzufügen
usermod -aG analysten <benutzername>
```

Das setgid-Bit (`2775`) bewirkt, dass neue Cache-Einträge automatisch der Gruppe `analysten` gehören. Das Tool setzt beim Schreiben `umask 002`, sodass Gruppenmitglieder die Dateien lesen können.

Kann das Tool das Cache-Verzeichnis nicht beschreiben, gibt es eine Warnung aus und läuft ohne Cache weiter — der Lauf bricht nicht ab.

**TTL-Konfiguration:** Die Standard-TTL beträgt 10 Tage. Sie kann pro Lauf mit `--ttl DAUER` oder dauerhaft in der Config-Datei über den Schlüssel `ttl` gesetzt werden. Die Dauer akzeptiert Tage (`10d`), Stunden (`36h`) oder eine nackte Zahl, die als Stunden gilt. Der ältere Config-Schlüssel `ttl_hours` (immer in Stunden) wird weiterhin akzeptiert; ist `ttl` gesetzt, hat es Vorrang vor `ttl_hours`.

---

## Sicherheit

- Die Config-Datei `~/.config/abuseipdb/config` muss die Rechte `600` haben. Das Tool warnt bei world-readable Dateien.
- Den Key nie in der Shell-History ablegen: `--api-key` nur für Ausnahmen verwenden, für Skripte stattdessen die Env-Variable oder Config-Datei nutzen.
- Die Datei `./apikey` im Projektverzeichnis (für Tests) nie committen oder in Logs ausgeben. Das Repo bringt dafür eine `.gitignore` mit, die Geheimnisse, Laufzeitdaten und lokale Werkzeuge ausschließt:
  ```
  apikey
  data/
  cache/
  tests/lib/
  .omc/
  ```
  Der `cache/`-Eintrag deckt weiterhin einen etwaigen Alt-Ordner ab, bis er nach `data/cache/` migriert ist.
- Der API-Key wird ausschließlich als HTTP-Header (`Key: ...`) übertragen, niemals als Query-Parameter.
- Der Key gelangt über `--config -` per stdin an curl und erscheint damit nie in der Prozessliste (`ps` / `/proc/<pid>/cmdline`). Auf Multi-User-Servern können andere Nutzer den Key so nicht aus laufenden Prozessen mitlesen.
- Alle Feldwerte aus API-Antworten und Cache werden vor Anzeige und Export zentral von Steuerzeichen bereinigt. Das verhindert Terminal-Escape-Injection über manipulierte Antwortfelder — auch bei absichtlich vergifteten Cache-Einträgen im geteilten Verzeichnis.
- Cache-Dateien dürfen keine Symlinks sein: Beim Lesen werden Symlinks abgelehnt, beim Schreiben ersetzt. Das wehrt Symlink-Angriffe im gemeinsam genutzten Cache-Verzeichnis ab (untergeschobene Verweise auf fremde Dateien).
- Config-Werte werden rechtsseitig getrimmt. Dadurch funktionieren auch unter Windows editierte Config-Dateien mit CRLF-Zeilenenden zuverlässig — das abschließende `\r` verfälscht weder Key noch andere Werte.
- Exports enthalten keinen API-Key.

---

## Tests

### Mock-basierte Test-Suite (kein echtes API-Kontingent)

Alle Unit- und Integrationstests laufen gegen einen Mock-curl und verbrauchen kein echtes Kontingent:

```bash
# Mit systemweitem bats
bats tests/0*.bats

# Mit lokaler bats-Kopie im Repo
tests/lib/bats-core/bin/bats tests/0*.bats
```

Alle Suiten (`00-scaffold` bis `09-cli-integration`) müssen grün durchlaufen. Der Mock protokolliert jeden curl-Aufruf; die Tests stellen sicher, dass ohne `AIC_CURL`-Override keine echten Netzwerkaufrufe stattfinden.

### Live-Smoke-Suite (≤ 8 echte API-Aufrufe)

Die Live-Suite wird nur bei explizitem Aufruf aktiv und setzt einen echten Key in `./apikey` voraus:

```bash
AIC_LIVE=1 tests/lib/bats-core/bin/bats tests/live-smoke.bats
```

Die Suite prüft strukturell (Felder vorhanden, Score im Bereich 0–100), nicht wertexakt, da Scores sich täglich ändern können. Fälle: bekannte saubere IP (9.9.9.9), bekannte gemeldete IP, IPv6-Probe, ungültiger Key (401-Pfad), Cache-Roundtrip (zweiter Aufruf liefert `CACHED`, kein zusätzlicher API-Call), Rate-Limit-Header vorhanden.

### shellcheck

```bash
tests/lib/bin/shellcheck abuseipdb-check
# alternativ systemweit
shellcheck abuseipdb-check
```
