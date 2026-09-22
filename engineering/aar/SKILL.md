---
name: aar
description: >-
  Synthesize what a prototype taught: separate discovered product behavior from
  implementation accident, and state what should become reliable and what to
  discard. Use on "aar", "what did the prototype teach us", after `prototype`
  and before `audit`. Also recovers prototype-first work that skipped the grill.
model: claude-opus-5-5
effort: medium
---

# aar

Synthesize the learning, don't defend the code. The prototype was a question;
the AAR is the answer: what's validated, what becomes reliable, what to throw
away.

Run at Opus 5.5 medium. This is synthesis from evidence you already hold.

1. **Draft from evidence first.** Read the source map/grill, the prototype
   note, and the prototype diff (resolve through `HEAD.md`). Ask focused
   questions only for learning that's missing or contradictory.
2. **Separate signal from accident.** Distinguish discovered product behavior
   from prototype implementation accidents. The AAR does not defend prototype
   code; it names what's worth making reliable and what to discard.
3. **Recover a missing grill.** If no grill exists, add a short retrospective:
   what problem, for whom, what behavior seems validated, what to discard, and
   the minimum viable honest increment now.

## Filing

Write the `aar` artifact per `~/Dev/notes/_saving.md`, and read it first.
`assurance: discovery`, reuse the increment `id`, `[[link]]` the prototype and
grill. The next step is usually `audit`. Close per `_saving.md`. Its **Report
back** step is the last thing you print.
