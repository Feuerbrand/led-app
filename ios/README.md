# LED Control für iPhone

Die Webseite aus diesem Repository als echte iPhone-App – ohne Bluefy, mit mehr Funktionen:

- **Mehrere Lichter gleichzeitig:** die ELK-BLEDOM-Leiste und Lichter, die sonst nur **Lotus Lamp X** steuert (MELK-Geräte). Alle eingeschalteten Lichter zeigen dieselbe Farbe und dieselben Effekte.
- **Licht:** An/Aus, Helligkeit, Farbe (Farbwähler, Farbton- und Weißton-Leiste, 12 Farbfelder) und **Szenen** zum Speichern und Antippen.
- **Effekte:** die acht Flow-Effekte der Webseite, ein **Musik-Modus** (Lichter pulsieren im Takt), Tempo und die eingebauten Effekte jedes Lichts.
- **Geräte:** eigene Lichter mit Status und Empfang, verbinden/trennen per Schalter, umbenennen, blinken lassen, neue Lichter in der Nähe hinzufügen.
- **Siri und Kurzbefehle:** „Hey Siri, LED Control an“, Automationen, Aktionstaste.
- **Updates:** Die App meldet neue Versionen; mit AltStore aktualisiert sie sich mit einem Tippen.

Die App kommt nicht aus dem App Store. GitHub baut sie auf einem Mac in der Cloud, du installierst sie vom Windows-PC aus mit deiner eigenen Apple-ID.

