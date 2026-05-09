# Design Conventions

## Panel Icons

Panels can display an icon before their title using the `icon:` option:

```ruby
panel "Title", icon: "icon-name" do
  # ...
end
```

The icon renders at half opacity (`opacity-50`) at `size-5`,
lighter than the title so it doesn't feel heavy — it serves as a quick visual cue.

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
| Support                | `message-circle-question-mark`   | Help / support               |
| Updates                | `gift`                           | What's new                   |

### Custom Icons

Two icons in `app/assets/images/icons/` are **not** from Lucide:

- **`banknotes`** — Custom Heroicon (stacked bills). Lucide only has singular `banknote`.
  Used for billing/payment panels and nav.
- **`redo-off`** — Custom icon (redo arrow with slash). Hand-made for "no renewal" state.

### Adding New Icons

1. Find the icon on [Lucide](https://lucide.dev)
2. Copy the SVG from the local Lucide clone (`lucide/icons/{name}.svg`)
3. Save it in `app/assets/images/icons/{name}.svg`
4. Adjust `stroke-width` from `2` to `1.5` and remove the `class` attribute
5. Use the icon via `icon("name")` helper or `panel "Title", icon: "name"`

### Style Guidelines

- **Lucide only** — all icons should come from Lucide for visual consistency
- **24px / stroke 1.5** — all SVGs use `width="24" height="24"` and `stroke-width="1.5"`
- **Match nav icons** — if a concept has a nav icon, the panel must use the same one
- **One icon per concept** — if the same concept appears in multiple places, use the same icon
- **Muted color** — panel icons are intentionally subdued; they orient, not distract
- **Size 5** — panel icons render at `size-5` (20px) matching the title's visual weight
