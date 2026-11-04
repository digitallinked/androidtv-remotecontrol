# Review response plan (first weeks after launch)

How the owner answers store reviews in launch week and after. Every reply below is written for this app from its own Help text and behaviour; none is copied from another app (CLAUDE.md). Claude can draft a reply when asked, but only the owner posts one (Ruling P9-R1).

## Cadence

- **Launch week (the first 7 days after each production stage starts):** read every new review on Google Play (Play Console → prod app → **Monitor and improve → Ratings and reviews → Reviews**) and the App Store (App Store Connect → the app → **Ratings and Reviews**) **once a day**, and reply to each review that describes a problem **within 48 hours**.
- **Weeks 2–4:** every two or three days, same 48-hour reply target for problems.
- **After that:** weekly, plus whenever the review count jumps.
- Reply to every 1–3 star review that describes a problem. Thank 4–5 star reviews only when they say something specific; don't paste the same thank-you everywhere.
- Each day, put the reviews in the categories below and count them. Three or more new reviews of the same problem in a day is a rollout gate (`crashlytics-alerts.md`): halt and investigate.

## Rules for every reply

1. **Never ask for an IP address, a MAC address, a TV's name, or any other detail about the user's home network in public.** Reviews are public. Ask them to write to us from inside the app instead (Settings → Send feedback, which opens their e-mail app with the app and system version filled in).
2. **Point to Help first.** Settings → Help has the troubleshooting steps and the common questions; name the exact screen.
3. **Log one bug per pattern, not per review.** Keep a list in `docs/knowledge/status.md` (problem, first seen, count, platform and version, link to the reviews). The second review of a pattern updates the count; it doesn't open a new entry.
4. **Be short and specific.** Google Play limits a reply to 350 characters, so every reply below fits that. Sign as the app's team, not as a person, unless the owner prefers otherwise.
5. **No promises of dates or features.** Say "we've noted it", not "coming next month". Store copy may only claim what v1 does (Ruling P9-R13); replies follow the same rule.
6. **Never argue about a rating, never offer anything in exchange for changing one, and never mention another app.**
7. **Ads:** describe them exactly as the privacy policy does: banners only on the Apps and Settings screens; an occasional full-screen ad when leaving Settings, only if we have switched those on; never while pairing; Premium removes them.
8. **Malay reviews get a Malay reply.** The Malay drafts below are **UNREVIEWED**: they need the owner's sign-off (with the DM-068 review) before use. Until then, reply in English.
9. **Update the reply** when a fix ships: "Version X.Y.Z fixes this" is the best reply there is.

## Categories and replies

Each category has one English reply and one Malay draft. Adapt the wording to the review, but keep the rules above.

### 1. Can't find the TV

Typical review: "doesn't find my TV", "searching forever", "no devices".

```text
Sorry the TV didn't show up. Your phone and TV need to be on the same Wi-Fi (not a guest network), and the TV needs Android TV Remote Service up to date. Settings → Help → Show troubleshooting steps goes through each check, and you can also add the TV with Enter IP address. If it still fails, write to us from Settings → Send feedback.
```

Malay draft (UNREVIEWED):

```text
Maaf, TV anda tidak muncul. Telefon dan TV perlu pada Wi-Fi yang sama (bukan rangkaian tetamu), dan Android TV Remote Service pada TV perlu dikemas kini. Tetapan → Bantuan → Tunjukkan langkah penyelesaian masalah menerangkan setiap semakan; anda juga boleh menambah TV melalui Masukkan alamat IP. Jika masih gagal, guna Tetapan → Hantar maklum balas.
```

### 2. The pairing code

Typical review: "code doesn't work", "keeps asking for a code", "no code on the TV".

```text
Thanks for telling us. The code shows on the TV for a short time; type it on your phone exactly as shown. If the app says it's wrong or expired, choose Get a new code. Reinstalling the app or resetting the TV removes the pairing, so the TV asks once more. Settings → Help explains more, and Send feedback reaches us directly.
```

Malay draft (UNREVIEWED):

```text
Terima kasih atas maklumat ini. Kod dipaparkan pada TV untuk masa yang singkat; taipkannya pada telefon tepat seperti yang dipaparkan. Jika apl mengatakan kod salah atau tamat tempoh, pilih Dapatkan kod baharu. Memasang semula apl atau menetapkan semula TV akan membuang penggandingan, jadi TV akan meminta kod sekali lagi. Lihat Tetapan → Bantuan.
```

### 3. Disconnects

Typical review: "keeps disconnecting", "lags", "stops working after a while".

```text
Sorry about the dropouts. The app reconnects by itself when the Wi-Fi comes back, but it can't reach a TV that is in deep standby or on another network. Keeping both on the same Wi-Fi helps most. We follow connection problems closely, so please tell us your phone and TV model through Settings → Send feedback.
```

