# Publishing LibreScan to Google Play — checklist

Everything in this checklist that can be prepared without a Play Console
account is done. The remainder needs your own Google Play Developer account
— that's a hard requirement from Google (identity verification + a one-time
$25 fee), not something that can be done on your behalf.

## ✅ Already done

- [x] **Signed release bundle**: `build/app/outputs/bundle/release/app-release.aab`
      (67MB), signed with a real upload key (not debug) — verified with
      `jarsigner -verify`. This is the exact file you upload to Play Console.
- [x] **App icon**: adaptive icon wired up for the app itself, plus a
      store-listing hi-res icon at `store_assets/play_icon_512.png` (512×512).
- [x] **Feature graphic**: `store_assets/feature_graphic.png` (1024×500).
- [x] **Screenshots**: 3 real on-device screenshots in
      `store_assets/screenshots/` (scan, multi-page session, export). Play
      requires a minimum of 2 — you can add more later from the device any
      time; it accepts up to 8.
- [x] **Privacy policy**, published and ready to link:
      https://claude.ai/code/artifact/6dac47d6-096a-486c-b9dc-8c6e895ce9ce
      **⚠️ Before using this link in Play Console: open it and click Share
      in the page's menu.** Artifacts publish private by default; Google's
      reviewers (and anyone checking the link from the store listing) need
      it to be a public URL, not one gated behind your own login.
- [x] **Store listing copy** (app name, short/full description, category,
      contact email): `store_assets/store_listing.md` — copy-paste ready,
      checked against Play Console's current character limits.
- [x] Compiles clean (`flutter analyze`: 0 issues) and passes its test suite
      (`flutter test`: 9/9) as of this build.

## Your turn: account + submission

### 1. Create a Google Play Developer account (one-time, ~$25)
https://play.google.com/console/signup — needs a Google account, a payment
method for the one-time registration fee, and identity verification (Google
has been requiring a D-U-N-S number or government ID verification for new
individual accounts since late 2023 — this can take a few days to clear, so
start this step first if you want to publish soon).

### 2. Create the app
Play Console → **Create app** →
- App name: `LibreScan`
- Default language: English (or your choice)
- App or game: **App**
- Free or paid: **Free**
- Accept the declarations (Developer Program Policies, US export laws)

### 3. Fill in "App content" (Play Console's policy questionnaire)
This is a short questionnaire Play Console walks you through; here's what to
answer for every section, since I know exactly what this app does and
doesn't do:

| Section | Answer |
|---|---|
| Privacy policy | Paste the artifact URL above (after sharing it) |
| Ads | **No**, the app does not contain ads |
| App access | **All functionality is available without special access** (no login) |
| Content ratings (IARC questionnaire) | Answer "No"/"None" to every category (violence, sexual content, gambling, etc.) — this is a document scanner with no such content. Should land at **Everyone**/**3+**-equivalent. |
| Target audience and content | Select an adult age range (e.g. 18+) or the broadest non-children range offered; do **not** mark it as primarily for children — that triggers the stricter Families policy and isn't the right fit for a general-purpose utility |
| News apps | **No** |
| COVID-19 contact tracing/status apps | **No** |
| Data safety | See below |
| Government apps | **No** |
| Financial features | **No** |

**Data safety section specifically** — Play Console will ask what data the
app collects/shares. Answer:
- Does your app collect or share any of the required user data types? **No**
- That's it — because it's true. The camera permission is used, but no
  photo or any other data is collected, transmitted, or shared anywhere; a
  camera permission alone doesn't require a "collects data" answer under
  Play's data-safety definitions as long as nothing captured is transmitted
  off-device, which is the case here (see the published privacy policy for
  the full explanation if a reviewer asks).

### 4. Store listing
Play Console → **Grow → Store presence → Main store listing**. Paste in:
- App name, short description, full description — from `store_listing.md`
- App icon — upload `store_assets/play_icon_512.png`
- Feature graphic — upload `store_assets/feature_graphic.png`
- Phone screenshots — upload all 3 from `store_assets/screenshots/`
- Category — Tools or Productivity (your call; `store_listing.md` has notes)
- Contact email — `shubhambansal500@gmail.com`

### 5. Upload the app bundle
Play Console → **Release → Production** (or start with **Internal testing**
if you'd rather try it with a small group first — recommended for a first
release) → **Create release** → upload
`build/app/outputs/bundle/release/app-release.aab`.

Play Console will prompt you to enroll in **Play App Signing** — accept
this (it's required for AAB uploads anyway). Google will manage the actual
distribution signing key; your `upload-keystore.jks` continues to be the
*upload* key you sign future bundles with before sending them to Google.
**Back up `android/upload-keystore.jks` and the password in
`android/key.properties` somewhere durable now, if you haven't** — losing
the upload key means Google support has to manually help you re-associate a
new one, which is slow.

### 6. Pricing & distribution
Mark it **Free**, pick the countries you want it available in (or "all
countries"), confirm the content guidelines/export compliance checkboxes.

### 7. Submit for review
Once every section above shows a green checkmark in Play Console's
left-hand checklist, hit **Submit for review**. Google's review for a new
app typically takes a few hours to a few days (sometimes up to ~7 for a
first-time publisher) — it can also get flagged for manual review the first
time, which takes longer.

## Updating the app later

Every time you want to ship an update:
```bash
# bump pubspec.yaml's `version:` line first, e.g. 0.1.0+1 -> 0.2.0+2
flutter build appbundle --release
```
Then Play Console → your app → **Production → Create new release** →
upload the new `.aab`. The version code (the number after `+`) must
increase every time; Play Console will reject a re-upload with the same or
lower version code.
