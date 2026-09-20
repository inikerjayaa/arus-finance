# SAKU — Final Design Direction

This document is the visual and product-interface direction for the final SAKU cosmetic sweep.
It is intentionally separate from product/domain rules. Financial behavior, local-first storage,
backup safety, and compatibility contracts are not changed by this document.

## Product character

SAKU should feel like a calm personal finance tool that belongs on a person's phone for years:
clear, private, fast, familiar, and quietly premium.

It must not look like a generic AI-generated fintech template, a game dashboard, or a marketing page
compressed into a mobile app.

Design keywords:
- calm
- precise
- personal
- warm restraint
- modern, not futuristic
- premium, not luxurious
- useful before decorative

## Liveliness dials

Use these as the default visual register for the app:

- ENERGY 2 / 5 — recognizable SAKU identity without visual noise
- RHYTHM 2 / 5 — consistent system with deliberate variation where hierarchy needs it
- MOTION 1 / 5 — subtle functional motion only; no ornamental animation loops

The interface must not become sterile. Restraint means every visible element earns its place, not that
all screens become flat grey lists.

## Brand system

### Core palette

- Cyprus `#004741` — brand depth / supporting primary
- Sand `#F0EDE4` — warm light surface
- Vulcanico `#FF4103` — deliberate accent / high-attention action
- Noturno `#001621` — dark surface / deep brand background

Use neutrals derived from the active theme for text, dividers and secondary surfaces.
Do not introduce unrelated decorative colors just to make a screen feel designed.

### Accent discipline

Vulcanico is an accent, not the default color of every interactive element.
Use it where attention is intentionally concentrated: primary creation/action moments,
selected high-value state, or a small brand emphasis.

If buttons, icons, chips, links, charts and decorative lines are all orange on the same screen,
the accent has failed.

Cyprus and Noturno provide structure. Sand provides warmth. Vulcanico provides the moment of focus.

## Typography

Typeface: bundled Plus Jakarta Sans only.

Typography should feel compact and confident rather than oversized.
Use hierarchy through size, weight, spacing and placement, not repeated uppercase labels.

Default intent:
- display / exceptional numeric emphasis: 700
- page title / strong section: 600–700
- normal control labels: 600
- body: 400–500
- secondary metadata: 400–500

Avoid:
- oversized marketing-style headlines inside utility screens
- excessive bold text
- wide-tracked uppercase eyebrow labels
- monospace as decoration
- tiny low-contrast secondary text

Financial numbers may receive stronger visual weight than surrounding labels, but should remain easy
to scan rather than theatrical.

## Shape language

Do not make every component a pill.

Use a small shape vocabulary:
- compact controls / inputs: `SakuBrand.controlRadius`
- larger grouped surfaces: `SakuBrand.cardRadius`
- circular shape only when the function is genuinely circular (avatar, icon button, FAB)
- capsule/pill only for real compact state/filter/chip semantics

A card, input, button and status chip should not all have the same silhouette.

## Surfaces and elevation

The default SAKU surface is flat or lightly separated.

Use hierarchy in this order:
1. whitespace
2. typography
3. surface tone
4. border/divider
5. elevation only when something is genuinely above another layer

Do not apply soft shadow to every card. Do not use glow as general decoration.
Do not use glassmorphism as the app's visual identity.

## Cards

A card is a grouping tool, not the default wrapper for every piece of content.

Use a card when the content forms one meaningful object:
- account summary
- budget state
- grouped setting
- important dashboard module

Prefer direct list/layout composition when the card would merely add another rounded rectangle.

Within one screen, stronger information may use a richer/full-width treatment while supporting items
can stay simple. Do not force every module to equal visual weight.

## Layout and spacing

Whitespace is structural.

Do not use one identical gap everywhere. Related elements sit closer; unrelated sections get more room.
The screen should have visible rhythm without becoming loose or wasteful.

Mobile layout is the primary layout, not a desktop layout reduced in size.

Requirements:
- respect safe areas
- no horizontal overflow
- bottom navigation must never cover content
- interactive targets remain at least 44x44 logical pixels; SAKU targets 48 where practical
- forms must remain usable with the on-screen keyboard open
- long text and large accessibility text must reflow rather than clip

## Navigation

Primary destinations stay easy to reach with one hand.
Keep persistent navigation compact enough that content remains dominant.

Navigation labels and icons must describe destinations, not decorate them.
Avoid duplicate navigation cues or arrows that add no meaning.

## Icons

Use icons for recognition and action, not decoration.

