# Design Conventions

UI and visual conventions for the admin and members portals. Read this when working on ActiveAdmin pages, members views, or CSS.

## CSS

No-build CSS. No Tailwind, Sass, or PostCSS. Propshaft serves `admin.css` and `member.css`.

- Tokens live in `shared/tokens.css` (OKLCH primitives + semantic names). Change a color or space there, not in a template.
- Dark mode is a token flip from the resolved theme (`system|light|dark` stored on `html[data-theme]`, paint via `html.dark` / `.dark`). Do not sprinkle paired light/dark properties in every rule if a token already flips. Numbered `--color-gray-*` / `--color-green-*` stay put.
- Semantic names that flip: `--color-canvas` (page, white→950), `--color-canvas-admin`, `--color-surface` (cards/menus, white→900), `--color-ink` (950→100), `--color-ink-heading` (900→100), `--color-ink-secondary` (700→300), `--color-ink-muted` (500→400), `--color-ink-soft` (600→300), `--color-fill` (100→900), `--color-fill-muted` (200→800), `--color-line` (cards/panels, 200→700), `--color-border` (inputs, 200→600), `--color-danger-soft`, `--color-accent`, `--color-accent-strong`, `--color-negative`. Do not invent a token for a 1–2× pair, a hover-only green, a status inversion, or CodeJar hex.
- Markup we own uses semantic classes (`.btn`, `.status-tag`, `.panel`). Name the thing, not the paint.
- Prefix members layout chrome (`member-app`, `member-nav`, `member-flash`, …) and Stimulus class maps (`member-menu-open`, `member-shop-sticky`). Admin chrome uses `admin-` the same way (`admin-bar`, `admin-nav`, `admin-flash`). Page widgets do not take the prefix (`.shop-cart`, `.billing-card`, `.pane`).
- Tiny utilities we own are allowed: `.is-hidden`, `.is-muted`, `.is-italic`, `.is-nowrap`, `.is-struck`, `.is-warning`, `.is-alert`, `.sr-only`, `.text-center`, `.text-start`, `.text-end`, `.text-right`, `.text-justify`, `.tabular-nums`, `.cluster`, `.stack`. Visibility on tooltips and menus is nested (`.tooltip.is-visible`, `.admin-menu.is-visible`). Do not grow a spacing scale in HTML. Name the widget when the layout is specific (`.panel-action-row`, `.mail-recipient`).
- ActiveAdmin gem HTML is styled with descendant selectors. Do not fork gem templates to rename their classes.
- Members layout may use `ch` spacing and content-width breakpoints. The page-column gutter on rewritten members chrome is `--inline-space` (`1ch`). Matching bleed pairs (`margin-inline: calc(var(--inline-space) * -1)`) live on sticky nav/shop/pricing/depot chrome. Converted Formtastic/table rules keep `rem` unless that rule is being redesigned. Do not find-replace rem.
- A one-column grid is `minmax(0, 1fr)`, not `1fr`. Tailwind `grid-cols-1` used the minmax form so nowrap tables scroll inside the track instead of stretching the page.
- Mobile nav child links with a badge are flex + `align-items: center`. `display: block` puts `.menu-inline-badge` on the next line.
- Icons: Lucide SVGs via `icon("name")`. Size and mute them in CSS, not with leftover utility classes.

## Icons in Panels and Form Fieldsets

Both `panel` and `f.inputs` support the `icon:` option:

```ruby
panel "Title", icon: "icon-name" do
  # ...
end

f.inputs "Title", icon: "icon-name" do
  f.input :field
end
```

Icons render at half opacity at `1.25rem` (`.icon-5` / `.panel-title-icon`) — a muted visual cue, not a distraction.

**Only titled fieldsets get icons** — bare `f.inputs do` blocks (no title string) should never receive an icon.

When a fieldset has extra options, place `icon:` before them:

```ruby
f.inputs "Title", icon: "icon-name", data: { controller: "..." } do
f.inputs "Title", icon: "icon-name", "data-controller" => "..." do
```

Use the same icon for the same concept everywhere (panels, fieldsets, nav).

### Icon Mapping

