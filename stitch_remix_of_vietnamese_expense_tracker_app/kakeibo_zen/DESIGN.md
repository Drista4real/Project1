---
name: Kakeibo Zen
colors:
  surface: '#f6fbf5'
  surface-dim: '#d7dbd6'
  surface-bright: '#f6fbf5'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f5f0'
  surface-container: '#ebefea'
  surface-container-high: '#e5e9e4'
  surface-container-highest: '#dfe4df'
  on-surface: '#181d1a'
  on-surface-variant: '#414943'
  inverse-surface: '#2c322e'
  inverse-on-surface: '#edf2ed'
  outline: '#717973'
  outline-variant: '#c0c9c1'
  surface-tint: '#3a674f'
  primary: '#14422d'
  on-primary: '#ffffff'
  primary-container: '#2d5a43'
  on-primary-container: '#9fcfb2'
  inverse-primary: '#a1d1b4'
  secondary: '#a0401c'
  on-secondary: '#ffffff'
  secondary-container: '#fe875d'
  on-secondary-container: '#722200'
  tertiary: '#004334'
  on-tertiary: '#ffffff'
  tertiary-container: '#005d49'
  on-tertiary-container: '#83d4b9'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#bceecf'
  primary-fixed-dim: '#a1d1b4'
  on-primary-fixed: '#002112'
  on-primary-fixed-variant: '#224f39'
  secondary-fixed: '#ffdbcf'
  secondary-fixed-dim: '#ffb59c'
  on-secondary-fixed: '#390c00'
  on-secondary-fixed-variant: '#802a05'
  tertiary-fixed: '#a1f3d6'
  tertiary-fixed-dim: '#85d6bb'
  on-tertiary-fixed: '#002118'
  on-tertiary-fixed-variant: '#00513f'
  background: '#f6fbf5'
  on-background: '#181d1a'
  surface-variant: '#dfe4df'
typography:
  display-currency:
    fontFamily: Be Vietnam Pro
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  display-currency-mobile:
    fontFamily: Be Vietnam Pro
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Be Vietnam Pro
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  body-md:
    fontFamily: Be Vietnam Pro
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  caption:
    fontFamily: Be Vietnam Pro
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.75rem
---

## Brand & Style

This design system embodies the mindful financial ethos of traditional Japanese Kakeibo merged with Scandinavian functional warmth ("Japandi"). Built specifically for mobile-first personal expense logging in Vietnam, the aesthetic rejects the aggressive gamification and sensory clutter of contemporary fintech. Instead, it cultivates calm, deliberate reflection on daily spending habits.

The experience feels like opening an exquisite, linen-bound ledger: tactile, quiet, and grounded. Interactions prioritize micro-rhythms of daily life—quick one-handed logging during transit, effortless category tagging, and serene visual summaries of balance without inducing financial anxiety. The visual tone balances discipline with softness: generous natural whitespace, organic corner radii, and honest, understated tactile feedback.

## Colors

The palette draws deeply from raw ceramics, unbleached washi paper, tea leaves, and fired clay:

- **Primary / Focus (`#2D5A43` & `#3A6351`):** Deep Sage Green grounds the system. Used for core structural anchors, active navigational states, primary transaction triggers, and balanced total states.
- **Surface & Canvas (`#F9F9F6`, `#FFFFFF`, `#F3F4EF`):** A warm porcelain base replaces sterile digital whites, easing visual strain. Primary content lives on crisp milk-white elevated cards (`#FFFFFF`), while secondary containers and utility zones utilize muted rice paper (`#F3F4EF`).
- **Expense Alert (`#D96B43`):** Warm terracotta coral. Avoids jarring emergency reds, signaling outflow and budget limits with dignified, humanistic clarity.
- **Income / Surplus (`#4E9F86`):** Soft jade mint. Expresses healthy growth, incoming funds, and savings surplus without garish neon tones.
- **Neutrals (`#1F2421` & `#7B8782`):** Primary copy uses Sumi Charcoal (`#1F2421`), ensuring crisp contrast and legible Vietnamese diacritics. Secondary timestamps, category metadata, and unit notations employ Slate Stone (`#7B8782`).

## Typography

The type architecture relies on **Be Vietnam Pro** for authentic, native handling of complex Vietnamese tonal marks (dấu hỏi, ngã, nặng, sắc, huyền) without vertical clipping or awkward kerning anomalies. Headings and currency amounts stay compact and structurally balanced.

