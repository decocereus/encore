---
name: Encore
description: A native macOS 26 menu bar player for YouTube Music, built as one Liquid Glass capsule that grows into a drawer.
colors:
  accent: "#0A84FF"
  warning: "#FF9F0A"
  label: "rgba(255, 255, 255, 0.85)"
  label-secondary: "rgba(255, 255, 255, 0.55)"
  label-tertiary: "rgba(255, 255, 255, 0.25)"
  fill-rest: "rgba(255, 255, 255, 0.06)"
  fill-hover: "rgba(255, 255, 255, 0.07)"
  fill-field: "rgba(255, 255, 255, 0.08)"
  fill-control: "rgba(255, 255, 255, 0.10)"
  fill-selected: "rgba(255, 255, 255, 0.14)"
  fill-on: "rgba(255, 255, 255, 0.20)"
typography:
  title:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: "20px"
  headline:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "13px"
    fontWeight: 700
    lineHeight: "16px"
  body:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: "15px"
  body-strong:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: "15px"
  subheadline:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: "14px"
  label:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "10px"
    fontWeight: 500
    lineHeight: "13px"
  caption:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "10px"
    fontWeight: 400
    lineHeight: "13px"
  time:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "10px"
    fontWeight: 400
    lineHeight: "13px"
    fontFeature: "tnum"
rounded:
  panel: "28px"
  icon-well: "22px"
  art-drawer: "18px"
  tile-lg: "12px"
  row: "10px"
  tile: "8px"
  thumb: "6px"
  capsule: "9999px"
spacing:
  hairline: "2px"
  xs: "4px"
  sm: "8px"
  md: "10px"
  panel-margin: "12px"
  stack: "14px"
  list-label: "18px"
  gutter: "24px"
  transport: "28px"
  empty-inset: "32px"
components:
  panel-pill:
    rounded: "{rounded.panel}"
    width: "360px"
    height: "128px"
    padding: "8px 10px 8px 8px"
  panel-drawer:
    rounded: "{rounded.panel}"
    width: "360px"
    height: "620px"
  drawer-header:
    height: "52px"
    padding: "0 12px"
  play-pause-drawer:
    backgroundColor: "{colors.accent}"
    textColor: "#FFFFFF"
    rounded: "{rounded.capsule}"
    size: "56px"
  play-pause-pill:
    backgroundColor: "{colors.accent}"
    textColor: "#FFFFFF"
    rounded: "{rounded.capsule}"
    size: "36px"
  play-pause-mini:
    backgroundColor: "{colors.accent}"
    textColor: "#FFFFFF"
    rounded: "{rounded.capsule}"
    size: "28px"
  play-collection:
    backgroundColor: "{colors.accent}"
    textColor: "#FFFFFF"
    typography: "{typography.body-strong}"
    rounded: "{rounded.capsule}"
  glyph-button:
    textColor: "{colors.label}"
    rounded: "{rounded.capsule}"
    size: "32px"
  glyph-button-hover:
    backgroundColor: "{colors.fill-control}"
    textColor: "{colors.label}"
    rounded: "{rounded.capsule}"
  tab-item:
    textColor: "{colors.label-secondary}"
    typography: "{typography.label}"
    rounded: "{rounded.capsule}"
    height: "34px"
    padding: "0 12px"
  tab-item-selected:
    backgroundColor: "{colors.fill-selected}"
    textColor: "{colors.label}"
    typography: "{typography.label}"
    rounded: "{rounded.capsule}"
    height: "34px"
  track-row:
    textColor: "{colors.label}"
    typography: "{typography.body}"
    rounded: "{rounded.row}"
    padding: "5px 8px"
  track-row-hover:
    backgroundColor: "{colors.fill-hover}"
    rounded: "{rounded.row}"
  playlist-row:
    textColor: "{colors.label}"
    rounded: "{rounded.tile-lg}"
    padding: "8px"
  playlist-row-hover:
    backgroundColor: "{colors.fill-hover}"
    rounded: "{rounded.tile-lg}"
  search-field:
    backgroundColor: "{colors.fill-field}"
    textColor: "{colors.label}"
    typography: "{typography.body}"
    rounded: "{rounded.capsule}"
    height: "34px"
    padding: "0 12px"
  source-row:
    backgroundColor: "{colors.fill-rest}"
    textColor: "{colors.label}"
    rounded: "{rounded.tile-lg}"
    height: "44px"
    padding: "0 12px"
  source-row-hover:
    backgroundColor: "{colors.fill-control}"
    rounded: "{rounded.tile-lg}"
  duck-badge:
    backgroundColor: "{colors.fill-control}"
    textColor: "{colors.label}"
    typography: "{typography.label}"
    rounded: "{rounded.capsule}"
    height: "24px"
    padding: "0 10px"
