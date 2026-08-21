---
name: unslop
description: >-
  Cut AI tells from prose a human will read, and put a voice back in. The full
  pattern catalogue behind the always-loaded voice contract. Use on "unslop
  this", "clean up this writing", "this reads like AI", or before filing a prose
  artifact a human reads (note, spec, ADR, PR body, docs). Not for thinking,
  tool inputs, sub-agent prompts, or code.
---

# unslop

Edit text so it does not read as machine-generated, without losing what it says.

Scope is set by the voice contract in `VOICE.md` (always loaded): prose a human
reads. Thinking, tool inputs, sub-agent traffic, structured output, and code are
out of scope. Precision beats every rule below.

Carries no `model` pin: it usually runs inside another skill's turn and inherits
that skill's tier.

## Process

1. Scan for the patterns below.
2. Rewrite. Preserve meaning, match the intended tone.
3. Add voice (next section).
4. Self-audit: "what makes this obviously AI generated?" Fix what is left.

## Adding voice

Removing patterns is half the job. Sterile writing is just as obvious.

- **Have opinions.** React to a fact instead of listing pros and cons neutrally.
- **Vary rhythm.** Short sentences. Then longer ones that take their time.
- **Acknowledge complexity.** "Impressive and a bit unsettling" beats
  "impressive".
- **Use "I" when it fits.** First person is not unprofessional.
- **Let some mess in.** Perfect structure looks machine-made.
- **Be specific.** Not "this is concerning" but "agents churning away at 3am".

## Patterns

### Content

1. **Puffery.** "pivotal moment", "testament to", "evolving landscape",
   "setting the stage for", "deeply rooted". Cut it, state what happened.
2. **Name-dropping.** Listing outlets or tools without context. Pick one, say
   what it said.
3. **Superficial -ing phrases.** "highlighting...", "ensuring...",
   "reflecting...", "showcasing...". Delete, or expand with a real source.
4. **Promotional language.** "vibrant", "breathtaking", "groundbreaking",
   "renowned", "seamless", "must-have". Describe neutrally.
5. **Vague attribution.** "Experts believe", "Reports suggest", "Some argue".
   Name the source or delete the claim.
6. **Formulaic challenge framing.** "Despite challenges, X continues to
   thrive." Replace with specific facts.

### Language

7. **AI vocabulary.** additionally, crucial, delve, enhance, fostering, garner,
   interplay, intricate, landscape (abstract), pivotal, showcase, tapestry,
   testament, underscore, vibrant. Use plain words.
8. **Fancy ways to say "is".** "serves as", "stands as", "boasts", "features".
   Say "is" or "has".
9. **"Not just X, but Y."** State the point directly.
10. **Rule of three.** Use the natural number of items.
11. **Synonym cycling.** Protagonist, main character, central figure, hero in
    one paragraph. Pick one and repeat it.
12. **False ranges.** "from X to Y" where X and Y share no scale. List directly.

### Style

13. **No em dashes.** Adopted in full. Parentheses, en dashes, and double
    hyphens are not substitutes, they trade one tell for another. If a thought
    needs separation, end the sentence or use a comma.
14. **Colon overuse.** Fine before a list or example. Not as a mid-sentence
    connector. Let the point stand without comparison framing.
15. **Boldface overuse.** Do not bold every proper noun or acronym.
16. **Inline-header lists.** The tell is a bold label and colon restating the
    line: "**Performance:** Performance improved...". Convert to prose. A bold
    lead-in that ends in a period, names the item, and is followed by genuinely
    new detail is fine, not a tell.
17. **Title case headings.** Use sentence case.
18. **Decorative emojis.** Remove from headings and bullets.
19. **Curly quotes.** Use straight quotes.

### Communication artifacts

20. **Chatbot phrases.** "I hope this helps", "Let me know if", "Of course",
    "Certainly", "Found the smoking gun". Remove.
21. **Cutoff disclaimers.** "While specific details are limited...". Find the
    source or drop the sentence.
22. **Sycophancy.** "Great question", "You're absolutely right". Respond
    directly.

### Filler

23. **Filler phrases.** "In order to" becomes "to". "Due to the fact that"
    becomes "because". "It is important to note that" gets deleted.
24. **Hedge stacks.** "could potentially possibly be argued that it might"
    becomes "may".
25. **Generic conclusions.** "The future looks bright." State a plan or a fact.

### Jargon

26. **Abstract metaphor nouns.** substrate, wedge, vector, locus, nexus,
    bedrock, modality, paradigm, gold-plating, flywheel, north star, endgame,
    ratchet, evacuate (for moving code). Usually a plainer concrete word exists:
    substrate is base, wedge in is add, vector is way, gold-plating is more than
    the job needs, endgame is the last phase.

    **Carve-out.** A term that is the precise name for a thing in this system's
    glossary stays: seam, module depth, adapter, primitive, harness, discipline,
    orchestrator, blast radius. The `design` discipline defines these on
    purpose. Swapping them for vaguer words loses meaning, and precision wins.
    The test is whether the word names a specific thing here or just sounds
    technical.

### Plain speech

27. **Say what it does, not how it feels.** "the database stays close at hand"
    names a feeling. Name the mechanism or the number instead: "`.toSQL()`
    returns the exact string sent to the database". If you cannot restate a
    sentence as a concrete instruction, fact, or number, cut it. If it could
    appear unchanged in another project's docs, it says nothing about this one.
28. **Split dense sentences.** If the reader backtracks to parse it, break it in
    two. One idea per sentence.
29. **Active voice.** Catch "is/are/was/were + past participle" and name the
    actor. "queries are validated" becomes "the compiler validates queries".
    Passive is fine only when the actor is unknown or does not matter.
30. **Cut adverbs, or use a stronger verb.** "runs quickly" becomes "is fast" or
    the number. An adverb propping up a weak verb means the verb is wrong.
31. **Prefer the plain word.** utilize becomes use, leverage becomes use,
    facilitate becomes help, numerous becomes many.

## Filing

Writes no artifact of its own. It edits whatever the composing skill is about
to file.

Adapted from the `unslop` skill in cursor/plugins (`pstack`), with rule 26
carved out for glossary terms and scope bound by `VOICE.md`.