Rules:
- icon meaning must match the real function
- prefer the approved SAKU icon registry / bundled assets
- brand icons are used only for actual brands
- no generic sparkle, magic, robot or decorative AI symbols
- no emoji in product UI
- do not add arrows to every button

Consistency means comparable stroke/weight and visual size, not blindly using one glyph style everywhere.

## Buttons and actions

Every screen should make the primary action obvious without making every action primary.

Hierarchy:
- Filled: primary action for the current decision
- Outlined / tonal: important secondary action
- Text: low-emphasis / reversible / navigation action
- Destructive actions use semantic error treatment and explicit copy

Avoid multiple equally loud filled buttons competing on one screen.
Use action labels that state the result: `Buat SAKU`, `Simpan`, `Tambah transaksi`, `Restore`, not vague
marketing verbs.

## Copy

SAKU copy should sound like a useful Indonesian app, not a chatbot or a fintech advertisement.

Rules:
- short and concrete
- use familiar words
- explain only what prevents a real mistake
- field labels should not repeat obvious examples
- never expose raw exceptions or developer terminology
- never invent statistics, claims or reassurance that the app cannot prove
- status/error text must tell the user what happened and what they can do next
- avoid filler such as “mulai perjalanan”, “tingkatkan pengalaman”, “solusi cerdas”, and similar generic hype

Keep SAKU's local-first promise factual and contextual; do not repeat it under every control.

## Financial dashboard hierarchy

The home screen is an operational finance surface, not a collection of equal cards.

Priority order:
1. current financial position / primary balance context
2. fast transaction action
3. current-period income/expense signal
4. category / spending insight that materially helps the user
5. recent activity / secondary context

Not every metric deserves a card. Do not create decorative KPIs merely to fill space.
Charts must answer a specific user question. If a number or list communicates the fact faster, use that.

## Forms

Keep forms direct.

- one clear label per field
- examples only when input format is genuinely ambiguous
- validation near the field
- keyboard type matches data
- important irreversible actions require confirmation
- avoid helper paragraphs that repeat the label

## States

Every data-driven surface must have intentional:
- loading state
- empty state
- error state

Empty states should explain the next useful action, not contain generic illustration/copy by default.
Errors must not depend on color alone.

## Light and dark parity

Light and dark are two supported presentations of the same design system.
Neither is a decorative afterthought.

Verify in both modes:
- text contrast
- icon contrast
- input boundaries
- selected/disabled states
- destructive states
- charts
- dialogs / sheets
- navigation

Do not make dark mode a neon version of light mode.

## Accessibility and human-use baseline

- normal text target WCAG AA contrast (4.5:1)
- large text at least 3:1
- non-text control/state boundaries at least 3:1 where the boundary carries meaning
- never communicate error/success/state using color alone
- screen-reader semantics remain meaningful
- minimum touch area 44x44; prefer existing 48x48 SAKU contract
- text scaling must not clip essential content

## Motion

Motion is functional only.

Allowed purposes:
- communicate navigation / hierarchy change
- acknowledge a completed interaction
- preserve spatial continuity
- soften an abrupt state transition

Avoid:
- endless pulsing status dots
- looping decorative animation
- bounce for ordinary buttons
- animation that delays access to finance data

Respect reduced-motion behavior where platform/framework support applies.

## Anti-slop filter for SAKU

Before considering a screen cosmetically complete, ask:

1. Is every decorative element serving hierarchy, state, identity or comprehension?
2. Is the accent color concentrated rather than sprayed everywhere?
3. Are cards used because content needs grouping, not because cards are the default component?
4. Are radii/shadows/elevation communicating component type and hierarchy?
5. Does spacing show which things belong together?
6. Is the copy concrete, human and free of technical leakage or filler?
7. Does the screen still look like SAKU if all labels are removed?
8. Is the primary action visually obvious within three seconds?
9. Does the design hold in both light and dark mode?
10. Does the screen remain usable on the physical Android target and at larger text scale?

If a technique cannot answer “why is this here?”, remove it or redesign it.

## Final cosmetic delivery gate

A V48 cosmetic checkpoint is ready only when all are true:

- visual hierarchy is intentional
- residual user-facing `Arus` branding is gone where compatibility does not require it
- typography follows this document
- palette follows SAKU brand tokens
- card/shape usage is purposeful
- no decorative gradient/glow/glass/emoji/default AI iconography has been introduced
- primary/secondary/destructive action hierarchy is clear
- loading/empty/error states remain understandable
- light and dark modes remain coherent
- accessibility/tap-target contracts remain intact
- finance/domain behavior and local-first/data-safety behavior are unchanged
- analyzer/tests/native compile gates remain green