---

# Design System: Encore

## Overview

**Creative North Star: "The Pill Is the Player"**

Encore is one piece of Liquid Glass hanging under the menu bar. At rest it is a 128pt compact player in three rows: the artwork with the title over the artist, the like and save glyphs and an expand chevron, a seek bar, then volume beside previous, play/pause and next. Expanding does not open another window: the same glass shape grows downward into a 620pt drawer, and the artwork moves with it, from a 40pt circle in the pill to a large rounded square in the drawer. Collapsing runs the same movement in reverse.

The glass is frosted Liquid Glass with nothing painted under it, so the desktop shows through, blurred. The artwork itself is the only colour that changes with the track, and the chrome brings no colour of its own. The one fixed colour is the system accent, and it appears only on controls that start playback. Everything else is drawn in hierarchical system foregrounds (primary, secondary, tertiary) and a short ladder of translucent primary fills. Type is SF Pro at macOS system text styles, and every icon is an SF Symbol.

The density is that of a menu bar utility: small, close, and quick to dismiss. There is no YouTube or YouTube Music branding anywhere in the chrome. Liked Songs uses Encore's own heart tile instead of the service's artwork.

**Key Characteristics:**
- One continuous glass shape, 360pt wide, in two heights: pill (128pt) and drawer (620pt).
- Frosted glass over the desktop. The chrome adds no colour except the accent.
- The accent fills play controls and nothing else.
- SF Pro system text styles and SF Symbols only. Hierarchy comes from weight and from the primary, secondary and tertiary foregrounds, never from new colours.
- Icon-only controls have no chrome at rest. They show a soft circular fill on hover.
- Scrolling lists fade out at their top and bottom edges instead of being cut off by the frame.

## Colors

The chrome is colourless: plain frosted glass, one accent, and a set of translucent neutrals that sit on whatever the desktop shows through. Values in the frontmatter are the dark-appearance resolutions of SwiftUI semantic styles; the source refers to the styles, not to the hex values. The light appearance has never been captured, so its legibility on the glass is unverified.

### Primary
- **System Accent** (`Color.accentColor`): fills the play/pause circle at every size (28, 36, 56pt) and the capsule Play button on a playlist. The glyph on it is always white. Because it is the user's own System Settings accent, Encore never hard-codes the hue. Captures render it as system blue, slightly deeper where it sits on glass.

### Neutral
- **Label** (`.primary`): track titles, the selected tab, active glyphs.
- **Secondary Label** (`.secondary`): artists, subtitles, times, unselected tabs, empty-state copy, the volume speaker icons.
- **Tertiary Label** (`.tertiary`): disclosure chevrons on rows and the placeholder note in an artwork that hasn't loaded.
- **Fill ladder** (`.primary.opacity(...)`): rest 0.06 (empty-state icon well, source row at rest), hover 0.07 (track and playlist row hover), field 0.08 (search capsule), control 0.10 (glyph hover, duck badge, source row hover), selected 0.14 (tab selection), on 0.20 (Up Next toggle when on, Liked Songs tile).

### Named Rules
**The Accent Means Play Rule.** The accent appears only on controls that start or pause playback: the play/pause circle and a collection's Play button. Navigation, selection, sliders and toggles use the primary foreground. Sliders are tinted `.primary`, and the selected tab is a primary fill, never the accent.

**The No Painted Colour Rule.** The chrome adds no hue of its own. The panel is plain frosted glass, and every overlay is a primary-foreground opacity from the fill ladder, so the panel stays readable over any desktop.

## Typography

**Display Font:** none. Encore has no display tier.
**Body Font:** SF Pro, through SwiftUI system text styles.
**Label/Mono Font:** SF Pro with monospaced digits (`.monospacedDigit()`) for times and percentages.

**Character:** Encore uses the system type styles at their macOS sizes and builds hierarchy from weight and foreground tier. The largest text is the track title in the drawer, at title3 semibold.

### Hierarchy
- **Title** (title3, semibold): the current track title in the drawer.
- **Headline** (headline): empty-state and error titles, the sign-in prompt title, a playlist's name in its header.
- **Body Strong** (callout, semibold or medium): the pill's track title, the playing track in a list (semibold), playlist names (medium), the Play button's label.
- **Body** (callout): row titles, empty-state explanations, the search field.
- **Subheadline** (subheadline): artist · album under the drawer title. In semibold it marks list sections ("Up Next", "Playlists").
- **Label** (caption, medium): tab labels and the duck badge.
- **Caption** (caption / caption2): row subtitles, the pill's artist line, the mini player.
- **Time** (caption2, monospaced digits): elapsed and remaining time under the drawer scrubber, animated with `.numericText()`, and elapsed time and track length either side of the pill's seek bar (no numeric transition).

