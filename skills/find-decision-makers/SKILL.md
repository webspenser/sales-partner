---
name: find-decision-makers
description: Use when the target company is known but the right person is not — identifies decision-makers, influencers, and gatekeepers, and finds a contact route for each.
---

This skill reads public pages only. LinkedIn is read here, never acted
on — no automated connection request, message, or scrape behind a
login; a LinkedIn profile URL found on a public company page or public
search is a legitimate source, viewing it as a human would is not.

## Procedure

1. Read `context/icp.md`'s Target roles section for this business's
   job titles and functions that make a real buyer, influencer, or
   gatekeeper — the search below is scoped to these, not to "everyone
   at the company."
2. Search, in this order: the company site's team or leadership page,
   the company's public LinkedIn page (and the public LinkedIn profiles
   it links to), and any public professional directory (e.g. a
   conference speaker list, a press mention with a named title).
3. For each person found who plausibly matches a Target role, classify
   them into exactly one of three roles:
   - **decision-maker** — has the authority to approve or kill the
     purchase (typically the budget-holder for this offer's price
     point, per `business-profile.md`'s Pricing section).
   - **influencer** — shapes the decision but doesn't hold the budget
     or the final call (a practitioner who'd use the product, a peer
     the decision-maker consults).
   - **gatekeeper** — controls access to the decision-maker (an
     executive assistant, a generic info@/contact form) without
     influence over the decision itself.
   Classify by what the role actually controls at this company, not by
   seniority — see the failure modes below.
4. For each person, find a contact route: an email address, a
   LinkedIn profile URL, or both. Note where each came from.
5. Write each person via CRM `upsert_contact(lead_id, name, title,
   email, linkedin_url, role, verified, notes)`. `role` must be exactly
   one of decision-maker, influencer, or gatekeeper — the operation
   rejects anything else. `title` holds only the person's job title —
   never fold any other annotation into it.
6. Set `Verified` only when the contact route came from a source that
   directly confirms it belongs to this person — a public bio page
   listing the address, a verified LinkedIn profile matching the
   name and current title, a press contact block. Leave `Verified`
   unchecked for anything inferred.
7. **A guessed email address is never written to the `Email` field.**
   If no verifiable email exists but the company's address pattern can
   be inferred (e.g. `first.last@domain.com` observed on one confirmed
   address and extrapolated to another person), leave `Email` empty on
   that Contact and instead record the guess in `Notes`, in the exact
   form `pattern guess, unverified`, together with the guessed address
   and the confirmed address it was inferred from. `Title` stays a
   plain job title and `Verified` stays unchecked.

## Worked example

**Halvorsen Freight**, a mid-market logistics company. `icp.md`'s
Target roles: "VP Operations or Director of Logistics (decision-maker),
Operations Manager (influencer)."

1. Company site team page lists "Dana Reyes, VP of Operations" with no
   email.
2. Company LinkedIn page links to Dana Reyes's public profile, which
   confirms the same name and current title — LinkedIn profile URL
   noted, and matches Target roles as decision-maker.
3. A press release from a logistics trade publication, 2026-05-02,
   quotes "Dana Reyes, VP of Operations at Halvorsen Freight" directly,
   with a listed press contact email `press@halvorsenfreight.com` —
   that's a gatekeeper contact, not Dana's own address.
4. One confirmed address exists from an earlier, unrelated Halvorsen
   Freight support ticket on record: `d.reyes@halvorsenfreight.com`
   was never independently confirmed as Dana's address (found only in
   a scraped support forum post, not a source that ties it to her by
   name and title) — so it is written as a **pattern guess**, not as a
   verified email.

Contacts written:

- `upsert_contact(lead_id, "Dana Reyes", "VP of Operations", email="",
  linkedin_url="linkedin.com/in/danareyes-example",
  role="decision-maker", verified=true, notes="pattern guess,
  unverified: d.reyes@halvorsenfreight.com, inferred from the
  confirmed press contact address's domain pattern")` — verified on the
  LinkedIn profile matching name and title; email left empty since no
  source confirms it; `Title` stays plain ("VP of Operations"); the
  guess lives only in `Notes`.
- `upsert_contact(lead_id, "Press contact", "Press/Media", email=
  "press@halvorsenfreight.com", linkedin_url="", role="gatekeeper",
  verified=true, notes="")` — the address itself is publicly listed as
  the press contact, which is exactly what it's verified to be: a
  route to someone who is not the decision-maker.

## Failure modes

- **Targeting the most senior person rather than the actual buyer.** A
  founder or CEO at a 300-person company is frequently not who
  approves an $8k engagement — the person who actually holds that
  budget, per Target roles, is the decision-maker, even when a more
  senior title exists at the company. Classify by what the role
  controls, not by title rank.
- **Recording a gatekeeper as a decision-maker.** A generic
  `info@`/press contact, an executive assistant, or a general contact
  form found on the team page is a route to someone, not a buyer —
  writing it in as `role: decision-maker` sends outreach at a wall
  instead of a person.
- **Writing a pattern-guessed address as if verified.** Any address
  built by extrapolating a naming convention (`first.last@domain.com`)
  rather than confirmed against a source belongs in `Notes` as
  `pattern guess, unverified`, never in `Email` with `Verified` checked
  — see step 7. A bounced or wrong-recipient send traces directly back
  to skipping this rule.
- **Folding a provenance note into `Title`.** `Title` holds only the
  person's job title. Mixing a pattern-guess annotation or any other
  scoring/provenance text into it corrupts a field everything
  downstream reads as a plain job title — that annotation belongs in
  `Notes`.
