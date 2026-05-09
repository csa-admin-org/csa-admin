# Translation Conventions

Translation and i18n conventions for CSA Admin. Read this when working on locale files,
mail templates, update announcements, or any user-facing text.

## Languages

Supported: English (`en`), French (`fr`), German (`de`), Italian (`it`), Dutch (`nl`).

## YAML Locale Files

Locale files live in `config/locales/`, organized by domain concept (one file per feature,
not per language). All languages coexist in the same file using the
[`i18n-backend-side_by_side`](https://github.com/nicolo-m/i18n-backend-side_by_side) gem:

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

Keys are under a single `_:` root, with language-prefixed leaf keys (`_en`, `_fr`, etc.).
This is **not** standard Rails `en:`/`fr:` nesting — the custom backend resolves the
correct locale at runtime.

## Liquid Templates

Mail and newsletter templates are stored in the database, not on disk. Template files
(when exported or referenced) use language suffixes: `invoice_created.en.liquid`,
`invoice_created.fr.liquid`.

## Two-Phase Process

1. **During development**: only add `_en` and `_fr` translations (if significant only)
2. **Once finalized**: add `_de`, `_it`, `_nl` translations (automatically for `.yml` files, on request for templates)

## Voice & Tone per Language

| Context | EN | FR | DE | NL | IT |
|---|---|---|---|---|---|
| **Admin UI** (buttons, hints, confirmations) | you | vous | **impersonal** (infinitive, passive) | **impersonal** | voi |
| **Member-facing** (member portal, emails, newsletters) | you | vous | **Du** (capitalized) | **je/jij** | tu |
| **Handbook** (docs for admins) | you | vous | **Du** (capitalized) | **je/jij** | tu |

### German

**Impersonal** (Admin UI) — Use infinitive constructions ("Alle Daten importieren"),
passive ("Soll das wirklich durchgeführt werden?"), drop possessives ("Die IBAN" not
"Ihre IBAN"). Never use "Sie" for direct address.

**Du** (Member-facing, Handbook) — Capitalize Du/Dein/Dir/Dich in direct address.
Adjust verb conjugations (hast, kannst, möchtest). Preserve lowercase "sie/ihre"
(= they/their, 3rd person) and "Siehe" (= See).

### Dutch

**Impersonal** (Admin UI) — Same patterns as German: infinitive, passive, drop
possessives. Never use "u/uw".

**je** (Member-facing, Handbook) — Use "je" as the default (lighter). Use "jouw"
only for emphasis. Adjust verb conjugations ("Je hebt", not "U heeft"). With
inversion, drop the -t ("heb je", not "hebt je").

### French

- Use "vous" consistently (both Admin UI and member-facing).
- Signal word **"désormais"** to introduce what's new in announcements.
- Impersonal openings preferred: "Il est désormais possible de…"
- Use «guillemets» for inline terminology, not English-style quotes.
- Colon `:` before every bullet list (standard French punctuation).
- Fully localized vocabulary, never anglicisms (dépôt, abonnement, panier, etc.).

### Italian

- Use "voi" for Admin UI, "tu" for member-facing and handbook.