All icons are sourced from [Lucide](https://lucide.dev), stored as SVGs in
`app/assets/images/icons/`. Two custom exceptions are noted below.

The panel icon for a concept **must** match the nav icon when one exists.

#### Resource / Model Icons

| Concept                | Icon Name              | Nav | Notes                            |
|------------------------|------------------------|:---:|----------------------------------|
| Member                 | `users`                | ✓   | Plural for collections           |
| Membership             | `calendar-range`       | ✓   |                                  |
| Delivery               | `calendar`             |     |                                  |
| Basket                 | `shopping-bag`         | ✓   | Paniers nav (basket_content.rb)  |
| Shop / Shop Orders     | `shopping-basket`      | ✓   | Shop nav (active_admin.rb)       |
| Activity               | `handshake`            | ✓   | Nav uses same icon               |
| Invoice / Billing      | `banknotes`            | ✓   | ⚠️ Custom Heroicon (no Lucide plural) |
| Payment                | `banknotes`            | ✓   | Same as above                    |
| Absence                | `tent`                 |     |                                  |
| Email / Mails          | `mails`                | ✓   | Plural; nav uses `mail`          |
| Newsletter             | `megaphone`            |     |                                  |
| Mail Template          | `clipboard`            |     |                                  |
| Announcement           | `megaphone`            |     | Same as newsletter               |
| Bidding Round          | `scale`                |     |                                  |
| Shares                 | `receipt-text`         |     |                                  |
| Basket Content         | `sprout`               |     |                                  |

#### Non-Model / Generic Panel Icons

| Concept                | Icon Name                        | Notes                        |
|------------------------|----------------------------------|------------------------------|
| Details                | `notebook-text`                  | ID, dates, validation info   |
| Contact                | `contact-round`                  | Name, email, phone, address  |
| Billing (panel)        | `banknotes`                      | ⚠️ Custom Heroicon           |
| Amount / Pricing       | `receipt-text`                   | Monetary breakdown           |
| Notes                  | `notepad-text`                   | Free-text notes              |
| Comments               | `message-square-text`            | ActiveAdmin comments         |
| Waiting / Pending      | `clock`                          | Waiting membership           |
| Config / Settings      | `sliders-horizontal`             | Configuration options        |
| Renewal                | `refresh-cw`                     | Membership renewal           |
| Sheets / PDF           | `file-spreadsheet`               | PDF sheet documents          |
| Attachments            | `paperclip`                      | File attachments             |
| Notifications          | `mail-check`                     | Email notifications          |
| Registration / Form    | `form`                           | Member registration form     |
| Recipients             | `users`                          | Mail recipients list         |
| Preview                | `eye`                            | Content preview              |
| Carpooling             | `car`                            | Carpooling info              |
| State / Status         | `circle-check-big`               | State/validation info        |
| Address / Location     | `map`                            | Physical address             |
| Overdue Notices        | `mail-warning`                   | Overdue/reminder notices     |
| Periods                | `calendar-days`                  | Delivery cycle periods       |
| Information            | `info`                           | Info/help text               |
| Missing Deliveries     | `triangle-alert`                 | Warning/missing data         |
| Support                | `life-buoy`                      | Help / support               |
| Updates                | `gift`                           | What's new                   |
| Analytics              | `chart-no-axes-combined`         | Historical year-over-year    |

### Custom Icons

Two icons in `app/assets/images/icons/` are **not** from Lucide:

- **`banknotes`** — Custom Heroicon (stacked bills). Lucide only has singular `banknote`.
  Used for billing/payment panels and nav.
- **`redo-off`** — Custom icon (redo arrow with slash). Hand-made for "no renewal" state.

### Adding New Icons

1. Find the icon on [Lucide](https://lucide.dev)
2. Download the SVG and save to `app/assets/images/icons/{name}.svg`
3. Set `stroke-width="1.5"` and remove the `class` attribute
4. Use via `icon("name")`, `panel "Title", icon: "name"`, or `f.inputs "Title", icon: "name"`

### Style Guidelines

- **Lucide only** — all icons come from Lucide (two custom exceptions noted above)
- **24px / stroke 1.5** — all SVGs use `width="24" height="24"` and `stroke-width="1.5"`
- **Match nav icons** — if a concept has a nav icon, the panel must use the same one
- **One icon per concept** — same concept = same icon everywhere
