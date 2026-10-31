# Store listing — English

The text for the Google Play and App Store listings (Ruling P9-R13). Each field is a `## <id> (max <n>)` heading and one `text` block; paste the block, nothing else. Prose outside the blocks is a note for the owner, not store copy.

- **Tokens:** the double-brace values come from `docs/release/placeholders.json`. `app/tool/fill_release_docs.dart` writes a filled copy to `build/release-docs/`; paste from there. Limits are counted after filling.
- **Checked by** `app/test/release/store_copy_test.dart`: every field within its store limit, no third-party trademark in the names, subtitle, keywords, captions or feature-graphic text, both descriptions end with the in-app trademark notice, and no feature v1 doesn't ship.
- **The app name** is the placeholder from decision #12 until the owner chooses the final one. `feature_graphic.title` repeats the short brand ("Remotely"): change it with the name.
- **Platform differences:** Wake-on-LAN is Android only, so only the Play description mentions turning the TV on. The App Store description carries the Terms and Privacy links Apple asks for with subscriptions (Guideline 3.1.2).

## play.title (max 30)

```text
{{APP_NAME}}
```

## play.short_description (max 80)

```text
Use your phone as a TV remote. Works with Android TV and Google TV.
```

## play.full_description (max 4000)

```text
Control your TV from your phone. {{APP_NAME}} connects over your home Wi-Fi to TVs and streaming boxes that run Android TV or Google TV, so you can move around, type and open apps without looking for the remote.

GET CONNECTED
• The app finds TVs on your Wi-Fi network by itself. If yours doesn't show up, enter its IP address.
• Pair once with the code your TV shows. After that, the app reconnects by itself.
• The status at the top of the remote shows whether the TV is connected, reconnecting or offline, so you know where your taps go.

CONTROL
• Touchpad: swipe to move, tap to select.
• D-pad: arrow keys around an OK button, like a TV remote.
• Number pad for channels and codes.
• Volume, mute, channel, Back, Home, Menu and power keys. With Smooth Press, holding a key acts like holding it on a TV remote.
• Choose the row above the pad: app shortcuts, colour keys, media keys or nothing at all.
• Type with your phone's keyboard. It opens by itself when the TV asks for text, like in a search box.
• Turn the TV on from your phone: add the TV's MAC address once and the power key wakes it over the network (Wake-on-LAN, if your TV supports it).

APPS
• Keep your favourite TV apps in a row on the remote and open them with one tap.
• Reorder the row, add apps from the list or create your own shortcut.

ALL YOUR TVS
• Save as many TVs as you like, rename them and switch between them from the remote.

TRY IT FIRST
• Demo mode shows a simulated TV, so you can look around the app before you pair one.

COMFORTABLE TO USE
• Light and dark themes, and layouts for phones and tablets.
• Every control has a screen reader label, and the screens adapt to larger text.
• Keep the screen on while the remote is open, or let theater mode dim it in a dark room.

PREMIUM
• Premium removes ads and adds three colour styles: Ocean, Ember and Midnight, in light and dark.
• Choose monthly, yearly or a one-time lifetime purchase. The app shows the price before you buy.
• Everything else stays free: every TV, every remote control, app shortcuts, the keyboard and turning your TV on.
• Banner ads only appear at the bottom of the Apps and Settings screens, never on the remote.

PRIVACY
• Your TVs' names, network addresses and MAC addresses never leave your phone, and backups don't copy them.
• You decide whether the app shares usage statistics and crash reports. Change it any time in Privacy choices.
• No account and no sign-in.

WHAT YOU NEED
• A TV or streaming box with Android TV or Google TV, with the Android TV Remote Service installed and up to date.
• Your phone and your TV on the same Wi-Fi network.
• TVs with other systems aren't supported.

Questions or ideas? Write to {{SUPPORT_EMAIL}}.

Android TV and Google TV are trademarks of Google LLC. This app isn't made or endorsed by Google.
```

## appstore.name (max 30)

```text
{{APP_NAME}}
```

## appstore.subtitle (max 30)

```text
Touchpad, D-pad and keyboard
```

## appstore.promotional_text (max 170)

```text
Swipe, tap and type on your TV from your phone. Pair once, open your favourite apps from one row and switch between all your TVs.
```

## appstore.description (max 4000)

