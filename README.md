# Plate Check: food tracker

A personal food tracker built to stop overeating. It's a single-page web app
you install to your phone's home screen. There's no server, no login and no
build step.

## What it does

- **Daily calorie limit.** Estimated from age, sex, height, weight and
  activity (Mifflin–St Jeor, about 400 kcal below maintenance to lose weight,
  never below 1200/1500). You can override it.
- **Quick-pick Indian foods.** About 80 common South Indian and Indian items
  (idli, dosa, sambar, biryani, sundal, filter coffee…) with typical
  home-portion calories, recent foods at the top, and custom foods.
- **Hunger check before logging.** A 1–5 scale. At 1–2 it suggests water and a
  10-minute wait, then checks back.
- **Warnings before you eat, not after.** The add button shows where the meal
  takes your day ("2,110 of 1,990 kcal. Could you eat half?"), and there are
  banners at 80% and 100%.
- **Diet-quality nudges.** Flags too many fried or sweet items, no
  vegetables, no protein, repeated eating when not hungry, late-night eating.
- **Daily "Why it matters" tip.** Worded only as strongly as its source (WHO,
  ICMR-NIN) supports.
- **History.** A 14-day chart against the limit, 7-day stats, and plain-language
  insights (biggest meal, % eaten without hunger, top calorie source).

## Reminders

A web app with no server cannot guarantee a notification at a fixed time while
it's closed, so reminders go through three routes, most reliable first:

1. **Calendar.** Settings → *Download calendar file (.ics)* (iPhone: open it,
   tap *Add All*) or the per-meal Google Calendar links (Android). Your
   calendar alerts you every day.
2. **In-app notifications.** These fire while the app is open or was recently
   used. On iPhone they need the app added to the Home Screen first.
3. **Background checks.** Periodic Background Sync, available only for the
   installed app in Chrome on Android. The browser decides when it runs.

## Data

Everything lives in the browser's `localStorage` on your phone. Nothing is
sent anywhere. Clearing browser data or changing phones erases it, so use
Settings → *Export backup*.

Calorie values are approximate home-style portions and can be off by 20% or
more. Oil and ghee cause most of the error, which is why they have their own
entries.

## Run it

Open `index.html` through any static server (the service worker needs
`http://localhost` or HTTPS):

```
python3 -m http.server 8000
```

To deploy, put the folder on any static host (Vercel, Netlify, GitHub Pages).
All paths are relative, so it works at a domain root or in a subfolder.

| File | Purpose |
| --- | --- |
| `index.html` | The whole app: markup, styles, food list, logic |
| `sw.js` | Offline cache, notification clicks, background reminder checks |
| `manifest.webmanifest` | Install-to-home-screen metadata |
| `icon.svg`, `icon-192.png`, `icon-512.png` | App icons |