Malay draft (UNREVIEWED):

```text
Maaf atas sambungan yang terputus. Apl akan bersambung semula dengan sendirinya apabila Wi-Fi kembali, tetapi ia tidak dapat mencapai TV dalam mod tunggu sedia yang mendalam atau pada rangkaian lain. Pastikan kedua-duanya pada Wi-Fi yang sama. Sila beritahu kami model telefon dan TV anda melalui Tetapan → Hantar maklum balas.
```

### 4. Ads

Typical review: "too many ads", "ads everywhere", "ad covered the button".

```text
Thanks for the feedback. The free version shows banners on the Apps and Settings screens, and maybe an occasional full-screen ad when you leave Settings; pairing never shows ads. Premium removes them all. If an ad covered a button or appeared elsewhere, please tell us via Settings → Send feedback.
```

Malay draft (UNREVIEWED):

```text
Terima kasih atas maklum balas anda. Dalam versi percuma, iklan sepanduk berada di bahagian bawah skrin Apl dan Tetapan; skrin alat kawalan jauh dan skrin penggandingan tidak mempunyai iklan. Premium membuang semua iklan. Jika iklan pernah menutup butang, sila beritahu kami melalui Tetapan → Hantar maklum balas.
```

### 5. Premium and restoring a purchase

Typical review: "paid but still see ads", "Premium gone after reinstall", "charged twice".

```text
Sorry for the trouble with Premium. Make sure your phone uses the same store account you bought it with, then open Settings → Premium → Restore purchases. Payments and refunds are handled by the store you bought from. If ads still show, please write to us through Settings → Send feedback and we'll sort it out.
```

Malay draft (UNREVIEWED):

```text
Maaf atas masalah dengan Premium. Pastikan telefon anda menggunakan akaun gedung yang sama semasa pembelian, kemudian buka Tetapan → Premium → Pulihkan pembelian. Pembayaran dan bayaran balik diuruskan oleh gedung tempat anda membeli. Jika iklan masih dipaparkan, sila hubungi kami melalui Tetapan → Hantar maklum balas.
```

### 6. A TV app won't open

Typical review: "the app buttons do nothing", "a shortcut opens the store".

```text
Thanks for letting us know. A shortcut opens an app only when that app is installed on the TV, and some apps have a different version in each country. In Settings → Apps you can edit your shortcuts and add the right app by its app ID. If an installed app still won't open, tell us which one through Settings → Send feedback.
```

Malay draft (UNREVIEWED):

```text
Terima kasih kerana memberitahu kami. Pintasan hanya membuka apl yang telah dipasang pada TV, dan sesetengah apl mempunyai versi berbeza bagi setiap negara. Di Tetapan → Apl, anda boleh menyunting pintasan dan menambah apl yang betul melalui ID aplnya. Jika apl yang dipasang masih tidak dibuka, beritahu kami melalui Tetapan → Hantar maklum balas.
```

### 7. Requests

Typical review: "please add …", "would be 5 stars with …".

```text
Thank you for the idea! We keep a list of what people ask for and go through it when we plan each update. We can't promise when, but requests like yours decide what we build next. If you'd like to add details, Settings → Send feedback reaches us directly.
```

Malay draft (UNREVIEWED):

```text
Terima kasih atas cadangan anda! Kami menyimpan senarai permintaan pengguna dan menelitinya setiap kali kami merancang kemas kini. Kami tidak dapat berjanji bila, tetapi permintaan seperti ini menentukan apa yang kami bina seterusnya. Untuk butiran lanjut, hubungi kami melalui Tetapan → Hantar maklum balas.
```

### 8. Not an Android TV

Typical review: "doesn't work with my Samsung", "useless for my Roku".

```text
Sorry for the confusion. This app controls TVs and streaming boxes that run Android TV or Google TV. TVs with other systems, such as Samsung (Tizen), LG (webOS), Roku or Fire TV, work differently and can't be controlled by it. Settings → Help → Which TVs does this app work with? has the details.
```

Malay draft (UNREVIEWED):

```text
Maaf atas kekeliruan ini. Apl ini mengawal TV dan kotak penstriman yang menjalankan Android TV atau Google TV. TV dengan sistem lain, seperti Samsung (Tizen), LG (webOS), Roku atau Fire TV, berfungsi secara berbeza dan tidak dapat dikawal oleh apl ini. Lihat Tetapan → Bantuan untuk butiran lanjut.
```

## Bug log (one line per pattern)

Copy this table into `docs/knowledge/status.md` → "Next up" when the first pattern appears:

| Pattern | Category | First seen | Reviews | Platform and version | Crashlytics issue | Status |
|---|---|---|---|---|---|---|
