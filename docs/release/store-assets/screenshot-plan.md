# Store images: feature graphic and screenshots

Ruling P9-R14. Everything here is drawn by our own code from the real app with made-up data. Nothing comes from another app.

## Feature graphic (Google Play)

- **File:** `feature_graphic.png` in this folder (committed). It is the golden baseline of `app/test/store_assets/feature_graphic_golden_test.dart`.
- **Format:** 1024 × 500 px and opaque, which a test checks.
- **Content:**
  - our brand mark (`BrandMarkPainter`), in white on the accent `#3D5AFE`;
  - `feature_graphic.title` and `feature_graphic.tagline` from `docs/release/store-listing/en.md`, in Roboto.
- **No "Google" and no Android TV logo.**
- **Regenerate** after a change to the name, the tagline or the brand. From `app/`, run `flutter test --update-goldens --tags golden test/store_assets/feature_graphic_golden_test.dart`, then look at the PNG before you commit it.

## Screenshots

### Sizes

| Set (folder) | Store | Canvas (px) | App drawn at (dp) @ ratio | Platform |
|---|---|---|---|---|
| `playPhone` | Google Play, phone | 1080 × 1920 | 412 × 732 @ 2.625 | Android |
| `playTablet` | Google Play, 10-inch tablet | 2560 × 1600 | 1280 × 800 @ 2 | Android |
| `iphone69` | App Store, iPhone 6.9″ | 1320 × 2868 | 440 × 956 @ 3 | iOS |
| `ipad13` | App Store, iPad 13″ (landscape) | 2752 × 2064 | 1376 × 1032 @ 2 | iOS |

Each set comes in `en` and `ms`. The Malay captions are **UNREVIEWED** (DM-068).

### Frame

- The canvas is filled with the accent `#3D5AFE`.
- The caption sits in the top 18 %, in white Roboto Medium, at up to 2 lines.
- The captured screen is 78 % of the canvas width, centred below the caption.
- Its corners are 4 % of its shortest side. 6 % of the width cut into the tablet screens' corners.

### Shots

| Id | Screen | Caption key |
|---|---|---|
| **Phone** (`playPhone`, `iphone69`) | | |
| `01_touchpad` | The remote, Touchpad | `shot.phone.01` |
| `02_dpad` | The remote, D-pad | `shot.phone.02` |
| `03_apps` | Apps | `shot.phone.03` |
| `04_keyboard` | The keyboard sheet, "Hello" typed | `shot.phone.04` |
| `05_discovery` | Discovery, two TVs found | `shot.phone.05` |
| `06_pairing` | The pairing code page | `shot.phone.06` |
| `07_styles` | Appearance, Ocean chosen, dark (Premium) | `shot.phone.07` |
| `08_tvs` | Your TVs, three TVs | `shot.phone.08` |
| **Tablet** (`playTablet`, `ipad13`) | | |
| `01_split` | The remote, split layout | `shot.tablet.01` |
| `02_apps` | Apps | `shot.tablet.02` |

The caption text isn't repeated here: each key's text is in `docs/release/store-listing/en.md` (and `ms.md`), which the generator reads, so a copy change shows up the next time you generate.

### Data

- A connected session on "Living Room TV". The saved TVs are Living Room TV, Bedroom TV and Kitchen TV, on made-up addresses 192.168.1.40–42.
- Custom shortcuts Movies, Music, News, Sports, Kids and Photos, each with our own colours and generic icons.
- The generator fails on any of these on screen:
  - a catalogue app's name;
  - "Google";
  - the demo badge;
  - a loaded ad.
- The banner slot stays empty.
- The fonts are the SDK's Roboto and MaterialIcons. iOS shots draw in Roboto too, because the SDK ships no San Francisco.

### Generate

From the repo root:

- Windows: `powershell -File tool/store_screenshots.ps1`
- macOS/Linux: `tool/store_screenshots.sh`

The script empties `build/store-screenshots/` and runs `app/test/store_assets/store_screenshots_test.dart` with `STORE_SCREENSHOTS_OUT` set. It writes `build/store-screenshots/<set>/<locale>/<id>.png` (40 files) and prints the count and the time taken, about 30 s. `build/` is git-ignored: **never commit the PNGs**.

### Owner review (before every upload)

1. Open every PNG.
2. Check that:
   - text is real, with no boxes;
   - no caption is cut;
   - there's no ad and no demo badge;
   - no third-party app name or logo appears;
   - the app name and colours are the final ones.
3. Compare one phone shot with the app on a real phone (DM-111). Differences are expected: iOS uses San Francisco on a device, and the status bar isn't drawn.
4. Have the Malay captions signed off (DM-068) before you upload the `ms` sets.

### Upload

- **Google Play Console**, Main store listing, for each language (English, Malay):
  - Phone screenshots: the 8 PNGs from `playPhone/<locale>/`, in id order.
  - 10-inch tablet screenshots: the 2 from `playTablet/<locale>/`. Play also asks for 7-inch tablet shots, and these are acceptable there.
  - Feature graphic: `docs/release/store-assets/feature_graphic.png`.
- **App Store Connect**, the version's localisations (English, Malay):
  - iPhone 6.9″ display: the 8 PNGs from `iphone69/<locale>/`.
  - iPad 13″ display: the 2 from `ipad13/<locale>/`.
  - Apple scales these down for smaller devices.
