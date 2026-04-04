# Stamped! Design Style Guide

## Purpose
This document defines the visual system for `Stamped! A City Passport`. It is written as a source document that can be exported to PDF for critique, handoff, or portfolio use. The goal is a cohesive app-wide identity: editorial, travel-inspired, tactile, and reward-driven.

## Brand Summary
`Stamped!` should feel like a modern city passport with hints of museum signage, travel ephemera, and collected stamp marks. The experience should balance discovery with warmth:

- Primary feeling: curious, collected, worldly
- Secondary feeling: tactile, celebratory, archival
- Avoid: generic tech UI, neon gradients, overly playful cartoon styling, heavy skeuomorphism

## Visual Keywords
- Passport
- Stamp
- Journey log
- Discovery dossier
- Editorial travel guide
- Civic landmark archive

## Design Principles
1. Use one strong accent color consistently instead of many competing brand colors.
2. Let typography create hierarchy before relying on decorative chrome.
3. Use grouped surfaces and generous spacing to keep dense information readable.
4. Make reward states feel ceremonial: stamps, seals, checkmarks, progress bars.
5. Respect accessibility settings by simplifying contrast, borders, and motion without changing the core structure.

## Color System

### Primary Brand Color
- Name: `Adventure Orange`
- Asset: `adventureOrange`
- Source value from asset catalog: `#F2743F`
- Role: primary accent, progress tint, highlight, stamp color, CTA emphasis

### Supporting Palette
Use Apple semantic backgrounds for most surfaces and reserve brand color for emphasis.

| Token | Value | Usage |
| --- | --- | --- |
| `Brand / Primary` | `#F2743F` | CTA buttons, progress, active icons, stamps |
| `Brand / Warm Gradient End` | `#FF8A57` | Brand gradients, celebratory fills |
| `Success` | System green | Visited/completed confirmation |
| `Error` | System red | Destructive actions, wrong answers |
| `Warning / Reward Gold` | `#D9A621` | Trophy/mastery moments only |
| `Background / Base` | `systemGroupedBackground` | Main app background |
| `Surface / Card` | `secondarySystemGroupedBackground` or `systemBackground` | Cards, grouped panels |
| `Text / Primary` | `primary` | Headings and body |
| `Text / Secondary` | `secondary` | Supporting information |
| `Border / Subtle` | `primary` at 10% to 20% | Card outlines in standard mode |

### Color Rules
- Brand orange is the dominant accent across `CityListView`, `CityDetailView`, `QuizView`, `PassportView`, `PassportGalleryView`, and `BuildingDetailView`.
- Do not introduce additional brand colors for screens unless they are semantic state colors.
- Green means completion or confirmed success only.
- Red means destructive state or incorrect quiz answer only.
- Gold is reserved for mastery or full completion.
- In standard mode, lean on semantic system backgrounds instead of filling screens with solid brand color.
- In high contrast mode, replace decorative color coding with `primary` and strong borders.

## Typography

### Type Direction
The app already mixes serif, rounded, monospaced, and SF system styles. That mix should be intentional:

- Serif display text for destinations, passport headings, and ceremonial moments
- Rounded/system bold text for approachable CTA and section headings
- Monospaced micro-labels for metadata, progress labels, and dossier labels
- Standard body text for readability and scalable accessibility

### Font Roles
| Role | Style | Usage |
| --- | --- | --- |
| `Display Hero` | `.system(.largeTitle, design: .serif)` bold | City names, country headers |
| `Display Section` | `.system(.title, design: .rounded)` bold or `.title2.bold()` | Welcome and section headlines |
| `Headline` | `.headline` or `.title3.bold()` | Card titles, primary labels |
| `Body` | `.body` | Descriptions and educational text |
| `Support` | `.subheadline` | Secondary explanations |
| `Caption` | `.caption`, `.caption2` | Metadata, status text, passive hints |
| `Utility Label` | monospaced caption, black/bold | Progress, dossier labels, stamp tags |

### Type Scale
Use this scale as the baseline visual spec:

| Token | Size | Weight | Suggested Use |
| --- | --- | --- | --- |
| `Hero XL` | 40-48 | Bold/Black | Country or passport spread title |
| `Hero L` | 34 | Bold | City hero title |
| `Title 1` | 28-32 | Bold | Major onboarding and modal headers |
| `Title 2` | 22-24 | Bold | Section entry points |
| `Title 3` | 20 | Semibold/Bold | Card headings |
| `Body L` | 17 | Regular/Semibold | Main explanatory text |
| `Body S` | 15-16 | Regular/Medium | Supporting copy |
| `Caption` | 12-13 | Medium/Bold | Metadata |
| `Micro Label` | 10-11 | Black | Utility labels and tracking-heavy tags |

