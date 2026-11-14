---
name: translations
description: Use when editing CSA Admin translations, locale YAML files, Liquid mail/newsletter templates, update announcements, or any user-facing copy. Covers the app-specific side-by-side i18n format, supported languages, two-phase translation workflow, and voice/tone rules from TRANSLATIONS.md.
---

# CSA Admin Translations

Use this skill whenever working on translations or user-facing copy in CSA Admin.

`TRANSLATIONS.md` is the canonical reference. Read it when possible before making translation changes. This skill summarizes the non-negotiable rules so they are available as soon as the skill is activated.

## Use This Skill For

- Editing `config/locales/**/*.yml`
- Adding or changing user-facing strings
- Translating Admin UI, member-facing, or handbook copy
- Mail and newsletter Liquid templates
- Update announcements
- Reviewing translation tone, consistency, or YAML structure

## Supported Languages

CSA Admin supports:

- English: `_en`
- French: `_fr`
- German: `_de`
- Italian: `_it`
- Dutch: `_nl`

## YAML Locale Format

Locale files live in `config/locales/` and are organized by domain concept, not by language.

They use the `i18n-backend-side_by_side` format:

```yaml
_:
  members:
    title:
      _en: Members
      _fr: Membres
      _de: Mitglieder
      _it: Membri
      _nl: Leden
```

Do not use standard Rails locale nesting:

```yaml
en:
  members:
    title: Members
```

All languages coexist in the same file under a single `_:` root. Language-specific values are leaf keys prefixed with the locale code.

## Two-Phase Workflow

During active development:

1. Add `_en`.
2. Add `_fr` only when the text is significant enough to matter.

Once wording is finalized:

1. Add `_de`, `_it`, and `_nl` for YAML files.
2. For Liquid templates, add other languages only when requested.

Do not eagerly translate unstable copy into all five languages unless asked.

## Tone Rules

Respect the context of the text.

### Admin UI

Buttons, hints, confirmations, ActiveAdmin text, admin workflows:

- EN: `you`
- FR: `vous`
- DE: impersonal; infinitive/passive; never `Sie`
- NL: impersonal; never `u/uw`
- IT: `voi`

### Member-Facing Copy

Member portal, emails, newsletters:

- EN: `you`
- FR: `vous`
- DE: `Du`, capitalized
- NL: `je/jij`
- IT: `tu`

### Handbook / Docs for Admins

- EN: `you`
- FR: `vous`
- DE: `Du`, capitalized
- NL: `je/jij`
- IT: `tu`

## Language-Specific Rules

### German

For Admin UI, use impersonal phrasing:

- Infinitive: `Alle Daten importieren`
- Passive: `Soll das wirklich durchgeführt werden?`
- Drop possessives: `Die IBAN`, not `Ihre IBAN`
- Never use `Sie` as direct address

For member-facing and handbook copy:

- Use capitalized `Du`, `Dein`, `Dir`, `Dich`
- Adjust verb conjugations: `hast`, `kannst`, `möchtest`
- Preserve lowercase `sie/ihre` when it means `they/their`
- Preserve `Siehe` when it means `See`

### Dutch

For Admin UI:

- Use impersonal phrasing
- Never use `u` or `uw`

For member-facing and handbook copy:

- Use `je` by default
- Use `jouw` only for emphasis
- Adjust inversion: `heb je`, not `hebt je`

### French

- Use `vous` consistently.
- Use the signal word `désormais` to introduce what is new in announcements.
- Prefer impersonal openings such as `Il est désormais possible de…`.
- Attach `:`, `;`, `?`, and `!` to the preceding text in all application copy; do not add regular, thin, or non-breaking spaces.
- Keep `:` before bullet lists, but attach it to the preceding text.
- Avoid anglicisms; fully localize vocabulary.
- Shop is `épicerie`, never `boutique`.

### Italian

- Use `voi` for Admin UI.
- Use `tu` for member-facing and handbook copy.

## Writing Style

- Use straight double quotes (`"..."`) for quoted terminology and interface labels in every
  language. Do not use guillemets or typographic double quotes.
- Keep copy human and direct.
- Avoid robotic phrasing.
- Avoid filler like `It is important to note that…`.
- Use em dashes sparingly.
- Prefer `<strong>` or `**bold**` over underlines for emphasis.
- Do not over-explain.
- Prefer clear, short sentences.

## Liquid Templates

Mail and newsletter templates are stored in the database, not primarily on disk.

When template files are exported or referenced, they use language suffixes:

- `invoice_created.en.liquid`
- `invoice_created.fr.liquid`

Follow the member-facing tone rules unless the template is clearly admin-facing.
