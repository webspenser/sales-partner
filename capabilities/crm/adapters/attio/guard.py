#!/usr/bin/env python3
"""Attio guard for sales-partner's CRM invariants (Agent Standard 1.2).

hooks/guard.sh runs this before every call to an Attio MCP tool inside a
sales-partner instance, with the hook input JSON on stdin. Exit 2 blocks the
call and stderr tells the model why; exit 0 allows it. Anything unexpected
blocks: a bug here must fail closed.

Rules (capabilities/crm/contract.md, Invariants):
  draft_only  - a new entry may carry status "draft" only; an update may set
                status to "voided" only. approved and sent are the operator's,
                set in the Attio app, which never passes through this hook.
  dnc_one_way - an update may write do_not_contact only as true.
  no_delete   - list configuration tools are refused; deletes and merges are
                refused by adapter.yaml's `block`.
An unknown tool that carries entry_values or values is checked with the
update rules, so a tool this guard has not heard of cannot slip a write
through; tools without those keys stay allowed.
Write calls must key attributes by api slug: an attribute ID could hide
`status` or `do_not_contact`.
"""
import json
import re
import sys

CREATE_TOOLS = {"add-record-to-list", "create-record"}
UPDATE_TOOLS = {"update-list-entry-by-id", "update-list-entry-by-record-id",
                "update-record", "upsert-record"}
REFUSED_TOOLS = {"create-list", "update-list"}
UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)


def scalars(value):
    """Leaf values of an Attio value: a scalar, a list, or {option|status|value|title: ...}."""
    if isinstance(value, list):
        return [leaf for item in value for leaf in scalars(item)]
    if isinstance(value, dict):
        leaves = [leaf for key in ("option", "status", "value", "title") if key in value
                  for leaf in scalars(value[key])]
        if not leaves:
            raise ValueError("unrecognized value shape")
        return leaves
    return [value]


def as_text(values):
    return [str(v).strip().lower() for v in values]


def problems(event):
    tool_name = event.get("tool_name")
    if not isinstance(tool_name, str) or "__" not in tool_name:
        raise ValueError("no MCP tool_name in the hook input")
    tool = tool_name.rsplit("__", 1)[1]
    if tool in REFUSED_TOOLS:
        return [f"{tool} changes the workspace's list configuration; sales-partner never does"]
    args = event.get("tool_input")
    known = tool in CREATE_TOOLS | UPDATE_TOOLS
    if not known and not (isinstance(args, dict) and ("entry_values" in args or "values" in args)):
        return []
    if not isinstance(args, dict):
        raise ValueError("tool_input is not an object")
    values = args.get("entry_values", args.get("values", {}))
    if not isinstance(values, dict):
        raise ValueError("attribute values are not an object")
    found = [f"attribute {key} is addressed by ID; use its api slug" for key in values if UUID.match(key)]
    if "status" in values:
        allowed = "draft" if tool in CREATE_TOOLS else "voided"
        if as_text(scalars(values["status"])) != [allowed]:
            found.append(f"status may only be written as {allowed} here (approved and sent are the operator's)")
    if "do_not_contact" in values and tool not in CREATE_TOOLS:
        if as_text(scalars(values["do_not_contact"])) != ["true"]:
            found.append("do_not_contact is one-way and can only be set to true")
    return found


def main():
    try:
        event = json.load(sys.stdin)
        if not isinstance(event, dict):
            raise ValueError("hook input is not an object")
        found = problems(event)
    except Exception as err:  # fail closed
        print(f"Blocked by the Attio guard: cannot check this call ({type(err).__name__}: {err})", file=sys.stderr)
        return 2
    for problem in found:
        print(f"Blocked by the Attio guard: {problem} (capabilities/crm/adapters/attio/adapter.md)", file=sys.stderr)
    return 2 if found else 0


if __name__ == "__main__":
    sys.exit(main())
