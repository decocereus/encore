# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

## Users
Mac users who listen to YouTube Music all day while working and don't want it living in a browser tab. The first user is the author, who dictates with Hex while music plays. The app will be distributed publicly later.

## Product Purpose
Encore is a menu bar YouTube Music player for macOS. It gives YouTube Music a native, minimal home: play and pause from the menu bar, media keys and Control Center; search; browse liked songs and playlists. Success is never opening a browser tab for music again.

## Positioning
A native SwiftUI interface (Liquid Glass on macOS 26) over YouTube Music's own web player, which runs hidden. Account, Premium, library and streaming come from YouTube Music itself, so nothing is re-implemented or scraped from streams. It also reacts to what else is happening on the Mac, starting with ducking music while a dictation tool listens.

## Operating Context
- Lives in the menu bar as a glass panel. Opened briefly between tasks, then dismissed. Music keeps playing when the panel is closed.
- The user dictates with Hex (voice to text). Other dictation tools exist (Superwhisper, Wispr Flow, MacWhisper).
- Multiple Google accounts are switched through isolated Encore accounts, each with its own sign-in.

## Capabilities and Constraints
- Default state is a compact card (art, title, transport). The pill also likes the song and saves it to playlists without expanding. The user expands it in place to reach Up Next and Library, which holds liked songs, playlists and search in one place.
- Playback engine: hidden WKWebView on music.youtube.com with an injected JS bridge. Library and search use YouTube Music's InnerTube API from inside the page, signed with the page's own session.
- Sign-in happens once per account on Google's own page, shown inside the drawer (no separate window). Passkeys can't work for google.com in a non-browser app, so the page hides them and Google offers a phone prompt or password. Copying cookies from a browser was tried and dropped: copied sessions go stale and need keychain prompts.
- Dictation ducking: when a chosen app uses the microphone, fade volume down to a set level, restore when it stops. The trigger apps are user configurable (Hex by default, or any app using the mic). The duck level is adjustable.
- macOS 26 minimum (Liquid Glass APIs).
- Name: Encore. Public GitHub repo decocereus/encore, MIT license.
- Undecided: distribution channel (DMG, Homebrew cask), notarization, app icon.

## Brand Commitments
Name is Encore. No YouTube logos or YouTube Music branding in the app's own chrome; it is an unofficial client.

## Evidence on Hand
No users, testimonials, or metrics yet. Do not fabricate any.

## Product Principles
1. Out of the way by default. The compact card is the product; everything else is one click deeper.
2. Native first. Use system controls, materials and conventions before custom ones.
3. YouTube Music stays the source of truth. Never fork its state; read it and drive it.
4. Integrations act quietly and undo themselves. Ducking always restores the user's own volume.
