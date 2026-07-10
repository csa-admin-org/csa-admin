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

## Scoped Translation Variants

CSA Admin prepends `I18n::Backend::ScopedLookup`, defined in
`lib/i18n/backend/scoped_lookup.rb`, to the side-by-side backend. Normal lookups
therefore automatically try variants matching the current organization's basket and
activity terminology before falling back to the unscoped key.

Slash suffixes are part of the key name, not YAML nesting:

```yaml
_:
  activerecord:
    attributes:
      basket:
        basket_size:
          _en: Size
          _fr: Taille
          _de: Grösse
          _it: Dimensione
          _nl: Grootte
        basket_size/bag:
          _en: Bag size
          _fr: Taille du sac
          _de: Taschengrösse
          _it: Dimensione della borsa
          _nl: Tasgrootte
```

Application code should request the base key (`basket_size`). The backend derives active
scopes from `Current.org`, tries the locale-specific basket scope followed by the activity
scope, and uses `basket_size/bag` when available. If no scoped variant exists, it returns
`basket_size`.

For keys ending in `_html`, insert the scope before that suffix so Rails keeps treating the
translation as HTML-safe:

```text
description_html → description/bag_html
```

Use scoped variants only when terminology genuinely differs. Application code must always
request the base key. Keep an unscoped fallback unless the scoped leaf has the complete
matrix for its terminology: every basket scope (`basket`, `bag`, `share`, `package`,
`cone`, `crate`) or every activity scope (`hour_work`, `halfday_work`, `day_work`,
`basket_preparation`). A complete matrix may omit the base because every organization
then resolves a valid variant. Every variant must contain all supported locales. The
`locales:check` task enforces the full contract.

During development, follow the two-phase process below; once wording is finalized, every
scoped variant needs values for all supported locales. See
`test/lib/i18n/backend/scoped_lookup_test.rb` for lookup and fallback examples.

## Liquid Templates

Database-backed member and newsletter templates use locale-suffixed `.liquid` files:
`invoice_created.en.liquid`, `invoice_created.fr.liquid`.

Application mailers, such as `AdminMailer`, use `app/views/.../*.liquid.erb` templates
and locale keys under `config/locales/`. Internal emails sent exclusively to
`ULTRA_ADMIN_EMAIL` may remain English-only.

### Source Defaults and Tenant Content

Source defaults provide initial or missing tenant content; they do not overwrite tenant
content that administrators have customized. When correcting a default, preserve customized
mail and newsletter content unless an explicit, safe default-equivalence migration is planned.

## Two-Phase Process

1. **During development**: only add `_en` and `_fr` translations (if significant only)
2. **Once finalized**: add `_de`, `_it`, `_nl` translations (automatically for `.yml` files, on request for templates)

## Voice & Tone per Language

| Context | EN | FR | DE | NL | IT |
|---|---|---|---|---|---|
| **Admin UI** (buttons, hints, confirmations) | you | vous | **impersonal** (infinitive, passive) | **impersonal** | voi |
| **Admin emails** | you | vous | **impersonal** | **impersonal** | voi |
| **Member-facing** (member portal; emails/newsletters sent to members) | you | vous | **Du** (capitalized) | **je/jij** | tu |
| **Handbook** (docs for admins) | you | vous | **Du** (capitalized) | **je/jij** | tu |
| **Update announcements** (long-form release notes) | you | vous | **Du** (capitalized) | **je/jij** | tu |

Update announcements are handbook/docs content, even though they render in the admin area.

### Admin emails

Use the recipient name in the greeting:

| EN | FR | DE | IT | NL |
|---|---|---|---|---|
| `Hello {{ admin.name }},` | `Salut {{ admin.name }},` | `Hallo {{ admin.name }},` | `Ciao {{ admin.name }},` | `Hallo {{ admin.name }},` |

CSA Admin intentionally combines French `Salut` with `vous`.

### English

Use US spelling for visible copy: `canceled` and `cancellation`. Keep technical identifiers
unchanged when they use different spelling.

### German

Use Swiss Standard German throughout: write `ss`, never `ß`.

**Impersonal** (Admin UI and admin emails) — Use infinitive constructions
("Alle Daten importieren"), passive ("Soll das wirklich durchgeführt werden?"), drop
possessives ("Die IBAN" not "Ihre IBAN"). Never use "Sie" for direct address.

**Du** (Member-facing, Handbook) — Capitalize Du/Dein/Dir/Dich in direct address.
Adjust verb conjugations (hast, kannst, möchtest). Preserve lowercase "sie/ihre"
(= they/their, 3rd person) and "Siehe" (= See).

### Dutch

**Impersonal** (Admin UI and admin emails) — Same patterns as German: infinitive,
passive, drop possessives. Never use "u/uw".

**je** (Member-facing, Handbook) — Use "je" as the default (lighter). Use "jouw"
only for emphasis. Adjust verb conjugations ("Je hebt", not "U heeft"). With
inversion, drop the -t ("heb je", not "hebt je").

### French

- Use "vous" consistently in Admin UI, admin emails, and member-facing copy.
- Signal word **"désormais"** to introduce what's new in announcements.
- Impersonal openings preferred: "Il est désormais possible de…"
- Attach `:`, `;`, `?`, and `!` to the preceding text in all application copy—do not
  add regular, thin, or non-breaking spaces. Keep the colon before bullet lists, but
  attach it to the preceding text. This follows the
  [Canton of Vaud typographic guidance](https://www.vd.ch/cha/bic/usages-typographiques)
  and is enforced by `test/lib/i18n/french_punctuation_test.rb`.
- Fully localized vocabulary, never anglicisms (dépôt, abonnement, panier, etc.).

### Italian

- Use "voi" for Admin UI and admin emails, "tu" for member-facing and handbook.

## Writing Style

- **Use straight double quotes in every language.** Write `"..."` for quoted terminology,
  labels, and interface elements. Do not use guillemets or typographic double quotes.
- **Keep it human.** Write like you would explain something to a colleague. Avoid
  robotic or overly structured prose (no walls of em dashes, no filler phrases like
  "It is important to note that…").
- **Use em dashes sparingly.** Prefer semicolons, periods, or commas. An em dash is
  fine when it genuinely adds clarity, but overuse makes text feel AI-generated.
- **Prefer `<strong>` / `**bold**` over `<u>` for emphasis** in user-facing copy.
  Underlines are easily confused with hyperlinks.
- **Be direct.** Say what happens, not what "the system does". Prefer active voice
  and short sentences when possible.
- **Don't over-explain.** Trust the reader. One clear sentence beats three hedging ones.