### Named Rules
**The System Styles Rule.** Set type with system text styles (`.title3`, `.headline`, `.callout`, `.subheadline`, `.caption`, `.caption2`) and weights. Never use fixed point sizes, except for SF Symbols sized relative to their control (the play glyph is 0.4 of the button diameter).

**The Numbers Hold Still Rule.** Any number that changes while you watch it (times, percentages) uses monospaced digits.

## Layout

The panel has a fixed width of 360pt and two fixed heights: pill 128pt and drawer 620pt. It sits inside a 12pt margin that leaves room for the glass edge. Nothing in it reflows; the expanded/collapsed state is the only layout change.

- **Pill:** three rows with 6pt spacing, inset 8pt top and bottom, 8pt leading and 10pt trailing.
  - **Track row:** a 40pt circular artwork, title over artist (1pt gap), a flexible spacer, the 28pt like and save glyphs side by side, and a 28pt expand chevron, 10pt apart. Clicking the row outside its buttons expands the drawer; the two rows below keep their clicks for the sliders and buttons.
  - **Seek row:** elapsed time, a mini seek slider, and the track length, in caption2 monospaced digits, with 8pt spacing and a further 4pt horizontal inset.
  - **Controls row:** a 132pt volume slider, a flexible spacer, then 32pt previous, a 36pt play/pause and 32pt next, 6pt apart.
- **Drawer:** a 52pt header (account menu or Back on the left, the collapse chevron on the right, and between them the mini now-playing or the duck badge), then the tab content, then the tab capsule with 6pt above and 12pt below. Toasts sit 4pt above the tab capsule, over the faded bottom edge of the content.
- **Now Playing:** a vertical stack with 14pt spacing. It holds the artwork (232pt, with 8pt vertical padding), the title row, the scrubber, the transport (28pt between previous, play and next), and a volume row with an Up Next toggle. The title row has the 30pt like glyph on the left, the centred title block, and the 30pt save glyph on the right, in an 18pt gutter. Scrubber and volume rows sit in a 24pt gutter. Up Next replaces the artwork in the same slot, at 248pt tall.
- **Lists:** rows sit inside 10pt horizontal list padding. Section labels align at 18pt, which matches the row content edge (10pt list padding plus 8pt row padding). Rows stack with no gap. Lists hide their scroll indicators and fade their edges (10pt at the top, 28pt at the bottom) so rows pass under the tab capsule.
- **Library:** the search field on top, then either the playlist list (New Playlist, Liked Songs, then a "Playlists" section) or, while there is a query, search results ("In Your Library" playlists whose names match, then "Songs"). An open playlist or the New Playlist / Edit Details form replaces the whole tab, with Back in the header.
- **Empty and error states:** centred vertically, with 32pt horizontal insets (28pt in the sign-in prompt), a 12pt or 10pt stack, a headline, secondary callout copy, and standard system buttons.
- **Settings:** a separate window with a standard grouped `Form`, 460pt wide, sized to its content. It uses system controls only.

## Elevation & Depth

Depth comes from material. There is no shadow vocabulary. The panel is a single `.glassEffect(.regular)` with nothing painted under it. The hosting panel turns its window shadow off and leaves the edge to the glass. The tab capsule is a second, interactive glass layer (`.regular.interactive()`) that floats over the scrolling content. Everything else is flat on the glass and separated only by fill opacity.

### Shadow Vocabulary
- **Artwork lift** (`.shadow(color: .black.opacity(0.3), radius: 16, y: 8)`): used only on the large drawer artwork, so the cover reads as an object resting on the glass.

### Named Rules
**The Two Glasses Rule.** There are exactly two glass surfaces: the panel itself and the tab capsule. Rows, fields, badges and buttons are opacity fills on the panel's glass, never glass of their own.

## Shapes

The form language is continuous curves and capsules. The panel is a continuous rounded rectangle with a 28pt corner radius at both heights: the 128pt pill and the 620pt drawer are the same shape, only taller. Corner radii scale with the size of the element: the 232pt artwork uses 18pt, the 96pt empty-state well 22pt, the 76pt playlist header tile and the 48pt rows' hover plate 12pt, track-row hover plates 10pt, playlist thumbnails 8pt, track thumbnails 6pt. Artwork in the pill (40pt) and the mini player (30pt) is fully circular. Every control capsule (tabs, search field, duck badge, Play button) and every round control (play/pause, glyph hover) is a capsule or a circle. The Liked Songs tile uses a 0.5pt primary stroke at 0.15. The New Playlist tile uses a 1pt dashed primary stroke at 0.2. These are the only strokes in the system.

