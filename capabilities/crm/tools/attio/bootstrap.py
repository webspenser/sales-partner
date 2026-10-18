#!/usr/bin/env python3
"""Create the Attio schema that usage.md describes.

Idempotent: every object, attribute, select option, and status is created
only if missing, so re-running after a partial failure is safe. Nothing is
ever deleted or renamed.

Reads ATTIO_API_KEY from the environment (set it in your shell; never write it to a file). Required token scopes:
object_configuration, list_configuration, record_permission, list_entry
(all read-write).

    python3 capabilities/crm/tools/attio/bootstrap.py [--catalog context/offer-catalog.md]

The Segment and Hero Offer choice lists come from the offer catalog in the
instance (run this from the instance folder, or pass --catalog). The catalog
is read first, before any API call. Re-run after changing the catalog: it
only adds options.

Uses one list rather than custom objects so it works on plans with no
custom-object allowance.
"""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

BASE = "https://api.attio.com/v2"

STAGES = [
    "New", "Scored", "Researched", "Approved", "Contacted",
    "Engaged", "Open Deal", "Nurture", "Customer", "Disqualified",
]

DEFAULT_CATALOG = "context/offer-catalog.md"
ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

PIPELINE = "sales_partner_pipeline"


def attr(slug, title, type_, options=None, config=None, description=""):
    return {
        "api_slug": slug, "title": title, "type": type_,
        "options": options or [], "config": config or {},
        "description": description,
    }


def read_catalog(path):
    """Return (segment_ids, offer_ids), in file order, from the one fenced YAML
    block in the offer catalog. Exits with a message naming offer-catalog.md on
    a missing file, no YAML block, a bad ID or a duplicate ID."""
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError as e:
        sys.exit(f"offer-catalog.md: cannot read {path}: {e.strerror}. "
                 "Run the interview to write it, or pass --catalog <path>.")
    blocks, cur = [], None
    for line in lines:
        if cur is None:
            if re.match(r"^\s*```ya?ml\s*$", line):
                cur = []
        elif re.match(r"^\s*```\s*$", line):
            blocks.append(cur)
            cur = None
        else:
            cur.append(line)
    if len(blocks) != 1:
        sys.exit(f"offer-catalog.md: {path} must hold exactly one fenced yaml block "
                 f"(found {len(blocks)}). If this is the unfilled package template, run the "
                 "interview's offer catalog round first; it writes the catalog.")
    segments, offers, seen, stack = [], [], set(), []  # stack: (indent, key)
    for raw in blocks[0]:
        line = re.sub(r"(^|\s)#.*$", "", raw).rstrip()
        text = line.lstrip()
        if not text:
            continue
        indent = len(line) - len(text)
        if text in ("segments:", "offers:"):
            while stack and stack[-1][0] >= indent:
                stack.pop()
            stack.append((indent, text[:-1]))
            continue
        m = re.match(r"^-\s+id:\s*(.*)$", text)
        if not m:
            continue
        while stack and stack[-1][0] > indent:
            stack.pop()
        if not stack:
            sys.exit(f"offer-catalog.md: an id outside segments: or offers: ({text!r}).")
        ident = m.group(1).strip().strip("\"'")
        if not ID_RE.match(ident):
            sys.exit(f"offer-catalog.md: id '{ident}' must be lowercase kebab-case "
                     "(letters, digits, single hyphens).")
        if ident in seen:
            sys.exit(f"offer-catalog.md: id '{ident}' appears twice; ids are unique "
                     "across the whole catalog (segments and offers).")
        seen.add(ident)
        (segments if stack[-1][1] == "segments" else offers).append(ident)
    if not segments or not offers:
        sys.exit(f"offer-catalog.md: {path} needs at least one segment and one offer.")
    return segments, offers


# One list, hanging off Companies: exactly one entry per lead company.
# Research and talking points are notes on the company, which need no schema.
def build_lists(segment_ids, offer_ids):
    return {
        PIPELINE: ("Sales Partner Pipeline", [
            attr("stage", "Stage", "status"),
            attr("stage_changed_at", "Stage Changed At", "timestamp"),
            attr("stage_reason", "Stage Reason", "text"),
            attr("fit_score", "Fit Score", "number"),
            attr("fit_breakdown", "Fit Breakdown", "text"),
            attr("approach_score", "Approach Score", "number"),
            attr("approach_breakdown", "Approach Breakdown", "text"),
            attr("industry", "Industry", "text"),
            attr("segment", "Segment", "select", segment_ids),
            attr("hero_offer", "Hero Offer", "select", offer_ids),
            attr("offer_reason", "Offer Reason", "text"),
            attr("offer_evidence", "Offer Evidence", "select", ["strong", "moderate", "weak"]),
            attr("research_anyway", "Research Anyway", "checkbox",
                 description="Operator only: research this lead although its Fit score or Segment would skip it."),
            attr("research_capped", "Research Capped", "checkbox",
                 description="Set by the agent when a scheduled run stopped at the per-lead Apify cap; cleared once an interactive continue completes."),
            attr("size", "Size", "text"),
            attr("source", "Source", "text"),
            attr("source_url", "Source URL", "text"),
            attr("next_action", "Next Action", "text"),
            attr("next_action_due", "Next Action Due", "date"),
            attr("revisit_on", "Revisit On", "date"),
            attr("do_not_contact", "Do Not Contact", "checkbox"),
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
        sys.exit("ATTIO_API_KEY is not set. In this terminal only, run: read -rs ATTIO_API_KEY && export ATTIO_API_KEY\n"
                 "(it prompts without echoing and keeps the key out of shell history), and run this again; never store it in a file.")
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
    ap = argparse.ArgumentParser(description="Create the Attio schema for Sales Partner.")
    ap.add_argument("--catalog", default=DEFAULT_CATALOG,
                    help=f"offer catalog (default {DEFAULT_CATALOG}, relative to the working directory)")
    args = ap.parse_args()
    segment_ids, offer_ids = read_catalog(args.catalog)  # before the key and any API call
    KEY = load_key()
    print("people")
    ensure_attributes("objects", "people", PEOPLE_ATTRS)
    for slug, (name, attrs) in build_lists(segment_ids, offer_ids).items():
        ensure_list(slug, name, attrs)
    print("done")
