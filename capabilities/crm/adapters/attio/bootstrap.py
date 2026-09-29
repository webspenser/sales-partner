#!/usr/bin/env python3
"""Create the Attio schema that adapter.md describes.

Idempotent: every object, attribute, select option, and status is created
only if missing, so re-running after a partial failure is safe. Nothing is
ever deleted or renamed.

Reads ATTIO_API_KEY from the environment (set it in your shell; never write it to a file). Required token scopes:
object_configuration, list_configuration, record_permission, list_entry
(all read-write).

    python3 capabilities/crm/adapters/attio/bootstrap.py

Uses lists rather than custom objects so it works on plans with no
custom-object allowance.
"""
import json
import os
import sys
import urllib.error
import urllib.request

BASE = "https://api.attio.com/v2"

STAGES = [
    "New", "Scored", "Researched", "Approach Drafted", "Contacted", "Replied",
    "Call Scheduled", "Call Held", "Following Up", "Won", "Lost", "Disqualified",
]

PIPELINE = "sales_partner_pipeline"
RESEARCH = "sales_partner_research"
OUTREACH = "sales_partner_outreach"


def attr(slug, title, type_, options=None, config=None, description=""):
    return {
        "api_slug": slug, "title": title, "type": type_,
        "options": options or [], "config": config or {},
        "description": description,
    }


# Every list hangs off Companies. Pipeline holds exactly one entry per
# company (the adapter upserts by parent record); Research and Outreach
# hold many entries per company, one per finding / per message.
LISTS = {
    PIPELINE: ("Sales Partner Pipeline", [
        attr("stage", "Stage", "status"),
        attr("stage_changed_at", "Stage Changed At", "timestamp"),
        attr("stage_reason", "Stage Reason", "text"),
        attr("score", "Score", "number"),
        attr("score_breakdown", "Score Breakdown", "text"),
        attr("industry", "Industry", "text"),
        attr("size", "Size", "text"),
        attr("location", "Location", "text"),
        attr("address", "Address", "text"),
        attr("phone", "Phone", "text"),
        attr("email", "Email", "text"),
        attr("source", "Source", "text"),
        attr("source_url", "Source URL", "text"),
        attr("next_action", "Next Action", "text"),
        attr("next_action_due", "Next Action Due", "date"),
        attr("do_not_contact", "Do Not Contact", "checkbox"),
        attr("lead", "Lead", "record-reference",
             config={"record_reference": {"allowed_objects": ["companies"]}},
             description="Same company as the parent record; exists because list "
                         "entries cannot be filtered by parent."),
    ]),
    RESEARCH: ("Sales Partner Research", [
        attr("type", "Type", "select",
             ["news", "funding", "social", "event", "hire", "listing", "web_presence"]),
        attr("summary", "Summary", "text"),
        attr("source_url", "Source URL", "text"),
        attr("date", "Date", "date"),
        attr("hook", "Hook", "text"),
        attr("lead", "Lead", "record-reference",
             config={"record_reference": {"allowed_objects": ["companies"]}},
             description="Same company as the parent record; exists because list "
                         "entries cannot be filtered by parent."),
    ]),
    OUTREACH: ("Sales Partner Outreach", [
        attr("channel", "Channel", "select", ["email", "linkedin", "call", "other"]),
        attr("direction", "Direction", "select", ["outbound", "inbound"]),
        attr("date", "Date", "date"),
        attr("summary", "Summary", "text"),
        attr("draft_body", "Draft Body", "text"),
        attr("status", "Status", "select", ["draft", "approved", "sent", "voided"]),
        attr("outcome", "Outcome", "text"),
        attr("contact", "Contact", "record-reference",
             config={"record_reference": {"allowed_objects": ["people"]}}),
        attr("lead", "Lead", "record-reference",
             config={"record_reference": {"allowed_objects": ["companies"]}},
             description="Same company as the parent record; exists because list "
                         "entries cannot be filtered by parent."),
    ]),
}

PEOPLE_ATTRS = [
    attr("sp_role", "Sales Role", "select", ["decision-maker", "influencer", "gatekeeper"]),
    attr("sp_verified", "Contact Verified", "checkbox"),
    attr("sp_notes", "Contact Notes", "text"),
]


def load_key():
    key = (os.getenv("ATTIO_API_KEY") or "").strip()
    if not key:
        sys.exit("ATTIO_API_KEY is not set. Export it in your shell for this run; never store it in a file.")
    return key


KEY = None


def call(method, path, body=None):
    data = json.dumps({"data": body}).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers={
        "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read() or b"{}")
        except ValueError:
            return e.code, {}


def must(status, body, what):
    if status >= 300:
        sys.exit(f"FAILED {what}: HTTP {status} {body.get('message', body)}")
    return body


def ensure_attributes(target, ident, attrs):
    base = f"/{target}/{ident}/attributes"
    existing = {a["api_slug"] for a in must(*call("GET", base + "?limit=200"), base)["data"]}
    for a in attrs:
        if a["api_slug"] in existing:
            print(f"  exists  {ident}.{a['api_slug']}")
        else:
            must(*call("POST", base, {
                "title": a["title"], "description": a["description"],
                "api_slug": a["api_slug"], "type": a["type"],
                "is_required": False, "is_unique": False, "is_multiselect": False,
                "config": a["config"],
            }), f"create {ident}.{a['api_slug']}")
            print(f"  created {ident}.{a['api_slug']}")
        if a["options"]:
            ensure_children(f"{base}/{a['api_slug']}/options", a["options"])
        if a["type"] == "status":
            ensure_children(f"{base}/{a['api_slug']}/statuses", STAGES)


def ensure_children(path, titles):
    have = {o["title"] for o in must(*call("GET", path), path)["data"]}
    for t in titles:
        if t not in have:
            must(*call("POST", path, {"title": t}), f"create {path} '{t}'")
            print(f"    + {t}")
    extra = have - set(titles)
    if extra:
        print(f"    note: extra options left in place (archive by hand if unwanted): {sorted(extra)}")


def ensure_list(slug, name, attrs):
    s, body = call("GET", f"/lists/{slug}")
    if s not in (200, 404):
        sys.exit(f"FAILED read list {slug}: HTTP {s} {body.get('message', body)}"
                 " (token needs list_configuration:read-write)")
    if s == 404:
        must(*call("POST", "/lists", {
            "name": name, "api_slug": slug, "parent_object": "companies",
            "workspace_access": "full-access", "workspace_member_access": []}),
            f"create list {slug}")
        print(f"created list {slug}")
    else:
        print(f"list {slug} exists")
    ensure_attributes("lists", slug, attrs)


if __name__ == "__main__":
    KEY = load_key()
    print("people")
    ensure_attributes("objects", "people", PEOPLE_ATTRS)
    for slug, (name, attrs) in LISTS.items():
        ensure_list(slug, name, attrs)
    print("done")