## Components

### Play/Pause Button
The only filled button in the panel.
- **Shape:** circle, in three sizes: 56pt in the drawer transport, 36pt in the pill, 28pt in the mini player.
- **Colour:** accent fill with a white `play.fill` / `pause.fill` glyph, semibold, at 0.4 of the diameter.
- **States:** the glyph swaps with `.symbolEffect(.replace)`. With no track loaded it is disabled at 0.45 opacity. Space toggles it in the drawer.

### Collection Play Button
- **Style:** system `.borderedProminent` with a capsule border shape: the accent fill and a `play.fill` label in callout semibold. Disabled until the playlist's tracks load.
- **Hover play (playlist rows):** a 28pt accent circle with a white `play.fill` replaces the row's chevron on hover, so a playlist starts without opening it.

### Like Glyph
- A Glyph Button with `heart` or, when liked, `heart.fill`, swapped with `.symbolEffect(.replace)`. 28pt in the pill and the mini player, 30pt in Now Playing, 26pt on rows. Hidden when signed out or with nothing playing. L toggles it on Now Playing; D dislikes, which also skips the song.

### Save Glyph
- A Glyph Button that opens a native menu: the account's playlists as checkable items (checked where the song already is), then New Playlist…, then Like and Dislike. The glyph is `plus.circle` when the song is in no playlist, and the SF Symbol `N.circle.fill` when it is in N playlists (up to 50, then `checkmark.circle.fill`). Its tooltip names the playlists. Encore never draws its own badge: Liquid Glass dims flattened overlays.

### Row Actions and Menus
- Song rows in Library show 26pt glyphs on hover at the trailing edge: like, then save (search results) or remove (`minus.circle`, in playlists you own and Liked Songs), then `ellipsis`. They fade with opacity instead of leaving the view tree, so a menu opened from them stays alive. The row's title gives up room only while hovered.
- The `ellipsis` menu and the right-click menu are the same native menu: Play, Like, Dislike, Save to Playlist ▸, and Remove from This Playlist where it applies.
- Your own playlists get an `ellipsis` menu next to Play with Edit Details… and Delete Playlist…. Deleting asks inline, in place of the Play row, with Cancel and a destructive Delete.

### Toast
- A 28pt capsule at the 0.14 fill with caption-medium text, and a semibold Undo when the action can be taken back. It fades and slides up from the bottom, and clears itself after 4 seconds. Removing a song hides it at once and only sends the change when the toast expires, so Undo needs no second request.

### Playlist Form
- New Playlist and Edit Details share one form: a headline, a 34pt name field at the 0.08 fill with a 10pt radius, a system segmented picker for Private, Unlisted and Public, and, when creating from a song, a switch row ("Start with {song}") at the 0.06 fill with a 12pt radius. Cancel and Create (or Save) are plain capsule buttons, so the accent stays on play controls; Return submits. The segmented picker and switch are system controls and draw their selected state in the accent, the one place it appears off a play control.

### Glyph Button
An icon-only control drawn directly on the glass.
- **Shape:** circular hit area. Sizes: 28pt (pill chevron), 30pt (Up Next), 32pt (header, and previous and next in the pill), 44pt (previous and next in the drawer).
- **Rest:** an SF Symbol with no background.
- **Hover:** a circular fill at control opacity (0.10).
- **Toggle on (Up Next):** a circular fill at 0.20 and the primary foreground. When off it uses secondary.
- Every glyph button carries a `.help` tooltip and an accessibility label.

### Tab Capsule (Navigation)
- **Style:** an interactive glass capsule with 4pt padding, holding two Label items (Now Playing, Library) 2pt apart. Each item is 34pt tall with 12pt horizontal padding, in caption medium.
- **Selected:** the filled symbol variant, the primary foreground, and a capsule fill at 0.14 that slides between tabs with a matched geometry effect.
- **Unselected:** outline symbol and secondary foreground.

### Track Row
- **Layout:** a 40pt thumbnail (6pt radius), title over subtitle (1pt gap), with 10pt spacing and 8pt × 5pt padding.
- **Hover:** a 10pt rounded plate at 0.07, and a secondary `play.fill` at the trailing edge, or the row's actions where it has them (see Row Actions).
- **Current:** a semibold title and a trailing secondary `waveform` animated with `.variableColor.iterative`.

