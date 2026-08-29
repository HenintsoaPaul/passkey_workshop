---
name: SignApp Passkey Mobile
colors:
  surface: '#11131c'
  surface-dim: '#11131c'
  surface-bright: '#373943'
  surface-container-lowest: '#0c0e17'
  surface-container-low: '#191b24'
  surface-container: '#1d1f29'
  surface-container-high: '#282933'
  surface-container-highest: '#32343e'
  on-surface: '#e1e1ef'
  on-surface-variant: '#d2c1d5'
  inverse-surface: '#e1e1ef'
  inverse-on-surface: '#2e303a'
  outline: '#9b8c9e'
  outline-variant: '#4f4353'
  surface-tint: '#e8b3ff'
  primary: '#e8b3ff'
  on-primary: '#500074'
  primary-container: '#c961ff'
  on-primary-container: '#460066'
  inverse-primary: '#921eca'
  secondary: '#c0c5e5'
  on-secondary: '#292f48'
  secondary-container: '#404560'
  on-secondary-container: '#aeb4d3'
  tertiary: '#ffb0ce'
  on-tertiary: '#63003b'
  tertiary-container: '#f750a4'
  on-tertiary-container: '#570033'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#f6d9ff'
  primary-fixed-dim: '#e8b3ff'
  on-primary-fixed: '#310049'
  on-primary-fixed-variant: '#7200a3'
  secondary-fixed: '#dde1ff'
  secondary-fixed-dim: '#c0c5e5'
  on-secondary-fixed: '#141a32'
  on-secondary-fixed-variant: '#404560'
  tertiary-fixed: '#ffd9e5'
  tertiary-fixed-dim: '#ffb0ce'
  on-tertiary-fixed: '#3e0022'
  on-tertiary-fixed-variant: '#8c0055'
  background: '#11131c'
  on-background: '#e1e1ef'
  surface-variant: '#32343e'
typography:
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Hanken Grotesk
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.05em
  button:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 20px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  margin-mobile: 16px
  gutter-mobile: 12px
---

## Brand & Style

The design system is engineered for **SignApp Passkey**, focusing on a high-trust, security-first mobile experience. The brand personality is professional, authoritative, and frictionless, catering to executives and legal professionals who require secure document signing on the move.

The visual style is **Corporate / Modern** with a focus on **Tonal Layering**. It moves away from the web's heavy gradients to favor solid, deep-ink surfaces that provide better readability and focus on mobile OLED screens. The aesthetic prioritizes clarity and precision, ensuring that the critical actions of authentication and signing feel deliberate and secure.

- **Professionalism:** Expressed through structured grids and a sober, dark-mode-first approach.
- **Security:** Evoked by high-contrast labels, clear status indicators, and robust component shapes.
- **Efficiency:** Achieved through optimized mobile density and clear visual hierarchies.

## Colors

This design system utilizes a sophisticated dark palette anchored in deep navy and vibrant purple/pink accents.

- **Primary & Accent:** A vibrant Purple (#BD52F5) serves as the primary action color, with Pink (#F54EA2) used sparingly for high-priority secondary actions or decorative indicators.
- **Surfaces:** To maintain a "solid" aesthetic, the system uses three tiers of dark navy/neutral. The background is a deep ink (#0F111A), while cards and interactive containers use lighter steps (#1A1D2D and #252B44) to create depth without relying on drop shadows.
- **Functional Colors:** Standardized success (green), warning (amber), and error (red) colors are used for signature status badges and system alerts, ensuring immediate recognition of document states.

## Typography

The typography system is unified under **Hanken Grotesk** across all roles, including headlines, body text, and labels. This ensures a cohesive, sharp, and contemporary feel with excellent legibility in high-density mobile interfaces.

For metadata, hash values, and cryptographic details (SHA-256 fingerprints), the system continues to use **Hanken Grotesk**, utilizing medium weights and increased letter-spacing to maintain a technical scannability without breaking the unified font aesthetic.

- **Headlines:** Use tight letter-spacing for a "locked-in" professional look.
- **Labels:** Utilize medium weights and slightly increased tracking (0.05em) to denote metadata or status clearly.
- **Mobile Scale:** Headlines are capped at 28px to ensure long document titles do not wrap excessively.

## Layout & Spacing

The design system employs a **fluid-to-safe-margin** layout. On mobile devices, a standard 16px side margin is maintained. The internal rhythm is based on a 4px baseline grid.

- **Vertical Rhythm:** Components are separated by 16px (md) or 24px (lg) depending on the content relationship.
- **Card Padding:** Internal padding for document cards is set to 16px to ensure touch targets for actions within the card (like "view" or "sign") are accessible.
- **Stacking:** Mobile layouts should be strictly vertical. Side-by-side elements (like two small badges) must maintain at least a 12px gutter.

## Elevation & Depth

To maintain the "clean and solid" requirement, this design system avoids heavy ambient shadows. Instead, it uses **Tonal Layering** and **Low-Contrast Outlines**.

- **Level 0 (Background):** Base surface at #0F111A.
- **Level 1 (Cards):** Surfaces at #1A1D2D with a subtle 1px border of #252B44 to define the edges against the background.
- **Level 2 (Modals/Popovers):** Surfaces at #252B44. These are the only elements allowed to have a subtle, 10% opacity black shadow to provide a slight lift from the card layer.
- **Interaction:** Buttons use a solid primary color fill. When pressed, they shift 10% darker rather than using an elevation change.

## Shapes

The design system uses a **Rounded** (Level 2) shape language. This provides a balance between the technical nature of the app and a modern, user-friendly mobile experience.

- **Standard Radius:** 8px (0.5rem) for cards and input fields.
- **Large Radius:** 16px (1rem) for bottom sheets and primary authentication containers.
- **Pill:** Reserved exclusively for status badges and primary "Passkey" action buttons to make them instantly recognizable as the most important interactive elements.

## Components

### Document Cards
Cards use the `#1A1D2D` surface. They must include the document title (Headline-sm), a timestamp (Label-md), and a trailing status badge. The bottom of the card can feature small action icons (Download, History) with a minimum 44x44px touch target.

### Signature Status Badges
Badges are pill-shaped with a 10% opacity background of the status color and a solid 100% opacity text.
- **Waiting:** Amber (#F59E0B)
- **Signed:** Green (#10B981)
- **Draft:** Neutral (#64748B)

### Passkey Authentication Buttons
The most prominent component in the system. These are full-width, pill-shaped buttons using the Primary Purple (#BD52F5) fill. They must feature a leading icon (Key or Fingerprint) and centered text in Hanken Grotesk Semibold.

### Input Fields
Inputs are outlined with a 1px border (#252B44) and a solid background (#0F111A). Labels are placed above the field using `label-md`.

### Signature Progress Bar
A horizontal bar with a background of `#252B44` and a fill using the Primary Purple. Progress percentage is displayed at the top right of the bar using `label-sm`.