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

## Weg 3: Apple-Entwickler-Account und TestFlight – ohne PC und Kabel

Mit dem bezahlten [Apple Developer Program](https://developer.apple.com/programs/) (99 €/Jahr) lädt GitHub jede neue Version direkt zu Apple hoch. Auf dem iPhone installierst du sie mit Apples App **TestFlight** aus dem App Store – ohne Kabel, ohne Entwicklermodus, ohne „Vertrauen“. TestFlight aktualisiert die App von selbst. Jede Version läuft 90 Tage; GitHub baut deshalb jeden Monat automatisch eine neue.

Die folgenden Schritte machst du selbst – Anmeldung, Bezahlung und Schlüssel gehören zu deinem Konto. Alles geht im Browser am PC oder am iPhone.

**1. Beim Apple Developer Program anmelden**
- Am einfachsten mit der App **Apple Developer** aus dem App Store: *Konto* → mit deiner Apple-ID anmelden → **Jetzt registrieren** → als **Einzelperson** → 99 € bezahlen.
- Oder im Browser: [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/).
- Die Freischaltung kann bis zu zwei Tage dauern; Apple schickt eine E-Mail.

**2. App-Kennung anlegen**
- [developer.apple.com/account](https://developer.apple.com/account) → **Certificates, IDs & Profiles** → **Identifiers** → **+** → **App IDs** → **App** → Weiter.
- *Description:* `LED Control`, *Bundle ID:* **Explicit** → `de.feuerbrand.ledcontrol`. Keine Häkchen bei den Funktionen nötig → **Register**.
- Meldet Apple, dass die Kennung vergeben ist, schreib mir – dann ändere ich sie in der App.

**3. App in App Store Connect anlegen**
- [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps** → **+** → **Neue App**.
- Plattform **iOS**, *Name* muss im ganzen App Store einmalig sein, z. B. `LED Control Feuerbrand` (auf dem Home-Bildschirm steht trotzdem „LED Control“), Sprache **Deutsch**, *Bundle-ID* die aus Schritt 2, *SKU* `ledcontrol`, Zugriff **Voller Zugriff** → **Erstellen**.
- Die App wird damit **nicht** im App Store veröffentlicht; sie bleibt privat für TestFlight.

**4. API-Schlüssel für GitHub erstellen**
- App Store Connect → **Benutzer und Zugriff** → **Integrationen** → **App Store Connect API** → **Team-Schlüssel** (beim ersten Mal „Zugriff anfordern“ bestätigen).
- **+** → Name `GitHub`, Zugriff **Admin** → **Generieren**. *Admin* ist nötig, damit GitHub die App selbst signieren darf.
- **API-Schlüssel herunterladen** – das geht nur ein einziges Mal. Die Datei heißt `AuthKey_XXXXXXXXXX.p8`.
- Notiere die **Schlüssel-ID** (in der Liste) und die **Issuer-ID** (oben über der Liste).

**5. Team-ID nachsehen**
- [developer.apple.com/account](https://developer.apple.com/account) → **Mitgliedschaftsdetails** → **Team-ID** (10 Zeichen).

**6. Die vier Werte bei GitHub hinterlegen**
- [github.com/Feuerbrand/led-app](https://github.com/Feuerbrand/led-app) → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**, viermal:

  | Name | Wert |
  | --- | --- |
  | `ASC_KEY_ID` | Schlüssel-ID aus Schritt 4 |
  | `ASC_ISSUER_ID` | Issuer-ID aus Schritt 4 |
  | `ASC_KEY_P8` | den **ganzen Text** der `.p8`-Datei (mit dem Editor öffnen, alles kopieren, inklusive der Zeilen `-----BEGIN PRIVATE KEY-----` und `-----END PRIVATE KEY-----`) |
  | `APPLE_TEAM_ID` | Team-ID aus Schritt 5 |

- Secrets sind nur für die Builds sichtbar, nicht für Besucher der Seite. Den Schlüssel sonst nirgends weitergeben und die `.p8`-Datei danach sicher aufbewahren oder löschen.

**7. Dich als Tester eintragen**
- App Store Connect → deine App → **TestFlight** → bei **Interne Tests** auf **+** → Gruppe `Ich` → dich selbst hinzufügen → **Automatische Verteilung** eingeschaltet lassen.

**8. Ersten Build starten**
- Oben **Actions** → **iOS-App bauen** → **Run workflow** (oder mir Bescheid sagen, dann stoße ich ihn an). Der Schritt **TestFlight** baut, signiert und lädt hoch; danach verarbeitet Apple die Version noch 10–30 Minuten.

**9. Auf dem iPhone installieren**
- **TestFlight** aus dem App Store laden, die Einladungs-E-Mail von Apple öffnen (oder TestFlight öffnen) → **LED Control** → **Installieren**.
- In TestFlight bei LED Control **Automatische Updates** einschalten.

Ab dann kommt jede Änderung an der App von selbst aufs iPhone. GitHub pausiert monatliche Läufe, wenn 60 Tage lang nichts am Repository geändert wurde; dann auf der Seite **Actions** einmal **Enable workflow** drücken.

## Weg 4: Im App Store veröffentlichen

Läuft TestFlight (Weg 3), kann dieselbe App in den App Store – ohne Zusatzkosten, solange sie kostenlos ist. Vorbereitet ist schon:

- **Vorführmodus:** Apple hat keine Leiste zum Testen. Auf dem ersten Bildschirm gibt es deshalb **„Ohne Licht ausprobieren“**, unter **Geräte** den Schalter **Vorführmodus**.
- **App-Store-Version:** Kommt die App aus dem App Store oder TestFlight, blendet sie alles zu AltStore, GitHub-Downloads und der eigenen Update-Prüfung aus und stellt keine Internetverbindung her.
- **Bildschirmfotos:** Jeder Build nimmt im Simulator vier Bilder im größten iPhone-Format auf (Artifact **app-store-bilder** im Lauf auf GitHub).
- **Texte:** [appstore/APPSTORE.md](appstore/APPSTORE.md) – Untertitel, Beschreibung, Schlüsselwörter, Hinweise für die Prüfer, Antworten zu Datenschutz und Altersfreigabe.
- **Datenschutzerklärung und Hilfeseite:** [DATENSCHUTZ.md](DATENSCHUTZ.md) und [SUPPORT.md](SUPPORT.md).

**Was du dann noch machst:**

1. In `DATENSCHUTZ.md` und `SUPPORT.md` die Platzhalter in eckigen Klammern (Name, Anschrift, E-Mail) ausfüllen – direkt auf GitHub über das Stift-Symbol oder mir die Angaben geben. Die Seiten sind öffentlich.
2. **App Store Connect → deine App → App-Informationen:** Untertitel, Kategorie, Inhaltsrechte, Altersfreigabe und die Datenschutz-URL aus `APPSTORE.md` eintragen.
3. **App-Datenschutz:** „Nein, wir erfassen keine Daten“.
4. **Preise und Verfügbarkeit:** kostenlos.
5. **Händlerstatus** (EU): siehe Ende von `APPSTORE.md`.
6. Links die **iOS-Version** öffnen: Versionsnummer auf die des Builds setzen (z. B. `1.1.12`), Bildschirmfotos hochladen, Werbetext, Beschreibung, Schlüsselwörter, Support-URL und Copyright einfügen, unter **Build** den neuesten auswählen, bei **App-Prüfung** Kontakt und die Notizen samt Video-Link eintragen.
7. **Zur Prüfung hinzufügen** → **Zur Prüfung einreichen.** Die Prüfung dauert meist ein bis drei Tage. Lehnt Apple ab, steht der Grund in App Store Connect – schick ihn mir.

Nach der Freigabe aktualisiert sich die App wie jede andere über den App Store. Für jede neue App-Store-Version wiederholst du Schritt 6 und 7 mit dem neuen Build.

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
- **TestFlight** (Weg 3): Sind die Secrets eingerichtet, lädt jeder Build die App zusätzlich zu Apple hoch – auch von anderen Zweigen, damit du Änderungen vor dem Übernehmen testen kannst. TestFlight aktualisiert die App dann von selbst; die App zeigt in diesem Fall keinen eigenen Update-Hinweis.
- **Die App** sieht beim Öffnen nach (höchstens alle 30 Minuten, abschaltbar unter **Mehr**) und zeigt „Update verfügbar“. Selbst austauschen kann sich eine App unter iOS nicht – das übernimmt AltStore oder Sideloadly.

## Alle 7 Tage erneuern (kostenlose Apple-ID)

Mit einer kostenlosen Apple-ID gilt die Signatur nur **7 Tage**. Danach lässt sich die App nicht öffnen, bis sie neu signiert wird. Einstellungen, Lichter und Szenen bleiben dabei erhalten.

- **AltStore:** erneuert von selbst, solange AltServer auf dem PC läuft und das iPhone im selben WLAN ist (oder per USB angeschlossen). Sonst in AltStore unter *My Apps* **Refresh All** tippen.
- **Sideloadly:** die `.ipa` noch einmal installieren. Sideloadly kann das auch automatisch im Hintergrund erledigen, wenn der PC läuft; kabellos geht es, wenn einmal per USB installiert wurde und PC und iPhone im selben WLAN sind.

Weitere Grenzen der kostenlosen Apple-ID: höchstens **3** so installierte Apps gleichzeitig pro Gerät und höchstens 10 neue App-Kennungen in 7 Tagen.

## Was der bezahlte Entwickler-Account ändert

Das [Apple Developer Program](https://developer.apple.com/programs/) kostet 99 US-Dollar im Jahr (in Deutschland rund 99 €).

- **TestFlight** wird möglich: Installation und Updates ohne PC und Kabel, siehe [Weg 3](#weg-3-apple-entwickler-account-und-testflight--ohne-pc-und-kabel). Der Build-Workflow ist dafür schon eingerichtet und wartet nur auf die vier Secrets.
- Mit AltStore oder Sideloadly gilt die Signatur **ein Jahr** statt 7 Tage, und die Grenze von 3 Apps entfällt.

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
| `LEDControl/PrivacyInfo.xcprivacy` | Datenschutz-Angaben für Apple (keine Datensammlung) |
| `DATENSCHUTZ.md`, `SUPPORT.md`, `appstore/APPSTORE.md` | Datenschutzerklärung, Hilfeseite und alle Texte für den App Store |
| `../.github/workflows/ios.yml` | Build auf GitHub, auf `main` zusätzlich Veröffentlichung |

Wer doch einmal einen Mac hat: `brew install xcodegen`, im Ordner `ios` `xcodegen generate` ausführen und `LEDControl.xcodeproj` in Xcode öffnen.

Ändert sich die Rechenlogik in `index.html`, die Soll-Werte neu erzeugen: `node ios/Tests/make-expected.mjs`.