### Playlist Row
- A 48pt tile (8pt radius), a medium callout title over a caption subtitle, and a tertiary trailing `chevron.right`. 8pt padding, with a 12pt hover plate at 0.07. New Playlist always comes first, with a dashed tile and a `plus`, then Liked Songs with Encore's heart tile.

### Search Field
- A plain `TextField` inside a 34pt capsule at 0.08 fill, with a leading secondary magnifying glass and a trailing clear button that appears only when there is text. 12pt inner padding and 16pt outer inset. It sits at the top of Library, reads "Your library and YouTube Music" ("Search YouTube Music" when signed out), and takes focus when the tab appears. Song results dim to 0.6 while a new search runs.

### Scrubbers
- **Scrubber (drawer):** a small system `Slider` tinted `.primary`, with times below in caption2 monospaced digits. Remaining time is shown with a leading minus. It seeks on release, not while dragging.
- **Volume:** one shared component, a mini system `Slider` tinted `.primary` between secondary caption2 speaker glyphs (8pt apart). It is 132pt wide in the pill's controls row and fills the volume row in Now Playing. It sets the player's own volume; ducking never moves it.
- **Compact scrubber (pill):** a mini system `Slider` tinted `.primary`, between the elapsed time and the track length (34pt each, caption2 monospaced digits, secondary). It also seeks on release, and is disabled with no track loaded.

### Duck Badge
- A 24pt capsule at 0.10 fill, with 10pt horizontal padding and a caption-medium `waveform` label that reads "Lowered for {app}", animated with `.variableColor.iterative`. It replaces the mini player in the drawer header. In the pill the same label replaces the artist line. **Not verified:** the ducked state was never captured. Its layout and legibility come from source only.

### Sign-In Sheet
- **Signed-out Library:** a centred prompt with a 36pt light `person.crop.circle.badge.plus`, a headline, secondary callout copy, and a large prominent capsule button, "Sign In with Google".
- **The sheet:** it replaces the drawer's content and tab bar while signing in. The header row is 52pt, with a 32pt `xmark` glyph button (cancel action), "Sign in with Google" in callout semibold, and a small spinner while a page loads. Google's page sits below in a web view clipped to an 18pt radius with an 8pt inset. While the sheet is up, the panel doesn't hide when it loses focus or on outside clicks.

### Artwork
- `RemoteImage` fills and crops to the frame its caller sets, so wide video thumbnails are cropped rather than letterboxed. Until it loads it shows a quaternary fill with a tertiary `music.note`. It is hidden from accessibility.

### Motion
- **Expand/collapse:** a spring with response 0.42 and damping fraction 0.86, applied to the panel height. Pill and drawer content crossfade (`.opacity`).
- **The art morph:** the artwork shares the matched geometry id "art" between the 40pt circle in the pill and the 232pt rounded square in the drawer, so it travels and reshapes along with the panel.
- **Reduce Motion:** the spring is replaced by a 0.2s ease-in-out.
- **Tab and Up Next switches:** a 0.25s ease-in-out. The tab selection plate moves with matched geometry.
- **Symbols:** `.replace` for play/pause, `.numericText()` for times, and `.variableColor.iterative` on the playing-track and ducking waveforms.

## Do's and Don'ts

### Do:
- **Do** keep the panel at 360pt wide, 128pt as a pill and 620pt as a drawer, with a 28pt corner radius, inside a 12pt margin.
- **Do** put new drawer content inside the existing glass, using fills from the ladder (0.06 to 0.20) for plates, fields and selection.
- **Do** use the accent only for controls that start or pause playback, with a white glyph.
- **Do** build icon controls as Glyph Buttons: an SF Symbol, a circular hit area, a 0.10 hover fill, a `.help` tooltip and an accessibility label.
- **Do** fade scrolling lists at their edges and hide their scroll indicators.
- **Do** use SwiftUI system text styles and monospaced digits for changing numbers.
- **Do** keep the expand spring at response 0.42 / damping 0.86 and provide the Reduce Motion ease-in-out.
- **Do** check the light appearance and the ducked state against real captures before relying on them. Neither has been verified.

### Don't:
- **Don't** use the accent for selection, sliders, links or navigation. Those use `.primary`.
- **Don't** add YouTube or YouTube Music logos or brand colours to the chrome.
- **Don't** add new glass layers for rows, cards or buttons. The panel and the tab capsule are the only glass.
- **Don't** open a separate window or popover for player content. It grows inside the drawer.
- **Don't** introduce fixed brand colours or paint a ground under the glass.