> **Stand:** Die App wurde kompiliert und die Rechenlogik automatisch gegen die Webseite geprüft. **Auf einem echten iPhone mit den Lichtern wurde sie noch nicht ausprobiert** – auch die MELK-Befehle nicht. Was du beim ersten Start prüfen solltest, steht unten unter [Checkliste](#checkliste-für-den-ersten-test).

## Was du brauchst

- iPhone mit iOS 17 oder neuer und ein USB-Kabel
- Windows-PC mit **iTunes** und **iCloud**, beide direkt von Apple heruntergeladen – **nicht** die Versionen aus dem Microsoft Store. Sind die Store-Versionen installiert, erst deinstallieren. Die richtigen Installer sind auf [sideloadly.io](https://sideloadly.io/) verlinkt.
- [AltStore](https://altstore.io/) (empfohlen, wegen der Updates) oder [Sideloadly](https://sideloadly.io/)
- eine Apple-ID (die kostenlose reicht). Passwort und Bestätigungscode tippst du immer selbst ein. Wer das nicht mit der Haupt-Apple-ID machen möchte, legt dafür eine zweite, kostenlose an.

## Weg 1: AltStore – mit automatischen Updates (empfohlen)

AltStore ist eine App auf dem iPhone, die andere Apps installiert, aktualisiert und alle 7 Tage neu signiert. Ein Programm auf dem PC (AltServer) hilft dabei.

1. **AltServer** auf dem PC installieren und darüber **AltStore** aufs iPhone bringen. Anleitung: [faq.altstore.io – Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).
2. Auf dem iPhone freischalten – siehe [Auf dem iPhone freischalten](#auf-dem-iphone-freischalten).
3. In AltStore den Reiter **Sources** öffnen, **+** antippen und diese Adresse eintragen:

   ```
   https://github.com/Feuerbrand/led-app/releases/latest/download/altstore.json
   ```

4. In der Quelle **LED Control** antippen und installieren.

Ab jetzt zeigt AltStore jede neue Version unter **My Apps** an; **Update** tippen genügt. Die App selbst meldet sich ebenfalls („Update verfügbar“).

> Die Quelle gibt es erst, wenn die App einmal auf `main` veröffentlicht wurde (siehe [Updates](#updates--so-funktioniert-es)). Bis dahin: `.ipa` herunterladen (siehe unten), in AltStore unter **My Apps** oben links **+** antippen und die Datei auswählen.

AltStore zählt selbst als eine der drei Apps, die eine kostenlose Apple-ID gleichzeitig erlaubt.

## Weg 2: Sideloadly

1. `.ipa` herunterladen (siehe nächster Abschnitt).
2. iPhone per USB anschließen, entsperren und **„Diesem Computer vertrauen“** bestätigen.
3. Sideloadly starten. Das iPhone erscheint oben bei *iDevice*.
4. `LEDControl.ipa` in das Sideloadly-Fenster ziehen, bei *Apple ID* deine Apple-ID eintragen und **Start** drücken. Passwort und Bestätigungscode tippst du selbst ein.
5. Warten, bis unten **Done** steht, dann auf dem iPhone freischalten (nächster Abschnitt).

**Updates mit Sideloadly:** die neue `.ipa` herunterladen und genauso noch einmal installieren. Einstellungen, Lichter und Szenen bleiben erhalten.

## Die .ipa herunterladen

- **Fertige Versionen:** im Repository rechts unter **Releases** → oberste Version → `LEDControl.ipa`.
- **Jeder Build, auch Testversionen:** oben **Actions** → links **iOS-App bauen** → obersten Lauf mit grünem Haken öffnen → ganz unten unter **Artifacts** auf **LEDControl.ipa** klicken (dafür bei GitHub angemeldet sein). Der Browser speichert direkt die `.ipa` – nicht entpacken, auch wenn Windows sie als Archiv anzeigt. Diese Dateien bleiben 90 Tage abrufbar.

## Auf dem iPhone freischalten

Beim ersten Mal sind zwei Schalter nötig, sonst startet die App nicht:

1. **Entwickler vertrauen:** Einstellungen → Allgemein → VPN & Geräteverwaltung → unter *Entwickler-App* deine Apple-ID antippen → **Vertrauen**.
2. **Entwicklermodus einschalten:** Einstellungen → Datenschutz & Sicherheit → ganz unten **Entwicklermodus** → einschalten. Das iPhone startet neu; danach noch einmal **Einschalten** bestätigen. Der Punkt erscheint erst, nachdem eine App so installiert wurde.

Dann die App öffnen und **Bluetooth erlauben**. Lotus Lamp X vorher ganz schließen.

## Lichter hinzufügen

- **ELK-Leiste:** wird beim allerersten Start automatisch gefunden und übernommen.
- **Lichter aus Lotus Lamp X (MELK-…):** Reiter **Geräte** → unter **In der Nähe** beim Licht auf **Hinzufügen** tippen. Lotus Lamp X muss dafür geschlossen sein, denn ein Licht nimmt immer nur eine Verbindung an. MELK-Lichter werden nie von selbst verbunden.
- **Licht mit anderem Namen:** unter **Geräte** „Alle Bluetooth-Geräte zeigen“ einschalten. Die App versucht es dann mit den Befehlen der ELK-Leiste; das klappt nicht bei jedem Gerät.
- Der **Schalter** neben einem Licht verbindet bzw. trennt es. Nur verbundene Lichter werden mitgesteuert. Über **⋯** lässt sich ein Licht **blinken lassen** (zum Erkennen), **umbenennen** oder **entfernen**.
- Die **eingebauten Effekte** unterscheiden sich je nach Gerät. Unter **Effekte → Eingebaut** steht deshalb für jede Gerätesorte eine eigene Liste; ein Effekt geht nur an die passenden Lichter.

Die Befehle für die MELK-Lichter stammen aus dem Open-Source-Projekt [elkbledom](https://github.com/dave-code-ruiz/elkbledom) (MIT-Lizenz). Nach dem Verbinden meldet sich die App bei MELK-Lichtern an (zwei kurze Befehle, je 1 s Pause) – das dauert rund 2 Sekunden.

## Musik-Modus

**Effekte → Musik** antippen und das Mikrofon erlauben. Die App misst nur, wie laut es gerade ist; es wird nichts aufgenommen oder gespeichert. Die Farbe wandert durch den Regenbogen (Tempo-Regler), die Helligkeit springt mit der Musik und passt sich an die Lautstärke im Raum an. Musik vom selben iPhone läuft dabei weiter.

## Siri und Kurzbefehle

- „**Hey Siri, LED Control an**“ / „**… aus**“ / „**… umschalten**“
- In der **Kurzbefehle-App** gibt es außerdem „Szene starten“ (nach Name) und „Helligkeit setzen“ – gut für Automationen (z. B. Licht an bei Sonnenuntergang, wenn der Wecker klingelt) und für die Aktionstaste.
- Links für die Aktion „URL öffnen“ (in der App unter **Mehr** zum Kopieren):
  `ledcontrol://on`, `ledcontrol://off`, `ledcontrol://toggle`, `ledcontrol://color?hex=FF7A00`, `ledcontrol://brightness?value=40`, `ledcontrol://scene?name=Kino`, `ledcontrol://flow?id=rainbow`

Die App öffnet sich dafür kurz, verbindet sich und führt den Befehl aus.

## Updates – so funktioniert es

- Jede Änderung im Ordner `ios/` auf dem Zweig `main` baut die App neu und veröffentlicht sie als **GitHub-Release** `ios-v1.1.<Nummer>` mit `LEDControl.ipa` und der AltStore-Quelle `altstore.json`. Auf anderen Zweigen wird nur gebaut, nicht veröffentlicht.
- **AltStore** liest die Quelle und bietet das Update an.
- **Die App** sieht beim Öffnen nach (höchstens alle 30 Minuten, abschaltbar unter **Mehr**) und zeigt „Update verfügbar“. Selbst austauschen kann sich eine App unter iOS nicht – das übernimmt AltStore oder Sideloadly.

## Alle 7 Tage erneuern (kostenlose Apple-ID)

Mit einer kostenlosen Apple-ID gilt die Signatur nur **7 Tage**. Danach lässt sich die App nicht öffnen, bis sie neu signiert wird. Einstellungen, Lichter und Szenen bleiben dabei erhalten.

- **AltStore:** erneuert von selbst, solange AltServer auf dem PC läuft und das iPhone im selben WLAN ist (oder per USB angeschlossen). Sonst in AltStore unter *My Apps* **Refresh All** tippen.
- **Sideloadly:** die `.ipa` noch einmal installieren. Sideloadly kann das auch automatisch im Hintergrund erledigen, wenn der PC läuft; kabellos geht es, wenn einmal per USB installiert wurde und PC und iPhone im selben WLAN sind.

Weitere Grenzen der kostenlosen Apple-ID: höchstens **3** so installierte Apps gleichzeitig pro Gerät und höchstens 10 neue App-Kennungen in 7 Tagen.

## Was der bezahlte Entwickler-Account ändert

Das [Apple Developer Program](https://developer.apple.com/programs/) kostet 99 US-Dollar im Jahr (in Deutschland rund 99 €).

- Die Signatur gilt **ein Jahr** statt 7 Tage.
- Die Grenze von 3 Apps entfällt.
- Der Weg bleibt derselbe (AltStore oder Sideloadly mit der bezahlten Apple-ID). Zusätzlich möglich wären TestFlight oder ein alternativer Marktplatz in der EU; dafür müsste der Build-Workflow die App selbst signieren. Das ist hier nicht eingerichtet.

Für die App selbst macht es keinen Unterschied.

## Checkliste für den ersten Test

Diese Punkte konnten ohne iPhone und Lichter nicht ausprobiert werden:

- [ ] Installation klappt, die App startet und fragt nach Bluetooth.
- [ ] Die ELK-Leiste wird beim ersten Start von selbst gefunden und verbunden – ein MELK-Licht dagegen nicht.
- [ ] **An / Aus**, **Helligkeit** und **Farbe** (Farbwähler, beide Leisten, 12 Farbfelder) wirken an der Leiste.
- [ ] **Flow-Effekte:** alle acht laufen flüssig, Wechsel ohne Sprung, **Tempo** wirkt, nochmal Antippen hält an.
- [ ] **Musik-Modus:** fragt nach dem Mikrofon, die Leiste pulsiert mit der Musik.
- [ ] **Szenen:** antippen, speichern, lange drücken zum Löschen.
- [ ] **MELK-Licht** (Lotus Lamp X vorher schließen): unter **Geräte** hinzufügen, es verbindet sich (nach rund 2 s), An/Aus, Helligkeit, Farbe und seine eigenen eingebauten Effekte wirken. Beide Lichter folgen gemeinsam.
- [ ] **Geräte:** Schalter trennt/verbindet, **Blinken lassen** blinkt das richtige Licht, Umbenennen, Entfernen, Empfangsbalken.
- [ ] **Neu verbinden:** Licht kurz vom Strom nehmen, außer Reichweite gehen, Bluetooth aus und an, App in den Hintergrund und zurück – jedes Mal verbindet sie von allein wieder.
- [ ] **Siri:** „Hey Siri, LED Control an“ und „… aus“; ein Link wie `ledcontrol://color?hex=FF7A00` aus Safari oder Kurzbefehle.
- [ ] **Updates** (erst nach der ersten Veröffentlichung auf `main`): AltStore-Quelle hinzufügen, App erscheint dort; nach einer neuen Version zeigt die App „Update verfügbar“.
- [ ] Der Bildschirm bleibt an, solange ein Flow läuft, und geht danach wieder normal aus.
- [ ] Aussehen: Geist-Schrift, die Lampe oben leuchtet in der Farbe der Lichter, Regler und Leisten lassen sich gut ziehen.

Wenn etwas hakt, hilft das **Protokoll** unter **Mehr**: den Text lange gedrückt halten, kopieren und mitschicken.

## Gut zu wissen

- Flow-Effekte und der Musik-Modus laufen, solange die App offen und im Vordergrund ist. Wird das iPhone gesperrt oder die App gewechselt, bleiben die Lichter auf der letzten Farbe stehen. Die eingebauten Effekte laufen im Licht selbst weiter.
- Die Webseite (`index.html`) bleibt unverändert und funktioniert weiter wie bisher.

## Aufbau

| Datei | Inhalt |
| --- | --- |
| `project.yml` | Beschreibung des Xcode-Projekts für [XcodeGen](https://github.com/yonaskolb/XcodeGen); das `.xcodeproj` wird daraus erzeugt und liegt nicht im Repository |
| `LEDControl/Command.swift` | Befehle und Bauarten: ELK-Leiste (wie `index.html`), weitere ELK-Geräte, MELK-Varianten, eingebaute Effekte je Bauart |
| `LEDControl/LightHub.swift` | Bluetooth: suchen, mehrere Lichter verbinden und neu verbinden, MELK-Anmeldung, je Licht eine Sende-Warteschlange |
| `LEDControl/LightController.swift` | Zustand und Lichtlogik (An/Aus, Farbe, Flows, Musik, Szenen, Kurzbefehle) |
| `LEDControl/ColorMath.swift`, `Flows.swift`, `SendQueue.swift` | Farbrechnung, Flow-Effekte und Sende-Regel, aus `index.html` übernommen |
| `LEDControl/SoundMeter.swift`, `Scenes.swift`, `Updater.swift`, `Intents.swift` | Musik-Pegel, Szenen und Speichern, Update-Prüfung, Siri/Kurzbefehle |
| `LEDControl/ContentView.swift`, `LightTab.swift`, `EffectsTab.swift`, `DevicesTab.swift`, `MoreTab.swift` | die vier Reiter |
| `LEDControl/Backdrop.swift`, `Controls.swift`, `Icons.swift`, `Theme.swift` | Hintergrund, Lampe, Bedienelemente, Symbole, Farben und Schrift |
| `LEDControl/Fonts/` | Geist und Geist Mono als `.ttf`, umgewandelt aus den `.woff2`-Dateien in `fonts/` (Lizenz: `OFL.txt`) |
| `Tests/` | Selbsttest: `make-expected.mjs` berechnet Soll-Werte mit dem echten Code aus `index.html`, `main.swift` vergleicht die App-Logik damit und prüft die MELK-Bytes. Läuft bei jedem Build. |
| `scripts/make-source.py` | erzeugt die AltStore-Quelle aus der fertigen `.ipa` |
| `../.github/workflows/ios.yml` | Build auf GitHub, auf `main` zusätzlich Veröffentlichung |

Wer doch einmal einen Mac hat: `brew install xcodegen`, im Ordner `ios` `xcodegen generate` ausführen und `LEDControl.xcodeproj` in Xcode öffnen.

Ändert sich die Rechenlogik in `index.html`, die Soll-Werte neu erzeugen: `node ios/Tests/make-expected.mjs`.
