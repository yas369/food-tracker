# Plate Check 1.0: the original web app

These are the files of the first version of Plate Check, a small installable
web app, exactly as they were served from the Happy Yogis site at
`/food-tracker/`. They were removed from that repository when the app moved
here, and are kept for reference only.

They are not part of the current app, which is the Flutter Android app in
this repository (`lib/`, `android/`). Nothing builds or ships these files.

The same version is also this repository's first commit (`093d6e7`), where
it sits at the root. The only difference: here, `sw.js` looks for the app
under `/food-tracker/` (where the site served it), while that commit uses the
service worker's own scope.

Anything logged with this version on the website stayed in that phone
browser's storage for the site; the Android app can't see it. (The app does
pick up data from its own earlier Android version automatically.)