### Type Rules
- Use uppercase tracked micro-labels sparingly for moments like `JOURNEY LOG`, `FIELD DATA`, `EXPLORATION PROGRESS`, and nickname tags.
- Keep body copy sentence case.
- Use serif only for important destination identity, not long-form paragraphs.
- Use monospaced captions for numerical progress, stats, and dossier-like metadata.
- Dynamic Type must not clip card content; layouts should stack before text shrinks aggressively.

## Spacing and Layout

### Spacing Scale
Adopt a restrained spacing scale derived from current screens:

| Token | Value |
| --- | --- |
| `XS` | 4 |
| `S` | 8 |
| `M` | 12 |
| `L` | 16 |
| `XL` | 20 |
| `2XL` | 24 |
| `3XL` | 30-32 |
| `4XL` | 40 |
| `5XL` | 60 |

### Layout Rules
- Default horizontal page padding on iPhone: `20` to `24`
- Default horizontal page padding on iPad content columns: `40`
- Preferred card spacing: `16` to `24`
- Preferred section spacing: `24` to `32`
- Large editorial sections: `40+`
- Max readable content width for dense detail screens: about `800`

## Shape Language

### Corner Radius
| Element | Radius |
| --- | --- |
| Hero cards and major surfaces | 20-24 |
| Passport or stamp cards | 15-20 |
| Utility buttons and chips | Capsule or 8-12 |
| High contrast mode | Reduce decorative radius if clarity improves |

### Borders and Shadows
- Standard mode: use soft shadows and subtle 1 pt outlines.
- High contrast mode: remove low-contrast shadows and replace with stronger outlines.
- Stamp treatments may use dashed borders for an analog passport feel.

## Imagery

### Image Direction
The app’s photography should feel documentary and place-based. Images are used to ground the architecture in real travel context.

### Image Style Rules
- Prioritize real city and building photography over illustration.
- Prefer vertical or cinematic crops that emphasize scale, facade, silhouette, and material.
- Avoid generic stock-photo lifestyle imagery.
- Favor daylight, legible structural detail, and minimal visual clutter.
- User-submitted photos should feel personal but still fit within the framed passport system.

### Asset Guidance
- Current asset catalog is intentionally minimal: app icon and the `adventureOrange` color token.
- Building images appear to be referenced via `building.assetName`, so imported photography should follow a consistent crop and naming pattern.
- When a building image is missing, fallback UI should remain branded and instructional rather than broken.

### Image Specifications
- Hero image aspect: flexible edge-to-edge crop
- Content mode: `.fill`
- Use clipping over letterboxing
- Overlay controls should sit in the lower trailing corner
- Fallback state should use branded background tint and camera iconography

## Iconography
- Use SF Symbols throughout for consistency and accessibility.
- Prefer filled symbols for reward, completion, or high-emphasis moments.
- Prefer outlined symbols for utility or passive controls.
- Common motifs: globe, seal, trophy, map pin, building, flame, mic, airplane, camera.
- Icons should usually inherit brand orange or semantic status color.

## Motion and Feedback

### Motion Tone
Motion should feel springy, celebratory, and tactile, but not noisy.

### Motion Rules
- Use spring animations for expansion, reveal, and button response.
- Use scale plus opacity for reward moments such as stamp unlocks and quiz completion.
- Use subtle lift effects for tappable cards.
- Avoid constant looping animations outside onboarding or reward moments.
- Respect `Reduce Motion`: replace scale/move transitions with opacity or no animation.

### Haptics and Sound
- Haptics should reinforce selection, success, and milestone moments.
- Sound should be rare and ceremonial, especially for stamp completion.
- Never require sound for understanding state changes.

## Component System

### 1. App Backgrounds
- Primary app shell background: `systemGroupedBackground`
- Card background: `secondarySystemGroupedBackground` or `systemBackground`
- Onboarding is the exception: use a dark, cinematic gradient anchored by brand orange fading into black.

### 2. Buttons
Primary CTA:
- Filled with brand orange
- White label text
- Bold weight
- Large control size
- Capsule or rounded rectangle shape

Secondary action:
- Tinted background using brand color at low opacity
- Brand-colored text
- Subtle border optional

Destructive action:
- System red
- Use only in alert flows and reset controls

### 3. Cards
Cards are core to the app’s identity. They should feel like artifacts, not generic tiles.

Shared card characteristics:
- Light semantic surface
- 16 to 24 radius
- Interior padding of `20` to `24`
- Soft shadow in standard mode
- Stronger border in high contrast mode

