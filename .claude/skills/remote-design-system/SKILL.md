---
name: remote-design-system
description: Use when designing or building any screen, widget, icon, color, typography, motion, layout, onboarding, empty/error state, paywall or ad placement for the TV remote app, or reviewing UI/UX and accessibility.
---

# Remote design system

## Overview
A one-handed, eyes-on-the-TV remote. Every decision serves: **find the control without looking, never mis-tap, always know if you're connected.** For visual craft also use `frontend-design:frontend-design`.

## UX principles (each fixes a competitor weakness — see teardown §8)
1. **Honest status.** The connection pill shows the live socket state (Connected / Reconnecting… / Offline + "Reconnect" button). Never a "Connected" badge on a disconnected TV.
2. **Safe zones.** Banners only go at the bottom of the Apps and Settings screens. Never on the remote, pairing, discovery, onboarding or paywall screens, and nothing within 48 dp of any ✕/back/primary control.
3. **Thumb first.** Most-used controls (pad, back, home, volume) sit in the bottom 60% of the screen.
4. **One navigation model.** Bottom-sheet modals close with a swipe or ✕; pushed pages use ←, with a header that names the page ("Remote layout", not "Settings").
5. **Recover, don't scold.** Every error has an action: "Retry", "Open troubleshooting", "Enter code again".
6. **Respect the room.** Theater Mode dims and darkens; haptics replace sounds.

## Tokens (`app/lib/app/theme/tokens.dart`)
| Token | Dark | Light |
|---|---|---|
| bg | `#0F1115` | `#F6F7F9` |
| surface | `#181B21` | `#FFFFFF` |
| surfaceRaised (keys) | `#232731` | `#ECEEF2` |
| outline | `#2E3340` | `#D5D9E0` |
| textPrimary | `#F2F4F8` | `#12151B` |
| textSecondary (≥4.5:1) | `#A7AFBF` | `#4A5263` |
| accent | `#6C8CFF` | `#3D5AFE` |
| success / warning / danger | `#3DDC97` / `#FFC857` / `#FF6B6B` | `#0F9D63` / `#B7791F` / `#D64545` |
| TV colour keys | red `#E5484D`, green `#30A46C`, yellow `#F5D90A`, blue `#3E63DD` | same |

Also support **Material You dynamic colour** on Android 12+ as an option in Settings → Appearance (System / Light / Dark / Dynamic).

- **Type:** Inter (or the system font) — Display 28/34 semibold, Title 20/26 semibold, Body 16/22, Label 14/18 medium, Caption 12/16. Respect text scaling up to 200% (reflow, don't clip).
- **Shape:** keys 20 dp radius, cards 16, sheets 28 (top), pills fully rounded. **Spacing:** 4-pt grid (4, 8, 12, 16, 24, 32).
- **Touch targets:** ≥ 56 dp for remote keys, ≥ 48 dp everything else; ≥ 8 dp gap between keys.
- **Motion:** 150–250 ms ease-out; key press = scale 0.94 + ripple + haptic (light impact; heavy for power). Respect "reduce motion".

## Screens (v1)
Onboarding (3 cards + permission explainers) → Discovery (scan list, manual IP entry, troubleshooting link) → Pairing (6-char code entry with paste, auto-advance, live validation) → **Remote** (status pill + device switcher, quick-access row, pad area [Touchpad | D-pad | Numpad, swipe between], bottom cluster [Back, Home, Mute, Keyboard, Vol rocker, Ch rocker, Power long-press]) → Keyboard sheet → Apps (grid, search, reorder, add custom, recommendations with real names/icons) → Devices → Settings → Paywall. **Demo mode** (reachable from onboarding and the empty Discovery state): the same remote UI driven by a simulated TV, a persistent "Demo" badge, and a small "TV preview" card showing the last action. App Store reviewers rely on it.

**Smooth Press:** holding volume, channel or a D-pad key sends one long press (`START_LONG` … `END_LONG`) like a physical remote. When the setting is off, holding repeats short presses every 120 ms.

Layouts: phone portrait (primary), phone landscape (pad left, controls right), tablet (two panes). **Accessibility:** every control has a semantic label ("Volume up"); D-pad works with TalkBack/VoiceOver; colour is never the only signal.

## Paywall rules
Show the value (no ads, widgets, themes, multiple TVs) first, prices second. Pre-select the best-value plan honestly, show renewal terms under each price, and put Restore + Terms + Privacy on the screen. Closing returns to where the user came from.

## Common mistakes
- Low-contrast secondary text (the competitor used `#565656` on `#1E1E1E`).
- Icons whose meaning changes with state (the competitor's numpad/D-pad toggle).
- Stock white Material dialogs in the dark theme; use the themed `AppDialog`.
