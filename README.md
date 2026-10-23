# 👀 WiFiWatch

A tiny macOS menu bar app that sends you a push notification when your internet stops working. Built for people who work off a phone hotspot (in the car, on a train, wherever) and want to know the moment the connection dies.

It lives in the menu bar as a 👀, hidden from the Dock, much like Amphetamine.

## Why

Phone hotspots have an annoying failure mode: your Mac stays "connected" to Wi-Fi, the icon looks fine, but nothing actually loads. WiFiWatch doesn't just watch the Wi-Fi status. It checks that the internet is really reachable.

## Features

- **Real internet check.** Fetches a small Apple test page every 5 seconds, so it catches "connected but dead" hotspots.
- **Instant Wi-Fi change detection.** Uses `NWPathMonitor` to re-check immediately when the network changes.
- **Low false alarms.** Waits for two failed checks in a row (about 5-10 seconds) before alerting.
- **Native notifications** when the connection drops and when it returns, including how long you were offline.
- **Menu bar only.** No Dock icon, no windows.
- **Menu options:** pause/resume, toggle back-online notifications, launch at login.
- **No dependencies.** One Swift file, built with the command line tools.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools: `xcode-select --install`

## Build and run

```bash
git clone https://github.com/aliengummybear7323/WiFiWatch.git
cd WiFiWatch
chmod +x build.sh
./build.sh
open WiFiWatch.app
```

macOS will ask for permission to send notifications the first time. Click **Allow**.

For everyday use, drag `WiFiWatch.app` into `/Applications`, open it from there, and tick **Launch at Login** in the 👀 menu.

### Custom app icon (optional)

Put an `AppIcon.icns` file next to `build.sh` and rebuild. The script bundles it automatically and it will show up in Finder, Spotlight, and notification banners.

## Usage

Click the 👀 in the menu bar to see the current status (Online, Offline, Checking, or Paused) and the options:

| Item | What it does |
| --- | --- |
| Status line | Shows the current connection state |
| Pause / Resume Monitoring | Stops or restarts checks (handy when you're deliberately offline) |
| Notify When Back Online | Toggles the "back online" notification |
| Launch at Login | Starts WiFiWatch automatically when you log in |
| Quit | Exits the app |

### Tips

- In **System Settings → Notifications → WiFiWatch**, set the style to **Alerts** if you want notifications to stay on screen until dismissed.
- To get notifications through Focus or Do Not Disturb, add WiFiWatch to that Focus mode's allowed apps.

## How it works

1. A timer fires every 5 seconds, and `NWPathMonitor` fires on any network change.
2. Each trigger requests `https://www.apple.com/library/test/success.html` with a 4-second timeout and checks for a 200 response containing "Success".
3. Two consecutive failures mark the connection as down and send a notification. The next success marks it as back up.

## Customizing

All the settings are in `WiFiWatch.swift`:

- **Check interval:** change `withTimeInterval: 5` in `applicationDidFinishLaunching`.
- **Failures before alerting:** change `failures >= 2` in `handle(ok:)`.
- **Request timeout:** change `timeoutIntervalForRequest` at the top of the file.
- **Menu bar emoji:** change `"👀"` in `updateIcon()`.

## Troubleshooting

- **No notifications.** Check System Settings → Notifications → WiFiWatch and make sure they're allowed.
- **Icon still looks blank.** macOS caches icons. Run `killall Dock Finder`, or move the app to `/Applications`.
- **Launch at Login doesn't stick.** Move the app to `/Applications` first, then enable it.
- **Captive portals** (hotel or airport Wi-Fi sign-in pages) count as offline until you've signed in, since the test page won't return "Success".

## License

MIT. See `LICENSE` if you add one, or choose whichever license you prefer.
