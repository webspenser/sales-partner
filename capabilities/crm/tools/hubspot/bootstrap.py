#!/usr/bin/env python3
"""Create the HubSpot properties usage.md describes (see its ## Setup).

Runs in two passes. Pass 1 only reads: it compares every existing property's
type with the definition and stops, writing nothing, if any differ. Pass 2
creates what is missing. Idempotent: every property group, property, and dropdown option is created
only if missing. Nothing is ever deleted or renamed.

Reads HUBSPOT_TOKEN (a private app access token) from the environment. Set it
in your own terminal only — never in a file, never in a chat. Required
scopes are listed in SCOPES.

    python3 capabilities/crm/tools/hubspot/bootstrap.py
"""
import json
import os
import sys
import urllib.error
import urllib.request

BASE = "https://api.hubapi.com/crm/v3/properties"
GROUP = "sales_partner"
SCOPES = ["crm.schemas.companies.read", "crm.schemas.companies.write",
          "crm.schemas.contacts.read", "crm.schemas.contacts.write",
          "crm.objects.companies.read", "crm.objects.contacts.read"]

STAGES = ["New", "Scored", "Researched", "Approach Drafted", "Ready to Send", "Contacted", "Replied",
          "Call Scheduled", "Call Held", "Following Up", "Won", "Lost", "Disqualified"]


def opts(values):
    return [{"label": v, "value": v, "displayOrder": i} for i, v in enumerate(values)]


YESNO = [{"label": "Yes", "value": "true", "displayOrder": 0},
         {"label": "No", "value": "false", "displayOrder": 1}]


def prop(name, label, type_, field, options=None):
    p = {"name": name, "label": label, "type": type_, "fieldType": field, "groupName": GROUP}
    if options is not None:
        p["options"] = options
    return p


PROPERTIES = {
    "companies": [
        prop("sp_stage", "Sales Partner stage", "enumeration", "select", opts(STAGES)),
        prop("sp_stage_changed_at", "Stage changed at", "datetime", "date"),
        prop("sp_stage_reason", "Stage reason", "string", "textarea"),
        prop("sp_score", "Score", "number", "number"),
        prop("sp_score_breakdown", "Score breakdown", "string", "textarea"),
        prop("sp_industry", "Industry (Sales Partner)", "string", "text"),
        prop("sp_size", "Size", "string", "text"),
        prop("sp_source", "Source", "string", "text"),
        prop("sp_source_url", "Source URL", "string", "text"),
        prop("sp_email", "General inbox", "string", "text"),
        prop("sp_next_action", "Next action", "string", "text"),
        prop("sp_next_action_due", "Next action due", "date", "date"),
        prop("sp_do_not_contact", "Do not contact", "bool", "booleancheckbox", YESNO),
    ],
    "contacts": [
        prop("sp_role", "Sales role", "enumeration", "select",
             opts(["decision-maker", "influencer", "gatekeeper"])),
        prop("sp_verified", "Contact verified", "bool", "booleancheckbox", YESNO),
        prop("sp_notes", "Contact notes", "string", "textarea"),
    ],
}


class Stop(Exception):
    """A problem the operator must fix; printed without a traceback."""


def call(token, method, path, body=None):
    req = urllib.request.Request(
        BASE + path, method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as err:
        try:
            detail = json.loads(err.read() or b"{}").get("message", "")
        except ValueError:
            detail = ""
        return err.code, {"message": detail}
    except urllib.error.URLError as err:
        raise Stop(f"cannot reach HubSpot: {err.reason}")


LABELS = {"companies": "Company properties", "contacts": "Contact properties"}


def check_group(token, obj):
    """Return True if the group is missing (pass 2 creates it)."""
    status, _ = call(token, "GET", f"/{obj}/groups/{GROUP}")
    if status == 404:
        return True
    if status >= 300:
        raise Stop(f"{obj}: cannot read property groups: HTTP {status} (check the token's scopes: {', '.join(SCOPES)})")
    return False


def check(token, obj):
    """Pass 1, read-only. Returns (missing property defs, enum props with missing options, problems)."""
    missing, to_patch, problems = [], [], []
    for p in PROPERTIES[obj]:
        status, have = call(token, "GET", f"/{obj}/{p['name']}")
        if status == 404:
            missing.append(p)
        elif status >= 300:
            raise Stop(f"{obj}.{p['name']}: cannot read it: HTTP {status} {have.get('message', '')}")
        elif (have.get("type"), have.get("fieldType")) != (p["type"], p["fieldType"]):
            problems.append(
                f"{obj}.{p['name']} exists as {have.get('type')}/{have.get('fieldType')} but must be "
                f"{p['type']}/{p['fieldType']}. Delete it in HubSpot (Settings \u2192 Properties \u2192 "
                f"{LABELS[obj]} \u2192 {p['name']} \u2192 Delete), then run this again.")
        elif p["type"] == "enumeration":
            existing = {o.get("value") for o in have.get("options", [])}
            add = [o for o in p["options"] if o["value"] not in existing]
            if add:
                to_patch.append((p, have.get("options", []), add))
    return missing, to_patch, problems


def create(token, obj, group_missing, missing, to_patch):
    """Pass 2: only runs when pass 1 found no problems."""
    if group_missing:
        status, body = call(token, "POST", f"/{obj}/groups", {"name": GROUP, "label": "Sales Partner"})
        if status >= 300:
            raise Stop(f"{obj}: cannot create property group {GROUP}: HTTP {status} {body.get('message', '')}")
        print(f"created group {obj}.{GROUP}")
    for p in missing:
        status, body = call(token, "POST", f"/{obj}", p)
        if status >= 300:
            raise Stop(f"{obj}.{p['name']}: HubSpot refused the property: HTTP {status} {body.get('message', '')}")
        print(f"created {obj}.{p['name']}")
    for p, have_opts, add in to_patch:
        status, body = call(token, "PATCH", f"/{obj}/{p['name']}", {"options": have_opts + add})
        if status >= 300:
            raise Stop(f"{obj}.{p['name']}: cannot add options: HTTP {status} {body.get('message', '')}")
        print(f"added {len(add)} option(s) to {obj}.{p['name']}")


def main():
    token = os.environ.get("HUBSPOT_TOKEN", "").strip()
    if not token:
        print("HUBSPOT_TOKEN is not set. Create a HubSpot private app with these scopes:\n  "
              + "\n  ".join(SCOPES)
              + "\nthen, in this terminal only, run: read -rs HUBSPOT_TOKEN && export HUBSPOT_TOKEN"
              + "\n(it prompts without echoing and keeps the token out of shell history), and run this again.",
              file=sys.stderr)
        return 2
    try:
        plan, problems = {}, []
        for obj in PROPERTIES:  # pass 1: read only
            group_missing = check_group(token, obj)
            missing, to_patch, probs = check(token, obj)
            plan[obj] = (group_missing, missing, to_patch)
            problems += probs
        if problems:
            print("\n".join(problems), file=sys.stderr)
            print("stopped: nothing was created. Fix the above, then run this again.", file=sys.stderr)
            return 1
        for obj, (group_missing, missing, to_patch) in plan.items():  # pass 2: write
            create(token, obj, group_missing, missing, to_patch)
    except Stop as err:
        print(f"stopped: {err}", file=sys.stderr)
        return 1
    print("done: every Sales Partner property exists")
    return 0


if __name__ == "__main__":
    sys.exit(main())
