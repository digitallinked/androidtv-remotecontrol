> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# Content rating (Google Play IARC) and age rating (App Store)

Ruling P9-R15. The app is a utility: a TV remote with no user content, no chat, no web browsing and no mature content. Its only purchases are Premium (no ads and colour styles) and its ads come from AdMob.

## Google Play: the IARC questionnaire

Play Console → Policy and programs → App content → Content rating → Start questionnaire.

| Question | Answer | Why |
|---|---|---|
| Email address for IARC | `{{SUPPORT_EMAIL}}` | Where IARC sends the certificate. **[owner]** |
| Category | **All other app types** (utility, productivity, communication or other; not a game, not social, not news) | A remote control. |
| Violence, fear, sexuality, nudity, bad language | **No** to every question | The app shows only its own controls. The TV's picture never reaches the phone. |
| Controlled substances (drugs, alcohol, tobacco) | **No** | |
| Gambling, simulated gambling, loot boxes | **No** | |
| Does the app let users interact or exchange content with each other? | **No** | No accounts, chat or sharing. Typed text goes only to the user's own TV. |
| Does the app share the user's current physical location with other users? | **No** | The app never reads location. (Advertisers and Analytics derive an approximate location from the IP address; that is declared in Data safety, not here.) |
| Does the app allow users to purchase digital goods? | **Yes** | Premium: monthly, yearly or lifetime, through Google Play billing. |
| Does the app contain or let users access unrestricted internet content (a web browser, a search engine)? | **No** | The privacy policy, terms and help links open the phone's own browser. |
| Does the app contain ads? | Not asked here; declared under App content → Ads (**Yes**; see `play-declarations.md`). | |
| Is the app a web browser or search engine? | **No** | |

**Expected result:** Everyone (ESRB), PEGI 3, USK 0, and the matching low ratings elsewhere, plus the interactive elements "In-App Purchases" (and, where IARC shows it, "Contains ads" comes from the Ads declaration).

**Source:** Play Console Help, "Content ratings": https://support.google.com/googleplay/android-developer/answer/9898843.

**Target audience is separate, and the two don't conflict** (Ruling P9-C12). The content rating (IARC on Play, the age rating on the App Store) describes the app's *content*, and this app's content is a TV remote: Everyone / 4+. The target audience (18+ only on Play, `play-declarations.md`) describes *whom the app is for*, and keeps the app out of the Families policy. A utility can have all-ages content and an adult audience; keep both.

## Ads must suit the rating: cap AdMob at G

Both stores require ads to be appropriate for the app's rating. Without a cap, AdMob serves its default range, which goes above G.

- **[owner]** AdMob console → Blocking controls → All apps (or this app) → **Maximum ad content rating = G** ("General audiences"). Do this before the first release that shows ads.
- **Code (Task 9.13):** the app also sets `RequestConfiguration(maxAdContentRating: MaxAdContentRating.g)` before `MobileAds.initialize`, with a test, so the cap holds even if the console setting changes.

**Sources:** AdMob Help, "Set a maximum ad content rating": https://support.google.com/admob/answer/7562142; App Review Guidelines 1.3 / ads appropriate to the age rating: https://developer.apple.com/app-store/review/guidelines/.

## App Store: age rating

App Store Connect → the app → App Information → Age Rating → Edit. Apple's questionnaire changed in 2025 (ratings 4+, 9+, 13+, 16+, 18+, with questions on in-app controls and capabilities); answer the current version with these facts.

| Topic | Answer |
|---|---|
| Violence, horror, sexual content, nudity, profanity, drugs, alcohol, tobacco, mature themes, medical information | **None** |
| Gambling, simulated gambling, contests | **None / No** |
| Unrestricted web access | **No** (links open Safari) |
| User-generated content, messaging or chat | **No** |
| Advertising | **Yes**, if asked (AdMob banners; an occasional full-screen ad may be switched on remotely) |
| Parental controls, age assurance | **No** |
| Made for Kids | **No** (don't choose the Kids category) |

**Expected result:** **4+**.

**Source:** App Store Connect Help, "Age ratings": https://developer.apple.com/help/app-store-connect/reference/age-ratings.

## Owner to confirm

- [ ] The questionnaire answers against the console's current questions. **[owner]**
- [ ] The resulting Play rating is Everyone / PEGI 3 and the App Store rating is 4+; if not, record which answer changed it. **[owner]**
- [ ] AdMob's maximum ad content rating is set to G (Blocking controls). **[owner]**
- [ ] Keep 4+ / Everyone (content) with the 18+ Play audience (who it is for); the privacy policy's owner item 9 says the same. **[owner]**
