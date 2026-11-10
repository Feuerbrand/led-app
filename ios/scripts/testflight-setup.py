#!/usr/bin/env python3
"""Richtet TestFlight ein, damit niemand in App Store Connect klicken muss:
eine interne Testgruppe „Ich“, die jede neue Version automatisch bekommt, mit allen Mitgliedern
des Entwickler-Kontos als Testern.

Läuft im Build-Workflow mit dem App-Store-Connect-API-Schlüssel:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (Pfad zur .p8-Datei)
  python3 testflight-setup.py de.feuerbrand.ledcontrol

Das Protokoll der Läufe ist öffentlich, deshalb gibt das Skript keine Namen oder E-Mail-Adressen aus.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt  # PyJWT

API = "https://api.appstoreconnect.apple.com/v1"


def make_token():
    with open(os.environ["ASC_KEY_PATH"], encoding="utf-8") as f:
        key = f.read()
    now = int(time.time())
    payload = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


TOKEN = make_token()


def call(method, path, body=None):
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + TOKEN,
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = ""
        try:
            errors = json.loads(e.read()).get("errors", [])
            detail = "; ".join("%s: %s" % (x.get("code", ""), x.get("title", "")) for x in errors)
        except ValueError:
            pass
        raise SystemExit("App Store Connect lehnt %s %s ab (HTTP %d) %s" % (method, path.split("?")[0], e.code, detail))


def all_pages(path):
    items, url = [], path
    while url:
        page = call("GET", url)
        items += page.get("data", [])
        url = page.get("links", {}).get("next")
    return items


def main():
    bundle = sys.argv[1] if len(sys.argv) > 1 else "de.feuerbrand.ledcontrol"

    apps = call("GET", "/apps?" + urllib.parse.urlencode({"filter[bundleId]": bundle}))["data"]
    if not apps:
        raise SystemExit("In App Store Connect gibt es noch keine App mit der Bundle-ID %s." % bundle)
    app_id = apps[0]["id"]

    groups = all_pages("/apps/%s/betaGroups?limit=200" % app_id)
    internal = [g for g in groups if g["attributes"].get("isInternalGroup")]
    if internal:
        group = internal[0]
        print("Interne Testgruppe vorhanden.")
    else:
        group = call("POST", "/betaGroups", {"data": {
            "type": "betaGroups",
            "attributes": {"name": "Ich", "isInternalGroup": True, "hasAccessToAllBuilds": True},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }})["data"]
        print("Interne Testgruppe „Ich“ angelegt (bekommt jede neue Version automatisch).")
    group_id = group["id"]

    testers = all_pages("/betaGroups/%s/betaTesters?limit=200" % group_id)
    known = {(t["attributes"].get("email") or "").lower() for t in testers}

    users = all_pages("/users?limit=200")
    added = 0
    for user in users:
        a = user["attributes"]
        email = (a.get("username") or "").lower()
        if not email or email in known:
            continue
        call("POST", "/betaTesters", {"data": {
            "type": "betaTesters",
            "attributes": {"email": email, "firstName": a.get("firstName") or "", "lastName": a.get("lastName") or ""},
            "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": group_id}]}},
        }})
        added += 1
    print("Tester in der Gruppe: %d bereits, %d neu hinzugefügt." % (len(known), added))


if __name__ == "__main__":
    main()