For structural metadata, numeric breakdowns, and interactive tags, **Plus Jakarta Sans** provides a warm, modern counterweight. Monospaced or tabular numeral styling is strictly applied to currency strings (`display-currency`) to prevent visual jittering across dynamic balance changes. Vietnamese dong currency symbols (`₫`) should sit with a subtle 80% opacity and slightly reduced scale adjacent to the numerical value.

## Layout & Spacing

Designed fundamentally around a base 393px viewport (iPhone / contemporary Android flagships). The grid relies on a fluid single-column stack bounded by strict safe areas:

- **Horizontal Margins:** Base page padding is pinned to `16px` (`margin: 1rem`) on standard mobile widths, expanding to `24px` on compact tablets.
- **Thumb Zone Hierarchy:** Destructive and primary logging controls cluster within the bottom 40% of the screen. Critical input fields and balance totals rest in the comfortable center zone, keeping the top zone reserved exclusively for non-interactive monthly summaries and date selectors.
- **Rhythm:** Internal card padding is strictly uniform at `16px` or `20px` to maintain visual serenity. Micro gaps between inline elements (such as category icon badges and expense labels) maintain a disciplined `8px` or `12px` interval.

## Elevation & Depth

This system avoids synthetic drop shadows, relying instead on surface tonality and Japanese paper-layering principles:

- **Base Canvas:** Neutral porcelain tint (`#F9F9F6`) forms the ground tier.
- **Resting Layer (Cards & Modules):** Pure ceramic white (`#FFFFFF`) with a subtle `1px` stroke tinted in `#E5E7DF`. When elevation is required for floating elements, use ambient, whisper-soft diffusion: `0 8px 24px -4px rgba(31, 36, 33, 0.05)`.
- **Active / Elevated Layer (Bottom Navigation & FAB):** The bottom bar floats with a background blur backdrop (`rgba(249, 249, 246, 0.85)` + 16px blur) combined with a soft ambient perimeter shadow `0 -4px 20px rgba(45, 90, 67, 0.04)`.
- **Primary Floating Action Button:** Casts a tinted organic shadow: `0 8px 16px -2px rgba(45, 90, 67, 0.28)`, signaling physical depressibility.

## Shapes

The geometric framework balances approachable softness with Japanese geometric discipline. Base card components use a 16px to 20px radius (`rounded-lg` through `rounded-xl`), evoking polished sea stones. Interactive touch targets (chips, filter capsules, and badges) transition to 9999px full-pill configurations, creating a clear visual dichotomy between containers of data and interactive triggers.

## Components

### Buttons
- **Primary FAB (Expense Quick-Add):** 56px circular button anchored centrally on the bottom navigation bar. Colored Deep Sage Green (`#2D5A43`) with a crisp white 2px stroke monoline `+` icon.
- **Standard Action Buttons:** 48px height, 16px radius or full-pill, filled with `#2D5A43` for positive commits or `#F3F4EF` with `#1F2421` text for secondary dismissal.

### Category Chips & Pills
- Pill-shaped (`rounded-full`), height of 32px with 12px horizontal padding.
- Resting state: Unselected chips sit on `#F3F4EF` with `#7B8782` text.
- Selected state: Soft Sage tint (`#E8EFEA`) with `#2D5A43` text and a refined 1px matching border.

### Transaction Lists
- Grouped by day with a quiet header (date left-aligned, total daily spent right-aligned in `label-sm`).
- List items have zero dividers; separation is achieved via `8px` vertical spacing between subtle white card strips or clean single-line rows with 40px category icon avatars.
- Avatars use 40px rounded squares (12px radius) filled with soft pastel category tints (e.g., `#FDF3EC` for Dining, `#EAF4F0` for Health) hosting a 2px monoline icon.

### Currency Input Display
- Large-format tactile keypad entry. Integers render in `display-currency-mobile` (`28px` to `32px` bold).
- The Vietnamese currency symbol `₫` remains anchored at the end. Negative outflow balances automatically prepend with a Terracotta (`#D96B43`) minus glyph.

### Cards & Ledger Blocks
- 16px or 20px border radius with milk-white background.
- Kakeibo Four-Pillar grouping (Needs / Survival, Wants / Optional, Culture / Enrichment, Extra / Unexpected) rendered as compact progress bars with soft, rounded ends and natural earth tones.