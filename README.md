# Plate Check: food tracker

A personal Android app for tracking food, built to stop overeating. No
account, no server, and no data leaves the phone.

## What it does

- **Low, medium or high calorie plan.** Your daily limit comes from age, sex,
  height, weight and activity (Mifflin–St Jeor). Low is about 500 kcal under
  what you burn, never below 1200/1500. Medium matches what you burn. High is
  about 300 over, meant for very active days or building muscle. You can also
  set your own number.
- **Every food labelled low, medium or high.** Per portion: up to 100 kcal is
  low, 101–250 medium, over 250 high. You can filter by level. On the Low plan
  (or when a meal would take you over), picking a high-calorie food offers a
  lighter swap, like chapati for parotta, or half a portion.
- **Diet plan: what to eat and how much.** A day of South Indian meals
  (breakfast, lunch, snack, dinner) for Veg, Egg or Non-veg, with portions
  sized so the day fits your limit: more idli or rice on a bigger limit, and
  more dal and vegetables rather than a pile of chapatis. Rounding never takes
  a meal over its share. Options rotate daily; *Another option* swaps one, and
  *I ate this* logs the whole meal in one tap. Empty meals on Today show the
  plan's suggestion too. A plate guide shows the half vegetables / quarter
  grains / quarter protein split (ICMR-NIN "My Plate for the Day").
- **Yours.** A three-screen first run: your name and photo, what you eat
  (veg, egg, non-veg), and what's in your kitchen (a typical kitchen is ticked
  already). The app greets you by name; the photo is cropped to 256 px and
  stored on the phone.
- **Plans from your kitchen.** The diet plan only uses what you have: no
  batter means no idli, and fruit, nuts and vegetables are named from your
  kitchen ("Poriyal (beans, carrot)").
- **Move.** Steps from the phone's step sensor (Android app), workouts added
  in two taps (yoga, surya namaskar, walk, cycling…), and calories burnt from
  MET values: (MET − 1) × kg × hours, and 0.0004 kcal × kg per step above
  2,500 a day. With "add calories I burn" on, the limit starts from a
  desk-job baseline and grows with what you burn, so nothing is counted twice.
- **Quick-pick Indian foods.** About 80 common South Indian and Indian items
  (idli, dosa, sambar, biryani, sundal, filter coffee…) as a shop-style grid:
  tap ADD, adjust with − / +, then add everything from the green bar at the bottom.
  Recent foods come first, and you can add your own.
- **Hunger check before logging.** A 1–5 scale. At 1–2 it suggests water and a
  10-minute wait, then checks back.
- **Warnings before you eat, not after.** The add button shows where the meal
  takes your day ("2,110 of 1,990 kcal. Could you eat half?"), and there are
  banners at 80% and 100%.
- **Diet-quality nudges.** Flags too many fried or sweet items, no
  vegetables, no protein, repeated eating when not hungry, late-night eating.
- **Daily "Why it matters" tip.** Worded only as strongly as its source (WHO,
  ICMR-NIN) supports.
- **Progress.** Streak and weekly stats, a 14-day chart against your limit, a
  donut of calories from low / medium / high foods, a split by meal, and
  plain-language insights.

## Install on your Android phone

1. On your phone, open
   **<https://github.com/yas369/food-tracker/releases/latest/download/plate-check.apk>**.
2. Open the downloaded file. If Android asks, allow your browser to
   *install unknown apps* (a one-time switch).
3. Open Plate Check, fill in Settings, then tap **Turn on reminders**. For
   reminders exactly on time, also tap **Allow on-time reminders**.

Every push to `main` builds a new APK (GitHub Actions → *Android APK*) and
publishes it at the same link. Install it over the old one; your data stays.

## Reminders

In the Android app, reminders are real scheduled notifications: one per meal
per day for the next 14 days, re-planned every time you open the app or log
something. They fire with the app closed and survive a restart. Logging a meal
cancels that day's reminder for it, and today's reminders show today's
remaining calories. If you don't open the app for two weeks they run out, and
the last one tells you so.

Android 12+ may delay them by a few minutes unless you grant *Alarms &
reminders*, which the Settings screen offers.

The web version (`www/` on any static host) can't schedule notifications while
closed, so it falls back to a calendar export (`.ics` / Google Calendar links)
and notifications while open.

## Data

Everything lives on the phone. In the Android app every save goes to
localStorage *and* to a file in the app's private storage
(`plate-check-state.json`), which Android's own backup covers. On start the
newer copy wins, so a WebView storage wipe doesn't lose your log. Nothing is
sent anywhere. Uninstalling or clearing the app's data erases it, so use Settings →
*Export backup* (it opens the share sheet, so you can save it to Drive or send it
to yourself). *Import backup* restores it.

Calorie values are approximate home-style portions and can be off by 20% or
more. Oil and ghee cause most of the error, which is why they have their own
entries.

## How it's built

The app is one web page (`www/index.html`) wrapped as a native Android app
with [Capacitor](https://capacitorjs.com). It has no build step and no
framework. Native features come from Capacitor plugins: local notifications,
the Android back button, file export and sharing.

| Path | Purpose |
| --- | --- |
| `www/index.html` | The whole app: markup, styles, food list, logic |
| `www/capacitor.js` | Capacitor's browser runtime, copied from `node_modules` by `npm run sync` (CI checks it matches) |
| `www/sw.js`, `www/manifest.webmanifest` | Offline cache and install metadata for the web version only |
| `android/` | The Android project Capacitor generated, with this app's icons and signing |
| `.github/workflows/android.yml` | Builds the APK and publishes the release |

To change the app: edit `www/index.html`, run `npm install && npm run sync`,
and push. To try the web version locally, run `npm run serve` and open
<http://localhost:8000>.

### The signing key

`android/app/plate-check.keystore` is committed on purpose. Android only
installs an update signed with the same key as the app already on the phone.
With a new key per build, every update would mean uninstalling, which erases
your log. The trade-off is that anyone who can read this repo could sign an APK
as "Plate Check". That's harmless as long as you only install from your own
releases link. Before ever publishing to the Play Store, generate a new key and
keep it out of the repo (GitHub Actions secrets).
