---
version: 1
slug: "sources-encore-encoreview-swift"
primary_target: "Sources/Encore/EncoreView.swift"
related_targets: ["Sources/Encore/AppDelegate.swift","Sources/Encore/NowPlayingTab.swift","Sources/Encore/LibraryTab.swift","Sources/Encore/SearchTab.swift"]
---

# Menu bar player

Scope: the Encore menu bar player (compact pill and expanded drawer), its Library, Search and Up Next views, sign-in import, and the Settings window for ducking. Mode: Operate.

Audience and job: a Mac user listening all day who wants play/pause at a glance and, occasionally, to pick something from liked songs, a playlist or search, then get out of the way.

Constraints: native SwiftUI on macOS 26, Liquid Glass, SF Pro and SF Symbols, system controls. Sign-in is imported from the user's browser profile; no in-app Google sign-in screen.

## Direction contract

THESIS: The pill is the player. A 56pt glass capsule under the menu bar carries art, title and play/pause; expanding grows that same capsule downward into a drawer instead of opening a separate window. Refuses the category default of a fixed popover with a web-page layout.

OWN-WORLD: Liquid Glass over a ground tinted by the current artwork, dark warm neutrals pulled from the cover, system blue for the primary play control only, SF Pro at system text styles, SF Symbols throughout. No YouTube branding.

STORY: The user sees what's playing and toggles it in one click. When they want more, they expand, read the big art and scrubber, switch to Library or Search from the bottom tab capsule, start something, and collapse.

FIRST VIEWPORT: Compact: 360x56pt capsule, circular 40pt art left, title over artist, a blue 40pt play/pause, expand chevron, a 2pt progress line along the bottom edge. Expanded 360x620pt: header capsule (art, title, collapse), 220pt rounded art, title and artist·album, scrubber with times, previous/play/next, volume with queue toggle, glass tab capsule at the bottom for Now Playing, Library, Search.

FORM: Pill and drawer, structure 5 of 7 on the ranked list, dealt by the roll and chosen by the user. seed:f864fbf5080e9d05

Signature interaction: the art morphs from the 40pt circle in the pill to the 220pt square in the drawer as the capsule grows, on a spring, reversing on collapse (crossfade under Reduce Motion).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
