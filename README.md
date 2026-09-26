# Plate Check: food tracker

A personal Android app for tracking food, built to stop overeating. It's
written in [Flutter](https://flutter.dev). No account, no server, and no data
leaves the phone.

## What it does

- **Yours.** A three-screen first run: your name and photo, what you eat
  (veg, egg, non-veg), and what's in your kitchen (a typical kitchen is ticked
  already). These are asked once; change them any time from **Me**.
- **Low, medium or high calorie plan.** Your daily limit comes from age, sex,
  height, weight and activity (Mifflin–St Jeor). Low is about 500 kcal under
  what you burn, never below 1200/1500. Medium matches what you burn. High is
  about 300 over, meant for very active days or building muscle. You can also
  set your own number.
- **Quick-pick Indian foods.** About 80 common South Indian and Indian items
  in a list grouped by kind of food: tap ADD, adjust with − / +, then add
  everything from the green bar at the bottom. Your five most recent foods
  come first, and you can add your own. Each food's icon is tinted by how
  calorie-dense it is: green low, amber medium, pink high.
- **Easy to correct.** Every log and every removal shows *Undo* for a few
  seconds. Tap a logged food on Today to change how much you ate. Swipe
  Today left or right to move between days.
- **Every food labelled low, medium or high.** Per portion: up to 100 kcal is
  low, 101–250 medium, over 250 high. On the Low plan (or when a meal would
  take you over), a high-calorie pick offers a lighter swap, like chapati for
  parotta, or half a portion.
- **Hunger check where it matters.** Snacks, and meals well away from their
  usual time, get a one-tap "how hungry are you?". At 1–2 it suggests water and
  a 10-minute wait, then reminds you. Meals at their usual time are never asked.
- **Diet plan from your kitchen.** A day of South Indian meals sized to your
  limit: more idli or rice on a bigger limit, and more dal and vegetables
  rather than a pile of chapatis. It only uses what you have ("Poriyal (beans,
  carrot)"). *Another option* swaps a meal; *I ate this* logs it in one tap.
- **Move.** Steps from the phone's step sensor, workouts added in two taps
  (yoga, surya namaskar, walk, cycling…), and calories burnt from MET values:
  (MET − 1) × kg × hours, and 0.0004 kcal × kg per step above 2,500 a day.
  With "add calories I burn" on, the limit starts from a desk-job baseline and
  grows with what you burn, so nothing is counted twice.
- **Progress.** Streak and weekly stats, a 14-day chart against your limit, a
  donut of calories from low / medium / high foods, a split by meal, and
  plain-language insights. Charts appear after three days of logging; each
  morning, Today says in one line how yesterday went.

## Install on your Android phone

1. On your phone, open
   **<https://github.com/yas369/food-tracker/releases/latest/download/plate-check.apk>**.
2. Open the downloaded file. If Android asks, allow your browser to
   *install unknown apps* (a one-time switch).
3. Install it over the earlier version: don't uninstall first, or your log is
   erased.

Every push to `main` builds a new APK (GitHub Actions → *Android APK*) and
publishes it at the same link.

## Your data

Everything is one JSON file in the app's private storage,
`plate-check-state.json`, which Android's own backup covers. Every change is
saved immediately (written to a temporary file and renamed, so a crash can't
leave half a file). *Export backup* opens the share sheet; *Import backup*
restores one.

**Moving from the earlier version.** Versions before 2.0 were a web page
inside the app. On first start, 2.0 picks up their data automatically: it reads
the same save file if there is one, and otherwise recovers the data from that
version's browser storage (a hidden WebView at the old address reads it back
once). Backups from the earlier version import unchanged.

Calorie values are approximate home-style portions and can be off by 20% or
more. Oil and ghee cause most of the error, which is why they have their own
entries.

## Reminders

One per meal per day for the next 14 days, re-planned whenever you open the
app or log something. They fire with the app closed and survive a restart.
Logging a meal cancels that day's reminder for it, and today's reminders show
today's remaining calories. If you don't open the app for two weeks they run
out, and the last one tells you so. Android 12+ may delay them by a few
minutes unless you allow *Alarms & reminders*, which the Me screen offers.

## Steps

The phone's step counter reports steps since the phone last started. The app
keeps the last reading and credits the difference to the right days (split
across midnight by time, with restarts detected from `/proc/uptime`). On some
phones the counter only counts reliably if the app is opened about once a day.

Each time the app comes back to the screen it checks the "Physical activity"
permission again and restarts the sensor if it had stopped, so allowing it in
Android settings takes effect straight away. If Android has blocked the
permission (after it was refused twice), Move offers *Open settings*. Until the
first reading arrives, Move says it's waiting for the sensor; if steps typed
in from a watch are higher than the phone's count, it says that too.

Distance is steps × stride. The app doesn't use GPS or your location. Until
you measure it, stride is estimated as 41.5% of your height, which is within
10–15% for most people. *Move → Settings → Stride length → Measure* has you walk
a distance you know (100 m or more): the phone counts the steps between
*Start* and *Stop*, or you type in steps you counted, and distance uses your
real stride from then on. Distance is only shown; calories burnt come from
steps and workouts.

## Working on it

```
flutter pub get
flutter analyze
flutter test          # calculations, and the main screens on a phone-sized screen
flutter run           # on a connected phone
flutter build web     # a browser copy of the same app, handy for a quick look
```

| Path | What's there |
| --- | --- |
| `lib/models.dart` | Saved data; the JSON shape matches the earlier version |
| `lib/logic.dart` | Limits, calories, diet sizing, steps: pure and unit-tested |
| `lib/data/` | Foods, tips, meals, plans, workouts, kitchen items, diet options |
| `lib/store.dart` | App state and every change to it; saves and re-plans reminders |
| `lib/reminders.dart` | Which reminders to schedule |
| `lib/services/` | Storage, old-data recovery, notifications, step sensor |
| `lib/ui/` | Theme, shared widgets, icons and the screens. The app uses Material icons only, never emoji (a test checks) |
| `test/` | Unit tests and screen tests (including a 360 px-wide phone in both themes) |

### The signing key

`android/app/plate-check.keystore` is committed on purpose, and it's the same
key the earlier version used. Android only installs an update signed with the
same key as the app already on the phone. With a new key per build, every
update would mean uninstalling, which erases your log. The trade-off is that
anyone who can read this repo could sign an APK as "Plate Check". That's
harmless as long as you only install from your own releases link. Before ever
publishing to the Play Store, generate a new key and keep it out of the repo
(GitHub Actions secrets).
