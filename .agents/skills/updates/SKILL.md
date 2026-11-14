---
name: updates
description: >
  Write CSA Admin user-facing update announcements/changelog entries, matching the
  existing app/views/updates format and TRANSLATIONS.md conventions. Draft English
  and French first by default, then add German, Italian, and Dutch only once the
  wording is finalized or explicitly requested.
when-to-use: Use when the user wants a user-facing update note, changelog entry, or announcement after a CSA Admin feature or change is complete.
argument-hint: "[feature or change description]"
disable-model-invocation: true
---

# Updates / Changelog Writer

You are writing CSA Admin update announcements for admins and organizations using the application.

Updates live in `app/views/updates/` as Markdown/ERB partials. Always inspect past updates there before drafting or creating files so the tone, structure, heading style, links, and length match the project.

Also read `TRANSLATIONS.md` before writing or translating user-facing text. Follow its language, tone, and two-phase translation conventions.

## Default Workflow

1. Understand the change from the conversation, diff, task documents, commit, and relevant files.
2. Inspect recent and/or similar updates in `app/views/updates/` for format and structure.
3. Identify what is truly user-facing:
   - What users can do now.
   - What changed in their workflow.
   - What became easier, clearer, faster, safer, or more visible.
   - Whether existing data/configuration is preserved.
4. Draft concise, human announcements in English and French first by default.
5. Wait for user iteration/approval before translating to German, Italian, and Dutch, unless the user explicitly asks for all languages immediately.
6. When asked to create files, write one partial per locale in `app/views/updates/` and validate the result lightly.

## Language Scope

Supported locales are:

- `en`
- `fr`
- `de`
- `it`
- `nl`

Use this two-phase process unless the user says otherwise:

1. **Draft/review phase:** English and French only.
2. **Publication phase:** Add German, Italian, and Dutch after the content is finalized or when explicitly requested.

## File Naming

Use the modern localized update file pattern:

```text
app/views/updates/_YYYYMMDD_short_slug.en.md.erb
app/views/updates/_YYYYMMDD_short_slug.fr.md.erb
app/views/updates/_YYYYMMDD_short_slug.de.md.erb
app/views/updates/_YYYYMMDD_short_slug.it.md.erb
app/views/updates/_YYYYMMDD_short_slug.nl.md.erb
```

Before creating files, check whether a file already exists for the same date/slug to avoid overwriting user work.

Use a short, descriptive, lowercase snake_case slug, for example:

```text
_20260607_organization_settings.en.md.erb
```

## Structure and Tone

Match existing updates, but generally prefer:

- One clear `#` heading.
- A short explanation of why the change exists when useful.
- A practical description of what changed.
- Bullets for lists of features, shortcuts, supported items, or concrete examples.
- Optional `##` sections when they improve scanability.
- A short support/contact sentence for large or risky changes.

Keep the announcement user-facing. Avoid implementation details unless they matter to users. Do not mention commit SHAs, migrations, backfills, internal class names, or test details in the announcement.

Remember that updates are written for admins and organization managers, not developers. Avoid technical delivery words such as "iframe", API, job, or migration unless they are necessary for the user's action; if needed, keep them in parentheses or move the detail to the handbook. Briefly explain uncommon technical terms the first time they appear, for example "geocoding means turning an address into map coordinates".

Use a warm, direct, human tone. Avoid marketing fluff and overexplaining.

## Links

Add helpful links when they make the announcement actionable:

- Use relative app links such as `/settings`, `/support`, or `/handbook/...`.
- Link the first meaningful mention of a page or feature.
- Avoid over-linking repeated occurrences of the same destination.
- Check past updates for link style before introducing a new pattern.

## Translation Guidance

Follow `TRANSLATIONS.md`.

Important reminders:

- French uses `vous`; prefer “désormais” when introducing what is new.
- German and Dutch admin-facing copy should generally be impersonal, but existing updates may use a more direct announcement style; match nearby project tone while respecting `TRANSLATIONS.md`.
- Italian admin-facing copy uses `voi` where direct address is needed.
- Keep feature names consistent with app/locales when possible, especially for terms from `config/locales/features.yml`.
- Translate meaning, not word-for-word structure.

## Creating Files

When the user asks to create the update files:

1. Confirm the date/slug from context or choose a sensible one based on today’s date and the topic.
2. Create all requested locale files in `app/views/updates/`.
3. Preserve Markdown/ERB conventions used by existing updates.
4. Run a light validation such as:

```bash
git --no-pager diff --check -- app/views/updates/_YYYYMMDD_slug.*.md.erb
```

5. Report the created files and any validation performed.

Full test/CI is usually unnecessary for text-only update files unless the user asks or the change includes code.

## Output

When drafting only, provide the update text in Markdown blocks, grouped by language.

When files are created, summarize the created paths and validation. Do not commit unless the user explicitly asks.
