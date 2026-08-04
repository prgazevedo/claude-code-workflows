# Review instructions

When reviewing pull requests in this repository, also check the prose:

- Markdown prose and PR descriptions follow the plain-language rules in
  `conventions/plain-language.md`: no invented terms, sentences under 25
  words, numbers instead of vague adjectives ("significantly", "robust").
- PR bodies use four sections: What changed / Why / Proof it works /
  What I need from you. Flag a missing section.
- Verification claims must say where they ran: CI, local, or not tested.
- Agent prompt files in `plugin/agents/` must not open with a persona line
  ("You are a ..."). Procedural instructions only.
