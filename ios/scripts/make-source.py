#!/usr/bin/env python3
"""Erzeugt die AltStore-Quelle (altstore.json) für eine neue Version der App.

Aufruf im Build-Workflow:
  python3 ios/scripts/make-source.py --ipa LEDControl.ipa --tag ios-v1.1.42 --repo Feuerbrand/led-app \
      --previous prev/altstore.json --out altstore.json

Die Datenschutz-Texte (…UsageDescription) werden direkt aus der Info.plist der .ipa gelesen,
weil AltStore die Installation ablehnt, wenn sie nicht zur App passen.
Ältere Versionen aus --previous bleiben erhalten (neueste zuerst, höchstens 10).
"""
import argparse
import datetime
import json
import os
import plistlib
import zipfile


def read_info(ipa):
    with zipfile.ZipFile(ipa) as z:
        name = next(n for n in z.namelist()
                    if n.startswith("Payload/") and n.endswith(".app/Info.plist") and n.count("/") == 2)
        return plistlib.loads(z.read(name))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ipa", required=True)
    ap.add_argument("--tag", required=True)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--previous")
    ap.add_argument("--notes", default="")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    info = read_info(a.ipa)
    version = info["CFBundleShortVersionString"]
    build = info["CFBundleVersion"]
    bundle = info["CFBundleIdentifier"]
    assert a.tag == "ios-v" + version, (a.tag, version)

    base = "https://github.com/%s/releases/download/%s/" % (a.repo, a.tag)
    entry = {
        "version": version,
        "buildVersion": build,
        "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "localizedDescription": a.notes or ("Version %s" % version),
        "downloadURL": base + "LEDControl.ipa",
        "size": os.path.getsize(a.ipa),
        "minOSVersion": info.get("MinimumOSVersion", "17.0"),
    }

    older = []
    if a.previous and os.path.exists(a.previous):
        try:
            with open(a.previous, encoding="utf-8") as f:
                prev = json.load(f)
            for app in prev.get("apps", []):
                if app.get("bundleIdentifier") == bundle:
                    older = [v for v in app.get("versions", []) if v.get("version") != version]
        except (ValueError, OSError):
            older = []

    privacy = {k: v for k, v in sorted(info.items()) if k.endswith("UsageDescription")}

    source = {
        "name": "LED Control",
        "subtitle": "Lichtsteuerung für ELK-BLEDOM und MELK",
        "description": "Eigene App für ELK-BLEDOM-Leisten und MELK-Lichter.",
        "iconURL": base + "icon.png",
        "website": "https://github.com/%s" % a.repo,
        "tintColor": "#FFD23F",
        "apps": [{
            "name": "LED Control",
            "bundleIdentifier": bundle,
            "developerName": a.repo.split("/")[0],
            "subtitle": "Licht, Farbe und Effekte über Bluetooth",
            "localizedDescription": "Steuert ELK-BLEDOM-Leisten und MELK-Lichter (Lotus Lamp X) direkt über "
                                    "Bluetooth: Farben, Helligkeit, Flow-Effekte, Musik-Modus, Szenen und Siri.",
            "iconURL": base + "icon.png",
            "tintColor": "#FFD23F",
            "category": "utilities",
            "versions": [entry] + older[:9],
            "appPermissions": {
                "entitlements": [],
                "privacy": privacy,
            },
        }],
        "news": [],
    }

    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(source, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("AltStore-Quelle:", a.out, "Version", version, "Build", build, "ältere:", len(older[:9]))


if __name__ == "__main__":
    main()