Card types:
- Discovery card
- Quiz interaction card
- Dossier card
- Travel info card
- Passport stamp card
- Progress summary card

### 4. Progress Indicators
- Tint with brand orange in standard mode
- Increase thickness when the moment matters
- Pair with explicit text value, not color alone
- Use monospaced numeric labels where possible

### 5. Stamp Motif
The stamp is the clearest distinctive element in the product. It should guide the rest of the visual language.

Stamp traits:
- Dashed or bordered frame
- Slight rotation when motion is allowed
- Strong orange accent
- White or neutral paper-like surface
- Official, commemorative copy tone

### 6. Quiz Surfaces
Quiz UI should feel like a field dossier:
- Structured panels
- Monospaced metadata labels
- Serif prompt headline
- Clear pass/fail colors
- Strong answer affordances with large hit areas

## Screen-Level Guidance

### Onboarding
Visual role: cinematic invitation

- Background should remain dark with a warm orange glow.
- Typography should be large, simple, and welcoming.
- Imagery should stay symbolic instead of photographic.
- Primary CTA remains orange and obvious.

### City List
Visual role: organized atlas

- Sidebar should feel clean and navigable.
- Orange appears in icons, progress, and active states.
- Welcome empty state should be spacious, icon-led, and lightly branded.
- Disclosure groups should animate with restraint.

### City Detail
Visual role: editorial city dossier

- Use serif city title and ceremonial nickname label.
- Hero card should feel elevated but not ornamental.
- Supporting cards should use grouped surfaces and strong hierarchy.
- Dividers should separate major knowledge sections cleanly.

### Building Detail
Visual role: immersive landmark profile

- Hero photography should lead the screen.
- Tooling for personal photo capture should feel integrated, not like a utility add-on.
- Metadata rows should read like a museum placard or travel note.
- Orange should guide actions and active states.

### Quiz
Visual role: field investigation

- Dossier card aesthetic is correct and should be preserved.
- Answer buttons should remain large, high contrast, and decisive.
- Celebration overlays can be bolder than the rest of the app.
- Progress and score should always stay visible.

### Passport and Passport Gallery
Visual role: collected travel record

- This is the app’s most branded area.
- Lean hardest into stamp, paper, archive, and completion metaphors.
- Country headings can be the largest serif typography in the app.
- Completed states should feel rewarding and collectible.

### Settings
Visual role: neutral utility with brand continuity

- Keep mostly system-native form styling.
- Use orange only for accent and preview controls.
- Destructive actions stay visually isolated.

## Accessibility
- Support Dynamic Type across all cards and stacked layouts.
- Do not encode meaning by color alone.
- Minimum tap target: `44x44`.
- In high contrast mode:
- Replace subtle shadows with visible borders.
- Use `primary` and semantic system colors instead of decorative tints.
- Reduce or remove low-opacity fills that obscure hierarchy.
- In reduce motion mode:
- Remove tilt, scale, and large spring transitions.
- Preserve hierarchy through opacity and timing instead.

## Content Tone
- Clear, concise, informed
- Slightly ceremonial for rewards and stamps
- Educational without sounding academic
- Travel-oriented without sounding like marketing copy

Preferred copy style:
- `Exploration Progress`
- `Journey Log`
- `Field Data`
- `Architectural Itinerary`
- `Official Passport Stamp`

## Do and Don't

### Do
- Use orange as the thread tying the app together.
- Mix serif display with system body text for editorial contrast.
- Keep screens airy even when content is dense.
- Reuse the stamp and dossier metaphors across the product.
- Let accessibility modes simplify, not redesign, the experience.

### Don't
- Add multiple unrelated accent colors.
- Overfill screens with orange.
- Use serif fonts for long passages.
- Overanimate standard navigation and forms.
- Introduce generic glassy tech-card aesthetics that conflict with the passport metaphor.

## Implementation Notes
To make this guide actionable in code, the next design-system step would be to centralize:

- color tokens
- typography tokens
- corner radius tokens
- spacing tokens
- shared card styles
- shared button styles

Recommended future files:
- `DesignTokens.swift`
- `AppTypography.swift`
- `AppCardStyle.swift`
- `AppButtonStyle.swift`

## PDF Export Notes
For a portfolio-style PDF, this document should be laid out in the following order:

1. Cover page
2. Brand summary
3. Color palette
4. Typography scale
5. Layout and spacing
6. Core components
7. Screen-by-screen guidance
8. Accessibility rules

If you want a more presentation-quality version next, the content in this file can be turned into:

- a polished PDF outline
- a Figma-ready style guide structure
- a visual spec with swatch tables and component callouts
