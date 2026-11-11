# App-Store-Angaben zum Kopieren

Alles, was App Store Connect für die Veröffentlichung abfragt, in der Reihenfolge der Seiten. Die Längen sind geprüft (Apples Grenzen in Klammern).

## App-Informationen

| Feld | Eintrag |
| --- | --- |
| Name (30) | Muss im ganzen App Store einmalig sein. Vorschläge: `LED Control Feuerbrand`, `Glow – LED Strip Control`, `LED Leiste – Farben & Musik` |
| Untertitel (30) | `Farben, Effekte & Musik-Modus` |
| Kategorie | **Dienstprogramme**, zweite Kategorie **Lifestyle** |
| Inhaltsrechte | „Ja, enthält Inhalte Dritter“ → Rechte vorhanden (Schrift *Geist*, SIL Open Font License) |
| Altersfreigabe | Alle Fragen mit **Keine** bzw. **Nein** beantworten → **4+** |
| Datenschutzrichtlinie (URL) | `https://github.com/Feuerbrand/led-app/blob/main/ios/DATENSCHUTZ.md` (erst nach dem Übernehmen in `main` erreichbar; vorher die Platzhalter darin ausfüllen) |

## App-Datenschutz

**„Erfassen Sie oder Ihre Drittpartner Daten aus dieser App?“** → **Nein, wir erfassen keine Daten aus dieser App.**

## Preise und Verfügbarkeit

**Kostenlos**, alle Länder oder nur Deutschland/EU – wie du möchtest.

## Version (z. B. „1.1.12“ – muss zur Build-Nummer passen)

**Werbetext (170)**
```
Deine LED-Leiste, endlich richtig gesteuert: Farbe abfotografieren, Musik-Modus, Gute Nacht und ein Knopf im Kontrollzentrum.
```

**Beschreibung (4000)**
```
Steuere deine Bluetooth-LED-Leisten direkt vom iPhone – schnell, schön und ohne Umwege.

LED Control verbindet sich von selbst mit deinen Lichtern. Im Hauptmenü schimmert jedes Licht in seiner Farbe – antippen und nur dieses Licht steuern, oder alle zusammen.

FARBE ABFOTOGRAFIEREN
• Kamera auf etwas halten – auf ein Kissen, ein Poster, ein Getränk – und dein Licht leuchtet live in genau dieser Farbe

LICHT
• An/Aus und große Helligkeits-Leiste, für jedes Licht einzeln oder alle zusammen
• Farbrad, Weißton-Leiste und deine zuletzt benutzten Farben
• Szenen speichern und mit einem Tippen abrufen
• Gute Nacht: alle Lichter werden warm und dimmen in 10 Minuten bis aus
• Aufwachen: ein Sonnenaufgang in 90 Sekunden

EFFEKTE
• Acht fließende Effekte: Regenbogen, Polarlicht, Sonnenuntergang, Ozean, Lava, Neon, Atmen und Kerzenschein – weich überblendet, ohne Sprünge
• Welle: Bei mehreren Lichtern wandert die Farbe von Licht zu Licht
• Musik-Modus: Die Lichter pulsieren im Takt deiner Musik. Die App misst nur die Lautstärke, es wird nichts aufgenommen.
• Tempo frei einstellbar
• Dazu die eingebauten Effekte deiner Lichter

LICHTER
• Neue Lichter mit einem Tippen hinzufügen – es werden nur passende LED-Lichter angezeigt
• Eigene Namen wie „Wohnzimmer“ oder „Bett“
• Blinken lassen, umbenennen, verbinden und trennen
• Verbindet sich nach Abbrüchen von selbst neu

KONTROLLZENTRUM, SPERRBILDSCHIRM UND SIRI
• Knöpfe für das Kontrollzentrum und den Sperrbildschirm: an/aus und Gute Nacht
• Widgets für den Home-Bildschirm
• „Hey Siri, LED Control an“ und „… aus“
• Szenen und Helligkeit in der Kurzbefehle-App – für Automationen und die Aktionstaste

PASSENDE LICHTER
LED-Leisten und -Lampen mit Bluetooth, die sich als „ELK-BLEDOM“ oder „MELK“ melden. Solche Steuerungen stecken in vielen günstigen LED-Strips. Ohne Licht lässt sich die App im Vorführmodus ausprobieren.

DATENSCHUTZ
Kein Konto, keine Werbung, kein Tracking. Die App erhebt keine Daten und braucht keine Internetverbindung.
```

**Schlüsselwörter (100)**
```
LED,Leiste,Lichtleiste,Strip,RGB,Bluetooth,Licht,Farbe,Kamera,Effekte,Musik,Lampe,ELK,BLEDOM,Widget
```

**Support-URL**
```
https://github.com/Feuerbrand/led-app/blob/main/ios/SUPPORT.md
```

**Copyright**
```
2026 [dein Name oder deine Firma]
```

**Bildschirmfotos:** die Bilder aus dem GitHub-Lauf (Artifact **app-store-bilder**) beim größten iPhone-Format hochladen. Die kleineren Formate erzeugt Apple daraus selbst.

## Informationen zur App-Prüfung

- **Anmeldung erforderlich:** Nein
- **Kontakt:** dein Name, Telefonnummer, E-Mail (sieht nur Apple)
- **Notizen** (auf Englisch, die Prüfer arbeiten weltweit):

```
LED Control controls Bluetooth LE LED strips and lamps (controllers that advertise as "ELK-BLEDOM" or "MELK", GATT service FFF0).

No hardware? Every feature can be tried in demo mode: on the home screen tap "Ohne Licht ausprobieren" (try without a light), or open the settings (gear icon, top right) → "Lichter verwalten" and switch on "Vorführmodus". Then tap "Alle steuern" – color, effects and scenes ("Farbe", "Effekte", "Szenen") work without a connected light. On first launch a short introduction is shown; it can be skipped ("Überspringen").

Video of the app controlling a real LED strip: [LINK ZUM VIDEO]

No account or login. The microphone is only used in the optional music mode ("Effekte" → "Musik") to measure loudness; nothing is recorded, stored or transmitted. The camera is only used in the optional "Farbe abfotografieren" feature ("Farbe" tab): the app reads the average color in the center of the live image to set the light; no photo or video is taken, stored or transmitted. The app makes no network connections.

Control Center / Lock Screen controls and widgets open the app briefly to send the command over Bluetooth.

Siri: "LED Control an" / "LED Control aus".
```

Ein **kurzes Video** (30 Sekunden genügen: App öffnen, Leiste verbindet sich, Farbe und ein Effekt wechseln) hilft sehr, weil Apple keine Leiste zum Testen hat. Am einfachsten mit der Bildschirmaufnahme des iPhones aufnehmen und das Licht gleichzeitig mit einem zweiten Handy filmen – oder das Licht im Hintergrund mit ins Bild nehmen. Hochladen z. B. als nicht gelistetes YouTube-Video und den Link oben eintragen.

## Händlerstatus (EU, Digital Services Act)

App Store Connect fragt, ob du **Händler** bist. Bietest du die App im Rahmen deines Gewerbes an, ist das „Ja“ – dann zeigt Apple in der EU **deine Adresse, Telefonnummer und E-Mail öffentlich** auf der App-Seite an. Ist die App ein privates Projekt außerhalb deines Gewerbes, kannst du „Nein“ angeben. Im Zweifel bei deinem Steuerberater nachfragen.
