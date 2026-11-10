# LED Control für iPhone

Die Webseite aus diesem Repository als echte iPhone-App: gleiche Bedienung, gleiche Effekte, gleicher Stil – aber ohne Bluefy.
Die App sucht beim Start selbst nach der Leiste (Name beginnt mit `ELK-BLED`), verbindet ohne Geräteliste und verbindet von allein neu, wenn die Verbindung abreißt.

Die App kommt nicht aus dem App Store. GitHub baut sie auf einem Mac in der Cloud, du lädst die fertige Datei `LEDControl.ipa` herunter und installierst sie vom Windows-PC aus mit deiner eigenen Apple-ID.

> **Stand:** Die App wurde kompiliert und die Rechenlogik automatisch gegen die Webseite geprüft. **Auf einem echten iPhone mit der Leiste wurde sie noch nicht ausprobiert.** Was du beim ersten Start prüfen solltest, steht unten unter [Checkliste](#checkliste-für-den-ersten-test).

## Was du brauchst

- iPhone mit iOS 17 oder neuer und ein USB-Kabel
- Windows-PC mit **iTunes** und **iCloud**, beide direkt von Apple heruntergeladen – **nicht** die Versionen aus dem Microsoft Store. Sind die Store-Versionen installiert, erst deinstallieren. Die richtigen Installer sind auf [sideloadly.io](https://sideloadly.io/) verlinkt.
- [Sideloadly](https://sideloadly.io/) (kostenlos) – oder alternativ [AltStore](https://altstore.io/)
- eine Apple-ID (die kostenlose reicht)

## 1. App herunterladen

1. Auf GitHub anmelden und im Repository oben auf **Actions** gehen.
2. Links **iOS-App bauen** wählen und den obersten Lauf mit grünem Haken öffnen.
3. Ganz unten unter **Artifacts** auf **LEDControl.ipa** klicken. Der Browser speichert direkt die Datei `LEDControl.ipa` (nicht entpacken, auch wenn Windows sie als Archiv anzeigt).

Die Datei bleibt 90 Tage abrufbar. Ist sie abgelaufen oder willst du einen frischen Build: auf der Seite **iOS-App bauen** rechts **Run workflow** drücken und ein paar Minuten warten. Bei jeder Änderung im Ordner `ios/` baut GitHub außerdem automatisch neu.

## 2. Mit Sideloadly installieren

1. iPhone per USB anschließen, entsperren und auf dem iPhone **„Diesem Computer vertrauen“** bestätigen.
2. Sideloadly starten. Das iPhone erscheint oben bei *iDevice*.
3. `LEDControl.ipa` in das Sideloadly-Fenster ziehen.
4. Bei *Apple ID* deine Apple-ID eintragen und **Start** drücken. Sideloadly fragt nach dem Passwort und dem Bestätigungscode (Zwei-Faktor) – beides tippst du selbst ein. Damit holt Sideloadly bei Apple das Zertifikat, mit dem die App für dein iPhone signiert wird. Wer das nicht mit seiner Haupt-Apple-ID machen möchte, legt dafür eine zweite, kostenlose Apple-ID an.
5. Warten, bis unten **Done** steht. Die App **LED Control** liegt jetzt auf dem Home-Bildschirm.

## 3. Auf dem iPhone freischalten

Beim ersten Mal sind zwei Schalter nötig, sonst startet die App nicht:

1. **Entwickler vertrauen:** Einstellungen → Allgemein → VPN & Geräteverwaltung → unter *Entwickler-App* deine Apple-ID antippen → **Vertrauen**.
2. **Entwicklermodus einschalten:** Einstellungen → Datenschutz & Sicherheit → ganz unten **Entwicklermodus** → einschalten. Das iPhone startet neu; danach noch einmal **Einschalten** bestätigen. Der Punkt erscheint erst, nachdem die App installiert wurde.

Dann die App öffnen und die Frage **„LED Control möchte Bluetooth verwenden“** mit **Erlauben** beantworten. Die Leiste wird gesucht und verbunden; Lotus Lamp X vorher schließen.

## Alternative: AltStore

AltStore macht dasselbe, läuft aber als eigene App auf dem iPhone und erneuert die Signatur selbst.

1. **AltServer** auf dem PC installieren (Anleitung: [faq.altstore.io](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)) und darüber AltStore aufs iPhone bringen. Auch hier: iTunes und iCloud direkt von Apple, Apple-ID selbst eintippen, danach Entwickler vertrauen und Entwicklermodus einschalten wie oben.
2. `LEDControl.ipa` aufs iPhone bringen (z. B. über iCloud Drive oder direkt am iPhone von GitHub laden).
3. In AltStore den Reiter **My Apps** öffnen, oben links **+** antippen und die `.ipa` auswählen.

AltStore zählt selbst als eine der drei erlaubten Apps (siehe unten).

## Alle 7 Tage erneuern (kostenlose Apple-ID)

Mit einer kostenlosen Apple-ID gilt die Signatur nur **7 Tage**. Danach lässt sich die App nicht mehr öffnen, bis sie neu signiert wird. Die Einstellungen (gemerkte Leiste) bleiben dabei erhalten.

- **Sideloadly:** iPhone anschließen und dieselbe `.ipa` noch einmal installieren. Sideloadly kann das auch automatisch im Hintergrund erledigen, wenn der PC läuft; kabellos geht es, wenn einmal per USB installiert wurde und PC und iPhone im selben WLAN sind.
- **AltStore:** erneuert von selbst, solange AltServer auf dem PC läuft und das iPhone im selben WLAN ist (oder per USB angeschlossen). Sonst in AltStore unter *My Apps* auf **Refresh All** tippen.

Weitere Grenzen der kostenlosen Apple-ID: höchstens **3** so installierte Apps gleichzeitig pro Gerät und höchstens 10 neue App-Kennungen in 7 Tagen.

## Was der bezahlte Entwickler-Account ändert

Das [Apple Developer Program](https://developer.apple.com/programs/) kostet 99 US-Dollar im Jahr (in Deutschland rund 99 €).

- Die Signatur gilt **ein Jahr** statt 7 Tage – einmal installieren, ein Jahr Ruhe.
- Die Grenze von 3 Apps entfällt.
- Der Weg bleibt derselbe (Sideloadly oder AltStore mit der bezahlten Apple-ID). Zusätzlich möglich wären TestFlight oder ein alternativer Marktplatz in der EU; dafür müsste der Build-Workflow die App selbst signieren. Das ist hier nicht eingerichtet.

Für die App selbst macht es keinen Unterschied, sie ist in beiden Fällen dieselbe.

## Checkliste für den ersten Test

Diese Punkte konnten ohne iPhone und Leiste nicht ausprobiert werden:

- [ ] Installation klappt, die App startet und fragt nach Bluetooth.
- [ ] Sie verbindet sich von selbst mit der Leiste (Status „Verbunden mit ELK-BLEDDM“) – und nicht mit dem MELK-Controller nebenan.
- [ ] **An / Aus** und **Helligkeit** wirken.
- [ ] **Farbe:** Farbfeld (öffnet den Farbwähler), Farbton-Leiste, Weißton-Leiste und die 12 Farbfelder zeigen an der Leiste die richtige Farbe.
- [ ] **Flow-Effekte:** alle acht laufen flüssig, der Wechsel überblendet ohne Sprung, **Tempo** wirkt, nochmal Antippen hält an.
- [ ] **Standard-Effekte der Leiste** starten, Tempo wirkt auch dort.
- [ ] **Neu verbinden:** Leiste kurz vom Strom nehmen, außer Reichweite gehen, Bluetooth aus und wieder an, App in den Hintergrund und zurück – jedes Mal sollte sie von allein wieder verbinden.
- [ ] Der Bildschirm bleibt an, solange ein Flow läuft, und geht danach wieder normal aus.
- [ ] Aussehen: Geist-Schrift, die Lampe oben leuchtet in der Farbe der Leiste, Regler und Leisten lassen sich gut ziehen, ohne dass die Seite dabei wegscrollt.

Wenn etwas hakt, hilft das **Protokoll** ganz unten in der App: den Text dort lange gedrückt halten, kopieren und mitschicken.

## Gut zu wissen

- Flow-Effekte berechnet die App selbst. Sie laufen, solange die App offen und im Vordergrund ist. Wird das iPhone gesperrt oder die App gewechselt, bleibt die Leiste auf der letzten Farbe stehen. Die eingebauten Effekte der Leiste laufen auch ohne App weiter.
- Die Webseite (`index.html`) bleibt unverändert und funktioniert weiter wie bisher.

## Aufbau

| Datei | Inhalt |
| --- | --- |
| `project.yml` | Beschreibung des Xcode-Projekts für [XcodeGen](https://github.com/yonaskolb/XcodeGen); das `.xcodeproj` wird daraus erzeugt und liegt nicht im Repository |
| `LEDControl/Command.swift` | die 9-Byte-Befehle der Leiste |
| `LEDControl/BLEManager.swift` | Bluetooth: suchen, verbinden, neu verbinden, schreiben |
| `LEDControl/LightController.swift` | Zustand und Lichtlogik (An/Aus, Farbe, Flows, Tempo) |
| `LEDControl/ColorMath.swift`, `Flows.swift`, `SendQueue.swift` | Farbrechnung, die acht Flow-Effekte und die Sende-Warteschlange, aus `index.html` übernommen |
| `LEDControl/ContentView.swift`, `Backdrop.swift`, `Controls.swift`, `Icons.swift`, `Theme.swift` | Oberfläche |
| `LEDControl/Fonts/` | Geist und Geist Mono als `.ttf`, umgewandelt aus den `.woff2`-Dateien in `fonts/` (Lizenz: `OFL.txt`) |
| `Tests/` | Selbsttest: `make-expected.mjs` berechnet Soll-Werte mit dem echten Code aus `index.html`, `main.swift` vergleicht die App-Logik damit. Läuft bei jedem Build. |
| `../.github/workflows/ios.yml` | der Build auf GitHub |

Wer doch einmal einen Mac hat: `brew install xcodegen`, im Ordner `ios` `xcodegen generate` ausführen und `LEDControl.xcodeproj` in Xcode öffnen.

Ändert sich die Rechenlogik in `index.html`, die Soll-Werte neu erzeugen: `node ios/Tests/make-expected.mjs`.
