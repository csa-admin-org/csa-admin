---
name: glossary
description: >
  Use when explaining or naming CSA Admin domain concepts, models, or
  product terms (tenant, FY, basket, shop, absences, Query API, …), or
  when a change may need a GLOSSARY.md update. Read GLOSSARY.md; keep it
  current. Not for locale copy (translations) or changelog text (updates).
---

# Glossary

`GLOSSARY.md` at the repo root is the canonical domain vocabulary. Read it
before inventing names or explaining unfamiliar CSA Admin concepts.

## Use this skill for

- Clarifying what a domain term or model means in this app
- Choosing wording in commits, PRs, task docs, or code comments
  (e.g. **organization** / **org** / **tenant** over **farm**)
- Shipping a change that adds, renames, or retires a domain concept
- Reviewing whether glossary entries still match the code

## Do not use for

- User-facing locale strings → `translations` + `TRANSLATIONS.md`
- Update announcements → `updates`
- Live tenant data → `query`

## Keep it up to date

When a change introduces, renames, or removes a lasting domain idea
(model, feature flag area, billing concept, API surface agents rely on):

1. Read the current `GLOSSARY.md` entry if any.
2. Add, tighten, or delete the bullet so it matches the code.
3. Keep entries short: what it is, where it lives if useful
   (`app/models/…`), and non-obvious gotchas only.
4. Prefer one established name; do not cycle synonyms in new prose.
5. No secrets, credentials, tenant slugs, or PII. Link task history under
   `.agents/tasks/done/` only when it helps archaeology.

Do not expand the glossary into a handbook. If the nuance belongs in
`docs/`, `AGENTS.md`, or a skill, point there instead of duplicating.