```text
Control your TV from your iPhone or iPad. {{APP_NAME}} connects over your home Wi-Fi to TVs and streaming boxes that run Android TV or Google TV, so you can move around, type and open apps without looking for the remote.

GET CONNECTED
• The app finds TVs on your Wi-Fi network by itself. If yours doesn't show up, enter its IP address.
• Pair once with the code your TV shows. After that, the app reconnects by itself.
• The status at the top of the remote shows whether the TV is connected, reconnecting or offline, so you know where your taps go.

CONTROL
• Touchpad: swipe to move, tap to select.
• D-pad: arrow keys around an OK button, like a TV remote.
• Number pad for channels and codes.
• Volume, mute, channel, Back, Home, Menu and power keys. With Smooth Press, holding a key acts like holding it on a TV remote.
• Choose the row above the pad: app shortcuts, colour keys, media keys or nothing at all.
• Type with your iPhone's keyboard. It opens by itself when the TV asks for text, like in a search box.

APPS
• Keep your favourite TV apps in a row on the remote and open them with one tap.
• Reorder the row, add apps from the list or create your own shortcut.

ALL YOUR TVS
• Save as many TVs as you like, rename them and switch between them from the remote.

TRY IT FIRST
• Demo mode shows a simulated TV, so you can look around the app before you pair one.

COMFORTABLE TO USE
• Light and dark themes, and layouts for iPhone and iPad.
• Every control has a screen reader label, and the screens adapt to larger text.
• Keep the screen on while the remote is open, or let theater mode dim it in a dark room.

PREMIUM
• Premium removes ads and adds three colour styles: Ocean, Ember and Midnight, in light and dark.
• Choose monthly, yearly or a one-time lifetime purchase. The app shows the price before you buy.
• Subscriptions renew automatically until you cancel them in your App Store account settings.
• Everything else stays free: every TV, every remote control, app shortcuts and the keyboard.
• Banner ads only appear at the bottom of the Apps and Settings screens, never on the remote.

PRIVACY
• Your TVs' names, network addresses and MAC addresses never leave your iPhone, and backups don't copy them.
• You decide whether the app shares usage statistics and crash reports. Change it any time in Privacy choices.
• No account and no sign-in.

WHAT YOU NEED
• A TV or streaming box with Android TV or Google TV, with the Android TV Remote Service installed and up to date.
• Your iPhone or iPad and your TV on the same Wi-Fi network. When iOS asks, allow the app to find devices on your local network.
• TVs with other systems aren't supported.

Terms of use: {{TERMS_URL}}
Privacy policy: {{PRIVACY_POLICY_URL}}
Questions or ideas? Write to {{SUPPORT_EMAIL}}.

Android TV and Google TV are trademarks of Google LLC. This app isn't made or endorsed by Google.
```

## appstore.keywords (max 100)

```text
tv remote,remote control,touchpad,dpad,keyboard,smart tv,television,controller,pairing,streaming
```

## release_notes (max 500)

```text
The first release. Find and pair your TV, control it with the touchpad or D-pad, type with your phone's keyboard and open your favourite apps from the remote. No TV nearby? Try the demo.
```

## shot.phone.01 (max 40)

Shot `01_touchpad`: the remote, Touchpad.

```text
Swipe to move, tap to select
```

## shot.phone.02 (max 40)

Shot `02_dpad`: the remote, D-pad.

```text
A D-pad that's easy to hit
```

## shot.phone.03 (max 40)

Shot `03_apps`: the Apps screen.

```text
Open your TV apps in one tap
```

## shot.phone.04 (max 40)

Shot `04_keyboard`: the keyboard sheet, "Hello" typed.

```text
Type with your phone's keyboard
```

## shot.phone.05 (max 40)

Shot `05_discovery`: discovery with two TVs found.

```text
Finds the TVs on your network
```

## shot.phone.06 (max 40)

Shot `06_pairing`: the pairing code page.

```text
Pair once with the code on your TV
```

## shot.phone.07 (max 40)

Shot `07_styles`: Appearance, a style chosen, dark.

```text
Dark mode and Premium colour styles
```

## shot.phone.08 (max 40)

Shot `08_tvs`: Your TVs with three TVs.

```text
Switch between all your TVs
```

## shot.tablet.01 (max 40)

Shot `01_split`: the remote, split layout.

```text
Touchpad and keys side by side
```

## shot.tablet.02 (max 40)

Shot `02_apps`: Apps.

```text
All your TV apps, one tap away
```

## feature_graphic.title (max 20)

```text
Remotely
```

## feature_graphic.tagline (max 40)

```text
The TV remote that lives on your phone
```
