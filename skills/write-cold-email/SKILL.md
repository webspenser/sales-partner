---
name: write-cold-email
description: Use when email is the chosen channel for a first touch or a follow-up — writes a short, specific message built on a research hook.
---

Every rule below is a hard constraint, not a suggestion. A draft that
breaks any one of them is not ready for `Status = draft`, regardless of
how well-written it otherwise reads:

- **Under 120 words**, counting the greeting and body, not the subject
  line or the sign-off.
- **Subject line under 6 words, and never a question.** A question
  subject reads as clickbait; state the angle instead of teasing it.
- **Opens with the hook, not with the sender.** The first sentence is
  about them — the specific thing research found — never "My name is…"
  or "I'm reaching out because we…".
- **Exactly one ask, and the ask is a conversation, not a purchase.**
  "Worth 15 minutes?" is a valid ask. "Want to buy this?" or a stacked
  "let me know if you're interested, and also check out our pricing
  page" is not — see Failure modes.
- **No adjectives about the sender's own product.** No "powerful,"
  "innovative," "best-in-class," "game-changing." State what happened
  for a named customer instead of what the product is like.
- **Every claim about the business traces to `context/business-profile.md`.**
  A proof point, a capability claim, a timeline — if it is not written
  in that file, this skill does not say it, no matter how plausible it
  sounds.
- **Signs with `sending_identity`** from `context/operating-config.md`,
  verbatim — never a hand-picked name or a generic "The Team."

## Procedure

1. Read the lead's `Hook` from its Research rows via CRM `get_lead`.
   Prefer the hook that is most specific to what's changing inside the
   company right now — a hiring surge tied to a funding round beats a
   funding round on its own, per `research-company`'s definition of a
   usable hook.
2. Read `context/operating-config.md`'s `tone` (three adjectives) and
   `sending_identity`, and `context/business-profile.md`'s Voice
   section for two example sentences in that voice — one of them is
   modeled to open a cold email. Match that register, not a generic
   "professional" one.
3. Write the subject line last conceptually, first on the page: under
   6 words, never a question, hinting at the hook or the relevance
   rather than the sender's category ("Quick question" and "Intro"
   both fail this — they say nothing about *them*).
4. Write the opening line as the hook itself, addressed to the
   recipient — not "I saw you raised a Series A" (about the sender's
   noticing) but the fact stated directly, the way someone who already
   knows them would mention it.
5. Add one bridging sentence connecting the hook to why this is
   relevant, pulling only from `business-profile.md`'s Who we serve
   and Proof sections. Do not describe the product yet — relevance
   first, capability second.
6. Add one line of proof: a named customer and a concrete result from
   `business-profile.md`'s Proof section. If Proof has no entry that
   fits, cut this line rather than write a vaguer version of it — an
   unsupported claim is worse than a shorter email.
7. Write exactly one ask, phrased as a conversation (a short call, a
   quick reply, a question answered) — never a demo booking framed as
   a purchase, never "let me know if interested."
8. Sign with `sending_identity`, verbatim.
9. Count the words in the greeting-through-ask block (excluding
   subject and sign-off). If it's at or over 120, cut a sentence
   entirely rather than trim words from every sentence — a cut
   sentence keeps the remaining ones intact; trimmed words leave
   fragments.
10. Re-read every factual claim against `business-profile.md` one more
    time. Anything that doesn't trace to a specific section gets cut.
11. Log the result via CRM `log_activity(lead_id, contact_id,
    channel="email", direction="outbound", draft_body=..., status=
    "draft")` — this skill never sets `status` to anything but `draft`.

## Worked example

**Fennimore Health**, using the Series A hiring hook from
`research-company`'s worked example: "they posted four clinical-ops
roles in one week, directly following the Series A — open by asking
how they're structuring that team as it scales." Contact: Renata Voss,
VP of Clinical Operations. This example assumes
`business-profile.md`'s Proof section has been filled in via the
interview with: *"cut onboarding time from six weeks to nine days for
Acme Co, a healthtech client of comparable size."*

> **Subject: Scaling clinical ops fast** (4 words, not a question)
>
> Hi Renata,
>
> Four clinical-ops hires in one week, right after a $9M Series A —
> that's a lot to onboard while the team is still being built.
>
> We help healthtech teams get new clinical-ops hires productive fast:
> our playbook took Acme Co's onboarding from six weeks to nine days.
>
> Worth 15 minutes to see if any of that maps onto how you're
> structuring the team as it scales?
>
> Andrew Ho Choy \<andrew@example.com\>

Body word count (greeting through the ask, excluding subject and
sign-off): 68 words — well under the 120-word limit. The opening line
is the hook, not a self-introduction. Proof line names Acme Co and a
concrete number, not an adjective. One ask, phrased as a conversation.
Sign-off is `sending_identity` verbatim.

## Failure modes

- **Opening with "I hope this finds you well" or any variant.** This
  and its cousins ("Hope you're doing great," "Trust this email finds
  you well") are about the sender's manners, not the recipient — they
  burn the first sentence on nothing, exactly where the hook belongs.
- **Describing the business before establishing relevance.** "We're a
  company that helps healthtech teams with X" as the opening move,
  before the recipient has any reason to care, reads as a form letter.
  Relevance — the hook — always comes first.
- **Stacking two asks.** "Worth a call? Also, feel free to check out
  our case studies page" is two asks wearing one sentence's clothing.
  Pick the one that actually moves the conversation forward and cut
  the other entirely.
- **A hook the recipient would not recognize as being about them.**
  "Companies like yours are growing fast these days" is true of
  thousands of companies and specific to none — see
  `research-company`'s own bar for what makes a hook usable in the
  first place. If the hook could open an email to any company in the
  industry, it isn't a hook, and this skill has nothing to open with.
